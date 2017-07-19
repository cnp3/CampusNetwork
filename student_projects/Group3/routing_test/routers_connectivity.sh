#!/bin/bash

ROUTERS=("HALL" "PYTH" "STEV" "CARN" "MICH" "SH1C")

echo "[TEST] Full connectivity test"
echo "[INFO] This test check connectivity to each router interface, DNS, load balancer and BGP peer."
echo "[INFO] fd00:200:3:8888:: should be unreachable from every machine"

for router in "${ROUTERS[@]}"
do
  sudo ip netns exec "$router" sudo /home/vagrant/lingi2142/routing_test/connectivity_test_on_machine.sh $router /etc/addresses_for_router_test.txt
  cat /tmp/${router}_test.txt
  sudo rm /tmp/${router}_test.txt
done

exit
