#!/bin/bash

# Usage : ./isp_down_connectivity.sh <router>
# <router> must be HALL or PYTH

if [ "$#" -ne 1 ]
then
  echo "Illegal number of parameter!"
  echo "Usage : ./isp_down_connectivity.sh <router>"
  echo "<router> must be HALL or PYTH"
  exit
fi

declare -A ROUTER_INTERFACE # Dictionary
ROUTER_INTERFACE+=( ["HALL"]="belneta" ["PYTH"]="belnetb" )

declare -A ROUTER_BGP # Dictionary
ROUTER_BGP+=( ["HALL"]="pop300" ["PYTH"]="pop200" )

declare -A ROUTER_ADDRESS
ROUTER_ADDRESS+=( ["HALL"]="fd00:300::3/64" ["PYTH"]="fd00:200::3/64" )

declare -A ROUTER_PREFIX
ROUTER_PREFIX+=( ["HALL"]="fd00:300:" ["PYTH"]="fd00:200:" )


echo "[TEST] Connectivity test while shutting down link towards ISPs"

echo "[INFO] Shutting down ${ROUTER_INTERFACE[$1]} on $1 : prefix ${ROUTER_PREFIX[$1]} will not be usable anymore (except inside the network)"

sudo ip netns exec $1 sudo ip link set ${ROUTER_INTERFACE[$1]} down

# Check BGP session status
sudo ip netns exec "$1" sudo /etc/check_bgp_status.sh $1 ${ROUTER_BGP[$1]}

if [ $? -eq 1 ]
then
  # The ISP is reachable
  echo "[WARN] ${ROUTER_BGP[$1]} BGP peering is still established"
else
  echo "[INFO] ${ROUTER_BGP[$1]} BGP peering has been shutted down"
fi

echo "[INFO] Waiting for network stabilization (30 sec)"
sleep 30

sudo /home/vagrant/lingi2142/routing_test/host_connectivity.sh

echo "[INFO] Turning on ${ROUTER_INTERFACE[$1]} on $1 : prefix ${ROUTER_PREFIX[$1]} will be usable"
sudo ip netns exec $1 sudo ip link set ${ROUTER_INTERFACE[$1]} up
sudo ip netns exec $1 sudo ip addr add ${ROUTER_ADDRESS[$1]} dev ${ROUTER_INTERFACE[$1]}

echo "[INFO] Waiting for BGP session to be re-established and for network stabilization (30sec)"
sleep 30

exit
