#!/usr/bin/env python3
import json
import os
from utils_dns import serial_update, translate_addr

with open('/home/vagrant/lingi2142/service_configuration.json') as data_file:
    data = json.load(data_file)

prefixes = ["fd00:200:3:", "fd00:300:3:"]
dhcp_addr = ["100::547", "101::547"]
vlan_uses = ["2", "3"]
service_use = "1"

reverse_file = {}
for prefix in prefixes :
    reverse_file[prefix] = (
    "$TTL 10800\n"
    "$ORIGIN "+translate_addr(prefix+"100::")[36:]+".\n"
    "@   IN SOA  @ service.group3.ingi.(\n"
    "            "+serial_update()+"   ; serial\n"
    "            7200    ; refresh  (  2   hours)\n"
    "            900     ; retry    (  15  min)\n"
    "            1209600 ; expire   (  2   weeks)\n"
    "            1800 )  ; minimum  (  30  min)\n"
    "@             IN        NS        ns1.group3.ingi. \n"
    "@             IN        NS        ns2.group3.ingi. \n"
    )


#######################
# Create file content #
#######################

for service, configs in data.items():
  if service != "MONIT":    
     for prefix in prefixes:
          reverse_file[prefix] = reverse_file[prefix] + (
          translate_addr(prefix+configs["use_type"]+configs["location"]+configs["forced_address"])[:-37]+ "    IN    PTR   "+service+".service.group3.ingi. \n"
          )

#######################
# Write file content #
#######################

for prefix, file_content in reverse_file.items() :
    db_file = open("/home/vagrant/lingi2142/end_user_management/bind/out/zones/db."+translate_addr(prefix+"100::")[36:-8]+"in-addr.arpa","w")
    db_file.write(file_content)
    db_file.close()
