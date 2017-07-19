#!/bin/bash

apt-get -y -qq --force-yes install build-essential libpcre3 libpcre3-dev libssl-dev
mkdir ~/working
cd ~/working
wget http://nginx.org/download/nginx-1.11.10.tar.gz
tar -zxvf nginx-1.11.10.tar.gz
cd nginx-1.11.10
./configure --with-http_ssl_module --with-stream --with-ipv6
sudo make
sudo make install
cd ../..
sudo wget https://raw.github.com/JasonGiedymin/nginx-init-ubuntu/master/nginx -O /etc/init.d/nginx
sudo chmod +x /etc/init.d/nginx
sudo update-rc.d nginx defaults
