#!/bin/bash

apt-get -y -qq --force-yes update
apt-get -y -qq --force-yes install git bash lib32z1 vim-nox tcpdump nano\
                                          bird6 quagga inotify-tools\
                                          iperf python3 radvd bind9\
                                          bind9utils bind9-doc apache2\
                                          haproxy curl isc-dhcp-server\
                                          rdnssd\

# Installing iperf3.1 (apt version is too old)
wget https://iperf.fr/download/ubuntu/libiperf0_3.1.3-1_amd64.deb
wget https://iperf.fr/download/ubuntu/iperf3_3.1.3-1_amd64.deb
sudo dpkg -i libiperf0_3.1.3-1_amd64.deb iperf3_3.1.3-1_amd64.deb
rm libiperf0_3.1.3-1_amd64.deb iperf3_3.1.3-1_amd64.deb

update-rc.d quagga disable &> /dev/null || true
update-rc.d bird disable &> /dev/null || true
update-rc.d bird6 disable &> /dev/null || true

service quagga stop
service bird stop
service bird6 stop

(cd /sbin && ln -s /usr/lib/quagga/* .)


