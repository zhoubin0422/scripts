#!/usr/bin/env python
# -*- coding:utf-8 -*-
# @Author: Zhou Bin
# @Email: 2350686113@qq.com
# @Date: 2021/05/18
# @Last modified by: Zhou Bin
# @Last modified time: 2021/05/18
# @Descriptions:

import pandas as pd

from pymysql import connect

mysql_host = '192.168.1.14'
mysql_port = 3306
mysql_user = 'glpi01'
mysql_password = '123456!@#'
mysql_db = 'glpi'


def get_data():
    df = pd.read_excel("cmdb-new.xlsx")
    return df


def connect_mysql():
    conn = connect(host=mysql_host,
                   port=mysql_port,
                   user=mysql_user,
                   password=mysql_password,
                   database=mysql_db,
                   charset='utf8')
    return conn


def get_id_from_mysql(table_name, name):
    """
    根据名称查询ID
    :param table_name: 数据表名称
    :param name: 需要查询的名称
    :return:
    """
    conn = connect_mysql()
    cs = conn.cursor()
    try:
        sql = "select id from %s where name = '%s'" % (table_name, name)
        cs.execute(sql)
        result = cs.fetchone()[0]
        return result
    except Exception as e:
        print(e)

    conn.close()


def insert_devices_type_data(table_name, sheet_name):
    """
    插入设备类型数据
    :param table_name: 数据表名称
    :param sheet_name: excel sheet 名称
    :return:
    """
    conn = connect_mysql()
    cs = conn.cursor()
    # 初始化数据表
    cs.execute("truncate table %s" % table_name)
    # 主键 ID 复位
    cs.execute("alter table %s AUTO_INCREMENT = 1" % table_name)
    conn.commit()
    df = pd.read_excel("cmdb-new.xlsx", sheet_name=sheet_name)
    data = df.c_types.unique().tolist()
    try:
        for item in data:
            print("正在插入数据 %s" % item)
            sql = "insert into %s(name,comment,date_mod,date_creation) values('%s','',now(), now())" % (table_name, item)
            cs.execute(sql)
    except Exception as e:
        print(e)

    conn.commit()
    cs.close()
    conn.close()


def insert_manufactures():
    """
    插入制造商数据
    :return:
    """
    df = get_data()
    data = df.manufactures.unique().tolist()
    conn = connect_mysql()
    cs = conn.cursor()
    # 初始化数据表
    print("正在清空 glpi_manufacturers 数据表.")
    cs.execute("truncate table glpi_manufacturers")
    print("正在将自增长字段 id 复位")
    cs.execute("alter table glpi_manufacturers AUTO_INCREMENT = 1")
    conn.commit()
    try:
        for item in data:
            print('正在插入数据 %s' % item)
            sql = "insert into glpi_manufacturers(name,comment,date_mod,date_creation) values('%s','',now(),now())" % item
            cs.execute(sql)
    except Exception as e:
        print(e)

    conn.commit()
    print('插入数据完成')
    cs.close()
    conn.close()


def insert_computers():
    """
    插入电脑数据
    """
    conn = connect_mysql()
    cs = conn.cursor()
    # 清空表数据
    cs.execute("truncate table glpi_computers")
    # 复位 ID 主键
    cs.execute("alter table glpi_computers AUTO_INCREMENT = 1")
    conn.commit()
    df = pd.read_excel("cmdb-new.xlsx", sheet_name="PC")
    for row in df.index.values:
        serials = df.iloc[row, 0]
        names = df.iloc[row, 1]
        c_types = get_id_from_mysql('glpi_computertypes', df.iloc[row, 2])
        manufactures = get_id_from_mysql('glpi_manufacturers', df.iloc[row, 3])
        c_models = 0
        contact = df.iloc[row, 5]
        locations = get_id_from_mysql('glpi_locations', df.iloc[row, 6])

        sql = """
        insert into glpi_computers(
            name,
            otherserial,
            contact,
            users_id_tech,
            groups_id_tech,
            date_mod,
            autoupdatesystems_id,
            locations_id,
            computermodels_id,
            computertypes_id,
            manufacturers_id,
            states_id,
            date_creation
        ) values('%s','%s','%s',%d, %d, now(), %d, %d, %d, %d, %d, %d, now())""" % \
              (names, serials, contact, 6, 1, 1, locations, c_models, c_types, manufactures, 1)
        try:
            print("正在插入数据 %s" % serials)
            cs.execute(sql)
            # print(sql)
        except Exception as e:
            print(e)

    conn.commit()
    cs.close()
    conn.close()


def insert_networks():
    """
    插入网络设备数据
    """
    conn = connect_mysql()
    cs = conn.cursor()
    # 清空表数据
    cs.execute("truncate table glpi_networkequipments")
    # 复位 ID 主键
    cs.execute("alter table glpi_networkequipments AUTO_INCREMENT = 1")
    conn.commit()
    df = pd.read_excel("cmdb-new.xlsx", sheet_name="network")

    for row in df.index.values:
        serials = df.iloc[row, 0]
        names = df.iloc[row, 1]
        c_types = get_id_from_mysql('glpi_networkequipmenttypes', df.iloc[row, 2])
        manufactures = get_id_from_mysql('glpi_manufacturers', df.iloc[row, 3])
        c_models = 0
        contact = df.iloc[row, 5]
        locations = get_id_from_mysql('glpi_locations', df.iloc[row, 6])

        sql = """
        insert into glpi_networkequipments(
            name,
            otherserial,
            contact,
            users_id_tech,
            groups_id_tech,
            date_mod,
            locations_id,
            networkequipmentmodels_id,
            networkequipmenttypes_id,
            manufacturers_id,
            states_id,
            date_creation
        ) values('%s','%s','%s',%d, %d, now(), %d, %d, %d, %d, %d, now())""" % \
              (names, serials, contact, 6, 1, locations, c_models, c_types, manufactures, 1)
        try:
            print("正在插入数据 %s" % serials)
            cs.execute(sql)
            # print(sql)
        except Exception as e:
            print(e)

    conn.commit()
    cs.close()
    conn.close()


def insert_printers():
    """
    插入打印机数据
    """
    conn = connect_mysql()
    cs = conn.cursor()
    # 清空表数据
    cs.execute("truncate table glpi_printers")
    # 复位 ID 主键
    cs.execute("alter table glpi_printers AUTO_INCREMENT = 1")
    conn.commit()
    df = pd.read_excel("cmdb-new.xlsx", sheet_name="printer")

    for row in df.index.values:
        serials = df.iloc[row, 0]
        names = df.iloc[row, 1]
        c_types = get_id_from_mysql('glpi_printertypes', df.iloc[row, 2])
        manufactures = get_id_from_mysql('glpi_manufacturers', df.iloc[row, 3])
        c_models = 0
        contact = df.iloc[row, 5]
        locations = get_id_from_mysql('glpi_locations', df.iloc[row, 6])

        sql = """
        insert into glpi_printers(
            name,
            otherserial,
            contact,
            users_id_tech,
            groups_id_tech,
            date_mod,
            locations_id,
            printermodels_id,
            printertypes_id,
            manufacturers_id,
            states_id,
            date_creation
        ) values('%s','%s','%s',%d, %d, now(), %d, %d, %d, %d, %d, now())""" % \
              (names, serials, contact, 6, 1, locations, c_models, c_types, manufactures, 1)
        try:
            print("正在插入数据 %s" % serials)
            cs.execute(sql)
            # print(sql)
        except Exception as e:
            print(e)

    conn.commit()
    cs.close()
    conn.close()


def insert_phones():
    """
    插入电话数据
    """
    conn = connect_mysql()
    cs = conn.cursor()
    # 清空表数据
    cs.execute("truncate table glpi_phones")
    # 复位 ID 主键
    cs.execute("alter table glpi_phones AUTO_INCREMENT = 1")
    conn.commit()
    df = pd.read_excel("cmdb-new.xlsx", sheet_name="phone")

    for row in df.index.values:
        serials = df.iloc[row, 0]
        names = df.iloc[row, 1]
        c_types = get_id_from_mysql('glpi_phonetypes', df.iloc[row, 2])
        manufactures = get_id_from_mysql('glpi_manufacturers', df.iloc[row, 3])
        c_models = 0
        contact = df.iloc[row, 5]
        locations = get_id_from_mysql('glpi_locations', df.iloc[row, 6])

        sql = """
        insert into glpi_phones(
            name,
            otherserial,
            contact,
            users_id_tech,
            groups_id_tech,
            date_mod,
            locations_id,
            phonemodels_id,
            phonetypes_id,
            manufacturers_id,
            states_id,
            date_creation
        ) values('%s','%s','%s',%d, %d, now(), %d, %d, %d, %d, %d, now())""" % \
              (names, serials, contact, 6, 1, locations, c_models, c_types, manufactures, 1)
        try:
            print("正在插入数据 %s" % serials)
            cs.execute(sql)
            # print(sql)
        except Exception as e:
            print(e)

    conn.commit()
    cs.close()
    conn.close()


def insert_monitors():
    """
    插入显示器监控设备数据
    """
    conn = connect_mysql()
    cs = conn.cursor()
    # 清空表数据
    cs.execute("truncate table glpi_monitors")
    # 复位 ID 主键
    cs.execute("alter table glpi_monitors AUTO_INCREMENT = 1")
    conn.commit()
    df = pd.read_excel("cmdb-new.xlsx", sheet_name="monitor")

    for row in df.index.values:
        serials = df.iloc[row, 0]
        names = df.iloc[row, 1]
        c_types = get_id_from_mysql('glpi_monitortypes', df.iloc[row, 2])
        manufactures = get_id_from_mysql('glpi_manufacturers', df.iloc[row, 3])
        c_models = 0
        contact = df.iloc[row, 5]
        locations = get_id_from_mysql('glpi_locations', df.iloc[row, 6])

        sql = """
        insert into glpi_monitors(
            name,
            otherserial,
            contact,
            users_id_tech,
            groups_id_tech,
            date_mod,
            locations_id,
            monitormodels_id,
            monitortypes_id,
            manufacturers_id,
            states_id,
            date_creation
        ) values('%s','%s','%s',%d, %d, now(), %d, %d, %d, %d, %d, now())""" % \
              (names, serials, contact, 6, 1, locations, c_models, c_types, manufactures, 1)
        try:
            print("正在插入数据 %s" % serials)
            cs.execute(sql)
            # print(sql)
        except Exception as e:
            print(e)

    conn.commit()
    cs.close()
    conn.close()


def insert_passives():
    """
    插入其他设备数据
    """
    conn = connect_mysql()
    cs = conn.cursor()
    # 清空表数据
    cs.execute("truncate table glpi_passivedcequipments")
    # 复位 ID 主键
    cs.execute("alter table glpi_passivedcequipments AUTO_INCREMENT = 1")
    conn.commit()
    df = pd.read_excel("cmdb-new.xlsx", sheet_name="other")

    for row in df.index.values:
        serials = df.iloc[row, 0]
        names = df.iloc[row, 1]
        c_types = get_id_from_mysql('glpi_passivedcequipmenttypes', df.iloc[row, 2])
        manufactures = get_id_from_mysql('glpi_manufacturers', df.iloc[row, 3])
        c_models = 0
        contact = df.iloc[row, 5]
        locations = get_id_from_mysql('glpi_locations', df.iloc[row, 6])

        sql = """
        insert into glpi_passivedcequipments(
            name,
            otherserial,
            users_id_tech,
            groups_id_tech,
            date_mod,
            locations_id,
            passivedcequipmentmodels_id,
            passivedcequipmenttypes_id,
            manufacturers_id,
            states_id,
            date_creation
        ) values('%s','%s',%d, %d, now(), %d, %d, %d, %d, %d, now())""" % \
              (names, serials, 6, 1, locations, c_models, c_types, manufactures, 1)
        try:
            print("正在插入数据 %s" % serials)
            cs.execute(sql)
            # print(sql)
        except Exception as e:
            print(e)

    conn.commit()
    cs.close()
    conn.close()


if __name__ == '__main__':
    # insert_manufactures()
    # insert_computers()
    # insert_computers()
    # insert_devices_type_data('glpi_networkequipmenttypes', 'network')
    # insert_networks()
    # insert_devices_type_data('glpi_printertypes', 'printer')
    # insert_printers()
    # insert_devices_type_data('glpi_phonetypes', 'phone')
    # insert_phones()
    # insert_devices_type_data('glpi_monitortypes', 'monitor')
    # insert_monitors()
    # insert_devices_type_data("glpi_passivedcequipmenttypes", "other")
    insert_passives()
