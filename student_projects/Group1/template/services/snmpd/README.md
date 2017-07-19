You need to have snmp and snmpd installed. If not present, run:

    sudo apt-get install snmp snmpd

snmpd should running on the 6 core routers and L3 switches. To query the server, run for example:

    sudo util/exec_command.sh CARN snmpwalk -v 2c -c public udp6:[::1]:161

if you want to query CARN.
