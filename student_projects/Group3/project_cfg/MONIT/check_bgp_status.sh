#!/bin/bash

# Usage : ./check_bgp_status <router> <bgp_protocol_name>
# Return 1 if bgp protocol <bgp_protocol_name> status is Established on <router>, return 0 otherwise

# Get the BGP status with BIRD
status=$(birdc -s /tmp/$1.ctl "show protocol ${2}" | grep $2 | awk {'print $6'})

if [ "$status" = "Established" ]; then
  exit 1
else
  exit 0
fi
