#!/bin/bash

# Open a shell to one of the routers


if [[ "$#" -lt "1" ]] ; then
    echo "This script takes the node name as argument (case sensitive)"
    exit 1
fi

for var in "$@"
do
	xterm -xrm 'XTerm.vt100.allowTitleOps: false' -T "$var" -e sudo ip netns exec "$var" bash & 
done
