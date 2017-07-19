#!/bin/bash

ROOT='/home/vagrant/lingi2142'
sudo mkdir -p $ROOT/end_user_management/bind/out/zones
sudo bash $ROOT/end_user_management/bind/src/dns_config_creation.sh
for i in 1 2
do
 sudo mkdir -p $ROOT/project_cfg/NS$i/bind/
 sudo mkdir -p $ROOT/project_cfg/NS$i/bind/zones
 sudo mkdir -p /var/log/bind/bind/dns$i.log
 sudo cp $ROOT/end_user_management/bind/src/utils_dns.py $ROOT/project_cfg/NS$i/bind/
 sudo cp $ROOT/end_user_management/bind/out/zones/* $ROOT/project_cfg/NS$i/bind/zones
 sudo cp $ROOT/end_user_management/bind/out/named$i.conf* $ROOT/project_cfg/NS$i/bind/
 sudo cp $ROOT/end_user_management/bind/src/update_dns.py $ROOT/project_cfg/NS$i/bind/
 chmod +x $ROOT/project_cfg/NS$i/bind/update_dns.py 
done

