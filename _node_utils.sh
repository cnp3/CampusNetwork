#!/bin/bash

# Common commands that are used by multiple scripts

# Get a node's config directory
# $1: node name
function node_cfg {
    echo "${BDIR}/${CONFIGDIR}/$1"
}

# Get a node /run directory
# $1: node name
function node_rundir {
    echo "/run/$1"
}

# Execute a command in a node
# $1: node name
# $@: command terms
function node_exec_command {
    ip netns exec "$1" bash -c "mount --bind $(node_cfg $1) /etc && mount --bind $(node_rundir $1) /run && ${@:2}"
}
