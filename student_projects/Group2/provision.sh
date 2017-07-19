#!/bin/bash

apt-get -y -qq --force-yes update
apt-get -y -qq --force-yes install git bash vim-nox tcpdump nano\
                                          bird6 quagga inotify-tools\
                                          iperf python-pip\
					  nginx isc-dhcp-server vlan radvd\
					  build-essential libpcre3 libpcre3-dev libssl-dev\
					  bind9 bind9utils bind9-doc ulogd nmap

su vagrant -c 'cd && git clone https://gitlab.com/bclasse/lingi2142.git'

#configuring and installing nginx
lingi2142/web/nginx_install.sh

update-rc.d quagga disable &> /dev/null || true
update-rc.d bird disable &> /dev/null || true
update-rc.d bird6 disable &> /dev/null || true

service quagga stop
service bird stop
service bird6 stop

(cd /sbin && ln -s /usr/lib/quagga/* .)

modprobe 8021q
pip install jinja2
