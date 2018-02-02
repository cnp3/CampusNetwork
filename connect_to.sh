#!/bin/bash

# Open a shell to one of the routers

if [[ "$UID" != "0" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

if [[ "$#" -lt "1" ]] ; then
    echo "This script takes 2 parameters: (i) the config directory and (ii) the node name (case sensitive)"
    exit 1
fi

CONFIGDIR="$1"
BDIR=$(cd $(dirname $0); pwd -P)
source "${BDIR}/_node_utils.sh"

node_exec_command "$2" bash
