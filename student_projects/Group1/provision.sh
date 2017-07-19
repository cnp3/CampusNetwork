#!/bin/bash

# Fix lang
echo "export LANGUAGE=en_US.UTF-8" >> ~/.bashrc
echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
echo "export LANG=en_US.UTF-8" >> ~/.bashrc
echo "export LC_TYPE=en_US.UTF-8" >> ~/.bashrc
. ~/.bashrc

# Install softwares
apt-get -y -qq --force-yes update
apt-get -y -qq --force-yes install git bash vim-nox tcpdump nano\
                                          bird6 quagga inotify-tools\
                                          iperf
apt-get -y -qq --force-yes install iperf3 xterm bind9 netcat6 nmap\
				   curl lighttpd radvd isc-dhcp-server\
				   python3 rdnssd snmp snmpd 

update-rc.d quagga disable &> /dev/null || true
update-rc.d bird disable &> /dev/null || true
update-rc.d bird6 disable &> /dev/null || true

# Stop some services
service quagga stop
service bird stop
service bird6 stop
service bind9 stop

(cd /sbin && ln -s /usr/lib/quagga/* .)

#su vagrant -c 'cd && git clone https://github.com/oliviertilmans/LINGI2142-setup.git'

