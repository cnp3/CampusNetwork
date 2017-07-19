#!/bin/bash

# Open a shell to one of the routers

if [[ "$UID" != "0" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

if [[ "$#" -lt "1" ]] ; then
    echo "This script takes the node name as argument (case sensitive)"
    exit 1
fi
ip netns exec "$1" bash
