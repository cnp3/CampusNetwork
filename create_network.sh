#!/bin/bash

# List here all files from /etc that should be copied
ETC_IMPORT=(hosts passwd group manpath.config services alternatives)

## See the bottom for the bootstrap

# Execute a script from the node's config dir
# $1: node name
# $2: script name
function node_exec {
    local cfg
    cfg=$(node_cfg "$1")
    local SPATH="${cfg}_$2"
    if [ -x "$SPATH" ]; then
        info "Executing $2 for node $1"
        node_exec_command "$1" "$SPATH" &
    else
        warn "No executable '$2' found for node $1"
    fi
}

# Create a node in a new namespace.
# $1: node name
function mk_node {
    info "Creating node $1"
    # Reset the port count for the node
    PORTCOUNT[$1]=0
    LANCOUNT[$1]=0
    # Create the namespace
    ip netns add "$1"
    mkdir -p "$(node_rundir $1)"
    # Get the node's config dir path
    local CDIR
    CDIR=$(node_cfg "$1")
    # Make the config dir if non-existent
    mkdir -p "$CDIR"
    [ ! -f "${CDIR}/hostname" ] && echo "$1" > "${CDIR}/hostname"
    for file in "${ETC_IMPORT[@]}"; do
        if [ -f "${CDIR}/${file}" ] || [ -d "${CDIR}/${file}" ]; then
                continue
        elif [ -f "/etc/${file}" ]; then
                cp "/etc/${file}" "${CDIR}/${file}"
        elif [ -d "/etc/${file}" ]; then
                cp -r "/etc/${file}" "${CDIR}/${file}"
        fi
    done
    # Enable the loopback in the net NS, quite a few programs require it
    ip netns exec "$1" ip link set dev lo up
    # execute startup script if given
    node_exec "$1" "$BOOT"
}

# Get the next port id for a node
# $1: node name
function next_port {
    if [ ! "${PORTCOUNT[$1]+isset}" ]; then
        mk_node "$1"
    fi
    __ret="${1}-eth${PORTCOUNT[$1]}"
    let '++PORTCOUNT[$1]'
}

# Create a veth pair
# $1, $2: interface names
function mk_veth {
    ip link add name "$1" type veth peer name "$2"
}

# Move an interface to a network namespace
# $1: interface
# $2: NS
function mv_to_ns {
    ip link set dev "$1" netns "$2"
    ip netns exec "$2" ip link set dev "$1" up
}

# Create a new veth pair and move the interfaces to node's net NS
# $1, $2: node names
function add_link {
    next_port "$1"
    local src="$__ret"
    next_port "$2"
    local dst="$__ret"
    mk_veth "$src" "$dst"
    # Move the interfaces to the net NS of the nodes
    mv_to_ns "$src" "$1"
    mv_to_ns "$dst" "$2"
    info "Connected $src to $dst"
}

# create a network bridge
# $1: bridge name
function mk_bridge {
    ip link add name "$1" type bridge
    ip link set dev "$1" up
}

# Get the LAN id for a node
# $1: node name
function next_LAN {
    if [ ! "${LANCOUNT[$1]+isset}" ]; then
        mk_node "$1"
    fi
    __ret="${1}-lan${LANCOUNT[$1]}"
    let '++LANCOUNT[$1]'
}

# Attach a node to a LAN, with named interfaces
# $1: bridge
# $2: node owning the bridge
# $3: node to attach
# $4: src intf name -- to be in the net NS of $3
# $5: dst intf name -- to be attached to the bridge
function _attach_to_LAN_named {
    # Create new veth pair
    mk_veth "$4" "$5"
    # Move the 4 to the node to attach NS
    mv_to_ns "$4" "$3"
    # Move the 5 to the bridge NS
    mv_to_ns "$5" "$2"
    # Attach the 5 to the bridge
    ip netns exec "$2" ip link set dev "$5" master "$1"
    info "Connected $3 [$4] to LAN $1"
}

# Attach a LAN to a given node
# $1: node name
function add_LAN {
    next_LAN "$1"
    local LAN="$__ret"
    # Create a brdige in the node NS
    ip netns exec "$1" ip link add name "$LAN" type bridge
    # Bring the bridge up
    ip netns exec "$1" ip link set dev "$LAN" up
    # Enable IPv6 numbering of the bridge
    ip netns exec "$1" sysctl -w "net.ipv6.conf.${LAN}.disable_ipv6=0"
    # Force Multicast forwarding on
    ip netns exec "$1" bash -c "echo -n 0 > /sys/class/net/${LAN}/bridge/multicast_snooping"
    __ret="$LAN"
}

# Attach node to a LAN (L2 bridge)
# $1: bridge
# $2: node owning the bridge in its NS
# $3: other node to attach
function attach_to_LAN {
    next_port "$3"
    local port="$__ret"
    local itf="${1}-${3}"
    _attach_to_LAN_named "$1" "$2" "$3" "$port" "${itf//${2}-}"
}

# Create a LAN linking a set of hosts and a router
# $1: node name
# $2+: all hosts that should be part of the LAN
function mk_LAN {
    # Create a new bridge attached to the first node
    add_LAN "$1"
    local LAN="$__ret"
    info "Populating LAN $LAN"
    local src="$1"
    shift
    for n in "$@"; do
        # Attach all next nodes to the bridge
        attach_to_LAN "$LAN" "$src" "$n"
    done
}

# Bridge a node to a given interface.
# $1: node name
# $2: interface name
# $3: name of the interface visible in the node net NS
function bridge_node {
    local BR="br$2"
    local in="${1}-${2}"
    # Create the vth pair to connect to the bridge
    mk_veth "$in" "$3"
    # Move one of the two interface to the node net NS
    mv_to_ns "$3" "$1"
    # Create a bridge and connect the physical interface as well as the other
    # end of the veth pair
    if ! ip link show dev "$BR" &> /dev/null ; then
        mk_bridge "$BR"
        ip link set "$2" master "$BR"
        ip link set "$2" up
    fi
    ip link set "$in" master "$BR"
    ip link set dev "$in" up
    info "Bridged $1 [$3] to interface $2 [${BR}/$in]"
}

function info { 
    echo "[INFO] $*"
}

function warn { 
    echo "[WARN] $*"
}

set -e

if [[ "$UID" != "0" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

# Script directory
_dname=$(dirname "$0")
BDIR=$(cd "$_dname"; pwd -P)
# Group number
GROUPNUMBER=255
# Node configs  
CONFIGDIR=cfg
# boot script name
BOOT="boot"
# startup script name
STARTUP="start"

if (( $# < 1 )); then
    warn "This script takes one mandatory argument:"
    warn "The path to a script defining a 'mk_topo' function"
    warn "to build the network."
    exit 1
fi

# Source the argument to get the mk_topo function, as well as potentially
# override GROUPNUMBER etc
source "$1"

# node -> next free port number associative array
declare -A PORTCOUNT
# node -> next free bridge number
declare -A LANCOUNT

# Load node commands
source "${BDIR}/_node_utils.sh"

# Instantiate the topology
mk_topo

# Execute the startup script on all nodes
for node in "${!PORTCOUNT[@]}"; do
    node_exec "$node" "$STARTUP"
done

info "The network has been started!"
