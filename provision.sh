#!/bin/bash

apt-get -y -qq --force-yes update
apt-get -y -qq --force-yes install git bash vim-nox tcpdump nano\
                                          bird6 quagga inotify-tools\
                                          iperf

update-rc.d quagga disable &> /dev/null || true
update-rc.d bird disable &> /dev/null || true
update-rc.d bird6 disable &> /dev/null || true

(cd /sbin && ln -s /usr/lib/quagga/* .)

su vagrant -c 'cd && git clone https://github.com/oliviertilmans/LINGI2142-setup.git'
