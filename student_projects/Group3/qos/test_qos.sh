#!/bin/bash

echo "NS1 is for network traffic"
echo "HA1 and HA2 is for default traffic"
echo "HA3 is for VOIP"
echo "HA4 is for CAMERA"


if [ $# != 2 ]
then
    echo "wrong number of parameters !"
    echo "usage : ./test_qos.sh <first usage> <seconde usage>"
    echo "example ./test_qos.sh HA1 HA3 will flood the links with DEFAULT AND VOIP traffic."
    exit
fi

sudo ip netns exec "SH1" iperf3 -s -D --one-off
sudo ip netns exec "SH2" iperf3 -s -D --one-off

SH1_ADDR=$(sudo ip netns exec "SH1" hostname -I)
SH2_ADDR=$(sudo ip netns exec "SH2" hostname -I)

SH1_ADDR=$(python3 -c "import sys, json;print(sys.argv[1].split()[0])" "$SH1_ADDR")
SH2_ADDR=$(python3 -c "import sys, json;print(sys.argv[1].split()[0])" "$SH2_ADDR")

echo $SH1_ADDR
echo $SH2_ADDR

echo "Starting test iperf test. You can see the output in the log files"
echo "Test will last 30 seconds"

sudo ip netns exec "$1" sudo iperf3 -u -V -c $SH1_ADDR -b 120M -R -t 30 -l 20Kb > $1.log&
sudo ip netns exec "$2" sudo iperf3 -u -V -c $SH2_ADDR -b 120M -R -t 30 -l 20Kb > $2.log


echo "Test finished"
cat $1.log
cat $2.log
echo "You can see the iperf3 output in the log files $1.log and $2.log"
