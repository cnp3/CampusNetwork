# Avoid spoofing for packets comming from [[interface]]
ip6tables -N spoof[[interface]]
# don't consider an ip that belong to the good /64 subnet as a spoofed ip:
ip6tables -A spoof[[interface]] -i [[interface]] --src [[prefix_a]]:[[suffix]]/64 -j RETURN 
ip6tables -A spoof[[interface]] -i [[interface]] --src [[prefix_b]]:[[suffix]]/64 -j RETURN
# don't consider local communications for spoofing:
ip6tables -A spoof[[interface]] -i [[interface]] --src fe80::/10 -j RETURN 
# don't consider initial unspecified source as a spoofed ip:
ip6tables -A spoof[[interface]] -i [[interface]] --src ::/128 -j RETURN 
# this can be considered as a spoofed source ip:
ip6tables -A spoof[[interface]] -i [[interface]] -j DROP -m comment --comment "spoofed source ip"
# link this additional filter in the general INPUT and FORWARD filter:
ip6tables -i [[interface]] -t filter -A INPUT -j spoof[[interface]]
ip6tables -i [[interface]] -t filter -A FORWARD -j spoof[[interface]]
# block OSPF from/towards this lan (it is routing packets, it should not be shared with end users
# and we should not accept such packets from end users)
ip6tables -A INPUT -i [[interface]] -p ospf -j DROP
ip6tables -A FORWARD -i [[interface]] -p ospf -j DROP
ip6tables -A OUTPUT -o [[interface]] -p ospf -j DROP
