#!/bin/sh

echo "Starting the firewalls on all routers ..."

sudo ip netns exec "CARN" ./CARN.sh

sudo ip netns exec "HALL" ./HALL.sh

sudo ip netns exec "MICH" ./MICH.sh

sudo ip netns exec "PYTH" ./PYTH.sh

sudo ip netns exec "SH1C" ./SH1C.sh

sudo ip netns exec "STEV" ./STEV.sh

echo "All the firewalls have been set !"

exit 0
