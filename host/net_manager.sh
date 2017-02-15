#!/bin/bash

# Group numbers
ALL_GROUPS=(1 2 3 5 6 7 10)
# The qemu executable on *this* machine
QEMU=qemu-system-x86_64
# Verbosity
LOG_LEVEL=0  # Set to 1 to restrict to info+, 2 to warn, 3 to disable
# Vagrant box version on Alas
BOX_VERSION="8.7.0"
# The master VM HD name
BASE_DISK="disk.qcow2"
# Guest VM max RAM
MEM=2G
# Base prefix for the whole network
NETBASE='fd00'
# Base prefix for SSH guest forwarding
SSHBASE="${NETBASE}:beef"
# Bridge on which we attach all SSH management interfaces of the VMs
SSHBR="sshbr"
# Prefix len for $NETBASE
BASELEN=16
# Store this script location
_dname=$(dirname "$0")
BDIR=$(cd "$_dname"; pwd -P)
# The provisioning script run by Vagrant
PROVISION_SCRIPT=provision.sh
# The IPv6 suffix of BGP servers
BGPSUFFIX="b"
# The IPv6 address of the DNS resolved available to the guests
DNSSUFFIX="d"
BIND_ADDRESS="${NETBASE}::${DNSSUFFIX}"
# The name of the SSH master key for all VMs
MASTERKEY="master"
# The base TCP port from which port forwarding to the VMs
# on port 22 should be established
TCPFWBASE=40000
# Bind configuration file
NAMEDCONF="${BDIR}/named.conf"
ZONE_INGI="${BDIR}/db.ingi"
REVERSE_INGI="${BDIR}/db.${NETBASE}"
# BGP ASNs
declare -A BGP_ASN
BGP_ASN['belneta']=300
BGP_ASN['belnetb']=200
# Return the ASN keys in a sorted fashion
ASN_KEYS=($(echo "${!BGP_ASN[@]}" | tr " " "\n" | sort | tr "\n" " "))
# NAT64 prefix
NAT64PREFIX="${NETBASE}:64"
# Tayga config file location
TAYGACONF="${BDIR}/tayga.conf"
TAYGAv4="192.168.255.1"
TAYGAv4RANGE="192.168.255.0/24"
TAYGADEV="nat64"
TAYGACHROOT="/tmp/tayga"


###############################################################################
## Provision the VMs
###############################################################################

# Build the master HD for the VMs
function prepare_vm {
    info "Creating VM base hdd"
    mk_master_hd

    local mountpoint=loop
    mount_qcow "$BASE_DISK" "$mountpoint"

    debg "Provisioning"
    provision_disk "$mountpoint"
    setup_sshd "$mountpoint"
    enable_sshd_login "$MASTERKEY" root "$mountpoint" /root
    # Set the resolver to our local DNS64
    echo "nameserver ${BIND_ADDRESS}" > "${mountpoint}/etc/resolv.conf"
    
    umount_qcow "$mountpoint"
    debg "VM base hdd is complete"
}

# Download and convert the master HD for the VMs as $BASE_DISK
function mk_master_hd {
    set -e
    debg "Retrieving VM box image"
    wget "https://atlas.hashicorp.com/debian/boxes/jessie64/versions/${BOX_VERSION}/providers/virtualbox.box"
    debg "Decompressing"
    mv virtualbox.box virtualbox.gz
    gunzip -d virtualbox.gz
    tar -xvf virtualbox
    rm -r include Vagrantfile box.ovf virtualbox 
    convert_img
    set +e
}

# Convert a VM HD image to qcow2
function convert_img {
    debg "Converting VM disk image"
    qemu-img convert -O qcow2 box-disk1.vmdk "$BASE_DISK"
}

# Prepare a given directory to be used as chroot
# $1: directory
function mk_chroot {
    debg "Mouting dev/proc/sys in the chroot"
    mount -t proc proc "${1}/proc"
    mount -t sysfs sys "${1}/sys"
    mount -o bind /dev "${1}/dev"
    mount -o bind /dev/pts "${1}/dev/pts"
}

# Tear down a chroot
# $1: directory
function del_chroot {
    set -e
    debg "Unmounting dev/proc/sys in the chroot"
    umount "${1}/proc"
    umount "${1}/sys"
    umount "${1}/dev/pts"
    umount "${1}/dev"
    set +e
}

# Provision the given chroot mountpoint
# $1: mountpoint
function provision_disk {
    local parent
    parent=$(dirname "$BDIR")
    cp "${parent}/${PROVISION_SCRIPT}" "$1"
    # We'll need to resolve apt repositories
    cp /etc/resolv.conf "${1}/etc/resolv.conf"
    debg "Executing provision script"
    chroot "$1" "/${PROVISION_SCRIPT}"
    unlink "${1}/${PROVISION_SCRIPT}"
}

# Enable ssh login on the VM
# $1: chroot mountpoint
function setup_sshd {
    debg "Installing OpenSSH server"
    chroot "$1" apt-get install -y -qq --force-yes openssh-server
    chroot "$1" update-rc.d ssh enable
    chroot "$1" service ssh stop
    # Disable password login
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' "${1}/etc/ssh/sshd_config"
}

# Create a new ssh key and authorize user to login with it
# $1: key name
# $2: user name
# $3: chroot mount point
# $4: user home dir
function enable_sshd_login {
    if [ ! -e "$1" ] || [ ! -e "${1}.pub" ]; then
        debg "Generating ssh key-pair $1 for user $2 in $3"
        ssh-keygen -b 2048 -t rsa -f "$1" -q -N ""
    fi
    # Copy the generated key in the HD
    debg "Authorizing the key"
    local k="${1}.pub"
    local sshdir="${3}${4}/.ssh"
    mkdir -p "$sshdir"
    cp "$k" "${sshdir}/authorized_keys"
    chroot "$3" chown -R "$2" "${4}/.ssh"
}

# Mount a qcow disk image to a directory
# $1: path to disk image
# $2: mount directory
function mount_qcow {
    debg "Mounting disk $1 on $2"
    mkdir -p "$2"
    guestmount -a "$1" -i --pid mountpid.pid "$2"
    sleep .5
    mk_chroot "$2"
}

# umount a qcow disk
# $1: directory on which the disk has been mounted
function umount_qcow {
    sync
    del_chroot "$1"
    set -e
    debg "Unmounting $1"
    local pid
    pid=$(cat mountpid.pid)
    guestunmount "$1"
    count=10
    while kill -0 "$pid" 2>/dev/null && [ $count -gt 0 ]; do
        sleep .5
        ((count--))
    done
    rm -f mountpid.pid
    sleep .5
    set +e
}

# Provision eth0 on the VM
# $1: group number
# $2: mount point
function configure_management_interface {
    local cfg="${mountpoint}/etc/network/interfaces"
    # Remove default config
    sed -i 's/iface eth0 inet dhcp//' "$cfg"
    guest_ssh_address "$1"
    local ssh_guest_address="$__ret"
    # Assign a static address to eth0
    cat << EOD >> "$cfg"
# SSH gateway for remote access
auto eth0
iface eth0 inet6 static
    address $ssh_guest_address
    netmask 64

# Leave these unnumbered and configure instead the addresses of their bridged
# Counterparts in the corresponding border routers
auto eth1
iface eth1 inet manual
auto eth2
iface eth2 inet manual
EOD
}

# Provision a new group
# $1: Group number
function provision_group {
    if [ ! -e "$BASE_DISK" ]; then
        warn "Missing base HDD [$BASE_DISK] for the VMs, attempting to rebuild it!"
        prepare_vm
    fi
    info "Creating overlay hdd for group $1"
    local hda
    hda=$(group_hda "$1")
    qemu-img create -o "backing_file=${BASE_DISK},backing_fmt=qcow2" -f qcow2 "$hda"

    local mountpoint=loop
    mount_qcow "$hda" "$mountpoint"

    # Generate and add a key for the group
    enable_sshd_login "group$1" vagrant "$mountpoint" /home/vagrant
    configure_management_interface "$1" "$mountpoint"

    umount_qcow "$mountpoint"
}

###############################################################################
## VMs properties
###############################################################################

# The IPv6 addresses listening for SSH connection on the guest mahcine
# $1: group number
function guest_ssh_address {
    __ret="${SSHBASE}::${1}"
}

# The name of the virtual dist for a given group
# $1: group number
function group_hda {
    echo "hdd-group${1}.qcow2"
}

# Build the list of virtual interface for a group
# $1: group number
function interfaces_list {
    __ret_array=("g${1}-e0" "g${1}-e1")
}

# The qemu control socket
# $1: group number
function ctrl_sock {
    __ret="g${1}.sock"
}

# The TCP port on the host that is forwarded to a guest VM
# $1: group number
function tcp_fw_port {
    __ret=$((TCPFWBASE + $1))
}

# The name of the administrative interface of the VM
function vm_admin_if {
    __ret="g${1}-ssh"
}

###############################################################################
## Generate host network configurations
###############################################################################


# BGP ASN config name
# $1: ASN
function asn_cfg {
    __ret="bgp_as${1}.conf"
}

function asn_ctl {
    __ret="as${1}.ctl"
}


# Return the IPv6 address of a BGP peer for given ASN
# $1: ASN
function asn_address {
    __ret="${NETBASE}:${1}::${BGPSUFFIX}"
}

# Output a BGP config for one of the two providers
# $1: ASN
function mk_bgpd_config {
    asn_address "$1"
    local src="$__ret"
    local neigh
    IFS='' read -r -d '' neigh << EOD || true
router id 192.0.0.${1:0:1};
listen bgp address ${src} port 179;

protocol kernel {
    export all;
    import all;
    learn;
    scan time 20;
}   

protocol device {
    scan time 10;
}

filter only_kernel_routes {
    if source = RTS_INHERIT then accept;
    reject;
}

EOD
    for g in "${ALL_GROUPS[@]}"; do
        IFS='' read -r -d '' __ret << EOD || true
protocol bgp group${g} {
    local as ${1};
    neighbor ${NETBASE}:${1}::${g} as ${g};
    source address ${src};
    next hop self;
    import filter {
        if net ~ ${NETBASE}:${1}:${g}::/$((BASELEN+32)) then
            accept;
        reject;
    };
    export filter only_kernel_routes;
}

EOD
        neigh+="$__ret"
    done

    asn_cfg "$1"
    echo "$neigh" > "$__ret"
}

# Generate the configuration files for named
function mk_named_config {
    # Start by creating the ingi zone file
    local zone
    IFS='' read -r -d '' zone << EOD || true
$TTL    604800
@       IN      SOA     ingi. root.ingi. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@         IN    NS      ns1.ingi.
@         IN    NS      ns2.ingi.
@         IN    AAAA    ${BIND_ADDRESS}
@         IN    TXT     "TLD for the LINGI2142 project"
ns1       IN    AAAA    ${BIND_ADDRESS}
ns2       IN    AAAA    ${BIND_ADDRESS}

EOD

    # TODO proper IPv6 address explosion functino
    local reverse
    IFS='' read -r -d '' reverse << EOD || true
$TTL    604800
@       IN      SOA     ingi. root.ingi. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@         IN    NS      ns1.ingi.
@         IN    NS      ns2.ingi.
@         IN    TXT     "Reverse bindings for the TLD of the LINGI2142 project"
ns1       IN    AAAA    fd00::d
ns2       IN    AAAA    fd00::d
b.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.2.0.0.0.d.f.ip6.arpa.    IN    PTR    belneta.ingi.
b.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.3.0.0.0.d.f.ip6.arpa.    IN    PTR    belnetb.ingi.
d.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.d.f.ip6.arpa.    IN    PTR    ns1.ingi.
d.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.d.f.ip6.arpa.    IN    PTR    ns2.ingi.

EOD
    # Add bindings for the BGP peerings
    for peer in "${ASN_KEYS[@]@}"; do
        asn_address "${BGP_ASN[${peer}]}"
        local src="$__ret"
        IFS='' read -r -d '' __ret << EOD || true
${peer}   IN    AAAA    ${src} 

EOD
        zone+="$__ret"
    done

    local named
    IFS='' read -r -d '' named << EOD
acl known_client {
        localhost;
        ${NETBASE}::/${BASELEN};
};

options {
        directory "/var/cache/bind";

        forwarders {
            $(grep nameserver /etc/resolv.conf | sed 's/nameserver //' | sed -e 's/$/;/')        
        };

        recursion yes;
        allow-query {
                known_client;
        };

        dnssec-validation auto;

        auth-nxdomain no;    # conform to RFC1035
        listen-on-v6 { any; };

        allow-transfer { none; };

        dns64 ${NAT64PREFIX}::/96 {
                clients {
                        known_client;
                };
        };
};

zone "ingi." {
        type master;
        file "${ZONE_INGI}";
        allow-query { any; };
        allow-transfer { "none"; };
};

zone "0.0.d.f.ip6.arpa" {
        type master;
        file "${REVERSE_INGI}";
        allow-query { any; };
        allow-transfer { "none"; };
};

include "/etc/bind/zones.rfc1918";

zone "localhost" {
        type master;
        file "/etc/bind/db.local";
};

zone "127.in-addr.arpa" {
        type master;
        file "/etc/bind/db.127";
};

zone "0.in-addr.arpa" {
        type master;
        file "/etc/bind/db.0";
};

zone "255.in-addr.arpa" {
        type master;
        file "/etc/bind/db.255";
};

EOD

    echo "$named" > "$NAMEDCONF"
    echo "$zone" > "$ZONE_INGI"
    echo "$reverse" > "$REVERSE_INGI"
}

# Generate the tayga configuration
function mk_tayga_cfg {
    local cfg
    IFS='' read -r -d '' cfg << EOD
tun-device $TAYGADEV
ipv4-addr $TAYGAv4
prefix ${NAT64PREFIX}::/96
dynamic-pool $TAYGAv4RANGE
data-dir $TAYGACHROOT

EOD
    echo "$cfg" > "$TAYGACONF"
}

# Print the current default IPv4 address of this node
function get_v4 {
    ip route get 8.8.8.8 | head -1 | cut -d' ' -f8
}

# Print the current default IPv6 address of this node
function get_v6 {
    ip route get 2001:4860:4860::8888 | head -1 | cut -d' ' -f10
}

# Return the name of the bridge of a POP
# $1: pop name
function pop_name {
    __ret="br$1"
}

###############################################################################
## Host network management
###############################################################################

# Start on POP: a bridge with a BGP router connected to all VMs
# $1: pop name
function start_pop {
    # Create the POP fabric
    pop_name "$1"
    local br="$__ret"
    ip link add name "$br" type bridge
    ip link set dev "$br" up

    # Connect the master interface to the fabric
    local out="${1}-out"
    ip link add name "$1" type veth peer name "$out"
    ip link set dev "$out" master "$br"
    ip link set dev "$out" up
    ip link set dev "$1" up

    local asn="${BGP_ASN[$1]}"
    asn_address "$asn"
    local range="${__ret}"
    # We assign fd00:xxxx::/48 to the bridge, e.g. do not include
    # peer's domains unless they announce it to us
    ip address add dev "$1" "${range}/$((BASELEN+32))"
    mk_bgpd_config "$asn"

    asn_cfg "$asn"
    local cfg="$__ret"
    asn_ctl "$asn"
    bird6 -c "$cfg" -s "$__ret"

    # Enable IPv6 forwarding on the master interface
    sysctl -w "net.ipv6.conf.${1}.forwarding=1"

    # Accept incoming related traffic towards the master interface
    ip6tables -A FORWARD -i eth0 -o "$1" -m state --state RELATED,ESTABLISHED -j ACCEPT
    # No restrictions on outgoing traffic
    ip6tables -A FORWARD -i "$1" -o eth0 -j ACCEPT
    # Drop any unrelated traffic from the bridge with the POP prefix
    ip6tables -A FORWARD -i "$br" -s "${range}/$((BASELEN+16))" -j ACCEPT
    ip6tables -A FORWARD -i "$br" -d "${range}/$((BASELEN+16))" -j ACCEPT
    ip6tables -A FORWARD -i "$br" -j DROP
    # Block IPv4 traffic on the POP bridge
    iptables -I FORWARD -o "$br" -j DROP
    iptables -I FORWARD -i "$br" -j DROP
}

function kill_pop {
    # Invert all iptables rules
    pop_name "$1"
    local br="$__ret"
    asn_address "${BGP_ASN[$1]}"
    local range="${__ret}"
    ip6tables -D FORWARD -i "$br" -s "${range}/$((BASELEN+16))" -j ACCEPT
    ip6tables -D FORWARD -i "$br" -d "${range}/$((BASELEN+16))" -j ACCEPT
    ip6tables -D FORWARD -i "$br" -j DROP
    ip6tables -D FORWARD -i eth0 -o "$1" -m state --state RELATED,ESTABLISHED -j ACCEPT
    ip6tables -D FORWARD -i "$1" -o eth0 -j ACCEPT
    iptables -D FORWARD -o "$1" -j DROP
    iptables -D FORWARD -i "$1" -j DROP

    sysctl -w "net.ipv6.conf.${1}.forwarding=0"

    # Remove the master interface
    ip link set dev "$1" down
    ip link del dev "$1"

    # Remove the brige
    ip link set dev "$br" down
    ip link del dev "$br"

    local asn="${BGP_ASN[$1]}"
    # Tell BIRD to stop
    asn_ctl "$asn"
    debg "Killing BIRD for ${1}/$__ret"
    echo "down" | birdc6 -s "$__ret"

    asn_cfg "$asn"
    rm "$__ret"
}

function start_network {
    info "Starting the host network"

    start_tayga
    start_named

    # Create the SSH management bridge
    if ! ip link show dev "$SSHBR"; then
        info "Creating SSH management bridge"
        ip link add name "$SSHBR" type bridge
        ip link set dev "$SSHBR" up
        ip link add name "${SSHBR}-in" type veth peer name "${SSHBR}-out"
        ip link set dev "${SSHBR}-out" master "$SSHBR"
        ip link set dev "${SSHBR}-out" up
        ip link set dev "${SSHBR}-in" up
        ip address add dev "${SSHBR}-in" "${SSHBASE}::/64"
        # Enable IPv6 forwarding towards the management bridge
        sysctl -w "net.ipv6.conf.${SSHBR}-in.forwarding=1"
        ip6tables -A FORWARD -i eth0 -o "${SSHBR}-in" -j ACCEPT
        ip6tables -A FORWARD -o eth0 -i "${SSHBR}-in" -j ACCEPT -m conntrack --ctstate ESTABLISHED,RELATED
        # We masquerade the source of external traffic as the VM will not have
        # a route towards it ...
        ip6tables -t nat -I POSTROUTING ! -s "${SSHBASE}::" -o "${SSHBR}-in" -j SNAT --to-source "${SSHBASE}::"
    fi

    ip6tables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source "$(get_v6)"
    for pop in "${ASN_KEYS[@]}"; do
        start_pop "$pop"
    done
}

function kill_network {
    info "Killing the host network"

    stop_named
    stop_tayga

    for pop in "${ASN_KEYS[@]}"; do
        kill_pop "$pop"
    done
    ip6tables -t nat -D POSTROUTING -o eth0 -j SNAT --to-source "$(get_v6)"

    # Delete the management bridge
    info "Tearing down SSH management bridge"
    ip link set dev "$SSHBR" down
    ip link del dev "$SSHBR"
    ip link set dev "${SSHBR}-in" down
    ip link del dev "${SSHBR}-in"
    ip6tables -D FORWARD -i eth0 -o "${SSHBR}-in" -j ACCEPT
    ip6tables -D FORWARD -o eth0 -i "${SSHBR}-in" -j ACCEPT -m conntrack --ctstate RELATED,ESTABLISHED
    ip6tables -t nat -D POSTROUTING ! -s "${SSHBASE}::" -o "${SSHBR}-in" -j SNAT --to-source "${SSHBASE}::"
}

function start_tayga {
    mk_tayga_cfg

    if ! ip l sh dev "$TAYGADEV" ; then
        debg "Creating tayga device $TAYGADEV"
        tayga --mktun -c "$TAYGACONF"
    fi

    debg "Configuring NAT64 routes"
    ip link set dev "$TAYGADEV" up
    ip route add "$TAYGAv4RANGE" dev "$TAYGADEV"
    ip route add "${NAT64PREFIX}::/96" dev "$TAYGADEV"

    debg "NATing interface $TAYGADEV"
    iptables -t nat -A POSTROUTING -o eth0 -j SNAT --to-source "$(get_v4)"
    iptables -A FORWARD -i eth0 -o "$TAYGADEV" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i "$TAYGADEV" -o eth0 -j ACCEPT

    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.eth0.forwarding=1
    # If forwarding, then by default RFC2462 transforms this node into a router,
    # thus causes it ignore RAs. As we are masquerading, bypass this.
    sysctl -w net.ipv6.conf.eth0.accept_ra=2
    sysctl -w "net.ipv6.conf.${TAYGADEV}.forwarding=1"
    tayga -c "$TAYGACONF" -p tayga.pid
    info "Started tayga"
}

function _default_sysctl {
    local default
    default=$(sysctl -n "$1")
    sysctl -w "${1}=$default"
}

function stop_tayga {
    _default_sysctl net.ipv6.conf.eth0.forwarding
    _default_sysctl net.ipv6.conf.eth0.accept_ra
    sysctl -w "net.ipv6.conf.${TAYGADEV}.forwarding=0"

    # Tayga creates its pid file *after* chrooting to its data dir
    kill -s 9 "$(cat $TAYGACHROOT/tayga.pid)" &> /dev/null
    rm -f "$TAYGACHROOT/tayga.pid"
    debg "Stopped tayga"

    iptables -t nat -D POSTROUTING -o eth0 -j SNAT --to-source "$(get_v4)"
    iptables -D FORWARD -i eth0 -o "$TAYGADEV" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -D FORWARD -i "$TAYGADEV" -o eth0 -j ACCEPT
    debg "Removed NATing rules for $TAYGADEV"

    ip link set dev "$TAYGADEV" down
    tayga --rmtun -c "$TAYGACONF"
    debg "Removed the $TAYGADEV interface"

    rm "$TAYGACONF"
}

function stop_named {
    killall named &> /dev/null
    debg "Stopped named"
}

# Start the named daemon
function start_named {
    debg "Starting named (bind)"
    if [[ ! -e "$ZONE_INGI" || ! -e "$REVERSE_INGI" || ! -e "$NAMEDCONF" ]]; then
        mk_named_config
    fi
    named -c "$NAMEDCONF"
    info "Started named (bind)"
}

###############################################################################
## Utility functions
###############################################################################

function warn {
    [ "$LOG_LEVEL" -lt "3" ] && echo "[WARN] $*"
}

function info {
    [ "$LOG_LEVEL" -lt "2" ] && echo "[INFO] $*"
}

function debg {
    [ "$LOG_LEVEL" -lt "1" ] && echo "[DEBG] $*"
}

# Ask for confirmation or exit
# $1: message
function _confirm {
    warn "$1 Confirm action? (y/*)"
    read -r answer || true
    if [[ "$answer" != "y" ]]; then
        info "Cancelled"
        exit 0
    fi
}

# Cleanup the file generated by a VM
# $1: group number
function _cleanup_vm {
    debg "Cleaning up VM files for group $1"
    interfaces_list "$1"
    local count=0
    for i in "${__ret_array[@]}"; do
        local as="${ASN_KEYS[$count]}"
        local asn="${BGP_ASN[$as]}"
        local rangebase="${NETBASE}:${asn}"
        local subnet="${rangebase}:${1}::/$((BASELEN+16))"
        ip6tables -D FORWARD -i "$i" -s "$subnet" -j ACCEPT
        ip6tables -D FORWARD -i "$i" -s "${rangebase}::$1" -j ACCEPT
        ip6tables -D FORWARD -i "$i" -d "$subnet" -j ACCEPT
        ip6tables -D FORWARD -i "$i" -d "${rangebase}::$1" -j ACCEPT
        ip6tables -D FORWARD -i "$i" -j DROP
        ip tuntap del dev "$i" mode tap
        ((++count))
    done

    del_ssh_management_port "$1"

    ctrl_sock "$1"
    unlink "$__ret"
    __ret=$(group_hda "$1")
    unlink "$__ret"
}

# Create an initialize the management port for the VM
# $1: group number
# $2: port
# $3: interface name
function setup_ssh_management_port {
    local port="$2"
    local intf="$3"
    if ! ip l sh dev "$intf"; then
        debg "Creating TAP interface $intf for SSH access to the VM"
        ip tuntap add dev "$intf" mode tap
        ip l set dev "$intf" master "$SSHBR"
        ip l set dev "$intf" up

        guest_ssh_address "$1"
        local sshtarget="$__ret"

        debg "Forwarding host TCP port ${port} to group $1 on $sshtarget"
        # Infer destination IPv6 address from destination port
        # We also rewrite the source IP address (cfr. start_network)
        ip6tables -t nat -A PREROUTING -i eth0 -p tcp --dport "$port" -j DNAT --to-destination "[${sshtarget}]:22"
        # Rewrite source port based on source address, and replace source address
        # by the public address.
        ip6tables -t nat -I POSTROUTING -o eth0 -s "${sshtarget}" -p tcp --sport 22 -j SNAT --to-source "[$(get_v6)]:${port}"
    fi
}

# Remove the ssh management interface and its associated rules
# $1: group number
function del_ssh_management_port {
    tcp_fw_port "$1"
    local port="$__ret"
    vm_admin_if "$1"
    local intf="$__ret"
    ip tuntap del dev "$intf" mode tap
    guest_ssh_address "$1"
    local sshtarget="$__ret"
    ip6tables -t nat -D PREROUTING -i eth0 -p tcp --dport "$port" -j DNAT --to-destination "[${sshtarget}]:22"
    ip6tables -t nat -D POSTROUTING -o eth0 -s "${sshtarget}" -p tcp --sport 22 -j SNAT --to-source "[$(get_v6)]:${port}"
}

###############################################################################
## Script entries points
###############################################################################

function start_all_vms {
    start_network
    info "Starting all VMs"
    for g in "${ALL_GROUPS[@]}"; do
        local hda
        hda=$(group_hda "$g")
        if [ ! -e "$hda" ]; then
            provision_group "$g"
        fi
    done
    for g in "${ALL_GROUPS[@]}"; do
        start_vm "$g"
    done
    info "Waiting for the VM to boot"
    set_hostnames
}

function set_hostnames {
    for g in "${ALL_GROUPS[@]}"; do
        local hname="group$g"
        debg "Setting VM hostname for $hname"
        ssh -p 22 -o "IdentityFile=$MASTERKEY" -o ConnectTimeout=20 "${SSHBASE}::$g" hostnamectl set-hostname "$hname"
    done
}

# $1: group number
function start_vm {
    info "Starting VM for group $1"

    local hda
    hda=$(group_hda "$1")
    if [ ! -e "$hda" ]; then
        provision_group "$1"
    fi

    # No GUI nor stdio input for the VM
    CMD="$QEMU -display none -enable-kvm -m $MEM -hda $hda"

    # Enable the use of a unix control socket
    ctrl_sock "$1"
    CMD+=" -monitor unix:${__ret},server,nowait"

    # eth0 on the VM will be the SSH gateway for remote access
    tcp_fw_port "$1"
    local port="$__ret"
    vm_admin_if "$1"
    local intf="$__ret"
    setup_ssh_management_port "$1" "$port" "$intf"
    CMD+=" -netdev tap,id=fwd${1},script=no,ifname=${intf}"
    CMD+=" -device e1000,netdev=fwd$1"

    local count=0
    interfaces_list "$1"
    for i in "${__ret_array[@]}"; do
        local as="${ASN_KEYS[$count]}"
        pop_name "$as"
        local peer="$__ret"
        local asn="${BGP_ASN[$as]}"
        if ! ip l sh dev "$i" ; then
            debg "Creating TAP interface $i"
            ip tuntap add dev "$i" mode tap
            local rangebase="${NETBASE}:${asn}"
            local subnet="${rangebase}:${1}::/$((BASELEN+16))"
            # Drop unrelated traffic (either the BGP traffic, or the delegated
            # prefix)
            ip6tables -A FORWARD -i "$i" -s "$subnet" -j ACCEPT
            ip6tables -A FORWARD -i "$i" -s "${rangebase}::$1" -j ACCEPT
            ip6tables -A FORWARD -i "$i" -d "$subnet" -j ACCEPT
            ip6tables -A FORWARD -i "$i" -d "${rangebase}::$1" -j ACCEPT
            ip6tables -A FORWARD -i "$i" -j DROP
        fi
        local cid="g${1}c${count}"
        CMD+=" -device e1000,netdev=${cid}"
        CMD+=" -netdev tap,id=${cid},script=no,ifname=${i}"
        info "Bridging $i on $peer (POP${asn}/$peer)"
        ip link set dev "$i" master "$peer"
        ip link set dev "$i" up
        ((++count))
    done

    debg "$CMD"
    $CMD &

    sleep .5

    info "Started VM for group $1"
}

function kill_all_vms {
   if [[ "$2" != "--noconfirm" ]]; then
        _confirm "Kill all VMs?" 
    fi
    for g in "${ALL_GROUPS[@]}"; do
        kill_vm "$g"
    done
    kill_network
}

# $1: group number
function kill_vm {
    info "Killing VM for group $1"
    # Send the poweroff signal to the QM monitor of the VM
    ctrl_sock "$1"
    IFS='' cat << EOD | socat - "UNIX-CONNECT:${__ret}"
    system_powerdown

EOD
}

DESTROYDELAY=5
function destroy_all_vms {
    _confirm "Destroy *ALL* VMs?"

    kill_all_vms --noconfirm
    sleep "$DESTROYDELAY"

    for g in "${ALL_GROUPS[@]}"; do
        _cleanup_vm "$g"
    done
}

function destroy_vm {
   if [[ "$2" != "--noconfirm" ]]; then
        _confirm "Destroy VM ${1}?"
    fi

    info "Destroying VM $1"
    kill_vm "$1"
    sleep "$DESTROYDELAY"

    _cleanup_vm "$1"
}

function restart_tayga {
    stop_tayga
    start_tayga
}

function restart_named {
    stop_named
    start_named
}

function restart_all_vms {
    _confirm "Restart all VMs?"
    kill_all_vms
    sleep "$DESTROYDELAY"
    start_all_vms
}

# $1: group number
function restart_vm {
    kill_vm "$1"
    sleep "$DESTROYDELAY"
    start_vm "$1"
}

# $1: group number
function connect_to {
    set -x 
    ssh -6 -b "${SSHBASE}::" -o "IdentityFile=$MASTERKEY" -p 22 "root@${SSHBASE}::${1}"
    set +x
}

# $1: group number
function conn_vagra {
    tcp_fw_port "$1"
    set -x 
    ssh -6 -o "IdentityFile=group${1}" -p "$__ret" "vagrant@nostromo.info.ucl.ac.be"
    set +x
}

function fetch_deps {
    apt-get -y --q --force-yes update
    apt-get -y --q --force-yes install socat tayga qemu bird6 bind9\
                                       qemu-system libguestfs-tools
    update-rc.d bind9 disable
    service bind9 stop
    update-rc.d bird6 disable
    service bird6 stop
    update-rc.d bird disable
    service bird stop
}

function asn_cli {
    if [ "${BGP_ASN[$1]+isset}" ]; then
        asn="${BGP_ASN[$1]}"
    else
        warn "Treating '$1' as ASN"
    fi
    asn_ctl "$1"
    debg "Connecting to birdc6 through control socket $__ret"
    birdc6 -s "$__ret"
}

function shutdown_net {
    kill_all_vms
    sleep "$DESTROYDELAY"
    killall "$QEMU"
    sleep 2
    for i in $(seq 10); do
        for j in e0 e1 ssh; do
            ip tunta del dev "g${i}-${j}" mode tap;
        done;
    done
    iptables -F
    iptables -F -t nat
    ip6tables -F
    ip6tables -F -t nat
}

function print_help {
    IFS='' read -r -d '' msg << EOD || true
Usage: $0 {action} [param] where {action} is one of

    -s/--start      Start all VMs, the BGP daemons, DNS resolver, and bridge them
    -S [group]      Start the VM of [group]

    -k/--kill       Stop all VMs, and services
    -K [group]      Stop the VM of [group]
    --shutdown      Stop all VMs and destroy the network
    --hostname      Sets all hostnames in the network

    -r/--restart    Restart the whole network
    -R [group]      Restart the VM of [group]

    -d/--destroy    Stop and destroy the network VMs
    -D [group]      Stop and destroy the VM of [group]

    -n/--named      (Re)start the named daemon
    -t/--tayga      (Re)start the tayga NAT64 daemon
    -B [ASN]        Connect to the router CLI of [ASN]

    -C [group]      Open an SSH connection to the VM of [group] as root
    -c [group]      Open an SSH connection to the VM of [group] as user 'vagrant'

    -V [level]      Set log verbosity level (higher means less verbose, [0-3])
    -h/--help       Display this message

    --fetch-deps    Install the required dependencies to run this script
EOD
    echo "$msg" >&2
}

###############################################################################
## main()
###############################################################################

if [ "$UID" -ne "0" ]; then
    warn "This script must be run as root!"
    exit 1
fi

[ "$#" -lt "1" ] && print_help
while getopts ":hskdrS:K:D:R:C:-:V:ntB:c:" optchar; do
    case "${optchar}" in
        -)
            case "${OPTARG}" in
                start)   start_all_vms  ;;
                kill)    kill_all_vms   ;;
                destroy) destroy_all_vms;;
                restart) restart_all_vms;;
                named)   restart_named  ;;
                tayga)   restart_tayga  ;;
                help)    print_help     ;;
                fetch-deps) fetch_deps  ;;
                shutdown) shutdown_net  ;;
                hostname) set_hostnames ;;
                *) echo "Unknown option --${OPTARG}" >&2 ;;
            esac;;
        s) start_all_vms       ;;
        S) start_vm "$OPTARG"  ;;
        k) kill_all_vms        ;;
        K) kill_vm "$OPTARG"   ;;
        d) destroy_all_vms     ;;
        D) destroy_vm "$OPTARG";;
        r) restart_all_vms     ;;
        R) restart_vm "$OPTARG";;
        n) restart_named       ;;
        t) restart_tayga       ;;
        C) connect_to "$OPTARG";;
        c) conn_vagra "$OPTARG";;
        V) LOG_LEVEL="$OPTARG" ;;
        h) print_help          ;;
        B) asn_cli "$OPTARG"   ;;
        :) echo "Missing argument for -${OPTARG}" >&2 ;;
        *) print_help          ;;
    esac
done
shift $((OPTIND - 1))
[[ "$#" -gt "0" ]] && print_help
