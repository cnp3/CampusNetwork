#!/usr/bin/env python3
import json
import os
import stat

from pprint import pprint

from constants import PATH, PREFIXES

with open(PATH+'service_configuration.json') as data_file:
    data = json.load(data_file)

# prefixes = ["fd00:200:3:", "fd00:300:3:"]

for host, configs in data.items():
    host_start_config = open("project_cfg/"+host+"_start", "w")
    host_start_config.write("#!/bin/bash \n\n")
    host_start_config.write("# This file has been generated automatically, see service_config_creation.py for details. \n\n")

    # Interface to LAN
    interface = host+"-eth0"
    host_start_config.write("ip link set dev "+interface+" up \n")
    for prefix in PREFIXES:
        host_start_config.write("ip address add dev "+interface+" "+prefix+configs["use_type"]+configs["location"]+configs["forced_address"]+"/64 \n")

    # Add the default route
    host_start_config.write("\nip -6 route add ::/0 via "+configs["default_route"]+" \n\n")


    if "bind9" in configs:
        host_start_config.write("named -6 -c /etc/bind/"+configs["bind9"]+".conf \n\n")

    # Extra commands that should be ran at the start 
    if "extra_commands" in configs:
        for command in configs["extra_commands"]:
            host_start_config.write(command+"\n\n")

    host_start_config.close()

    # Add execution right to new file
    file_stat = os.stat("project_cfg/"+host+"_start")
    os.chmod("project_cfg/"+host+"_start", file_stat.st_mode | stat.S_IEXEC)
