# [[router]] is a border router (it is connected to the internet through [[interface]]).
# block traffic going to wrong AS output.
ip6tables -A FORWARD -o [[interface]] -s [[prefix]]::/48 -j DROP
ip6tables -A OUTPUT  -o [[interface]] -s [[prefix]]::/48 -j DROP

# Border router: block incomming packets that have a source ip from our network (spoofed source ip).
ip6tables -A FORWARD -i [[interface]] -s [[prefix_a]]::/50 -j DROP -m comment --comment "spoofed source ip"
ip6tables -A INPUT   -i [[interface]] -s [[prefix_b]]::/50 -j DROP -m comment --comment "spoofed source ip"

# Allow bgp on this border router on the interface where bgp should be enabled
ip6tables -A OUTPUT -o [[interface]] -p tcp -j ACCEPT --dport 179
ip6tables -A INPUT  -i [[interface]] -p tcp -j ACCEPT --dport 179

# Block ospf (in both direction) on interface [[interface]] as we should not receive such 
# packet from internet and it permits to avoid by error to send or ospf packet to the internet.
ip6tables -A INPUT   -i [[interface]] -p ospf -j DROP
ip6tables -A FORWARD -i [[interface]] -p ospf -j DROP
ip6tables -A FORWARD -o [[interface]] -p ospf -j DROP
ip6tables -A OUTPUT  -o [[interface]] -p ospf -j DROP

# block dhcp client/server on the interface [[interface]] as it should not transit 
# towards/from the internet.
ip6tables -A FORWARD -p udp -i [[interface]] --dport 547 -j DROP
ip6tables -A FORWARD -p udp -i [[interface]] --dport 546 -j DROP
ip6tables -A FORWARD -p udp -o [[interface]] --dport 547 -j DROP
ip6tables -A FORWARD -p udp -o [[interface]] --dport 546 -j DROP
ip6tables -A INPUT   -p udp -i [[interface]] --dport 547 -j DROP
ip6tables -A INPUT   -p udp -i [[interface]] --dport 546 -j DROP
ip6tables -A OUTPUT  -p udp -o [[interface]] --dport 547 -j DROP
ip6tables -A OUTPUT  -p udp -o [[interface]] --dport 546 -j DROP

# block packets received on the interface [[interface]] towards routers
# (prevent from discovering topology from outside and to target a router directly 
# + protection against neighbor discovery attack)
ip6tables -A FORWARD -i [[interface]] -d [[prefix_a]]:0f00::/56 -j DROP
ip6tables -A INPUT   -i [[interface]] -d [[prefix_a]]:0f00::/56 -j DROP
ip6tables -A FORWARD -i [[interface]] -d [[prefix_b]]:0f00::/56 -j DROP
ip6tables -A INPUT   -i [[interface]] -d [[prefix_b]]:0f00::/56 -j DROP

# block icmpv6 forwarding on the interface [[interface]]
# (see report for more explainations on this choice).
ip6tables -A FORWARD -i [[interface]] -p ipv6-icmp -j DROP

# block traceroute on the interface [[interface]]
# (see report for more explainations on this choice).
ip6tables -A INPUT   -i [[interface]] -p udp --dport 33434:33534 -j DROP
ip6tables -A FORWARD -i [[interface]] -p udp --dport 33434:33534 -j DROP
