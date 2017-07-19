#!/bin/bash
# This script tests some scenarios with guests, students, staff
# in order to check the different policies for the web servers
# and the monitoring servers.

sudo ip netns exec SH3 sudo timeout 3 curl www.group2.ingi 2>/dev/null > tmp.txt
echo "Trying to reach www.group2.ingi from SH3"
if [ -s tmp.txt ]
then
    echo "[Success] Reached www.group2.ingi"
else
    echo "[Failure] Could not reach www.group2.ingi"
fi
rm tmp.txt

sudo ip netns exec SH3 sudo timeout 3 curl google.be 2>/dev/null > tmp.txt
echo "Trying to reach google.be from SH3"
if [ -s tmp.txt ]
then
    echo "[Failure] Reached google.be"
else
    echo "[Success] Could not reach google.be"
fi
rm tmp.txt

sudo ip netns exec PY2 timeout 3 curl www.group2.ingi 2>/dev/null > tmp.txt
echo "Trying to reach www.group2.ingi from PY2"
if [ -s tmp.txt ]
then
    echo "[Success] Reached www.group2.ingi"
else
    echo "[Failure] Could not reach www.group2.ingi"
fi
rm tmp.txt

sudo ip netns exec PY2 timeout 3 curl google.be 2>/dev/null > tmp.txt
echo "Trying to reach google.be from PY2"
if [ -s tmp.txt ]
then
    echo "[Success] Reached google.be"
else
    echo "[Failure] Could not reach google.be"
fi
rm tmp.txt

sudo ip netns exec CA1 timeout 3 curl mon1.group2.ingi 2>/dev/null > tmp.txt
echo "Trying to reach mon1.group2.ingi from CA1"
if [ -s tmp.txt ]
then
    echo "[Success] Reached MON1"
else
    echo "[Failure] Could not reach MON1"
fi
rm tmp.txt

sudo ip netns exec CA3 timeout 3 curl mon1.group2.ingi 2>/dev/null > tmp.txt
echo "Trying to reach mon1.group2.ingi from CA3"
if [ -s tmp.txt ]
then
    echo "[Failure] Reached MON1"
else
    echo "[Success] Could not reach MON1"
fi
rm tmp.txt
