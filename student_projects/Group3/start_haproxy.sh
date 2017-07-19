#!/bin/bash

function info {
    echo "[INFO] $*"
}

if [[ "$UID" != "0" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

info "Launching HAProxy on DataCenter 1"
ip netns exec "DC1LB" ./launch_proxy
info "Launching HAProxy on DataCenter 2"
ip netns exec "DC2LB" ./launch_proxy

info "The proxy servers has been launched"
