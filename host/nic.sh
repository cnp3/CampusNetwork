#!/usr/bin/env sh

sysctl -w net.ipv6.conf.all.forwarding=1

# Flush and down interface. Student will configure it for
# inter VM peering

ip addr flush eth1
ip addr flush eth2
ip addr flush eth3
ip addr flush eth4
ip addr flush eth5
ip addr flush eth6
ip addr flush eth7

ip link set dev eth1 down
ip link set dev eth2 down
ip link set dev eth3 down
ip link set dev eth4 down
ip link set dev eth5 down
ip link set dev eth6 down
ip link set dev eth7 down