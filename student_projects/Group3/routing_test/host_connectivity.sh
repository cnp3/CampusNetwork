#!/bin/bash

HOSTS=("HA1" "PY1" "ST1" "CA1" "MI1" "SH1")

echo "[TEST] Connectivity test for hosts"
echo "[INFO] This test check connectivity to each router interface, DNS, load balancer, BGP peer and google."
echo "[INFO] fd00:200:3:8888:: should be unreachable from every machine"

for host in "${HOSTS[@]}"
do
  sudo ip netns exec "$host" sudo /home/vagrant/lingi2142/routing_test/connectivity_test_on_machine.sh $host /etc/addresses_for_host_test.txt
  cat /tmp/${host}_test.txt
  sudo rm /tmp/${host}_test.txt
done

exit
