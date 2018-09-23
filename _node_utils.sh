#!/bin/bash

# Common commands that are used by multiple scripts

# Get a node's config directory
# $1: node name
function node_cfg {
    echo "${BDIR}/${CONFIGDIR}/$1"
}

# Get the config template directory
function template_cfg {
    # Make the template dir if non-existent
    mkdir -p "${BDIR}/${CONFIGDIR}/templates" > /dev/null &> /dev/null
    echo "${BDIR}/${CONFIGDIR}/templates"
}

# Get the puppet module directory
function puppet_modules {
    mkdir -p "${BDIR}/${CONFIGDIR}/puppetmodules" > /dev/null &> /dev/null
    echo "${BDIR}/${CONFIGDIR}/puppetmodules"
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
    ip netns exec "$1" bash -c "mount --bind $(node_cfg $1) /etc && mkdir -p /templates \
     && mount --bind $(template_cfg) /templates && mkdir -p /puppetmodules \
     && mount --bind $(puppet_modules) /puppetmodules && mount --bind $(node_rundir $1) /run && ${@:2}"
}
