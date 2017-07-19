#########################################################
#	        	Make SNMP run on router            		#
#########################################################
/usr/sbin/snmpd -Lsd -Lf /dev/null -u snmp -g snmp -I -smux,mteTrigger,mteTriggerConf -p /run/[[node]]snmpd.pid udp6:161
