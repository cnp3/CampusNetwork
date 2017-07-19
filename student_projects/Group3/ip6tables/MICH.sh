#!/bin/bash

# Useful variables
STUDENTS_2="fd00:200:3:304::/64"
STUDENTS_3="fd00:300:3:304::/64"

echo 'Flushing previous ruleset'
    ip6tables -F
    ip6tables -t nat -F
    ip6tables -t mangle -F
    ip6tables -X
    ip6tables -t nat -X
    ip6tables -t mangle -X 

echo 'Setting default policies'

    # Drop everything
    ip6tables -P INPUT DROP
    ip6tables -P OUTPUT DROP
    ip6tables -P FORWARD DROP

    # Accept traffic for already established connections & local
    ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A INPUT -i lo -j ACCEPT #local loopback
    ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    ip6tables -A OUTPUT -o lo -j ACCEPT #local loopback
    ip6tables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Drop INVALID packets
    ip6tables -A INPUT -m state --state INVALID -j DROP
    ip6tables -A OUTPUT -m state --state INVALID -j DROP
    ip6tables -A FORWARD -m state --state INVALID -j DROP
    
    ip6tables -A INPUT ! -p icmpv6 -m state --state INVALID -j DROP
    ip6tables -A OUTPUT ! -p icmpv6 -m state --state INVALID -j DROP
    ip6tables -A FORWARD ! -p icmpv6 -m state --state INVALID -j DROP

    # Echo Request (limitation to avoid flooding)
    ip6tables -A INPUT -p icmpv6 --icmpv6-type 128/0 -j ACCEPT --match limit --limit 10/minute

    # Neighbor Solicitation limitation to avoid DoS on neighboor cache
    # (http://www.labs.lacnic.net/site/sites/default/files/070-ipv6-security-lacnic-01.pdf)
    ip6tables -A INPUT -p icmpv6 --icmpv6-type 135/0 -j ACCEPT --match limit --limit 10/minute

    # ICMPv6 traffic (128/0, 133/0, 134/0, 135/0, 136/0)
    ip6tables -A INPUT -p icmpv6 -j ACCEPT
    ip6tables -A OUTPUT -p icmpv6 -j ACCEPT
    ip6tables -A FORWARD -p icmpv6 -j ACCEPT

    # Refuse router advertisement from students (flooding or misbehaviour)
    # (https://www.researchgate.net/publication/266022049_ICMPv6_Router_Advertisement_Flooding)
    ip6tables -A INPUT -s $STUDENTS_2 -p icmpv6 --icmpv6-type 134/0 -j DROP
    ip6tables -A INPUT -s $STUDENTS_3 -p icmpv6 --icmpv6-type 134/0 -j DROP

    # Multicast Listener Report Message v2
    ip6tables -A INPUT -p icmpv6 --icmpv6-type 143/0 -j ACCEPT

    # Allow OSPF
    ip6tables -A INPUT -p ospf -j ACCEPT
    ip6tables -A OUTPUT -p ospf -j ACCEPT
    ip6tables -A FORWARD -p ospf -j ACCEPT

    # Allow DHCPv6 traffic
    ip6tables -A INPUT -m state --state NEW -m udp -p udp --dport 546 -d fe80::/64 -j ACCEPT

    # Allow TCP traffic towards port 5201 for iperf3 used in QoS
    ip6tables -A INPUT -p tcp -m tcp --destination-port 5201 -j ACCEPT
    ip6tables -A OUTPUT -p tcp -m tcp --destination-port 5201 -j ACCEPT
    ip6tables -A FORWARD -p tcp -m tcp --destination-port 5201 -j ACCEPT

    # Authorize incoming SSH connections
    ip6tables -A INPUT -s 2000::/3 -p tcp --dport 22 --syn -m state --state NEW -j ACCEPT

    # Authorize SSH, SMTP, HTTP, HTTPS, DNS
    # For first and second provider, staff and students
    for i in 200 300;
    do
        for j in 2 3; 
        do
            temp="04"
            tempf=$j$temp

            # Block student and staff from connecting with each other
            ip6tables -A FORWARD -s fd00:$i:3:$tempf::/64 -d fd00:$i:3:$tempf::/64 -j DROP 
  
            # Allow SSH for students and staff members
            ip6tables -A FORWARD -p tcp -s fd00:$i:3:$tempf::/64 -d fd00:$i::3/48 --destination-port 22 -j ACCEPT

            # Allow SMTP for students and staff members
            ip6tables -A FORWARD -p tcp -s fd00:$i:3:$tempf::/64 -d fd00:$i::3/48 --destination-port 25 -j ACCEPT
  
            # Allow HTTP and HTTPS for students and staff members
            ip6tables -A FORWARD -p tcp -s fd00:$i:3:$tempf::/64 -d fd00:$i::3/48 --destination-port 80 -j ACCEPT
            ip6tables -A FORWARD -p tcp -s fd00:$i:3:$tempf::/64 -d fd00:$i::3/48 --destination-port 443 -j ACCEPT

            # Allow DNS traffic (both over UDP and TCP)
            # First datacenter
            ip6tables -A INPUT -s fd00:$i:3:100::80 -p udp --destination-port 53 -j ACCEPT
            ip6tables -A OUTPUT -d fd00:$i:3:100::80 -p udp --destination-port 53 -j ACCEPT
            ip6tables -A FORWARD -d fd00:$i:3:100::80 -p udp --destination-port 53 -j ACCEPT
            ip6tables -A INPUT -s fd00:$i:3:100::80 -p tcp --destination-port 53 -j ACCEPT
            ip6tables -A OUTPUT -d fd00:$i:3:100::80 -p tcp --destination-port 53 -j ACCEPT
            ip6tables -A FORWARD -d fd00:$i:3:100::80 -p tcp --destination-port 53 -j ACCEPT
            # Second datacenter
            ip6tables -A INPUT -s fd00:$i:3:101::80 -p udp --destination-port 53 -j ACCEPT
            ip6tables -A OUTPUT -d fd00:$i:3:101::80 -p udp --destination-port 53 -j ACCEPT
            ip6tables -A FORWARD -d fd00:$i:3:101::80 -p udp --destination-port 53 -j ACCEPT
            ip6tables -A INPUT -s fd00:$i:3:101::80 -p tcp --destination-port 53 -j ACCEPT
            ip6tables -A OUTPUT -d fd00:$i:3:101::80 -p tcp --destination-port 53 -j ACCEPT
            ip6tables -A FORWARD -d fd00:$i:3:101::80 -p tcp --destination-port 53 -j ACCEPT;
        done;
    done

    # Allow HTTP and HTTPS for guests
    for k in 200 300
    do
        ip6tables -A FORWARD -p tcp -s fd00:$k:3:404::/64 -d fd00:$k::3/48 --destination-port 80 -j ACCEPT
        ip6tables -A FORWARD -p tcp -s fd00:$k:3:404::/64 -d fd00:$k::3/48 --destination-port 443 -j ACCEPT
    done

    # Record all dropped packets in files
    ip6tables -N LOGGING
    ip6tables -A INPUT -j LOGGING
    ip6tables -A OUTPUT -j LOGGING
    ip6tables -A FORWARD -j LOGGING
    ip6tables -A LOGGING -m limit --limit 10/minute -j LOG --log-prefix "IP6Tables-Dropped: " --log-level 4
    ip6tables -A LOGGING -j DROP

exit 0

