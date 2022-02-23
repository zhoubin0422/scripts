#!/usr/bin/env python
# -*- coding:utf-8 -*-
# @Author: zhou bin
# @Email: 2350686113@qq.com
# @Date: 2020/5/17
# @Description:

import os
import sys
import subprocess
import time


VMS = {
    'salt': 'Salt-Master.vmwarevm/Salt-Master.vmx',
    'kibana': 'Kibana.vmwarevm/Kibana.vmx',
	'gitlab': 'GitLab.vmwarevm/GitLab.vmx',
    'logstash': 'Logstash.vmwarevm/Logstash.vmx',
    'es1': 'Elasticsearch1.vmwarevm/Elasticsearch1.vmx',
    'es2': 'Elasticsearch2.vmwarevm/Elasticsearch2.vmx',
    'es3': 'Elasticsearch3.vmwarevm/Elasticsearch3.vmx',
    'jenkins': 'Jenkins.vmwarevm/Jenkins.vmx',
    'prometheus': 'Prometheus.vmwarevm/Prometheus.vmx',
    'zabbix': 'Zabbix.vmwarevm/Zabbix.vmx',
    'server2003': 'Windows Server 2003 Standard Edition.vmwarevm/Windows Server 2003 Standard Edition.vmx',
	'docker': 'Docker-Server.vmwarevm/Docker-Server.vmx'
}

def change_dir():
    """ 进入到虚拟机目录 """
    os.chdir('/Volumes/Data/Virtual Machines')


def start_vm(key):
    """
    启动虚拟机
    :param key: VMS 的 key
    :return:
    """
    change_dir()
    subprocess.run(['vmrun', 'start', VMS[key], 'nogui'])


def stop_vm(key):
    """
    停止虚拟机
    :param key:
    :return:
    """
    change_dir()
    subprocess.run(['vmrun', 'stop', VMS[key], 'nogui'])


def show_vms():
    """ 查看正在运行的虚拟机 """
    subprocess.run(['vmrun', 'list'])


def start_vms(vm):
    """ 启动多个虚拟机 """
    if isinstance(vm, list):
        for i in vm:
            if i in VMS.keys():
                print("正在启动虚拟机 %s" % i)
                start_vm(i)
            else:
                print("VMS 虚拟机列表中找不到 %s" % i)
                continue
    else:
        print('传入的参数必须为列表类型')


def stop_vms(vm):
    """ 关掉多个虚拟机 """
    if isinstance(vm, list):
        for i in vm:
            if i in VMS.keys():
                print("正在停止虚拟机 %s" % i)
                stop_vm(i)
            else:
                print("VMS 虚拟机列表中找不到 %s" % i)
                continue
    else:
        print('传入的参数必须为列表类型')


if __name__ == '__main__':
    if sys.argv[1] == 'start_vms':
	    vms = sys.argv[2:]
	    start_vms(vms)
    elif sys.argv[1] == 'stop_vms':
        vms = sys.argv[2:]
        stop_vms(vms)
    elif sys.argv[1] == 'show_vms':
        show_vms()
