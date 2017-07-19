
## INPUT
# block packets that targets routers (protection against neighbor discovery attack)
ip6tables -A INPUT -d [[prefix_a]]:0f00::/56 -j DROP
ip6tables -A INPUT -d [[prefix_b]]:0f00::/56 -j DROP
# Allows loopback
ip6tables -A INPUT -i lo -j ACCEPT
# Prevents from ddos attack with Router Advertisements
ip6tables -A INPUT -p icmpv6 --icmpv6-type router-advertisement -j DROP
# We allow ICMPv6 for testing purpose (ping, traceroute). Note this is already
# blocked from outside of the network in a previous script "router_border_network".
ip6tables -A INPUT -p ipv6-icmp -j ACCEPT
# Allows ospf
ip6tables -A INPUT -p ospf -j ACCEPT
# Permits to use traceroute without completely open these ports to the internet
ip6tables -A INPUT -p udp --dport 33434:33534 -j REJECT
# Allow DHCP packets inside the network.
ip6tables -A INPUT -p udp --dport 547 -d ff02::1:2 -j ACCEPT

## OUTPUT
# Allows loopback
ip6tables -A OUTPUT -o lo -j ACCEPT
# We allow ICMPv6 for testing purpose (ping, traceroute)
ip6tables -A OUTPUT -p ipv6-icmp -j ACCEPT
# Allows ospf (knowing it is previously forebidden towards/from lans and external network)
ip6tables -A OUTPUT -p ospf -j ACCEPT
# Allows to use traceroute
ip6tables -A OUTPUT -p udp --dport 33434:33534 -j ACCEPT
# Allow DHCP packets inside the network
ip6tables -A OUTPUT -p udp --dport 547 -j ACCEPT
# DHCP towards client
ip6tables -A OUTPUT -p udp --dport 546 -j ACCEPT
# Allow SNMP responses from routers and administrators only (Prefix:0f00::/56)
ip6tables -A OUTPUT -p udp --sport 161 -s [[prefix_a]]:0f00::/56 -j ACCEPT
ip6tables -A OUTPUT -p udp --sport 161 -s [[prefix_b]]:0f00::/56 -j ACCEPT
ip6tables -A OUTPUT -p udp --sport 161 -s [[prefix_a]]:0020::/64 -j ACCEPT
ip6tables -A OUTPUT -p udp --sport 161 -s [[prefix_b]]:0020::/64 -j ACCEPT

## FORWARD
# Prevents from ddos attack with Router Advertisements
ip6tables -A FORWARD -p icmpv6 --icmpv6-type router-advertisement -j DROP
# block packets that targets routers (protection against neighbor discovery attack)
ip6tables -A FORWARD -d [[prefix_a]]:0f00::/56 -j DROP
ip6tables -A FORWARD -d [[prefix_b]]:0f00::/56 -j DROP
# We accept ICMPv6 for testing purpose when it comes from inside of the network.
ip6tables -A FORWARD -p ipv6-icmp -j ACCEPT
# Allows ospf
ip6tables -A FORWARD -p ospf -j ACCEPT
# Permits to use traceroute
ip6tables -A FORWARD -p udp --dport 33434:33534 -j ACCEPT
# Allow DHCP packets inside the network
ip6tables -A FORWARD -p udp --dport 547 -j ACCEPT
# DHCP toward client
ip6tables -A FORWARD -p udp --dport 546 -j ACCEPT
# Allow SNMP from routers and administrators only (routers have 'prefix:0f00::/56')
ip6tables -A FORWARD -p udp --sport 161 -s [[prefix_a]]:0f00::/56 -j ACCEPT
ip6tables -A FORWARD -p udp --sport 161 -s [[prefix_b]]:0f00::/56 -j ACCEPT
ip6tables -A FORWARD -p udp --sport 161 -s [[prefix_a]]:0020::/64 -j ACCEPT
ip6tables -A FORWARD -p udp --sport 161 -s [[prefix_b]]:0020::/64 -j ACCEPT
