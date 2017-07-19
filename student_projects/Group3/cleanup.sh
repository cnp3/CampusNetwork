#!/bin/bash

if [[ "$UID" != "0" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

_dname=$(dirname "$0")
BDIR=$(cd "$_dname"; pwd -P)
# Get config-specific settings (i.e. to override GROUPNUMBER)
_settings="${BDIR}/settings"
if [ -x "$_settings" ]; then
    source "$_settings"
fi

echo 'Destroying the root bridges'
# Gracefully disconnect from the bridge in the root namespace (if any)
for i in eth0\
         eth1\
         eth2; do
    ip link del dev "br$i" &> /dev/null
done

ip link del dev "HALL-eth1" &> /dev/null
ip link del dev "PYTH-eth2" &> /dev/null

# Remove the added routes for the birdge prefix
ip route del "$PREFIXB" via "fd00:300::${GROUPNUMBER}"
ip route del "$PREFIXA" via "fd00:200::${GROUPNUMBER}"

# Cleanup all network namespaces
for ns in $(ip netns list) ; do
    echo "Killing namespace $ns"
    # Kill all processes running in the namespaces
    # First SIGTERM
    ip netns pids "$ns" | xargs '-I{}' kill '{}'
    sleep .05
    # Then SIGKILL
    ip netns pids "$ns" | xargs '-I{}' kill -s 9 '{}'
    # Destroy the net NS --- All interfaces/bridges will be destroyed alonside
    ip netns del "$ns"
done

    # Unlink the config symlinks
for f in /etc/netns/* ; do
    unlink "$f"
done

# Destroy bird/zebra temp files
rm -f /tmp/*.{api,ctl}
