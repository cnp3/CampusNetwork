# Allows the responses to legitime messages and allows other 
# connections related to an authorized connection.
ip6tables -A OUTPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT
ip6tables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -A INPUT   -m state --state ESTABLISHED,RELATED -j ACCEPT
