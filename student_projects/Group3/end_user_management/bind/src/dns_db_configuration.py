#!/usr/bin/env python3
import sys
import json
import os
from utils_dns import serial_update

sys.path.append('/home/vagrant/lingi2142/')
from constants import PREFIXES, PATH, VLAN_USES,SERVICE_LOCATION,SERVICE_USE

with open(PATH+'/router_configuration.json') as host_data_file:
    host_data = json.load(host_data_file)

with open('/home/vagrant/lingi2142/service_configuration.json') as service_data_file:
    service_data = json.load(service_data_file)

prefixes = ["fd00:200:3:", "fd00:300:3:"]
dhcp_addr = ["100::547", "101::547"]
vlan_uses = ["2", "3"]
service_use = "1"
PATH = PATH+"end_user_management"

###########################################
# Configuration db.group3.ingi            #
###########################################
db_group3 = open(PATH+"/bind/out/zones/db.group3.ingi","w")

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
port_dns = "53"
port_website = "80"
for prefix in PREFIXES :
    for location in SERVICE_LOCATION :
        dns_addr = prefix+str(SERVICE_USE)+"0"+location+"::"+port_dns
        website_addr = prefix+str(SERVICE_USE)+"0"+location+"::"+port_website
        db_group3.write("ns"+str(1+int(location))+"           IN        AAAA      "+dns_addr+" \n")
        db_group3.write("website       IN        AAAA      "+website_addr+" \n")

db_group3.write("www.website   IN        CNAME     website\n")

db_group3.close()


###########################################
# Configuration db.router.group3.ingi     #
###########################################

db_router = open(PATH+"/bind/out/zones/db.router.group3.ingi","w")

db_router.write(
"$TTL 10800\n"
"@   IN SOA  @ router.group3.ingi.(\n"
"            "+serial_update()+"   ; serial\n"
"            7200    ; refresh  (  2   hours)\n"
"            900     ; retry    (  15  min)\n"
"            1209600 ; expire   (  2   weeks)\n"
"            1800 )  ; minimum  (  30  min)\n"
)

db_router.write("@             IN        NS        ns1.group3.ingi. \n")
db_router.write("@             IN        NS        ns2.group3.ingi. \n")
db_router.write("@             IN        TXT       \"Router group3\" \n")

for router, configs in host_data.items():
    for eth, location in configs["eths"].items():
        for prefix in prefixes:
            db_router.write(router+"          IN        AAAA      "+prefix+location+"::"+configs["router_id"]+" \n")

db_router.close()


###########################################
# Configuration db.service.group3.ingi    #
###########################################

db_service = open(PATH+"/bind/out/zones/db.service.group3.ingi","w")

db_service.write(
"$TTL 10800\n"
"@   IN SOA  @ service.group3.ingi.(\n"
"            "+serial_update()+"   ; serial\n"
"            7200    ; refresh  (  2   hours)\n"
"            900     ; retry    (  15  min)\n"
"            1209600 ; expire   (  2   weeks)\n"
"            1800 )  ; minimum  (  30  min)\n"
)

db_service.write("@             IN        NS        ns1.group3.ingi. \n")
db_service.write("@             IN        NS        ns2.group3.ingi. \n")
db_service.write("@             IN        TXT       \"Service group3\" \n")


for service, configs in service_data.items() :
  if service != "MONIT" : 
     for prefix in prefixes:
          db_service.write(service +"      IN    AAAA     "+ prefix+configs["use_type"]+configs["location"]+configs["forced_address"]+" \n")

db_service.close()
