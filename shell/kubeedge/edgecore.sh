#!/bin/bash                                                                                                                                                                                               
# @Author: zhoubin<2350686113@qq.com>
# @Email: 2350686113@qq.com
# @Date: 2022-04-29
# @Last modified by: zhoubin
# @Last modified by time: 2022-04-29
# @Descriptions: Edgecore 服务安装脚本

# shellcheck disable=SC2129

export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

# 脚本相关信息
__ScriptVersion="2022.04.29"
__ScriptName="edgecore.sh"
__ScriptFullName="$0"
__ScriptArgs="$#"

BS_TRUE=0
BS_FALSE=1

# keadm 加入集群的参数
FTP_SERVER=${FTP_SERVER:-ftp.59izt.com}
FTP_USERNAME=${FTP_USERNAME:-'username'}
FTP_PASSWD=${FTP_PASSWD:-'passwd'}

TOKEN=$1

KubeEdgeVersion=${KubeEdgeVersion:-1.9.2}
CloudCoreIP=${CloudCoreIP:-1.1.1.1}
CloudCorePort=${CloudCorePort:-10000}

# whoami alternative for SunOS
if [ -f /usr/xpg4/bin/id ]; then
    whoami='/usr/xpg4/bin/id -un'
else
    whoami='whoami'
fi

# Root permissions are required to run this script
if [ "$($whoami)" != "root" ]; then
    echoerror "Edgecore requires root privileges to install. Please re-run this script as root."
    exit 1
fi

# 配置控制台颜色支持
#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  __detect_color_support
#   DESCRIPTION:  Try to detect color support.
#----------------------------------------------------------------------------------------------------------------------
_COLORS=${BS_COLORS:-$(tput colors 2>/dev/null || echo 0)}
__detect_color_support() {
    # shellcheck disable=SC2181
    if [ $? -eq 0 ] && [ "$_COLORS" -gt 2 ]; then
        RC='\033[1;31m'
        GC='\033[1;32m'
        BC='\033[1;34m'
        YC='\033[1;33m'
        EC='\033[0m'
    else
        RC=""
        GC=""
        BC=""
        YC=""
        EC=""
    fi
}
__detect_color_support

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  echoerr
#   DESCRIPTION:  错误信息输出
#----------------------------------------------------------------------------------------------------------------------
echoerror() {
    printf "${RC} * ERROR${EC}: %s\\n" "$@" 1>&2;
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  echoinfo
#   DESCRIPTION:  正常信息输出
#----------------------------------------------------------------------------------------------------------------------
echoinfo() {
    printf "${GC} *  INFO${EC}: %s\\n" "$@";
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  echowarn
#   DESCRIPTION:  告警信息输出.
#----------------------------------------------------------------------------------------------------------------------
echowarn() {
    printf "${YC} *  WARN${EC}: %s\\n" "$@";
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  echodebug
#   DESCRIPTION: 调试信息输出.
#----------------------------------------------------------------------------------------------------------------------
echodebug() {
    if [ "$_ECHO_DEBUG" -eq $BS_TRUE ]; then
        printf "${BC} * DEBUG${EC}: %s\\n" "$@";
    fi
}

# 设置日志输出文件以及日志输出管道
LOGFILE="/tmp/$( echo "$__ScriptName" | sed s/.sh/.log/g )"
LOGPIPE="/tmp/$( echo "$__ScriptName" | sed s/.sh/.logpipe/g )"

# 删除残留的旧管道
rm "$LOGPIPE" 2>/dev/null

# 创建日志输出管道
# On FreeBSD we have to use mkfifo instead of mknod
if ! (mknod "$LOGPIPE" p >/dev/null 2>&1 || mkfifo "$LOGPIPE" >/dev/null 2>&1); then
    echoerror "Failed to create the named pipe required to log"
    exit 1
fi

# 将日志管道中的信息写入到日志文件中
tee < "$LOGPIPE" "$LOGFILE" &

# 关闭标准输出，然后将其重新打开并重定向到日志输出管道
exec 1>&-
exec 1>"$LOGPIPE"

# 关闭错误输出，然后将其重新打开并重定向到日志输出管道
exec 2>&-
exec 2>"$LOGPIPE"

# 检查系统软件包管理工具
if [ -e "/usr/bin/yum" ]; then
  PM=yum
  if [ -e /etc/yum.repos.d/CentOS-Base.repo ] && grep -Eqi "release 6." /etc/redhat-release; then
    sed -i "s@centos/\$releasever@centos-vault/6.10@g" /etc/yum.repos.d/CentOS-Base.repo
    sed -i 's@centos/RPM-GPG@centos-vault/RPM-GPG@g' /etc/yum.repos.d/CentOS-Base.repo
    [ -e /etc/yum.repos.d/epel.repo ] && rm -f /etc/yum.repos.d/epel.repo
  fi
  if ! command -v lsb_release >/dev/null 2>&1; then
    if [ -e "/etc/euleros-release" ]; then
      yum -y install euleros-lsb
    elif [ -e "/etc/openEuler-release" -o -e "/etc/openeuler-release" ]; then
      if [ -n "$(grep -w '"20.03"' /etc/os-release)" ]; then
        rpm -Uvh https://repo.openeuler.org/openEuler-20.03-LTS-SP1/everything/aarch64/Packages/openeuler-lsb-5.0-1.oe1.aarch64.rpm
      else
        yum -y install openeuler-lsb
      fi
    else
      yum -y install redhat-lsb-core
    fi
    clear
  fi
fi

if [ -e "/usr/bin/apt-get" ]; then
  PM=apt-get
  command -v lsb_release >/dev/null 2>&1 || { apt-get -y update > /dev/null; apt-get -y install lsb-release; clear; }
fi

command -v lsb_release >/dev/null 2>&1 || { echoerror "source failed!"; kill -9 $$; }

# 获取系统类型
OS=$(lsb_release -is)
if [[ "${OS}" =~ ^CentOS$|^CentOSStream$|^RedHat$|^Rocky$|^Fedora$|^Amazon$|^AlibabaCloud\(AliyunLinux\)$|^EulerOS$|^openEuler$ ]]; then
  LikeOS=CentOS
  CentOS_ver=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
  [[ "${OS}" =~ ^Fedora$ ]] && [ ${CentOS_ver} -ge 19 >/dev/null 2>&1 ] && { CentOS_ver=7; Fedora_ver=$(lsb_release -rs); }
  [[ "${OS}" =~ ^Amazon$|^EulerOS$|^openEuler$ ]] && CentOS_ver=7
  [[ "${OS}" =~ ^AlibabaCloud\(AliyunLinux\)$ ]] && [[ "${CentOS_ver}" =~ ^2$ ]] && CentOS_ver=7
  [[ "${OS}" =~ ^AlibabaCloud\(AliyunLinux\)$ ]] && [[ "${CentOS_ver}" =~ ^3$ ]] && CentOS_ver=8
elif [[ "${OS}" =~ ^Debian$|^Deepin$|^Uos$|^Kali$ ]]; then
  LikeOS=Debian
  Debian_ver=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
  [[ "${OS}" =~ ^Deepin$|^Uos$ ]] && [[ "${Debian_ver}" =~ ^20$ ]] && Debian_ver=10
  [[ "${OS}" =~ ^Kali$ ]] && [[ "${Debian_ver}" =~ ^202 ]] && Debian_ver=10
elif [[ "${OS}" =~ ^Ubuntu$|^LinuxMint$|^elementary$ ]]; then
  LikeOS=Ubuntu
  Ubuntu_ver=$(lsb_release -rs | awk -F. '{print $1}' | awk '{print $1}')
  if [[ "${OS}" =~ ^LinuxMint$ ]]; then
    [[ "${Ubuntu_ver}" =~ ^18$ ]] && Ubuntu_ver=16
    [[ "${Ubuntu_ver}" =~ ^19$ ]] && Ubuntu_ver=18
    [[ "${Ubuntu_ver}" =~ ^20$ ]] && Ubuntu_ver=20
  fi
  if [[ "${OS}" =~ ^elementary$ ]]; then
    [[ "${Ubuntu_ver}" =~ ^5$ ]] && Ubuntu_ver=18
    [[ "${Ubuntu_ver}" =~ ^6$ ]] && Ubuntu_ver=20
  fi
fi

# 检查系统版本
if [ ${CentOS_ver} -lt 6 >/dev/null 2>&1 ] || [ ${Debian_ver} -lt 8 >/dev/null 2>&1 ] || [ ${Ubuntu_ver} -lt 16 >/dev/null 2>&1 ]; then
  echoerror "Does not support this OS, Please install CentOS 6+,Debian 8+,Ubuntu 16+"
  kill -9 $$
fi

# 检查 gcc库信息
command -v gcc > /dev/null 2>&1 || $PM -y install gcc
gcc_ver=$(gcc -dumpversion | awk -F. '{print $1}')

# 检查系统架构
if uname -m | grep -Eqi "arm|aarch64"; then
  armplatform="y"
  if uname -m | grep -Eqi "armv7"; then
    TARGET_ARCH="armv7"
  elif uname -m | grep -Eqi "armv8"; then
    TARGET_ARCH="arm64"
  elif uname -m | grep -Eqi "aarch64"; then
    TARGET_ARCH="aarch64"
  else
    TARGET_ARCH="unknown"
  fi
fi

# 检查是否为 Windows 子系统
if [ "$(uname -r | awk -F- '{print $3}' 2>/dev/null)" == "Microsoft" ]; then
  Wsl=true
fi

# 检查系统位数
if [ "$(getconf WORD_BIT)" == "32" ] && [ "$(getconf LONG_BIT)" == "64" ]; then
  OS_BIT=64
  SYS_BIT_j=x64
  SYS_BIT_a=x86_64
  SYS_BIT_b=x86_64
  SYS_BIT_c=x86_64
  SYS_BIT_d=x86-64
  SYS_BIT_n=x64
  [ "${TARGET_ARCH}" == 'aarch64' ] && { SYS_BIT_j=aarch64; SYS_BIT_c=aarch64; SYS_BIT_d=aarch64; SYS_BIT_n=arm64; }
else
  OS_BIT=32
  SYS_BIT_j=i586
  SYS_BIT_a=x86
  SYS_BIT_b=i686
  SYS_BIT_c=i386
  SYS_BIT_d=x86
  SYS_BIT_n=x86
  [ "${TARGET_ARCH}" == 'armv7' ] && { SYS_BIT_j=arm32-vfp-hflt; SYS_BIT_c=armhf; SYS_BIT_d=armv7l; SYS_BIT_n=armv7l; }
fi

# CPU 线程数
THREAD=$(grep 'processor' /proc/cpuinfo | sort -u | wc -l)


#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  __yum_install_noinput
#   DESCRIPTION:  (DRY) yum install with noinput options
#----------------------------------------------------------------------------------------------------------------------
__yum_install_noinput(){
    for package in "${@}"; do
        echoinfo "正在安装软件 ${package} ..."
        yum install -y "${package}" || return $?

        [[ $? -ne $BS_TRUE ]] && echoerror "${package} 安装失败！" || echoinfo "${package} 安装完成."
    done
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  __install_noinput
#   DESCRIPTION:  (DRY) install with noinput options
#----------------------------------------------------------------------------------------------------------------------
__install_noinput(){
    for package in "${@}"; do
        echoinfo "正在安装软件 ${package} ..."
        $PM install -y "${package}" || return $?

        [[ $? -ne $BS_TRUE ]] && echoerror "${package} 安装失败！" || echoinfo "${package} 安装完成."
    done
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  __modify_repo_mirror
#   DESCRIPTION:  修改软件管理仓库镜像源
#----------------------------------------------------------------------------------------------------------------------
__modify_repo_mirror(){
    if [[ $LikeOS == "CentOS" ]];then
        echoinfo "开始配置 YUM 镜像源..."
        mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
        curl -o /etc/yum.repos.d/CentOS-Base.repo -sSL http://mirrors.aliyun.com/repo/Centos-7.repo
        curl -o /etc/yum.repos.d/epel.repo -sSL http://mirrors.aliyun.com/repo/epel-7.repo
        curl -o /etc/yum.repos.d/CentOS7-Base-163.repo -sSL http://mirrors.163.com/.help/CentOS7-Base-163.repo
        yum clean all && yum makecache || return 1
        [[ $? -ne $BS_TRUE ]] && echoerror "YUM  镜像源修改失败!" || echoinfo "YUM 镜像源已修改完成."       
    elif [[ $LikeOS == "Ubuntu" ]];then
        echoinfo "开始配置 APT 镜像源..."
        mv /etc/apt/sources.list /etc/apt/sources.list.bak
        curl -o /etc/apt/sources.list -u ${FTP_USERNAME}:${FTP_PASSWD} -sSL http://${FTP_SERVER}/others/repos/ubuntu/sources.list
        sudo $PM update
        [[ $? -ne $BS_TRUE ]] && echoerror "APT 镜像源修改失败!" || echoinfo "APT 镜像源已修改完成."
    else
        echoerror '未知系统类型!!'
        return 1
    fi
}

#---  FUNCTION  -------------------------------------------------------------------------------------------------------
#          NAME:  __install_base_software
#   DESCRIPTION:  安装常用的基础软件
#----------------------------------------------------------------------------------------------------------------------
__install_base_software(){
    if [[ $LikeOS == "CentOS" ]];then
        echoinfo "正在安装常用的软件..."
        __install_noinput net-tools vim wget lrzsz tree telnet bash-completion epel-release ntpdate || return 1
    elif [[ $LikeOS == "Ubuntu" ]];then
        echoinfo "正在安装常用的软件..."
        __install_noinput net-tools vim wget lrzsz tree telnet bash-completion ntpdate || return 1
    else
        echoerror "未知系统类型!!"
    fi
}


# 安装常用的软件
__yum_install_base() {
    echoinfo "正在安装常用的软件..."
    __yum_install_noinput net-tools vim wget lrzsz tree telnet bash-completion epel-release ntpdate || return 1
}

# 关闭 firewalld 防火墙
__disable_firewalld(){
    if [[ $LikeOS == "CentOS" ]];then
        echoinfo "正在关闭防火墙..." 
        systemctl disable --now firewalld  >/dev/null 2>&1 || return 1
        [[ $? -ne $BS_TRUE ]] && echoerror "防火墙关闭失败!" || echoinfo "防火墙已关闭."
    elif [[ $LikeOS == "Ubuntu" ]];then
        echoinfo "正在关闭防火墙..." 
        systemctl disable --now ufw.service >/dev/null 2>&1 || return 1
        [[ $? -ne $BS_TRUE ]] && echoerror "防火墙关闭失败!" || echoinfo "防火墙已关闭."
    else
        echoerror "未知系统类型!!"
    fi
}

# 禁用 Selinux
__disable_selinux(){
    echoinfo "开始配置 Selinux..."
    SELINUX_STATUS=`getenforce`
    if [[ ${SELINUX_STATUS} =~ "^Disabled" ]];then
        echoinfo "SeLinux 已经是关闭状态."
    else
        echoinfo "正在关闭 SeLinux..."
        setenforce 0 >/dev/null 2>&1
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config || return 1
        [[ $? -ne $BS_TRUE ]] && echoerror "SeLinux 关闭失败!" || echoinfo "SELINUX 关闭成功."
    fi
}

# 关闭交换分区
__disable_swap(){
    echoinfo "开始配置关闭 swap..."
    swapoff -a && sysctl -w vm.swappiness=0 > /dev/null 2>&1
    sed -ri 's/.*swap.*/#&/' /etc/fstab
    echoinfo "swap 分区已禁用."
}

# 配置系统时区以及时间同步
__setting_tz_and_time_sync(){
    echoinfo "开始配置系统时区以及时间同步..."
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo 'Asia/Shanghai' > /etc/timezone
    echo '*/5 * * * * /usr/sbin/ntpdate time2.aliyun.com >/dev/null' >> /var/spool/cron/root
    echo '/usr/sbin/ntpdate time2.aliyun.com' >> /etc/rc.local
    ntpdate time2.aliyun.com >/dev/null 2>&1
    echoinfo "系统时区以及时间同步配置完成."
}

# 配置 yum 镜像源
__modify_yum_repo(){
    echoinfo "开始配置 YUM 仓库镜像..."
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
    wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
    wget -O /etc/yum.repos.d/CentOS7-Base-163.repo http://mirrors.163.com/.help/CentOS7-Base-163.repo

    yum clean all && yum makecache || return 1

    [[ $? -ne $BS_TRUE ]] && echoerror "YUM repo 修改失败!" || echoinfo "YUM repo 已修改完成."
}

# 配置 PS1 样式
__modify_ps_style(){
    echoinfo "开始配置 PS1 样式..."
    echo "export PS1='\[\e[37;40m\][\[\e[32;40m\]\u\[\e[37;40m\]@\[\e[33;40m\]\h \[\e[35;40m\]\W\[\e[0m\]]\\$ '" >>/etc/profile
    echoinfo "PS1 样式修改完成."
}

# 配置历史命令记录格式
__modify_history_format(){
    echoinfo "开始修改历史命令记录格式..."
    echo "export HISTTIMEFORMAT=\"%Y-%m-%d %H:%M:%S  \$(whoami)  \"" >> /etc/profile
    echo "export PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; }); logger \"[euid=\$(whoami)]\":\$(who am i):[\$(pwd)]\"\$msg\";}'" >> /etc/profile
    echoinfo "命令历史记录格式配置完成."
}

# 配置会话超时时间
__modify_session_timeout(){
    echoinfo "开始配置会话超时时间..."
    echo "export TMOUT=1800" >> /etc/profile
    echoinfo "回话超时时间已设置为 10 分钟."
}

# 修改文件描述符限制
__modify_limit(){
    echoinfo "开始配置文件 ulimit 限制..."
    ulimit -SHn 65535

    sed -i '/^# End/i\* soft nofile    655350' /etc/security/limits.conf
    sed -i '/^# End/i\* hard nofile    131072' /etc/security/limits.conf
    sed -i '/^# End/i\* soft nproc    655350' /etc/security/limits.conf
    sed -i '/^# End/i\* hard nproc    655350' /etc/security/limits.conf
    sed -i '/^# End/i\* soft memlock   unlimited' /etc/security/limits.conf
    sed -i '/^# End/i\* hard memlock   unlimited' /etc/security/limits.conf
    echoinfo "ulimit 限制配置完成."
}

# 配置 ipvs 模块
__config_ipvs_modules(){
echoinfo "安装 ipvs,ipset,sysstat,conntrack 等依赖软件..."
__yum_install_noinput ipvsadm ipset sysstat conntrack libseccomp jq psmisc || return 1

echo

echoinfo "开始配置 ipvs 模块..."
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_lc
modprobe -- ip_vs_wlc
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_lblc
modprobe -- ip_vs_lblcr
modprobe -- ip_vs_dh
modprobe -- ip_vs_sh
modprobe -- ip_vs_fo
modprobe -- ip_vs_nq
modprobe -- ip_vs_sed
modprobe -- ip_vs_ftp
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
modprobe -- ip_tables
modprobe -- ip_set
modprobe -- xt_set
modprobe -- ipt_set
modprobe -- ipt_rpfilter
modprobe -- ipt_REJECT
modprobe -- ipip
EOF

chmod 755 /etc/sysconfig/modules/ipvs.modules
systemctl enable --now systemd-modules-load.service
bash /etc/sysconfig/modules/ipvs.modules && lsmod |grep -e ip_vs -e nf_conntrack
echoinfo "ipvs 模块配置完成."
}

# 配置内核参数
__config_kernels(){
echoinfo "开始配置内核参数..."
cat >/etc/sysctl.d/k8s.conf <<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
fs.may_detach_mounts = 1
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
fs.file-max=52706963
fs.nr_open=52706963
net.netfilter.nf_conntrack_max=2310720

net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl =15
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 327680
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_conntrack_max = 65536
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_timestamps = 0
net.core.somaxconn = 16384
EOF
sysctl --system 
echoinfo "内核参数配置完成."
}

# 安装以及配置 Docker
__install_docker(){
echoinfo "开始安装 Docker 程序依赖软件..."
__yum_install_noinput yum-utils device-mapper-persistent-data lvm2 git
echoinfo "添加 Docker 仓库..."
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sed -i 's/$releasever/7/g' /etc/yum.repos.d/docker-ce.repo
yum makecache fast
echoinfo "安装指定版本 Docker(19.03.x)..."
__yum_install_noinput docker-ce-19.03.*

if [[ $? -ne $BS_TRUE ]];then
    echoerror "Docker 安装失败! 请检查 Docker Repo 仓库配置或网络是否正常!"
else
    echoinfo "Docker 安装完成，正在配置 Docker."
    mkdir /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": [
    "https://b9pmyelo.mirror.aliyuncs.com",
    "https://registry.docker-cn.com",
    "http://hub-mirror.c.163.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "insecure-registries": ["http://10.1.40.14"],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "log-opts": {
    "max-size": "30m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF
echoinfo "启动 Docker 并配置开机启动"
systemctl enable --now docker.service
fi
}

# 安装 keadm
__install_keadm(){
    echoinfo "开始安装 keadm"

    echoinfo "*Setup1: 下载 keadm..."
    curl -O -s --basic \
        -u ${FTP_USERNAME}:${FTP_PASSWD} \
        http://${FTP_SERVER}/kubeedge/keadm-v${KubeEdgeVersion}-linux-amd64.tar.gz

    echoinfo "*Setup2: 安装 keadm..."
    if [[ -f keadm-v${KubeEdgeVersion}-linux-amd64.tar.gz ]];then
        tar xf keadm-v${KubeEdgeVersion}-linux-amd64.tar.gz
        cp -v keadm-v1.9.2-linux-amd64/keadm/keadm /usr/local/bin/
        [[ $? -ne $BS_TRUE ]] && echoerror "keadm 安装失败!" || echoinfo "keadm 安装完成."
    else
        echoerror "keadm 压缩包文件不存在，请检查是否下载文件到本地"
    fi
    
}

# 安装 yaml文件配置工具 yq
__install_yq(){
    echoinfo "开始安装 yq"
    echoinfo "*Setup1: 下载 yq 安装包"
    curl -O -s --basic \
        -u ${FTP_USERNAME}:${FTP_PASSWD} \
        http://${FTP_SERVER}/tools/yq_linux_amd64.tar.gz

    echoinfo "*Setup2: 安装 yq ..."
    if [[ -f yq_linux_amd64.tar.gz ]];then
        tar -xf yq_linux_amd64.tar.gz ./yq_linux_amd64 && mv yq_linux_amd64 /usr/local/bin/yq
        echoinfo "yq 工具安装完成."
    else
        echoerror "yq_linux_amd64.tar.gz 文件不存在！"
    fi
}

# 安装 kubeedge
__install_edgecore(){
    echoinfo "开始安装 EdgeCore..."

    [[ ! -x /usr/local/bin/keadm ]] && echoerror "keadm 命令未找到，或没有执行权限，请确认是否正确安装 keadm!" && return 1

    echoinfo '创建 /etc/kubeedge 目录'
    [[ ! -d "/etc/kubeedge" ]] && mkdir -p /etc/kubeedge/ || echo "/etc/kubeedge 已存在"

    echoinfo "开始下载 kubeedge 相关的文件"

    echoinfo "Setupr1: 下载 kubeedge checksum_文件..."
    curl -s --basic \
        -u ${FTP_USERNAME}:${FTP_PASSWD} \
        -L http://${FTP_SERVER}/kubeedge/checksum_kubeedge-v${KubeEdgeVersion}-linux-amd64.tar.gz.txt \
        -o /etc/kubeedge/checksum_kubeedge-v${KubeEdgeVersion}-linux-amd64.tar.gz.txt
    [[ $? -eq $BS_TRUE ]] && echoinfo "checksum 文件下载完成." || echoerror "kubeedge checksum 文件下载失败！"

    echoinfo "Setup2: 下载 kubeedge 文件..."
    curl -s --basic \
         -u ${FTP_USERNAME}:${FTP_PASSWD} \
         -L http://${FTP_SERVER}/kubeedge/kubeedge-v${KubeEdgeVersion}-linux-amd64.tar.gz \
         -o /etc/kubeedge/kubeedge-v${KubeEdgeVersion}-linux-amd64.tar.gz
    [[ $? -eq $BS_TRUE ]] && echoinfo "kubeedge 安装包下载完成." || echoerror "kubeedge 安装包下载失败！"

    echoinfo "Setup3: 下载 edgecore.service 文件..."
    curl -s --basic \
         -u ${FTP_USERNAME}:${FTP_PASSWD} \
         -L http://${FTP_SERVER}/kubeedge/edgecore.service \
         -o /etc/kubeedge/edgecore.service 
    [[ $? -eq $BS_TRUE ]] && echoinfo "edgecore.service 文件下载完成." || echoerror "edgecore.service 文件下载失败."

    echoinfo "开始安装 edgecore 服务..."
    keadm join --kubeedge-version=${KubeEdgeVersion} \
      --cloudcore-ipport=${CloudCoreIP}:${CloudCorePort} \
      --token=${TOKEN}
    
    echoinfo "开始配置 edgecore"
    yq -i '.modules.edged.cgroupDriver = "systemd"' /etc/kubeedge/config/edgecore.yaml
    yq -i '.modules.edged.clusterDNS = "169.254.96.16"' /etc/kubeedge/config/edgecore.yaml
    yq -i '.modules.edged.clusterDomain = "cluster.local"' /etc/kubeedge/config/edgecore.yaml
    yq -i '.modules.edgeStream.enable = true' /etc/kubeedge/config/edgecore.yaml
    yq -i '.modules.edgeMesh.enable = true' /etc/kubeedge/config/edgecore.yaml
    yq -i '.modules.metaManager.metaServer.enable = true' /etc/kubeedge/config/edgecore.yaml
    
    echoinfo "配置完成，正在重启 edgecore..."
    cp -v /etc/kubeedge/edgecore.service /usr/lib/systemd/system/ && systemctl enable edgecore.service
    systemctl restart edgecore
    ps aux |grep edgecore |grep -v 'grep' > /dev/null 2>&1
    [[ $? -eq $BS_TRUE ]] && echoinfo "edgecore 配置完成." || echoerror "edgecore 配置失败!"
}

# 程序入口
main(){
    if [[ $LikeOS == 'CentOS' ]];then
        #__yum_install_base
        __modify_repo_mirror
        __install_base_software
        __disable_firewalld
        __disable_selinux
        __disable_swap
        __setting_tz_and_time_sync
        #__modify_yum_repo
        __modify_ps_style
        __modify_history_format
        __modify_session_timeout
        __modify_limit
        __config_ipvs_modules
        __config_kernels
        __install_docker
        __install_keadm
        __install_yq
        __install_edgecore
    elif [[ $LikeOS == 'Ubuntu' ]];then
        __modify_repo_mirror
        __install_base_software
    else
        echoerror "未知系统类型!!"
    fi
    echo -e "\033[1;33m详细执行日志信息请查看: $LOGFILE，查看方式: more $LOGFILE\033[0m"
}

# 说明
show_usage(){
    echo "Usage: $__ScriptFullName -t {TOKEN} [-i {CloudCoreIP}] [-p {CloudCorePort}]"
    echo ""
    echo "参数说明:"
    echo "-t, --token: kubeedge 集群获取的 token (必须参数), 获取方式 keadm gettoken"
    echo "-i, --CloudCoreIP: kubeedge 集群对外暴露的IP (可选参数)，默认值为: 1.1.1.1"
    echo "-p, --CloudCorePort: kubeedge 集群对外暴露的端口 (可选参数)，默认值为 10000"
    echo ""
}

GETOPT_ARGS=$(getopt -o i::p::t: -l token:,CloudCoreIP::,CloudCorePort:: -n $(basename $0) -- "$@")

eval set -- "$GETOPT_ARGS"

#获取参数
while [ -n "$1" ]
do
    case "$1" in
        -t|--token) TOKEN=$2; shift 2;;
        -i|--CloudCoreIP) CloudCoreIP=$2; shift 2;;
        -p|--CloudCorePort) CloudCorePort=$2; shift 2;;
        --) break ;;
        *) show_usage; break ;;
    esac
done

#对必填项做输入检查，此处假设都为必填项
if [[ -z $TOKEN || -z $CloudCoreIP || -z $CloudCorePort ]]; then
    show_usage
    exit 0
else
    echo -e "\033[1;33mTOKEN: $TOKEN, CloudCoreIP: $CloudCoreIP, CloudCorePort: $CloudCorePort\033[0m"
    main
fi
