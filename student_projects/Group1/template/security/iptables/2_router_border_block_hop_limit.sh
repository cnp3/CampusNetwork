# This router is a 'border router': there is a BGP session running on the interface [[interface]].
# We block hop limit exceeded towards outside network (rule against topology discovery with traceroute)
ip6tables -A OUTPUT  -o [[interface]] -p icmpv6 --icmpv6-type time-exceeded -j DROP
ip6tables -A FORWARD -o [[interface]] -p icmpv6 --icmpv6-type time-exceeded -j DROP
