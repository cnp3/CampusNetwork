#!/bin/bash

echo "[TEST] Link failure test : HALL-PYTH (on HALL-eth1)"

sudo ip netns exec HALL sudo ip link set HALL-eth1 down
echo "[INFO] fd00:200:3:1::1 and fd00:300:3:1::1 should not be reachable anymore"

echo "[INFO] Wait for network to stabilize (20 sec)"
sleep 20

echo "[INFO] Launching host connectivity test"
sudo /home/vagrant/lingi2142/routing_test/host_connectivity.sh

sudo ip netns exec HALL sudo ip link set HALL-eth1 up
sudo ip netns exec HALL sudo ip address add fd00:200:3:1::1/64 dev HALL-eth1
sudo ip netns exec HALL sudo ip address add fd00:300:3:1::1/64 dev HALL-eth1

exit
