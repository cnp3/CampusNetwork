#!/bin/python

# Francois Michel, Group 1.
# These test gets the dns address via DHCP.

import os, re, random, time

helpers.subtitle("Test DHCP client (running on CLASSICAL_USERS)")

def do_the_test():
    # doing the test in 5 different machines.
    for n in [random.choice(topo.CLASSICAL_USERS) for x in range(5)]:
        p = helpers.execute_in(n, 'dhclient -6 -v -S %s-eth0' % n)
        helpers.print_condition("PRC: Done." in p[1], "dhclient via %s" % n)
        p = helpers.execute_in(n, 'cat /etc/resolv.conf')
        ip = topo.IPS["[DNS1]-lo"]
        helpers.print_condition("%s" % ip in p[0], "checking that %s is in /ets/resolv.conf of %s" % (ip, n))

helpers.subsubtitle("no DHCP server down")
do_the_test()

for n in ["DHC1", "DHC2"]:
    helpers.subsubtitle("after killing DHCP %s" % n)
    with open("/var/run/dhcpd_%s.pid" % n, "r") as f:
        pid = int(f.read())
    helpers.execute_in(n, "kill %d" % pid)
    do_the_test()
    helpers.execute_in(n, "dhcpd -6 -lf /var/lib/dhcp/dhcpd_%s.leases -pf /var/run/dhcpd_%s.pid" % (n, n))

helpers.fancy_wait(10)

helpers.subtitle("Test RDNSSD client (running on CLASSICAL_USERS)")

# doing the test in 5 different machines.
for n in [random.choice(topo.EQUIPMENTS) for x in range(5)]:
    # no need to execute a command to get the IP addresses, it is executed at start of each node
    p = helpers.execute_in(n, 'cat /etc/resolv.conf')
    ip = topo.IPS["[DNS1]-lo"]
    helpers.print_condition(re.search(ip, p[0]), "Checking that {} is in /etc/resolv.conf of {}".format(ip, n))

