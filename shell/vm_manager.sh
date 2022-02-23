#!/bin/bash
# Author: zhoubin
# Date: 2022-02-23
# Descriptions: 简单的虚拟机管理脚本


list_vms(){
    echo "当前存在的虚拟机为:"
    for i in $(vmrun list |grep vmx | awk -F '/' '{print $NF}');do echo ${i%.*};done   
}

start_k8s_master(){
    echo "准备启动 k8s master 节点..."
    for i in {1..3};do vmrun start k8s-master-0${i}.vmwarevm/k8s-master-0${i}.vmx nogui;done
}

stop_k8s_master(){
    echo "准备停止 k8s master 节点..."
    for i in {1..3};do vmrun stop k8s-master-0${i}.vmwarevm/k8s-master-0${i}.vmx nogui;done
}

start_k8s_worker(){
    echo "正在启动 k8s worker 节点..."
	for i in {1,2};do vmrun start k8s-node-0${i}.vmwarevm/k8s-node-0${i}.vmx nogui;done
}

stop_k8s_worker(){
    echo "正在停止 k8s worker 节点..."
	for i in {1,2};do vmrun stop k8s-node-0${i}.vmwarevm/k8s-node-0${i}.vmx nogui;done
}

start_k8s(){
	start_k8s_master;
	start_k8s_worker;
}

stop_k8s(){
	stop_k8s_worker;
	stop_k8s_master
}


__menu(){
    echo "*********************************************************"
    echo "*          0.  list_vms                                 *"
    echo "*          1.  start_k8s                                *"
    echo "*          2.  stop_k8s                                 *"
    echo "*          q.  quit                                     *"
    echo "*********************************************************"
}

while true
do
    __menu

    read -p "请输入你的选择: " opt
    case $opt in
        0)
			list_vms
			;;
    	1)
			start_k8s
			;;
		2)
			stop_k8s
			;;
		q)
			sleep 1
			break
			;;
		*)
			echo -e "\033[;31m输入错误，请重新输入.\033[0m"
			sleep 1
			continue
			;;
	esac
done
