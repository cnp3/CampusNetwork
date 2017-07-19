#########################################################
#	             Setting up firewall            		#
#########################################################

# Begin by flushing any default rules to create them from scratch:
ip6tables -F INPUT
ip6tables -F OUTPUT
ip6tables -F FORWARD
ip6tables -F

# We use a whitlisting policy so we only allow packets that match precise rules and we drop 
# anything else, in INPUT/FORWARD/OUTPUT (see our report for more details about whitelisting)
ip6tables -P OUTPUT DROP
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
