#!/bin/bash

HALL_INTERFACE=("HALL-eth0" "HALL-eth1" "HALL-eth2" "HALL-lan0" "HALL-lan1")
PYTH_INTERFACE=("PYTH-eth0" "PYTH-eth1" "PYTH-eth2" "PYTH-lan0" "PYTH-lan1" "PYTH-lan2")
STEV_INTERFACE=("STEV-eth0" "STEV-eth1" "STEV-lan0")
CARN_INTERFACE=("CARN-eth0" "CARN-eth1" "CARN-lan0")
MICH_INTERFACE=("MICH-eth0" "MICH-eth1" "MICH-lan0")
SH1C_INTERFACE=("SH1C-eth0" "SH1C-eth1" "SH1C-lan0")

for var in "${HALL_INTERFACE[@]}"
do
  sudo ip netns exec "HALL" sudo ./qos/qos.sh $var
done

for var in "${PYTH_INTERFACE[@]}"
do
  sudo ip netns exec "PYTH" sudo ./qos/qos.sh $var
done


for var in "${STEV_INTERFACE[@]}"
do
  sudo ip netns exec "STEV" sudo ./qos/qos.sh $var
done

for var in "${CARN_INTERFACE[@]}"
do
  sudo ip netns exec "CARN" sudo ./qos/qos.sh $var
done

for var in "${MICH_INTERFACE[@]}"
do
  sudo ip netns exec "MICH" sudo ./qos/qos.sh $var
done

for var in "${SH1C_INTERFACE[@]}"
do
  sudo ip netns exec "SH1C" sudo ./qos/qos.sh $var
done
