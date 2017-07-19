#!/bin/bash

# Starting from scratch
ip6tables -F INPUT
ip6tables -F OUTPUT
ip6tables -F FORWARD
ip6tables -F


# Whitelisting policy
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP

# Allow packets coming from related and established connections
ip6tables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow local traffic
ip6tables -A INPUT -i lo -j ACCEPT
ip6tables -A OUTPUT -o lo -j ACCEPT

# Allow DHCP packet
ip6tables -A INPUT -p udp --dport 547 -d ff02::1:2 -j ACCEPT
ip6tables -A FORWARD -p udp -m multiport --dports 546,547 -j ACCEPT
ip6tables -A OUTPUT -p udp -m multiport --dports 546,547 -j ACCEPT

# Allow OSPF
ip6tables -A INPUT -p 89 -j ACCEPT
ip6tables -A OUTPUT -p 89 -j ACCEPT

# Allow ICMPv6
ip6tables -A INPUT -p ipv6-icmp -j ACCEPT
ip6tables -A FORWARD -p ipv6-icmp -j ACCEPT
ip6tables -A OUTPUT -p ipv6-icmp -j ACCEPT

# Allow router to send DNS requests to RNservers
ip6tables -A OUTPUT --dst fd00:200:2::/48 -p udp --dport 53 -j ACCEPT
ip6tables -A OUTPUT --dst fd00:300:2::/48 -p udp --dport 53 -j ACCEPT

# Services policy
ip6tables -A FORWARD --src fd00:200:2::/52 -j ACCEPT
ip6tables -A FORWARD --src fd00:300:2::/52 -j ACCEPT
ip6tables -A INPUT --src fd00:200:2::/52 -j ACCEPT
ip6tables -A INPUT --src fd00:300:2::/52 -j ACCEPT

# Staff policy
# Restrict the services available for the staff
# + Access to MON1/MON2
ip6tables -A FORWARD --src fd00:200:2:1000::/52 -j ACCEPT
ip6tables -A FORWARD --src fd00:300:2:1000::/52 -j ACCEPT
ip6tables -A INPUT --src fd00:200:2:1000::/52 -j ACCEPT
ip6tables -A INPUT --src fd00:300:2:1000::/52 -j ACCEPT

ip6tables -A FORWARD --dst fd00:200:2::1 -j DROP -m comment --comment "restrict access to MON1"
ip6tables -A FORWARD --dst fd00:200:2:205::1 -j DROP -m comment --comment "restrict access to MON2"

# Student policy
# Prevent students to host services
ip6tables -A FORWARD --dst fd00:200:2:2000::/52 -j DROP
ip6tables -A FORWARD --dst fd00:300:2:2000::/52 -j DROP
# Prevent guests to host services
ip6tables -A FORWARD --dst fd00:200:2:3000::/52 -j DROP
ip6tables -A FORWARD --dst fd00:300:2:3000::/52 -j DROP
# Restrict the services available for the students
ip6tables -A FORWARD --src fd00:200:2:2000::/52 -p tcp -m multiport --dports 22,53,80,443,5001 -j ACCEPT
ip6tables -A FORWARD --src fd00:300:2:2000::/52 -p tcp -m multiport --dports 22,53,80,443,5001 -j ACCEPT
ip6tables -A FORWARD --src fd00:200:2:2000::/52 -p udp --dport 53 -j ACCEPT
ip6tables -A FORWARD --src fd00:300:2:2000::/52 -p udp --dport 53 -j ACCEPT

# Guest policy
# Restrict the services available for the guests (HTTP,HTTPS,DNS)
# Only LB1:fd00:200:2:103::4
# LB2:fd00:200:2:204::4
# RNS1:fd00:200:2:103::3
# RNS2:fd00:200:2:204::3

ip6tables -A FORWARD --src fd00:200:2:3000::/52 --dst fd00:200:2:103::4 -p tcp -m multiport --dports 80,443 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:300:2:3000::/52 --dst fd00:200:2:103::4 -p tcp -m multiport --dports 80,443 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:200:2:3000::/52 --dst fd00:300:2:103::4 -p tcp -m multiport --dports 80,443 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:300:2:3000::/52 --dst fd00:300:2:103::4 -p tcp -m multiport --dports 80,443 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:200:2:3000::/52 --dst fd00:200:2:204::4 -p tcp -m multiport --dports 80,443 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:300:2:3000::/52 --dst fd00:200:2:204::4 -p tcp -m multiport --dports 80,443 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:200:2:3000::/52 --dst fd00:300:2:204::4 -p tcp -m multiport --dports 80,443 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:300:2:3000::/52 --dst fd00:300:2:204::4 -p tcp -m multiport --dports 80,443 -j ACCEPT -m comment --comment "restrict guest access"

ip6tables -A FORWARD --src fd00:200:2:3000::/52 --dst fd00:200:2:103::3 -p tcp --dport 53 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:300:2:3000::/52 --dst fd00:200:2:103::3 -p tcp --dport 53 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:200:2:3000::/52 --dst fd00:200:2:103::3 -p udp --dport 53 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:300:2:3000::/52 --dst fd00:200:2:103::3 -p udp --dport 53 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:200:2:3000::/52 --dst fd00:200:2:204::3 -p tcp --dport 53 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:300:2:3000::/52 --dst fd00:200:2:204::3 -p tcp --dport 53 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:200:2:3000::/52 --dst fd00:200:2:204::3 -p udp --dport 53 -j ACCEPT -m comment --comment "restrict guest access"
ip6tables -A FORWARD --src fd00:300:2:3000::/52 --dst fd00:200:2:204::3 -p udp --dport 53 -j ACCEPT -m comment --comment "restrict guest access"

# Phones policy
ip6tables -A FORWARD --src fd00:200:2:4000::/52 -p tcp -m multiport --dports 53,5001,5060 -j ACCEPT
ip6tables -A FORWARD --src fd00:300:2:4000::/52 -p tcp -m multiport --dports 53,5001,5060 -j ACCEPT

# Allow traceroute tool
ip6tables -A INPUT -p udp --dport 33434:33534 -j ACCEPT
ip6tables -A FORWARD -p udp --dport 33434:33534 -j ACCEPT
ip6tables -A OUTPUT -p udp --dport 33434:33534 -j ACCEPT

# Allow DNS and other services from outside
ip6tables -A FORWARD --dst fd00:200:2::/48 -p tcp -m multiport --dports 22,25,53,80,443 -j ACCEPT -m comment --comment "outside traffic"
ip6tables -A FORWARD --dst fd00:300:2::/48 -p tcp -m multiport --dports 22,25,53,80,443 -j ACCEPT -m comment --comment "outside traffic"
ip6tables -A FORWARD --dst fd00:200:2::/48 -p udp --dport 53 -j ACCEPT -m comment --comment "outside traffic"
ip6tables -A FORWARD --dst fd00:300:2::/48 -p udp --dport 53 -j ACCEPT -m comment --comment "outside traffic"

# Log the dropped packets
ip6tables -A INPUT -j NFLOG --nflog-prefix "[DROP-INPUT]CARN"
ip6tables -A FORWARD -j NFLOG --nflog-prefix "[DROP-FORWARD]CARN"
ip6tables -A OUTPUT -j NFLOG --nflog-prefix "[DROP-OUTPUT]CARN"
