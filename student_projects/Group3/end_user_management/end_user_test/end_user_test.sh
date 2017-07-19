#!/bin/bash

mkdir -p result/service
mkdir -p result/dns
mkdir -p result/dns/intern
mkdir -p result/dns/intern/service
mkdir -p result/dns/intern/router
mkdir -p result/dns/intern/reverse
mkdir -p result/dns/extern
mkdir -p result/dhcpd

rm result/service/*
rm result/dns/intern/router/*
rm result/dns/intern/service/*
rm result/dns/intern/reverse/*
rm result/dns/extern/*
rm result/dhcpd/*

echo -e '\033[94m' SERVICE '\033[0m'

sudo python3 src/test_launcher.py src/ping.py
cat result/service/*

echo -e '\033[94m' DNS '\033[0m'

sudo python3 src/test_launcher.py src/dns.py
echo TEST ROUTER 
cat result/dns/intern/router/* 
echo TEST SERVICE 
cat  result/dns/intern/service/* 
echo TEST REVERSE SERVICE 
cat result/dns/intern/reverse/* 
echo TEST GOOGLE 
cat result/dns/extern/*

echo -e '\033[94m' DHCP '\033[0m'
sudo python3 src/test_launcher.py src/dhcp.py
cat result/dhcpd/*
