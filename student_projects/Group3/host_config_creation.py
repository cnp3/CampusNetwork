#!/usr/bin/env python3
# coding: utf-8
import json
import os
import stat
from random import random 


from constants import PATH

with open(PATH+'host_configuration.json') as data_file:
    data = json.load(data_file)

for host, configs in data.items():
    host_start_config = open("project_cfg/"+host+"_start", "w+")
    host_start_config.write("#!/bin/bash \n\n")
    host_start_config.write("# This file has been generated automatically, see host_config_creation.py for details. \n\n")

    # Hosts are on VLAN (VLAN ID is the concatenation of use and location)
    if "vlan" in configs:
        interface = host+"-eth0"
        vlan_interface = interface+"."+configs["vlan"]
        host_start_config.write("""
        ip link set dev """+interface+""" up
        ip link add link """+interface+""" name """+vlan_interface+""" type vlan id 0x"""+configs["vlan"]+"""
        ip link set dev """+vlan_interface+""" up
        """)
    random_seed = random()
    if random_seed < 0.5 :
        host_start_config.write("""
        sleep 20; rdnssd -H /etc/rdnssd/merge-hook -u rdnssd -p /var/run/"""+host+"""_rdnssd.pid
        """)
    else :
        host_start_config.write("""
        sleep 20; dhclient -6 -pf /var/run/dhclient_"""+host+""".pid -S """+host+"""-eth0."""+configs["vlan"]+"""
        """)

    # Extra commands that should be ran at start
    if "extra_commands" in configs:
        for command in configs["extra_commands"]:
            host_start_config.write(command+"\n\n")

    host_start_config.close()

    # Add execution right to new file
    file_stat = os.stat("project_cfg/"+host+"_start")
    os.chmod("project_cfg/"+host+"_start", file_stat.st_mode | stat.S_IEXEC)
