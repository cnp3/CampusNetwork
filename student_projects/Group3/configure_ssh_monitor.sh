#!/bin/bash

function info {
    echo "[INFO] $*"
}

if [[ "$UID" != "0" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

info "Configuring the ssh key"
sudo ip netns exec "MONIT" sudo ./add_ssh_key
