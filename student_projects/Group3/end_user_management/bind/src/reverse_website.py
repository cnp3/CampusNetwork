#!/usr/bin/env python3
import json
import os
from utils_dns import serial_update, translate_addr

with open('/home/vagrant/lingi2142/router_configuration.json') as data_file:
    data = json.load(data_file)

websites = ["fd00:200:3:100::80", "fd00:300:3:100::80","fd00:200:3:101::80","fd00:300:3:101::80"]

for website_addr in websites :
    #/home/vagrant/lingi2142
    db_file = open("/home/vagrant/lingi2142/end_user_management/bind/out/zones/db."+translate_addr(website_addr)[:-8]+"in-addr.arpa","w")
    db_file.write(
    "$TTL 10800\n"
    "@   IN SOA  @ router.group3.ingi.(\n"
    "            "+serial_update()+"   ; serial\n"
    "            7200    ; refresh  (  2   hours)\n"
    "            900     ; retry    (  15  min)\n"
    "            1209600 ; expire   (  2   weeks)\n"
    "            1800 )  ; minimum  (  30  min)\n"
    "@             IN        NS        ns1.group3.ingi. \n"
    "@             IN        NS        ns2.group3.ingi. \n"
    +translate_addr(website_addr)+".             IN        PTR       website.group3.ingi\n"
    )
    db_file.close()
