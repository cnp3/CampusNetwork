#!/bin/bash

# Check BGP peering with group 1
echo "[TEST] Check BGP peering with group 1 and exported prefix"

sudo ip netns exec "PYTH" sudo /etc/check_bgp_status.sh PYTH group1

if [ $? -ne 1 ]
then
  echo "[WARN] group1 BGP peering is not established"
else
  echo "[INFO] BGP peering with group 1 is established"

  # Check exported prefix
  sudo ip netns exec "PYTH" sudo /etc/check_exported_prefix_bgp.sh PYTH group1
fi

exit
