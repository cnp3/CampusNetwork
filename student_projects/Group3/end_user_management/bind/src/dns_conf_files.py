#!/usr/bin/env python3
import json
import os
import stat
import sys

dns = sys.argv[1]
PATH = "/home/vagrant/lingi2142/end_user_management"
#File namedX.conf
dns_conf = open(PATH+"/bind/out/named"+dns+".conf", "w")

dns_conf.write(
"// This is the primary configuration file for the BIND DNS server named.\n"
"//\n"
"// Please read /usr/share/doc/bind9/README.Debian.gz for information on the \n"
"// structure of BIND configuration files in Debian, *BEFORE* you customize \n"
"// this configuration file.\n"
"//\n"
"// If you are just adding zones, please do that in /etc/bind/named.conf.local\n"
"\n"
"include \"/etc/bind/named"+dns+".conf.options\";\n"
"include \"/etc/bind/named"+dns+".conf.local\";\n"
"include \"/etc/bind/named"+dns+".conf.log\";\n"
)

dns_conf.close()

#File namedX.conf.options
dns_conf_local = open(PATH+"/bind/out/named"+dns+".conf.local", "w")

dns_conf_local.write(
"//\n"
"// Do any local configuration here\n"
"//\n"
"\n"
"//Reverse of loadbalancer fd00:200:3:100::80\n"
"zone 0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.3.0.0.0.0.0.2.0.0.0.d.f.ip6.arpa IN{\n"
"    type master;\n"
"    file \"/etc/bind/zones/db.0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.3.0.0.0.0.0.2.0.0.0.d.f.in-addr.arpa\";\n"
"};\n"
"\n"
"//Reverse of loadbalancer fd00:300:3:100::80\n"
"zone 0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.3.0.0.0.0.0.3.0.0.0.d.f.ip6.arpa IN{\n"
"    type master;\n"
"    file \"/etc/bind/zones/db.0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.3.0.0.0.0.0.3.0.0.0.d.f.in-addr.arpa\";\n"
"};\n"
"\n"
"//Reverse of loadbalancer fd00:200:3:101::80\n"
"zone 0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0.3.0.0.0.0.0.2.0.0.0.d.f.ip6.arpa IN{\n"
"    type master;\n"
"    file \"/etc/bind/zones/db.0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0.3.0.0.0.0.0.2.0.0.0.d.f.in-addr.arpa\";\n"
"};\n"
"\n"
"//Reverse of loadbalancer fd00:300:3:101::80\n"
"zone 0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0.3.0.0.0.0.0.3.0.0.0.d.f.ip6.arpa IN{\n"
"    type master;\n"
"    file \"/etc/bind/zones/db.0.8.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0.3.0.0.0.0.0.3.0.0.0.d.f.in-addr.arpa\";\n"
"};\n"
"\n"
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
"\n"
)
dns_conf_local.close()

#File namedX.conf.local

dns_conf_options = open(PATH+"/bind/out/named"+dns+".conf.options", "w")

dns_conf_options.write(
"\n"
"acl intern_user {\n"
"	fd00:200:3::/48;\n"
"	fd00:300:3::/48;\n"
"};\n"
"\n"
"options {\n"
"       directory \"/var/cache/bind/ns"+dns+"\";\n"
"       pid-file  \"/var/run/named_ns"+dns+".pid\";\n"
"\n"
"       // Exchange port between DNS servers\n"
"       //query-source address * port *;\n"
"\n"
"       // Transmit requests to fd00::d\n"
"       forward first;\n"
"       forwarders { fd00::d; };\n"
"\n"
"       auth-nxdomain no;    # conform to RFC1035\n"
"\n"
"       // Turn on IPv6 \n"
"	listen-on-v6 { any; };\n"
"\n"
"       // Transfer only allow to the user of the project \n"
"       allow-transfer { fd00::; };\n"
"\n"
"       // Accept requests for internal network only\n"
"       allow-query { any; };\n"
"\n"
"       // Allow recursive queries from intern users to do the recursion job\n"
"       allow-recursion { intern_user; };\n"
"\n"
"	// Allow cache queries answear only for user inside our network\n"
"	// Thanks to that other users can't have informations about our cache\n"
"       allow-query-cache { intern_user;};\n"
"\n"
"       // Do not make public version of BIND\n"
"       version none;\n"
"};\n"
)
dns_conf_options.close()

#Log file


dns_conf_log = open(PATH+"/bind/out/named"+dns+".conf.log", "w")

dns_conf_log.write(
"logging {\n"
"  channel bind_log {\n"
"    file \"/var/log/bind/bind"+dns+".log\" versions 3 size 5m;\n"
"    severity info;\n"
"    print-category yes;\n"
"    print-severity yes;\n"
"    print-time yes;\n"
"  };\n"
"  category default { bind_log; };\n"
"  category update { bind_log; };\n"
"  category update-security { bind_log; };\n"
"  category security { bind_log; };\n"
"  category queries { bind_log; };\n"
"  category lame-servers { null; };\n"
"};\n"

)
dns_conf_log.close()
