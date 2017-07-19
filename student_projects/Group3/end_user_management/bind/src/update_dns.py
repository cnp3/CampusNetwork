#!/usr/bin/env python3
import json
import os
import sys
from utils_dns import serial_update, translate_addr
import argparse


sys.path.append('/home/vagrant/lingi2142')
from constants import PREFIXES, VLAN_USES,SERVICE_LOCATION,SERVICE_USE
PATH = "/etc"

parser = argparse.ArgumentParser(description='Process some integers.')
parser.add_argument('--prefix', nargs='*')
parser.add_argument('--addr', nargs='*')
parser.add_argument('--dns',nargs=1)
arg = parser.parse_args()
prefix_up = arg.prefix
addr_down = arg.addr
dns = arg.dns[0]
port_website = "80"
port_dns ="53"

###########################################
# Configuration db.router.group3.ingi     #
###########################################

db_group3 = open(PATH+"/bind/zones/db.group3.ingi","w")

db_group3.write(
"$TTL 10800\n"
"@   IN SOA  @ group3.ingi.(\n"
"            "+serial_update()+"   ; serial\n"
"            7200    ; refresh  (  2   hours)\n"
"            900     ; retry    (  15  min)\n"
"            1209600 ; expire   (  2   weeks)\n"
"            1800 )  ; minimum  (  30  min)\n"

)

db_group3.write("@             IN        NS        ns1.group3.ingi. \n")
db_group3.write("@             IN        NS        ns2.group3.ingi. \n")
db_group3.write("@             IN        TXT       \"zone group3\" \n")

website_annonced = False
for prefix in prefix_up :
    for location in SERVICE_LOCATION :
        dns_addr = prefix+str(SERVICE_USE)+"0"+location+"::"+port_dns
        website_addr = prefix+str(SERVICE_USE)+"0"+location+"::"+port_website
        if addr_down is None or dns_addr not in addr_down :
            db_group3.write("ns"+str(1+int(location))+"           IN        AAAA      "+dns_addr+" \n")
        if addr_down is  None or website_addr not in addr_down :
            website_annonced = True
            db_group3.write("website       IN        AAAA      "+website_addr+" \n")

if website_annonced :
    db_group3.write("www.website   IN        CNAME     website\n")
db_group3.close()


###################
# reverse website #
###################

dns_conf_local = open(PATH+"/bind/named"+dns+".conf.local", "w")

dns_conf_local.write(
"//\n"
"// Do any local configuration here\n"
"//\n"
"\n")

if "fd00:200:3:" in prefix_up :
    if addr_down is  None or "fd00:200:3:100::80" not in addr_down :
        dns_conf_local.write(
        "//Reverse of loadbalancer fd00:200:3:100::80\n"
        "zone 0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.3.0.0.0.0.0.2.0.0.0.d.f.ip6.arpa IN{\n"
        "    type master;\n"
        "    file \"/etc/bind/zones/db.0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.3.0.0.0.0.0.2.0.0.0.d.f.in-addr.arpa\";\n"
        "};\n"
        "\n")
    if addr_down is  None or "fd00:200:3:101::80" not in addr_down :
        dns_conf_local.write(
        "//Reverse of loadbalancer fd00:200:3:101::80\n"
        "zone 0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0.3.0.0.0.0.0.2.0.0.0.d.f.ip6.arpa IN{\n"
        "    type master;\n"
        "    file \"/etc/bind/zones/db.0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0.3.0.0.0.0.0.2.0.0.0.d.f.in-addr.arpa\";\n"
        "};\n"
        "\n")
if "fd00:300:3:" in prefix_up:
    if addr_down is  None or "fd00:300:3:100::80" not in addr_down :
       dns_conf_local.write(
       "zone 0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.3.0.0.0.0.0.3.0.0.0.d.f.ip6.arpa IN{\n"
       "    type master;\n"
       "    file \"/etc/bind/zones/db.0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.3.0.0.0.0.0.3.0.0.0.d.f.in-addr.arpa\";\n"
       "    allow-query { any; };\n"
       "};\n"
       "\n")

    if addr_down is  None or "fd00:300:3:101::80" not in addr_down :
       dns_conf_local.write(
       "//Reverse of loadbalancer fd00:300:3:101::80\n"
       "zone 0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0.3.0.0.0.0.0.3.0.0.0.d.f.ip6.arpa IN{\n"
       "    type master;\n"
       "    file \"/etc/bind/zones/db.0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0.3.0.0.0.0.0.3.0.0.0.d.f.in-addr.arpa\";\n"
       "};\n"
       "\n")

dns_conf_local.write(
"//Zone group3.ingi : public zone\n"
"zone \"group3.ingi\" IN {\n"
"    type master;\n"
"    file \"/etc/bind/zones/db.group3.ingi\";\n"
"};\n"
"\n"
"//Zone router.group3.ingi : zone with all our routers : allow only inside our network\n"
"zone \"router.group3.ingi\" IN {\n"
"    type master;\n"
"    file \"/etc/bind/zones/db.router.group3.ingi\";\n"
"    //Only available for users inside the network\n"
"    allow-query {intern_user;};\n"
"    allow-transfer {intern_user;};\n"
"};\n"

"zone \"service.group3.ingi\" IN {\n"
"    type master;\n"
"    file \"/etc/bind/zones/db.service.group3.ingi\";\n"
"    //Only available for users inside the network\n"
"    //WARNING : informations about the services available for all users of the network \n"
"    //Better solution to allow only one kind of user but now it's available for all users to debug\n"
"    allow-query {intern_user;};\n"
"    allow-transfer {intern_user;};\n"
"};\n"
"\n"

"// Reverse infrastructure/router zone fd00:300:3:00xx::\n"
"zone \"0.0.3.0.0.0.0.0.3.0.0.0.d.f.ip6.arpa\" IN {\n"
"    type master ;\n"
"    file \"/etc/bind/zones/db.0.0.3.0.0.0.0.0.3.0.0.0.d.f.in-addr.arpa\";\n"
"    //Only available for users inside the network\n"
"    allow-query {intern_user;};\n"
"    allow-transfer {intern_user;};\n"
"};\n"
"\n"
"// Reverse infrastructure/router zone fd00:200:3:00xx::\n"
"zone \"0.0.3.0.0.0.0.0.2.0.0.0.d.f.ip6.arpa\" IN {\n"
"    type master ;\n"
"    file \"/etc/bind/zones/db.0.0.3.0.0.0.0.0.2.0.0.0.d.f.in-addr.arpa\";\n"
"    //Only available for users inside the network\n"
"    allow-query {intern_user;};\n"
"    allow-transfer {intern_user;};\n"
"};\n"
"\n"
"// Reverse service zone fd00:200:3:01xx::\n"
"zone \"1.0.3.0.0.0.0.0.3.0.0.0.d.f.ip6.arpa\" IN {\n"
"    type master ;\n"
"    file \"/etc/bind/zones/db.1.0.3.0.0.0.0.0.3.0.0.0.d.f.in-addr.arpa\";\n"
"    //Only available for users inside the network\n"
"    //Same remark as the service zone\n"
"    allow-query {intern_user;};\n"
"    allow-transfer {intern_user;};\n"
"};\n"
"\n"
"// Reverse service zone fd00:300:3:00xx::\n"
"zone \"1.0.3.0.0.0.0.0.2.0.0.0.d.f.ip6.arpa\" IN {\n"
"    type master ;\n"
"    file \"/etc/bind/zones/db.1.0.3.0.0.0.0.0.2.0.0.0.d.f.in-addr.arpa\";\n"
"    //Only available for users inside the network\n"
"    //Same remark as the service zone\n"
"    allow-query {intern_user;};\n"
"    allow-transfer {intern_user;};\n"
"};\n"
"\n"
"\n"
"// Consider adding the 1918 zones here, if they are not used in your\n"
"// organization\n"
"//include \"/etc/bind/zones/zones.rfc1918\";\n"
"\n")
dns_conf_local.close()
