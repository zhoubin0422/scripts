#!/root/scripts/fabfile/venv/bin/python
# @Author: zhoubin
# @Email: 2350686113@qq.com
# @Date: 2021-06-07
# @Last modified by: zhoubin
# @Last modified time: 2021-06-07
# @Descriptions: Fabric 自动化文件

import configparser

from datetime import datetime
from fabric.api import run, sudo, env, settings, hide, get, put, cd, lcd
from fabric.api import runs_once, execute, task
from fabric.colors import red, green, blue, yellow
from fabric.utils import abort
from fabric.contrib.console import confirm


server = configparser.ConfigParser(allow_no_value=True)
server.read('servers.ini')

#env.hosts = server.options('product-dbs')
env.user = server.get('global', 'user')
env.password = server.get('global', 'password')
env.port = server.get('global', 'port')


BACKUP_DATE = datetime.now().strftime('%Y-%m-%d')


@task
def get_hostname():
    """ 获取主机名 """
    with settings(hide('everything'), warn_only=True):
        result = run('hostname')
        print(green(result.return_code))


@task
def export_database(username, password, sid, schema):
    """ 导出数据库 """

    with settings(hide('everything'), warn_only=True):
        print(yellow('正在备份 [{}] ...'.format(schema)))
        result = run('expdp \'{username}/"{password}"\'@{sid} '
                     'directory=dump_dir '
                     'dumpfile=schema_{schema}.dmp schemas={schema} '
                     'logfile=export_{schema}.log'.format(username=username,
                                                          password=password,
                                                          sid=sid,
                                                          schema=schema))
        if result.return_code == 0:
            print(green("[{}] 备份完成".format(schema)))

        with cd('/u01/backup/oradata'):
            print(yellow('正在压缩备份文件 [schema_{}.dmp]...'.format(schema)))
            result = run('tar zcvf schema-{0}_{1}.tar.gz schema_{2}.dmp export_{3}.log'.format(schema, BACKUP_DATE, schema, schema))
            if result.return_code == 0:
                print(green("压缩文件完成."))

            print(yellow('正在拉取压缩文件到本地.'))
            remote_path = 'schema-{0}_{1}.tar.gz'.format(schema, BACKUP_DATE)
            local_path = '/backup/{0}/schema-{1}_{2}.tar.gz'.format(BACKUP_DATE, schema, BACKUP_DATE)
            result = get(remote_path, local_path)
            print(green("备份文件已被下载到 {}".format(result)))

            print(yellow('正在清理临时文件...'))
            result = run('rm -rf schema_{0}.dmp export_{0}.log schema-{0}_{1}.tar.gz'.format(schema, BACKUP_DATE))
            if result.return_code == 0:
                print(green("清理临时文件完成"))
