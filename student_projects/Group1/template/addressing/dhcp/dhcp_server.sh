#########################################################
#		Run the DHCP server (to announce DNS)    		#
#########################################################
touch /var/lib/dhcp/dhcpd_[[node]].leases
dhcpd -6 -lf /var/lib/dhcp/dhcpd_[[node]].leases -pf /var/run/dhcpd_[[node]].pid
