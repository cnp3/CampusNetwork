#!/bin/bash

# initializing paramters
MAX_BANDWIDTH=80mbit
INTERFACE=$1

# Class 1 params (network)
CLASS1_RATE=8mbit
CLASS1_CEIL=$MAX_BANDWIDTH
CLASS1_BURST=25k
CLASS1_PFIFO_LIMIT=100

# Class 2 params(VoIP)
CLASS2_RATE=8mbit
CLASS2_CEIL=$MAX_BANDWIDTH
CLASS2_BURST=25k
CLASS2_PFIFO_LIMIT=100

# Class 3 params(video)
CLASS3_RATE=24mbit
CLASS3_CEIL=$MAX_BANDWIDTH
CLASS3_BURST=25k
CLASS3_PFIFO_LIMIT=100

# Class 4 params(ssh)
CLASS4_RATE=4mbit
CLASS4_CEIL=$MAX_BANDWIDTH
CLASS4_BURST=25k
CLASS4_SFQ_PERTURB=10
CLASS4_SFQ_LIMIT=100

# Class 5 params(http/ https)
CLASS5_RATE=20mbit
CLASS5_CEIL=$MAX_BANDWIDTH
CLASS5_BURST=25k
CLASS5_SFQ_PERTURB=10
CLASS5_SFQ_LIMIT=100

# Class default(rest)
DEFAULT_RATE=16mbit
DEFAULT_CEIL=$MAX_BANDWIDTH
DEFAULT_BURST=25K
DEFAULT_SFQ_PERTURB=10
DEFAULT_SFQ_LIMIT=100

# _______________________________________________________________________________________________________________________________



# Defining root qdisc
tc qdisc add dev $INTERFACE root handle 1: htb default 99

# First class to limit max bandwith
tc class add dev $INTERFACE parent 1:0 classid 1:1 htb rate $MAX_BANDWIDTH ceil $MAX_BANDWIDTH



# _______________________________________________________________________________________________________________________________



# Class 1 for network packet (highest priority): Low bandwith needed but high availability (DNS included here)
tc class add dev $INTERFACE parent 1:1 classid 1:10 htb rate $CLASS1_RATE ceil $CLASS1_CEIL burst $CLASS1_BURST prio 1

# Pfifo for class 1
tc qdisc add dev $INTERFACE parent 1:10 handle 10: pfifo limit $CLASS1_PFIFO_LIMIT

# Defining filter for pfifo class 1
tc filter add dev $INTERFACE parent 1:0 protocol ipv6 prio 1 handle 100 fw flowid 1:10

# Marking packets for pfifo class 1(network packets)
# Filter for ospfv3
 ip6tables -A POSTROUTING -t mangle -o $INTERFACE -p 89 -j MARK --set-mark 100

# Adresse of dns servers
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:200:3:100::53/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:300:3:100::53/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:200:3:101::53/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:300:3:101::53/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:200:3:100::53/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:300:3:100::53/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:200:3:101::53/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:300:3:101::53/128 -j MARK --set-mark 100

# Adresse of dhcp servers
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:200:3:100::547/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:300:3:100::547/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:200:3:101::547/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:300:3:101::547/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:200:3:100::547/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:300:3:100::547/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:200:3:101::547/128 -j MARK --set-mark 100
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:300:3:101::547/128 -j MARK --set-mark 100


# _______________________________________________________________________________________________________________________________


#Class 2 for voice over ip and dns: Low bandwidth needed but high availability
tc class add dev $INTERFACE parent 1:1 classid 1:20 htb rate $CLASS2_RATE ceil $CLASS2_CEIL burst $CLASS2_BURST prio 2

# Pfifo for class 2
tc qdisc add dev $INTERFACE parent 1:20 handle 20: pfifo limit $CLASS2_PFIFO_LIMIT

# Defining filter for pfifo class 2
tc filter add dev $INTERFACE parent 1:0 protocol ipv6 prio 2 handle 200 fw flowid 1:20

# Marking packets for pfifo class 2(VoIP)
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:200:3:0500::/56 -j MARK --set-mark 200
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:300:3:0500::/56 -j MARK --set-mark 200
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:200:3:0500::/56 -j MARK --set-mark 200
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:300:3:0500::/56 -j MARK --set-mark 200


# _______________________________________________________________________________________________________________________________


# Class 3 for TCP ACKS(video)
tc class add dev $INTERFACE parent 1:1 classid 1:30 htb rate $CLASS3_RATE ceil $CLASS3_CEIL burst $CLASS3_BURST prio 3

# Pfifo for class 3
tc qdisc add dev $INTERFACE parent 1:30 handle 30: pfifo limit $CLASS3_PFIFO_LIMIT

# Defining filter for pfifo class 3
tc filter add dev $INTERFACE parent 1:0 protocol ipv6 prio 3 handle 300 fw flowid 1:30

# Marking packet for class 3
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:200:3:0600::/56 -j MARK --set-mark 300
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -s fd00:300:3:0600::/56 -j MARK --set-mark 300
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:200:3:0600::/56 -j MARK --set-mark 300
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -d fd00:300:3:0600::/56 -j MARK --set-mark 300



# _______________________________________________________________________________________________________________________________


# Class 4 for ssh
tc class add dev $INTERFACE parent 1:1 classid 1:40 htb rate $CLASS4_RATE ceil $CLASS4_CEIL burst $CLASS4_BURST prio 4

# Sfq for class 4
tc qdisc add dev $INTERFACE parent 1:40 handle 40: sfq perturb $CLASS4_SFQ_PERTURB limit $CLASS4_SFQ_LIMIT

# filter for sfq class 4
tc filter add dev $INTERFACE parent 1:0 protocol ipv6 prio 4 handle 400 fw flowid 1:40

# Marking packet for class 4
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -m multiport -p tcp --dport 23 -j CONNMARK --set-mark 400
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -m multiport -p tcp --sport 23 -j CONNMARK --set-mark 400



# _______________________________________________________________________________________________________________________________


# Class 5 for http/https
tc class add dev $INTERFACE parent 1:1 classid 1:50 htb rate $CLASS5_RATE ceil $CLASS5_CEIL burst $CLASS5_BURST prio 4

# Sfq for class 5
tc qdisc add dev $INTERFACE parent 1:50 handle 50: sfq perturb $CLASS5_SFQ_PERTURB limit $CLASS5_SFQ_LIMIT

# filter for sfq class 5
tc filter add dev $INTERFACE parent 1:0 protocol ipv6 prio 5 handle 500 fw flowid 1:50

# Marking packet for class 5
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -m multiport -p tcp --dport 80 -j CONNMARK --set-mark 500
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -m multiport -p tcp --dport 443 -j CONNMARK --set-mark 500
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -m multiport -p tcp --sport 80 -j CONNMARK --set-mark 500
ip6tables -A POSTROUTING -t mangle -o $INTERFACE -m multiport -p tcp --sport 443 -j CONNMARK --set-mark 500


# _______________________________________________________________________________________________________________________________

# Default class
tc class add dev $INTERFACE parent 1:1 classid 1:99 htb rate $DEFAULT_RATE ceil $DEFAULT_CEIL burst $DEFAULT_BURST prio 9

# sfq qdisc default class
tc qdisc add dev $INTERFACE parent 1:99 handle 99: sfq perturb $DEFAULT_SFQ_PERTURB limit $DEFAULT_SFQ_LIMIT

# filter for default class
#tc filter add dev $INTERFACE parent 1:0 protocol ipv6 prio 99 handle 999 fw flowid 1:99


