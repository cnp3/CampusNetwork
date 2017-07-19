ip6tables -A FORWARD --src [[prefix_a]]:[[zone]]000::/56 -j ACCEPT -m comment --comment "user type: 0"
ip6tables -A FORWARD --src [[prefix_b]]:[[zone]]000::/56 -j ACCEPT -m comment --comment "user type: 0"
ip6tables -A INPUT   --src [[prefix_a]]:[[zone]]000::/56 -j ACCEPT -m comment --comment "user type: 0"
ip6tables -A INPUT   --src [[prefix_b]]:[[zone]]000::/56 -j ACCEPT -m comment --comment "user type: 0"
