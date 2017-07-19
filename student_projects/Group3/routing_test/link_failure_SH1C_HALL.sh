#!/bin/bash

echo "[TEST] Link failure test : SH1C-HALL (on SH1C-eth1)"

sudo ip netns exec SH1C sudo ip link set SH1C-eth1 down
echo "[INFO] fd00:200:3:7::6 and fd00:300:3:7::6 should not be reachable anymore"

echo "[INFO] Wait for network to stabilize (20 sec)"
sleep 20

echo "[INFO] Launching host connectivity test"
sudo /home/vagrant/lingi2142/routing_test/host_connectivity.sh

sudo ip netns exec SH1C sudo ip link set SH1C-eth1 up
sudo ip netns exec SH1C sudo ip address add fd00:200:3:7::6/64 dev SH1C-eth1
sudo ip netns exec SH1C sudo ip address add fd00:300:3:7::6/64 dev SH1C-eth1

exit
