
# drop everything else comming from our network as it should have match a previous criterion.
ip6tables -A FORWARD --src [[prefix_a]]::/48 -j DROP
ip6tables -A FORWARD --src [[prefix_b]]::/48 -j DROP

# here we know that the packet has a source not in our prefix. It comes from outside our own network.
# Only the following port are open from outside : 22,25,53,80,443 in tcp; 53 in udp. 
# We consider these services as the minimal services that should be allowed for external users. 
# This list can easily be extended as needed.
ip6tables -A FORWARD --dst [[prefix_a]]::/48 -p tcp --match multiport --dports 22,25,53,80,443 -j ACCEPT -m comment --comment "comming from outside" 
ip6tables -A FORWARD --dst [[prefix_b]]::/48 -p tcp --match multiport --dports 22,25,53,80,443 -j ACCEPT -m comment --comment "comming from outside"
ip6tables -A FORWARD --dst [[prefix_a]]::/48 -p udp --dport 53 -j ACCEPT -m comment --comment "comming from outside"
ip6tables -A FORWARD --dst [[prefix_b]]::/48 -p udp --dport 53 -j ACCEPT -m comment --comment "comming from outside"

