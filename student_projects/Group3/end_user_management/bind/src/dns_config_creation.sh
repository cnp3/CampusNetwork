#!/bin/bash

PATH_SRC='/home/vagrant/lingi2142/end_user_management/bind/src'
for i in 1 2
do
	sudo python3 $PATH_SRC/dns_conf_files.py $i
done

sudo python3 $PATH_SRC/dns_db_configuration.py
sudo python3 $PATH_SRC/reverse_db_service.py
sudo python3 $PATH_SRC/reverse_website.py
sudo python3 $PATH_SRC/reverse_dns_configuration_creation.py

