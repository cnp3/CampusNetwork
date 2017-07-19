#!/usr/bin/env bash
NAME="$(ip netns identify $$)"
ALL_IFACES="$(ip link | grep -Po "([A-Z0-9]+)-eth?[0-9]")"

echo "$ALL_IFACES" | while read -r line ; do
    IFACE="$line"

    IFACE200="$(ip addr show dev $IFACE | grep -i fd00:200 | grep  -Po "fd00([a-f0-9:]*)" | head -n 1)"
    IFACE200PREFIX="$(ip addr show dev $IFACE | grep -i fd00:200 | grep  -Po "fd00([a-f0-9:]*/[0-9]+)" | head -n 1)"
    IFACE300PREFIX="$(ip addr show dev $IFACE | grep -i fd00:300 | grep  -Po "fd00([a-f0-9:]*/[0-9]+)" | head -n 1)"
    ping6 -I $IFACE200 fd00::d -W1 -c2  > /dev/null 2>&1

    if [ $? -ne 0 ]
    then
        # Cannot reach from 200: Force to pick 300 as source
        ip addr change $IFACE200PREFIX dev $IFACE preferred_lft 0 > /dev/null 2>&1
        ip addr change $IFACE300PREFIX dev $IFACE preferred_lft 3600 > /dev/null 2>&1
    else
        # Can reach from 200: Force to pick 200 as source
        ip addr change $IFACE200PREFIX dev $IFACE preferred_lft 3600 > /dev/null 2>&1
        ip addr change $IFACE300PREFIX dev $IFACE preferred_lft 0 > /dev/null 2>&1
    fi

done