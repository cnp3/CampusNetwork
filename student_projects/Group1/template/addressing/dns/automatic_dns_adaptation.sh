#!/usr/bin/env bash
NAME="$(ip netns identify $$)"
IFACENAME="$NAME-eth0"
IFACE200="$(ip addr show dev $IFACENAME | grep -i fd00:200 | grep  -Po "fd00([a-f0-9:]*)" | head -n 1)"
IFACE200PREFIX="$(ip addr show dev $IFACENAME | grep -i fd00:200 | grep  -Po "fd00([a-f0-9:]*/[0-9]+)" | head -n 1)"
IFACE300PREFIX="$(ip addr show dev $IFACENAME | grep -i fd00:300 | grep  -Po "fd00([a-f0-9:]*/[0-9]+)" | head -n 1)"

ping6 -I $IFACE200 fd00::d -W1 -c5  > /dev/null 2>&1
if [ $? -ne 0 ]
then
    # Cannot reach from 200: Force to pick 300 as source
    ip addr change $IFACE200PREFIX dev $IFACENAME preferred_lft 0 > /dev/null 2>&1
    ip addr change $IFACE300PREFIX dev $IFACENAME preferred_lft 3600 > /dev/null 2>&1
    cp -rf /etc/bind/300/* /etc/bind/
    sudo /etc/bind/bind_service.sh restart > /dev/null 2>&1
else
    # Cannot reach from 300: Force to pick 200 as source
    ip addr change $IFACE200PREFIX dev $IFACENAME preferred_lft 3600 > /dev/null 2>&1
    ip addr change $IFACE300PREFIX dev $IFACENAME preferred_lft 0 > /dev/null 2>&1
    cp -rf /etc/bind/200/* /etc/bind/
    sudo /etc/bind/bind_service.sh restart > /dev/null 2>&1
fi
