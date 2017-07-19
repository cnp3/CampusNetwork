#########################################################
#	         Shaping for [[interface]]          		#
#########################################################

IFC="[[interface]]"

# Project definition
#   Link are 10mbps (assume it's 10gbps in real life)
#   -> Scale factor for the project = 1:1000

# Default qdisc and root class (htb)
tc qdisc add dev $IFC root handle 1: htb default 30                     # Default qdisc = HTB
tc class add dev $IFC parent 1: classid 1:1 htb rate 9mbit burst 30k    # Root class: rate = 90% of max BW
                                                                        # Burst = Bc = CIR*Tc ; CIR = 9Mbit/s, Tc(Cisco by default) = 125ms
                                                                        # Bc = 0.125s * 9000000bits/s = 1125000 bits = 140625 bytes
                                                                        # Let's take 30k, the highest value from its children

# Class definition
ADDCLASS="tc class add dev $IFC parent 1:1 classid"
$ADDCLASS 1:10 htb rate 100kbit ceil 1mbit prio 0 burst 5k        # Super interactive: high prio, low BW
                                                                   #        no bursts (real time)
                                                                   #        = small burst
                                                                   # https://linux.die.net/man/8/tc-tbf
$ADDCLASS  1:20 htb rate 1mbit ceil 3mbit prio 1 burst 15k         # Interactive: middle-high prio and BW
$ADDCLASS  1:30 htb rate 6mbit ceil 9mbit prio 2 burst 30k         # Normal: high BW
$ADDCLASS  1:40 htb rate 300kbit ceil 9mbit prio 3 burst 20k       # Low: low BW (but can borrow if possible)

# Fairness inside classes
tc qdisc add dev $IFC parent 1:10 handle 10: sfq perturb 10
tc qdisc add dev $IFC parent 1:20 handle 20: sfq perturb 10
tc qdisc add dev $IFC parent 1:30 handle 30: sfq perturb 10
tc qdisc add dev $IFC parent 1:40 handle 40: sfq perturb 10

# Using iptables for marking in order to have more flexibility
FILTER="tc filter add dev $IFC protocol ipv6 parent 1:0"
$FILTER handle 51 fw flowid 1:10 # Super interactive traffic : mark 51
$FILTER handle 52 fw flowid 1:20 # Interactive traffic       : mark 52
$FILTER handle 53 fw flowid 1:30 # Normal traffic            : mark 53
$FILTER handle 54 fw flowid 1:40 # Bulk traffic              : mark 54

ip6tables -t mangle -A PREROUTING -i $IFC -p icmp -j MARK --set-mark 51                                      # ICMP is super high prio
ip6tables -t mangle -A PREROUTING -i $IFC -p tcp --dport 2100 -j MARK --set-mark 51                          # Camera is super high prio
ip6tables -t mangle -A PREROUTING -i $IFC -p tcp --match multiport --dports 5061,5060 -j MARK --set-mark 51  # SIP is super high prio
ip6tables -t mangle -A PREROUTING -i $IFC -p udp --match multiport --dports 5061,5060 -j MARK --set-mark 51  # SIP is super high prio
ip6tables -t mangle -A PREROUTING -i $IFC -p udp --dport 16384:32767 -j MARK --set-mark 51                   # VOIP is super high prio

ip6tables -t mangle -A PREROUTING -i $IFC -p tcp --dport 22 -j MARK --set-mark 52                            # SSH is high prio
ip6tables -t mangle -A PREROUTING -i $IFC -p tcp --match multiport --dports 161,162 -j MARK --set-mark 52    # SNMP is high prio
ip6tables -t mangle -A PREROUTING -i $IFC -p udp --dport 53 -j MARK --set-mark 52                            # DNS is high prio
ip6tables -t mangle -A PREROUTING -i $IFC -p tcp --dport 53 -j MARK --set-mark 52                            # DNS is high prio

ip6tables -t mangle -A PREROUTING -i $IFC -p tcp --match multiport --dports 80,443 -j MARK --set-mark 53     # HTTP(s) is normal trafic

ip6tables -t mangle -A PREROUTING -i $IFC -p tcp --dport 5001 -j MARK --set-mark 54                          # Suppose 5001 is backup protocol

