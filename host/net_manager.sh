#!/bin/bash

# Main interface on the host machine
INTERFACE="enp6s4f0"
# Group numbers
ALL_GROUPS=(1 2 3 4 5 6 7 8 9 10 42)
# The qemu executable on *this* machine
QEMU=qemu-system-x86_64
# Verbosity
LOG_LEVEL=0  # Set to 1 to restrict to info+, 2 to warn, 3 to disable
# Vagrant box version on Alas
BOX_VERSION="8.10.0"
# disk image in the box
VMDK_IMG="jessie.vmdk"
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
cd "$BDIR"
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
NAMEDPID='named.pid'
NAMEDCACHE='/var/cache/bind'
# BGP ASNs
declare -A BGP_ASN
BGP_ASN['belneta']=300
BGP_ASN['belnetb']=200
BIRDCTL="bird6.ctl"
BIRDCFG="bird6.conf"
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
# Mac address base for all VM interfaces
MACBASE="be:ef:de:ad"
# Max retries when waiting for ssh access to VMs
MAX_TRIES=90

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
    wget "https://app.vagrantup.com/debian/boxes/jessie64/versions/${BOX_VERSION}/providers/virtualbox.box"
    debg "Decompressing"
    mv virtualbox.box virtualbox.gz
    gunzip -d virtualbox.gz
    tar -xvf virtualbox
    rm -r Vagrantfile box.ovf virtualbox 
    convert_img
    set +e
}

# Convert a VM HD image to qcow2
function convert_img {
    debg "Converting VM disk image"
    qemu-img convert -O qcow2 "$VMDK_IMG" "$BASE_DISK"
    chown qemu:qemu "$BASE_DISK"
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
    gateway ${SSHBASE}::

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
    chown qemu:qemu "$hda"

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


# Return the IPv6 address of a BGP peer for given ASN
# $1: ASN
function asn_address {
    __ret="${NETBASE}:${1}::${BGPSUFFIX}"
}

# Output a BGP config with a dedicated routing table for each providers
function mk_bgpd_config {
    local src
    local cfg
    IFS='' read -r -d '' cfg << EOD || true
router id 10.0.0.0;

protocol kernel kernel_rt {
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
    for asn in "${BGP_ASN[@]}"; do
        asn_address "$asn"
        src="$__ret"
        IFS='' read -r -d '' __ret << EOD || true
table as${asn};
protocol pipe pipe_as${asn} {
    mode transparent;
    table as${asn};
    peer table master;
    import where proto = "kernel_rt";
    export all;
}

EOD
        cfg+="$__ret"
        for g in "${ALL_GROUPS[@]}"; do
            IFS='' read -r -d '' __ret << EOD || true
protocol bgp as${asn}_group${g} {
    table as${asn};
    local as ${asn};
    neighbor ${NETBASE}:${asn}::${g} as ${g};
    source address ${src};
    next hop self;
    import filter {
        if net ~ ${NETBASE}:${asn}:${g}::/$((BASELEN+32)) then
            accept;
        reject;
    };
    export filter only_kernel_routes;
}

EOD
            cfg+="$__ret"
        done
    done

    echo "$cfg" > "$BIRDCFG"
}

function ip6_reverse {
    local nf=':'
    local prog='BEGIN {OFS=""; }
    {
        # How many nibbles are left blank ?
        nibbles = 9 - NF;
        for (i = 1; i <= NF; i++) {
            # Find the :: location
            if (length($i) == 0) {
                # Fill it with quads
                for (j = 1; j <= nibbles; j++) {
                    $i = ($i "0000");
                }
            } else {
                # Prepend zeroes as needed
                $i = substr(("0000" $i), length($i) + 1);
            }
        }; 
        print
    }'
    local reversed
    reversed=$(echo "$1" | awk -F"$nf" "$prog" | rev | sed -e "s/./&./g")
    echo "${reversed}ip6.arpa"
}

# Generate the configuration files for named
function mk_named_config {
    # Start by creating the ingi zone file
    local zone
    IFS='' read -r -d '' zone << EOD || true
\$TTL    604800
\$ORIGIN ingi.
@       IN      SOA     ingi. root.ingi. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@         IN    NS      ns1
@         IN    NS      ns2
@         IN    AAAA    ${BIND_ADDRESS}
@         IN    TXT     "TLD for the LINGI2142 project"
ns1       IN    AAAA    ${BIND_ADDRESS}
ns2       IN    AAAA    ${BIND_ADDRESS}

EOD

    # TODO proper IPv6 address explosion functino
    local reverse
    IFS='' read -r -d '' reverse << EOD || true
\$TTL    604800
\$ORIGIN ingi.
@       IN      SOA     ingi. root.ingi. (
                              1         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@         IN    NS      ns1
@         IN    NS      ns2
@         IN    TXT     "Reverse bindings for the TLD of the LINGI2142 project"
ns1       IN    AAAA    $BIND_ADDRESS
ns2       IN    AAAA    $BIND_ADDRESS
$(ip6_reverse "$BIND_ADDRESS")    IN    PTR    ns1
$(ip6_reverse "$BIND_ADDRESS")    IN    PTR    ns2
EOD
    # Add bindings for the BGP peerings
    for peer in "${ASN_KEYS[@]@}"; do
        asn_address "${BGP_ASN[${peer}]}"
        local src="$__ret"
        IFS='' read -r -d '' __ret << EOD || true
${peer}   IN    AAAA    ${src} 
EOD
        zone+="$__ret"
        IFS='' read -r -d '' __ret << EOD || true
$(ip6_reverse "$src")    IN    PTR    ${peer}
EOD
        reverse+="$__ret"
    done

    local named
    IFS='' read -r -d '' named << EOD || true
acl known_client {
        localhost;
        ::1;
        ${NETBASE}::/${BASELEN};
};

options {
        directory "$NAMEDCACHE";

        forwarders {
            $(grep nameserver /etc/resolv.conf | sed 's/nameserver //' | sed -e 's/$/;/')        
        };

        recursion yes;
        allow-query {
                known_client;
        };

        dnssec-validation auto;

        auth-nxdomain no;    # conform to RFC1035
        listen-on-v6 { ${BIND_ADDRESS}; };
        listen-on { 127.0.0.1; };

        allow-transfer { ::1; 127.0.0.1; ${BIND_ADDRESS}; };

        dns64 ${NAT64PREFIX}::/96 {
                clients {
                        known_client;
                };
        };

        pid-file "${NAMEDPID}";
};

zone "ingi." {
        type master;
        file "${ZONE_INGI}";
        forwarders { };
};

zone "0.0.d.f.ip6.arpa" {
        type master;
        file "${REVERSE_INGI}";
};

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

    # DNS servers of the groups
    python dns_group.py "$ZONE_INGI"
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
    ip route get 8.8.8.8 | head -1 | cut -d' ' -f7
}

# Print the current default IPv6 address of this node
function get_v6 {
    ip route get 2001:4860:4860::8888 | head -1 | cut -d' ' -f9
}

###############################################################################
## Host network management
###############################################################################

# Create a network bridge
# $1: name
# $2: address
# $3: FORWARD chain from $INTERFACE ctstate extra
# $4: allow traffic from prefix
function mk_bridge {
    if ip link sh dev "$1"; then 
        echo "Bridge $1 already exists"
        return 0
    fi
    ip link add dev "$1" type bridge
    ip link set dev "$1" up

    echo -n 0 > "/sys/class/net/${1}/bridge/multicast_snooping"
    sysctl -w "net.ipv6.conf.all.forwarding=1"
    sysctl -w "net.ipv6.conf.${1}.disable_ipv6=0"
    sysctl -w "net.ipv6.conf.${1}.forwarding=1"
    sysctl -w "net.ipv6.conf.${1}.accept_ra=0"
    sysctl -w "net.ipv6.conf.${1}.accept_redirects=0"

    ip address add dev "$1" "$2"

    # Allow 'debug' icmpv6
    ip6tables -A INPUT -i "$1" -p icmpv6 --icmpv6-type destination-unreachable -j ACCEPT
    ip6tables -A INPUT -i "$1" -p icmpv6 --icmpv6-type packet-too-big -j ACCEPT
    ip6tables -A INPUT -i "$1" -p icmpv6 --icmpv6-type time-exceeded -j ACCEPT
    ip6tables -A INPUT -i "$1" -p icmpv6 --icmpv6-type neighbor-solicitation -j ACCEPT
    ip6tables -A INPUT -i "$1" -p icmpv6 --icmpv6-type neighbor-advertisement -j ACCEPT
    ip6tables -A INPUT -i "$1" -p icmpv6 --icmpv6-type echo-request -j ACCEPT
    ip6tables -A INPUT -i "$1" -p icmpv6 --icmpv6-type echo-reply -j ACCEPT
    # Drop the hazardous ones
    ip6tables -A INPUT -i "$1" -p icmpv6 -j DROP
    # NAT to the touside v6-native connection
    ip6tables -A FORWARD -i "$INTERFACE" -o "$1" -m conntrack --ctstate "RELATED,ESTABLISHED$3" -j ACCEPT
    ip6tables -A FORWARD -i "$1" -o "$INTERFACE" -j ACCEPT
    # NAT to the NAT64 interface
    ip6tables -A FORWARD -i "$TAYGADEV" -o "$1" -m conntrack --ctstate "RELATED,ESTABLISHED$3" -j ACCEPT
    ip6tables -A FORWARD -i "$1" -o "$TAYGADEV" -j ACCEPT
    # Allow inter-VM traffic with proper source or destination address
    ip6tables -A FORWARD -i "$1" -s "$4" -j ACCEPT
    ip6tables -A FORWARD -o "$1" -d "$4" -j ACCEPT

    # Drop IPv4
    iptables -I FORWARD -o "$1" -j DROP
    iptables -I FORWARD -i "$1" -j DROP
}

# Delete the network bridge
# $1: name
# $2: address
# $3: FORWARD chain from "$INTERFACE" ctstate extra
function del_bridge {
    ip link del dev "$1"
    ip6tables -D INPUT -i "$1" -p icmpv6 --icmpv6-type destination-unreachable -j ACCEPT
    ip6tables -D INPUT -i "$1" -p icmpv6 --icmpv6-type packet-too-big -j ACCEPT
    ip6tables -D INPUT -i "$1" -p icmpv6 --icmpv6-type time-exceeded -j ACCEPT
    ip6tables -D INPUT -i "$1" -p icmpv6 --icmpv6-type neighbor-solicitation -j ACCEPT
    ip6tables -D INPUT -i "$1" -p icmpv6 --icmpv6-type neighbor-advertisement -j ACCEPT
    ip6tables -D INPUT -i "$1" -p icmpv6 --icmpv6-type echo-request -j ACCEPT
    ip6tables -D INPUT -i "$1" -p icmpv6 --icmpv6-type echo-reply -j ACCEPT
    ip6tables -D INPUT -i "$1" -p icmpv6 -j DROP

    ip6tables -D FORWARD -i "$INTERFACE" -o "$1" -m conntrack --ctstate "RELATED,ESTABLISHED$3" -j ACCEPT
    ip6tables -D FORWARD -i "$1" -o "$INTERFACE" -j ACCEPT
    ip6tables -D FORWARD -i "$TAYGADEV" -o "$1" -m conntrack --ctstate "RELATED,ESTABLISHED$3" -j ACCEPT
    ip6tables -D FORWARD -i "$1" -o "$TAYGADEV" -j ACCEPT
    ip6tables -D FORWARD -o "$1" -s "$4" -j ACCEPT
    ip6tables -D FORWARD -i "$1" -d "$4" -j ACCEPT

    # Drop IPv4
    iptables -D FORWARD -o "$1" -j DROP
    iptables -D FORWARD -i "$1" -j DROP
}

# Start on POP: a bridge with a BGP router connected to all VMs
# $1: pop name
function start_pop {
    # Create the POP fabric
    local asn="${BGP_ASN[$1]}"
    asn_address "$asn"
    local range="${__ret}"
    # We assign fd00:xxxx::/48 to the bridge, e.g. do not include
    # peer's domains unless they announce it to us in the routing table
    # However allow peer traffic over the bridge
    # No extra FORWARD iptables rules
    mk_bridge "$1" "${range}/$((BASELEN+32))" '' "${range}/$((BASELEN+16))"
}

# Start bird6
function start_bgp {
    mk_bgpd_config
    bird6 -c "$BIRDCFG" -s "$BIRDCTL"
}

# Stop bird6
function stop_bgp {
    echo "down" | birdc6 -s "$BIRDCTL"
    unlink "$BIRDCFG"
}

function restart_bgp {
    stop_bgp
    start_bgp
}

function kill_pop {
    local asn="${BGP_ASN[$1]}"
    asn_address "$asn"
    local range="${__ret}"
    del_bridge "$1" "${range}/$((BASELEN+32))" '' "${range}/$((BASELEN+16))"
}

function start_network {
    info "Starting the host network"

    start_tayga
    start_named

    # Create the SSH management bridge
    if ! ip link show dev "$SSHBR"; then
        info "Creating SSH management bridge"
        mk_bridge "$SSHBR" "${SSHBASE}::/64" ",DNAT" "${SSHBASE}::/64"
    fi

    ip6tables -t nat -A POSTROUTING -o "$INTERFACE" -s "${NETBASE}::/${BASELEN}" -j SNAT --to-source "$(get_v6)"
    ip6tables -P FORWARD DROP

    for pop in "${ASN_KEYS[@]}"; do
        start_pop "$pop"
    done

    ebtables -j ACCEPT -p ip6 --ip6-protocol ipv6-icmp --ip6-icmp-type neighbor-solicitation -I INPUT
    ebtables -j ACCEPT -p ip6 --ip6-protocol ipv6-icmp --ip6-icmp-type neighbor-advertisement -I INPUT
    ebtables -j ACCEPT -p ip6 --ip6-protocol ipv6-icmp --ip6-icmp-type neighbor-solicitation -I OUTPUT
    ebtables -j ACCEPT -p ip6 --ip6-protocol ipv6-icmp --ip6-icmp-type neighbor-advertisement -I OUTPUT

    start_bgp
    sleep 10
    start_looking_glass
}

function start_looking_glass {
    "${BDIR}/net_manager.sh" --dump-bgp &
    echo "$!" > dump.pid
    for asn in "${BGP_ASN[@]}"; do
        asn_address "$asn"
        python looking_glass.py "$__ret" "as${asn}.status" &> "looking_glass${asn}.log" &
        echo "$!" > "as${asn}_looking_glass.pid"
    done
}

function stop_looking_glass {
    kill -s 9 "$(cat dump.pid)"
    unlink dump.pid
    for asn in "${BGP_ASN[@]}"; do
        kill -s 9 "$(cat as${asn}_looking_glass.pid)"
        unlink "as${asn}_looking_glass.pid"
        unlink "as${asn}.status"
    done
}

function kill_network {
    info "Killing the host network"

    stop_named
    stop_tayga

    for pop in "${ASN_KEYS[@]}"; do
        kill_pop "$pop"
    done
    ip6tables -t nat -D POSTROUTING -o "$INTERFACE" -s "${NETBASE}::/${BASELEN}" -j SNAT --to-source "$(get_v6)"

    # Delete the management bridge
    info "Tearing down SSH management bridge"
    del_bridge "$SSHBR" "${SSHBASE}::/64" ",DNAT" "${SSHBASE}::/64"

    stop_bgp
    stop_looking_glass

    ebtables -j ACCEPT -p ip6 --ip6-protocol ipv6-icmp --ip6-icmp-type neighbor-solicitation -D INPUT
    ebtables -j ACCEPT -p ip6 --ip6-protocol ipv6-icmp --ip6-icmp-type neighbor-advertisement -D INPUT
    ebtables -j ACCEPT -p ip6 --ip6-protocol ipv6-icmp --ip6-icmp-type neighbor-solicitation -D OUTPUT
    ebtables -j ACCEPT -p ip6 --ip6-protocol ipv6-icmp --ip6-icmp-type neighbor-advertisement -D OUTPUT
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
    ip address add dev "$TAYGADEV" "${NAT64PREFIX}::1"

    debg "NATing interface $TAYGADEV"
    iptables -t nat -A POSTROUTING -o "$INTERFACE" -j SNAT --to-source "$(get_v4)"
    iptables -A FORWARD -i "$INTERFACE" -o "$TAYGADEV" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i "$TAYGADEV" -o "$INTERFACE" -j ACCEPT

    sysctl -w net.ipv4.ip_forward=1
    sysctl -w "net.ipv6.conf.${INTERFACE}.forwarding=1"
    # If forwarding, then by default RFC2462 transforms this node into a router,
    # thus causes it ignore RAs. As we are masquerading, bypass this.
    sysctl -w "net.ipv6.conf.${INTERFACE}.accept_ra=2"
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
    _default_sysctl "net.ipv6.conf.${INTERFACE}.forwarding"
    _default_sysctl "net.ipv6.conf.${INTERFACE}.accept_ra"
    sysctl -w "net.ipv6.conf.${TAYGADEV}.forwarding=0"

    # Tayga creates its pid file *after* chrooting to its data dir
    kill -s 9 "$(cat $TAYGACHROOT/tayga.pid)" &> /dev/null
    rm -f "$TAYGACHROOT/tayga.pid"
    debg "Stopped tayga"

    iptables -t nat -D POSTROUTING -o "$INTERFACE" -j SNAT --to-source "$(get_v4)"
    iptables -D FORWARD -i "$INTERFACE" -o "$TAYGADEV" -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -D FORWARD -i "$TAYGADEV" -o "$INTERFACE" -j ACCEPT
    debg "Removed NATing rules for $TAYGADEV"

    ip link set dev "$TAYGADEV" down
    tayga --rmtun -c "$TAYGACONF"
    debg "Removed the $TAYGADEV interface"

    rm "$TAYGACONF"
}

function stop_named {
    kill -s 9 $(cat "${NAMEDCACHE}/${NAMEDPID}") &> /dev/null
    debg "Stopped named"
    ip address del dev lo "$BIND_ADDRESS"
}

# Start the named daemon
function start_named {
    debg "Starting named (bind)"
    if [[ ! -e "$ZONE_INGI" || ! -e "$REVERSE_INGI" || ! -e "$NAMEDCONF" ]]; then
        mk_named_config
    fi
    # Make DNS resolver address bindable and pingable
    ip address add dev lo "$BIND_ADDRESS"
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
        local subnet="${rangebase}:${1}::/$((BASELEN+32))"
        ebtables -D INPUT -i "$i" -p ip6 --ip6-source "$subnet" -j ACCEPT
        ebtables -D INPUT -i "$i" -p ip6 --ip6-source "${rangebase}::$1" -j ACCEPT
        ebtables -D INPUT -i "$i" -p ip6 -j DROP
        ebtables -D INPUT -i "$i" -p ip -j DROP

        ebtables -D OUTPUT -o "$i" -p ip6 --ip6-destination "$subnet" -j ACCEPT
        ebtables -D OUTPUT -o "$i" -p ip6 --ip6-destination "${rangebase}::$1" -j ACCEPT
        ebtables -D OUTPUT -o "$i" -p ip6 -j DROP
        ebtables -D OUTPUT -o "$i" -p ip -j DROP
        ip tuntap del dev "$i" mode tap
        ((++count))
    done

    del_ssh_management_port "$1"

    ctrl_sock "$1"
    unlink "$__ret"
    __ret=$(group_hda "$1")
    unlink "$__ret"
}

function mk_tuntap {
    ip tuntap add dev "$1" mode tap
    sysctl -w "net.ipv6.conf.${1}.forwarding=1"
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
        mk_tuntap "$intf"
        ip l set dev "$intf" master "$SSHBR"
        ip l set dev "$intf" up 

        guest_ssh_address "$1"
        local sshtarget="$__ret"

        debg "Forwarding host TCP port ${port} to group $1 on $sshtarget"
        # Infer destination IPv6 address from destination port
        # We also rewrite the source IP address (cfr. start_network)
        ip6tables -t nat -A PREROUTING -i "$INTERFACE" -p tcp --dport "$port" -j DNAT --to-destination "[${sshtarget}]:22"

        ebtables -A INPUT -i "$intf" -p ip6 --ip6-source "$sshtarget" -j ACCEPT
        ebtables -A INPUT -i "$intf" -p ip6 -j DROP
        ebtables -A INPUT -i "$intf" -p ip -j DROP

        ebtables -A OUTPUT -o "$intf" -p ip6 --ip6-destination "$sshtarget" -j ACCEPT
        ebtables -A OUTPUT -o "$intf" -p ip6 -j DROP
        ebtables -A OUTPUT -o "$intf" -p ip -j DROP
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
    ip6tables -t nat -D PREROUTING -i "$INTERFACE" -p tcp --dport "$port" -j DNAT --to-destination "[${sshtarget}]:22"

    ebtables -A INPUT -i "$intf" -p ip6 --ip6-source "$sshtarget" -j ACCEPT
    ebtables -A INPUT -i "$intf" -p ip6 -j DROP
    ebtables -A INPUT -i "$intf" -p ip -j DROP

    ebtables -A OUTPUT -o "$intf" -p ip6 --ip6-destination "$sshtarget" -j ACCEPT
    ebtables -A OUTPUT -o "$intf" -p ip6 -j DROP
    ebtables -A OUTPUT -o "$intf" -p ip -j DROP
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
    sleep 10
    set_hostnames
}

function set_hostnames {
    for g in "${ALL_GROUPS[@]}"; do
        local hname="group$g"
        debg "Testing VM connection with nc \"${SSHBASE}::$g\" 22"
        for i in $(seq 1 "$MAX_TRIES"); do
            if echo "" | nc "${SSHBASE}::$g" 22; then
                break
            fi
            sleep 1
	done
        debg "Setting VM hostname for $hname"
        ssh -6 -b "${SSHBASE}::" -p 22 -o "IdentityFile=$MASTERKEY" -o ConnectTimeout=20 "${SSHBASE}::$g" hostnamectl set-hostname "$hname"
        ssh -6 -b "${SSHBASE}::" -p 22 -o "IdentityFile=$MASTERKEY" -o ConnectTimeout=20 "${SSHBASE}::$g" sed  "s/127.0.1.1\\\t.*/127.0.1.1\\\t${hname}/g" /etc/hosts
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
    local macvm
    printf -v macvm "%02d" "$1"
    CMD+=" -netdev tap,id=fwd${1},script=no,ifname=${intf}"
    CMD+=" -device e1000,netdev=fwd$1,mac=${MACBASE}:${macvm}:ff"

    local count=0
    interfaces_list "$1"
    for i in "${__ret_array[@]}"; do
        local as="${ASN_KEYS[$count]}"
        local asn="${BGP_ASN[$as]}"
        if ! ip l sh dev "$i" ; then
            debg "Creating TAP interface $i"
            mk_tuntap "$i"
            local rangebase="${NETBASE}:${asn}"
            local subnet="${rangebase}:${1}::/$((BASELEN+32))"
            # Drop unrelated traffic (either the BGP traffic, or the delegated
            # prefix)
            ebtables -A INPUT -i "$i" -p ip6 --ip6-source "$subnet" -j ACCEPT
            ebtables -A INPUT -i "$i" -p ip6 --ip6-source "${rangebase}::$1" -j ACCEPT
            ebtables -A INPUT -i "$i" -p ip6 -j DROP
            ebtables -A INPUT -i "$i" -p ip -j DROP

            ebtables -A OUTPUT -o "$i" -p ip6 --ip6-destination "$subnet" -j ACCEPT
            ebtables -A OUTPUT -o "$i" -p ip6 --ip6-destination "${rangebase}::$1" -j ACCEPT
            ebtables -A OUTPUT -o "$i" -p ip6 -j DROP
            ebtables -A OUTPUT -o "$i" -p ip -j DROP
        fi
        local cid="g${1}c${count}"
        local cnt
        printf -v cnt "%02d" "$count"
        CMD+=" -device e1000,netdev=${cid},mac=${MACBASE}:${macvm}:${cnt}"
        CMD+=" -netdev tap,id=${cid},script=no,ifname=${i}"
        info "Bridging $i on $as (POP${asn}/$as)"
        ip link set dev "$i" master "$as"
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
    ssh -6 -o "IdentityFile=group${1}" -p "$__ret" "vagrant@lingi2142tp.info.ucl.ac.be"
    set +x
}

function fetch_deps {
    # Presume that if we have yum we're on CentOS (7)
    if ! type yum > /dev/null; then
        yes | yum --enablerepo=extras install epel-release
        yes | yum install git socat tayga bird6 bind qemu libguestfs-tools
        systemctl restart libvirt.service
    else
        apt-get -y --q --force-yes update
        apt-get -y --q --force-yes install socat tayga qemu bird6 bind9\
                                           qemu-system libguestfs-tools
        update-rc.d bind9 disable
        service bind9 stop
        update-rc.d bird6 disable
        service bird6 stop
        update-rc.d bird disable
        service bird stop
    fi
}

function asn_cli {
    debg "Connecting to birdc6 through control socket $BIRDCTL"
    birdc6 -s "$BIRDCTL"
}

function shutdown_net {
    kill_all_vms
    sleep "$DESTROYDELAY"
    killall "$QEMU" &> /dev/null
    sleep 2
    for i in $(seq 10); do
        for j in e0 e1 ssh; do
            ip tunta del dev "g${i}-${j}" mode tap;
        done;
    done
    ebtables -F
    iptables -F
    iptables -F -t nat
    ip6tables -F
    ip6tables -F -t nat
}

function ping_status {
    local cnt=1
    if ping6 -c "$cnt" -i 0.2 "$1" | grep "${cnt} received" &> /dev/null; then
        echo "ping:ok"
    else
        echo "\e[31mping:down\e[39m"
    fi
}

function ssh_status {
    if echo "" | nc "$1" 22 | grep "SSH" &> /dev/null; then
        echo "ssh:ok"
    else
        echo "\e[31mssh:down\e[39m"
    fi
}

function admin_status {
    vm_admin_if "$1"
    if ! ip link sh dev "$__ret" | grep UP &> /dev/null; then
        echo "\e[31mmngmt{${__ret},status:down}\e[39m"
    else
        local ifname="$__ret"
        guest_ssh_address "$1"
        local addr="$__ret"
        local pingres
        pingres=$(ping_status "$addr")
        local sshres
        sshres=$(ssh_status "$addr")
        local statuscurr="{${ifname}@${addr}, status:up, ${pingres}, ${sshres}}"
        if [[ "$statuscurr"  =~ "\e[31m" ]]; then
            echo "mngmnt $statuscurr"

        else
            echo "\e[32mmngmt\e[39m $statuscurr"
        fi
    fi
}

function bgp_status {
    if [ !  -e "$BIRDCTL" ]; then
        echo "\e[31mbgp:POP${1}-down\e[39m"
    else
        local statuscode
        statuscode=$(echo "sh prot" | birdc6 -s "$BIRDCTL" | grep "$2 " | sed "s/.*as${asn}[ ]*[^ ]*[ ]*[^ ]*[ ]*\([^ ]*\).*/\1/")
        echo "bgp:${statuscode}"
    fi
}

function if_status {
    local out=""
    local count=0
    interfaces_list "$1"
    for i in "${__ret_array[@]}"; do
        out+="\n        "
        local as="${ASN_KEYS[$count]}"
        local asn="${BGP_ASN[$as]}"
        local heading="${as}/POP${asn}"
        if ! ip link sh dev "$i" | grep UP &> /dev/null; then
            out+="\e[31m${heading}{${i},status:down}\e[39m"
        else
            local addr="${NETBASE}:${asn}::${1}"
            local pingres
            pingres=$(ping_status "$addr")
            local bgpres
            bgpres=$(bgp_status "$asn" "as${asn}_group$1")
            local statuscurr="{${i}@${addr}, status:up, ${pingres}, ${bgpres}}"
            if [[ "$statuscurr"  =~ "\e[31m" ]]; then
                out+="${heading} $statuscurr"

            else
                out+="\e[32m${heading}\e[39m $statuscurr"
            fi
        fi
        ((++count))
    done
    echo "$out"
}

function vm_status {
    for g in "${ALL_GROUPS[@]}"; do
        local running
        ctrl_sock "$g"
        local ctl="$__ret"
        if echo "info status" | socat - "UNIX-CONNECT:$ctl" 2>&1 | grep running &> /dev/null; then
            local SSHstatus
            SSHstatus=$(admin_status "$g")
            local interfacesstatus
            interfacesstatus=$(if_status "$g")
            running="\n        ${SSHstatus}${interfacesstatus}"
            if [[ "$running" =~ "\e[31m" ]]; then
                running="\e[33mRUNNING\e[39m$running"
            else
                running="\e[32mRUNNING\e[39m$running"
            fi
        else
            running="\e[31mSTOPPED\e[39m"
        fi
        echo -e "[VM $g] $running"
    done
}

function dump_bgp {
    local ctl
    local fname
    local page
    local head
    IFS='' read -r -d '' head << EOD
<html><head><style>
body{
  font-family: -apple-system, "Helvetica Neue", Helvetica, Arial, sans-serif;
  font-size: 1rem;
  line-height: 1.5;
  color: #373a3c;
}

h1, h2{
  font-family: inherit;
  font-weight: 500;
  line-height: 1.1;
  color: inherit;
}

h1 {
  font-size: 2.5rem;
  margin-top: 3rem;
  margin-bottom: 1rem;
}

h2 {
  font-size: 2rem;
  margin-bottom: 0;
}

ul {
  list-style-type: none;
  font-size: .75rem;
}

a, a:visited, a:active, a:hover {
  color: inherit;
  font-size: inherit;
  font-family: inherit;
  font-style: inherit;
  text-decoration: inherit;
}

li {
  background-color: #d5d5d5;
  border-radius: .25rem;
  padding: .25rem;
  margin: .25rem;
  color: black;
}

li:hover {
  background-color: #c0c0c0;
}

.sep {
  background-color: inherit;
  margin-bottom: .25rem;
}

.menu {
  position: fixed;
  right: 0;
  top: 0;
  margin: 2rem;
  padding: 2rem;
}

code {
  padding: 0.25rem;
  background-color: #f0f0f0;
  border: 1px solid #ddd;
  border-radius: 0.25rem;
  display: inline-block;
  max-width: 100%;
  height: auto;
  font-family: "Courier New", Courier, monospace;
  color: inherit;
  margin-top: 2rem;
}
</style></head><body>
EOD
    while "true"; do
        for asn in "${BGP_ASN[@]}"; do
            fname="as${asn}.status"
            IFS='' read -r -d '' page << EOD || true
${head}
  <h1 id="top">Dump of <strong>ASN${asn}</strong> at $(date)</h1>
    <ul class="menu">
EOD
            for g in "${ALL_GROUPS[@]}"; do
                IFS='' read -r -d '' __ret << EOD || true
      <li><a href="#proto_g${g}">Group ${g} BGP session statistics</a></li>
      <li><a href="#route_g${g}">Routes received from Group ${g}</a></li>
      <li class="sep"></li>
EOD
                page+="$__ret"
            done
            IFS='' read -r -d '' __ret << EOD || true
      <li><a href="#route">Show all routes</a></li>
    </ul>
EOD
            page+="$__ret"
            for g in "${ALL_GROUPS[@]}"; do
                IFS='' read -r -d '' __ret << EOD || true
    <div id="proto_g${g}">
        <h2>Group ${g} BGP session statistics</h2>
        <pre><code>$(echo "show proto all as${asn}_group${g}" | birdc6 -s "$BIRDCTL")</code></pre>
    </div>
    <div id="route_g${g}">
        <h2>Routes received from Group ${g}</h2>
        <pre><code>$(echo "show route all protocol as${asn}_group${g}" | birdc6 -s "$BIRDCTL")</code></pre>
    </div>
EOD
                page+="$__ret"
            done
            IFS='' read -r -d '' __ret << EOD || true
    <div id="route">
        <h2>Show all routes</h2>
        <pre><code>$(echo "show route all table as${asn}" | birdc6 -s "$BIRDCTL")</code></pre>
    </div>
</body></html>
EOD
        page+="$__ret"
        echo "$page" > "$fname"
        done
        sleep 5;
    done
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
    --cli           Connect to the router CLI of the POPs
    --restart-bird  Restart the BGP peering servers
    --dump_bgp      Dump the BGP status of the peers

    -C [group]      Open an SSH connection to the VM of [group] as root
    -c [group]      Open an SSH connection to the VM of [group] as user 'vagrant'

    -V [level]      Set log verbosity level (higher means less verbose, [0-3])
    -h/--help       Display this message

    --status        Print the status of each VM

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
while getopts ":hskdrS:K:D:R:C:-:V:ntc:" optchar; do
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
                status)   vm_status     ;;
                cli)      asn_cli       ;;
                restart-bird) restart_bgp;;
                dump-bgp) dump_bgp      ;;
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
        :) echo "Missing argument for -${OPTARG}" >&2 ;;
        *) print_help          ;;
    esac
done
shift $((OPTIND - 1))
[[ "$#" -gt "0" ]] && print_help
