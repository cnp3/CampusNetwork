#!/bin/bash

# Check BGP peering with group 1
echo "[TEST] Check BGP peering with ISPs and exported prefixes"

declare -A BGP # Dictionary
BGP+=( ["PYTH"]="pop200" ["HALL"]="pop300" )

for ROUTER in "${!BGP[@]}";
do
  sudo ip netns exec "$ROUTER" sudo /etc/check_bgp_status.sh $ROUTER ${BGP[$ROUTER]}

  if [ $? -ne 1 ]
  then
    echo "[WARN] ${BGP[$ROUTER]} BGP peering is not established on $ROUTER"
  else
    echo "[INFO] ${BGP[$ROUTER]} BGP peering is established on $ROUTER"

    # Check exported prefix
    sudo ip netns exec $ROUTER sudo /etc/check_exported_prefix_bgp.sh $ROUTER ${BGP[$ROUTER]}
  fi

done

exit
