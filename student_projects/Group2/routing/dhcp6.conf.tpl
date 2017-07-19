#-updates-style parameter controls whether or not the server will
# attempt to do a DNS update when a lease is confirmed.
ddns-update-style none;

# Option definitions common to all supported networks...
default-lease-time 43200; # 12 hours
max-lease-time 43200; # 12 hours

# This DHCP server is the official DHCP server for the local network
authoritative;

option dhcp6.name-servers fd00:200:2:103::3, fd00:200:2:204::3; # Both recursive DNS servers

# Subnet declaration
subnet6 {{ own_subnet }} { # Stub subnet, needed by dhcpd, otherwise it won't start
}

{% for subnet in subnets %}
subnet6 {{ subnet.net }} { # Subnet managed by DHCP
	range6 {{ subnet.low }} {{ subnet.high }}; # Indicate the pool of IP addresses that can be allocated by this server
}
{% endfor %}

