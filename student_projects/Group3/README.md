# Group 3

Every commands needs to be ran with 'sudo'.

To launch the network : sudo ./launch.sh
This launch script will cleanup the project, create all configuration files and create the network.
Don't forget to install the dhcp relay : sudo apt-get install isc-dhcp-relay
Wait two minutes after the launch of the network to be sure it stabilized before running tests.

##TESTING

##### Routing test
All the routing tests should be ran on MONIT (sudo ./connect_to MONIT) with 'sudo'.

The script give information but when doing connectivity test, only the UNREACHABLE
addresses are displayed.

Routing tests in routing_test/
- bgp_peering_group1.sh : give the status of peering with group1 and show exported prefix
- status_and_exported_prefix_to_isp.sh : give status of peering with ISPs and show exported prefixes
- host_connectivity.sh : launch connectivity test from one host on each lan (<host>1) to each address in project_cfg/MONIT/addresses_for_host_test.txt (every router interface, DNS, load balancer, ISP and Google), print only unreachable addresses.
- router_connectivity.sh : launch connectivity test from all routers to each address in project_cfg/MONIT/addresses_for_router_test.txt (every router interface, DNS, load balancer, ISP and Google), print only unreachable addresses.
- isp_down_connectivity.sh <router> : router must be HALL or PYTH. Set interface down on <router> which communicate with ISP, check that the peering is down, wait for 20 sec, run host_connectivity.sh, brings roruter interface back up.
- link_failure_SH1C_HALL.sh : shut down interface SH1C-eth1, wait for 20 seconds, run host_connectivity.sh, bring interface back up.
- link_failure_HALL_PYTH.sh : shut down interface HALL-eth1, wait for 20 seconds, run host_connectivity.sh, bring interface back up. This test is used to make sure that the source routing between HALL and PYTH is still working if one of the link between them fails.
- router_failure.sh : kill bird daemon on HALL, wait 30 seconds, run host_connectivity.sh, restart bird daemon on HALL,
- routes_both_prefixes.sh : print the route on STEV to show that both prefixes are used.
- connectivity_test_on_machine.sh <machine> <list_addresses> : ping every address in <list_addresses> from <machine>, print results for unreachable addresses in /tmp/<machine>\_test.txt

### End user test

Don't forget to install the dhcp relay : sudo apt-get install isc-dhcp-relay

The test end_user_test.sh must be launched from the folder end_user_management/end_user_test/ with the root privileges

This script will launched from each host a list of test :
- ping to all service : warning some services can be perhaps no accessible due to the firewall
- dig request to our DNS servers for every router from every host
- dig request to our DNS servers for every service from every host
- dig reverse request to our DNS servers for every service from every host
- dig requests to our DNS servers for google.
- DHCPv6 client from every host
