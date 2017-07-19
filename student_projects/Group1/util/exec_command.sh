#!/bin/bash

# Open a shell to one of the routers

if [[ "$UID" != "0" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

if [[ "$#" -lt "2" ]] ; then
    echo "usage: ./exec_command NODE COMMAND"
    exit 1
fi
ip netns exec "$1" "${@:2}"
