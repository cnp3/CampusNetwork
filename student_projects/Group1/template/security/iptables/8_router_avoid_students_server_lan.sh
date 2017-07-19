ip6tables -A FORWARD --dst [[prefix_a]]:[[zone]]100::/56 -j DROP
ip6tables -A FORWARD --dst [[prefix_b]]:[[zone]]100::/56 -j DROP
