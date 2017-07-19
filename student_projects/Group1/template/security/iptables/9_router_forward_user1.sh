ip6tables -A FORWARD --src [[prefix_a]]:[[zone]]100::/56 -p tcp --match multiport --dports 22,25,53,80,110,143,220,443,993,995,5001 -j ACCEPT -m comment --comment "user type: 1" 
ip6tables -A FORWARD --src [[prefix_b]]:[[zone]]100::/56 -p tcp --match multiport --dports 22,25,53,80,110,143,220,443,993,995,5001 -j ACCEPT -m comment --comment "user type: 1"
ip6tables -A FORWARD --src [[prefix_a]]:[[zone]]100::/56 -p udp --dport 53 -j ACCEPT -m comment --comment "user type: 1"
ip6tables -A FORWARD --src [[prefix_b]]:[[zone]]100::/56 -p udp --dport 53 -j ACCEPT -m comment --comment "user type: 1"
