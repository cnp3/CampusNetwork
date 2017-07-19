#!/bin/bash

# Usage : ./check_exported_prefix_bgp.sh <router> <bgp_protocol_name>
# Check the exported prefix for <bgp_protocol_name> on <router>

# Get the exported prefix with BIRD
route=$(birdc -s /tmp/$1.ctl "show route export $2" | sed "1d" )

if [ "$route" = "" ] 
then
  echo "[INFO] no route is exported for $2"
else
  echo "[INFO] advetised prefix to $2 (bird output, marked as unreachable because 'router .. reject' is used to advertise prefix in bird)"
  echo "$route"
fi

exit
