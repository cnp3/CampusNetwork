#!/bin/python

# Francois Michel, Group 1.
# These get the dns addres via DHCP.

import os, re, random, time

column_size = 35

errors = 0

def do_the_dig():
    # select one node at random
    for n in ["MENS"]:
        result_array = []
        tested_ip_dn = set()
        helpers.information('testing the resolution of all the AAAA records (public and hidden) on %s' % n)
        # dig for AAAA records
        for aaaa, ips in list(topo.dns_aaaa_records.items()) + list(topo.dns_aaaa_hidden_records.items()):
            done = True
            # do the dig
            p = helpers.execute_in(n, 'dig %s.group1.ingi AAAA' % aaaa)
            # check that every IP is returned by the DNS
            for addr in ips:
                # remove the prefix
                addr = addr.replace('fd00:200:1:', '').replace('fd00:300:1:', '')
                # if we have never tested this domain
                if aaaa not in tested_ip_dn:
                    # flush the set of tested ips
                    tested_ip_suffix = set()
                    # Note that we tested this domain
                    tested_ip_dn.add(aaaa)
                # if we never checked this suffix for this NS (the suffixes could appear twice, with two different prefixes)
                if aaaa+addr not in tested_ip_suffix:
                    tested_ip_suffix.add(aaaa+addr)
                    # check the AAAA record
                    contains = re.search("%s.group1.ingi.( |\t)*\d+( |\t)*IN( |\t)*AAAA( |\t)*fd00:(200|300):1:%s" % (aaaa, addr), p[0])
                    done = done and contains
                    if contains:
                        result_array.append(["dig %s AAAA" % aaaa, "%s [V]" % addr])
                    else:
                        errors += 1
                        result_array.append(["dig %s AAAA" % aaaa, "%s [X]" % addr])
        helpers.table(result_array, column_size)
        result_array = []

        helpers.information('testing the resolution of all the CNAME records on %s' % n)
        # dig for CNAME records
        for aaaa, dn in list(topo.dns_cname_records.items()):
            # do the dig
            p = helpers.execute_in(n, 'dig %s.group1.ingi AAAA' % aaaa)
            # check the CNAME record
            contains = re.search("%s.group1.ingi.( |\t)*\d+( |\t)*IN( |\t)*CNAME( |\t)*%s.group1.ingi" % (aaaa, dn), p[0])
            if contains:
                result_array.append(["dig %s AAAA" % aaaa, "CNAME %s [V]" % dn])
            else:
                errors += 1
                result_array.append(["dig %s AAAA" % aaaa, "CNAME %s [X]" % dn])
        # verify that everything has gone well
        helpers.table(result_array, column_size)
        result_array = []

        helpers.information('testing the resolution of all the public NS records on %s' % n)
        # dig for NS records
        for dn, nss in list(topo.dns_ns_records.items()):
            p = helpers.execute_in(n, 'dig %s NS' % dn)
            for ns in nss:
                # check the NS record
                contains = re.search("%s( |\t)*\d+( |\t)*IN( |\t)*NS( |\t)*%s" % (dn, ns), p[0])
                if contains:
                    result_array.append(["dig %s NS" % dn, "%s.group1.ingi. [V]" % ns])
                else:
                    errors += 1
                    result_array.append(["dig %s NS" % dn, "%s.group1.ingi. [X]" % ns])
        # verify that everything has gone well
        helpers.table(result_array, column_size)
        result_array = []
        tested_ip_suffix = set()
        tested_ip_dn = set()
        helpers.information('testing the reverse resolution of all the hidden PTR records on %s' % n)
        # dig for PTR records
        for dn, ips in topo.dns_aaaa_hidden_records.items():
            done_ptr = True
            done_aaaa = True
            for ip in ips:
                p = helpers.execute_in(n, 'dig -x %s' % ip)
                # check the PTR record
                done_ptr = done_ptr and (dn in p[0])
                if dn in p[0]:
                    result_array.append(['dig -x %s' % ip, "%s.group1.ingi. [V]" % dn])
                else:
                    errors += 1
                    result_array.append(['dig -x %s' % ip, "%s.group1.ingi. [X]" % dn])
        # verify that everything has gone well
        helpers.table(result_array, column_size)
        result_array = []

def dig_for_test():
    column_size = 50
    for n in ["TEST"]:
        result_array = []
        tested_ip_dn = set()
        helpers.information('testing the resolution of all the hidden AAAA records on %s (external node). It should not get an answer.' % n)
        for dn, ips in topo.dns_aaaa_hidden_records.items():
            done_aaaa = True
            for ip in ips:
                suffix = ip.replace('fd00:200:1:', '').replace('fd00:300:1:', '')
                # if we have never tested this domain
                if dn not in tested_ip_dn:
                    # flush the set of tested ips
                    tested_ip_suffix = set()
                    # Note that we tested this domain
                    tested_ip_dn.add(dn)
                # if we never checked this suffix for this dn (the suffixes could appear twice, with two different prefixes)
                if dn + suffix not in tested_ip_suffix:
                    tested_ip_suffix.add(dn + suffix)
                    p = helpers.execute_in(n, 'dig @fd00:200:1:%s %s.group1.ingi AAAA' % (topo.IPS['DNS1-eth0'], dn))
                    done_aaaa = done_aaaa and ("ANSWER: 0" in p[0])
                    if ("ANSWER: 0" in p[0]):
                        result_array.append(['dig @fd00:200:1:%s %s.group1.ingi AAAA' % (topo.IPS['DNS1-eth0'], dn), "No answer expected. [V]"])
                    else:
                        errors += 1
                        result_array.append(['dig @fd00:200:1:%s %s.group1.ingi AAAA' % (topo.IPS['DNS1-eth0'], dn), "No answer expected. [X]"])
        # verify that everything has gone well
        helpers.table(result_array, column_size)
        result_array = []
        tested_ip_suffix = set()

        helpers.information('testing the resolution of all the hidden PTR records on %s (external node). It should not get an answer.' % n)
        # dig for PTR records
        for dn, ips in topo.dns_aaaa_hidden_records.items():
            done_ptr = True
            for ip in ips:
                suffix = ip.replace('fd00:200:1:', '').replace('fd00:300:1:', '')
                # if we have never tested this domain
                if dn not in tested_ip_dn:
                    # flush the set of tested ips
                    tested_ip_suffix = set()
                    # Note that we tested this domain
                    tested_ip_dn.add(dn)
                # if we never checked this suffix for this dn (the suffixes could appear twice, with two different prefixes)
                if suffix not in tested_ip_suffix:
                    tested_ip_suffix.add(suffix)
                    p = helpers.execute_in(n, 'dig @fd00:200:1:%s -x %s' % (topo.IPS['DNS1-eth0'],ip))
                    # check the PTR record (we check that we didn't receive an answer)
                    if ("ANSWER: 0" in p[0]):
                        result_array.append(['dig @fd00:200:1:%s -x %s' % (topo.IPS['DNS1-eth0'],ip), "No answer expected. [V]"])
                    else:
                        errors += 1
                        result_array.append(['dig @fd00:200:1:%s -x %s' % (topo.IPS['DNS1-eth0'],ip), "No answer expected. [X]"])
                    done_ptr = done_ptr and ("ANSWER: 0" in p[0])
        # verify that everything has gone well
        helpers.table(result_array, column_size)
        result_array = []
        tested_ip_suffix = set()
        tested_ip_dn = set()

        helpers.information('testing the resolution of the public AAAA records on %s' % n)
        # dig for AAAA records
        for aaaa, ips in list(topo.dns_aaaa_records.items()):
            done = True
            # do the dig
            p = helpers.execute_in(n, 'dig %s.group1.ingi AAAA' % aaaa)
            # check that every IP is returned by the DNS
            for addr in ips:
                suffix = addr.replace('fd00:200:1:', '').replace('fd00:300:1:', '')
                # if we have never tested this domain
                if aaaa not in tested_ip_dn:
                    # flush the set of tested ips
                    tested_ip_suffix = set()
                    # Note that we tested this domain
                    tested_ip_dn.add(aaaa)
                # if we never checked this suffix for this dn (the suffixes could appear twice, with two different prefixes)
                if aaaa + suffix not in tested_ip_suffix:
                    tested_ip_suffix.add(aaaa + suffix)
                    # remove the prefix
                    addr = addr.replace('fd00:200:1:', '').replace('fd00:300:1:', '')
                    # check the AAAA record
                    contains = re.search("%s.group1.ingi.( |\t)*\d+( |\t)*IN( |\t)*	AAAA( |\t)*fd00:(200|300):1:%s" % (aaaa, addr), p[0])
                    if contains:
                        result_array.append(['dig %s.group1.ingi AAAA' % aaaa, "%s [V]" % addr])
                    else:
                        errors += 1
                        result_array.append(['dig %s.group1.ingi AAAA' % aaaa, "%s [X]" % addr])
                    done = done and contains
        # verify that everything has gone well
        helpers.table(result_array, column_size)
        result_array = []

        helpers.information('testing the resolution of all the CNAME records on %s' % n)
        # dig for CNAME records
        for aaaa, dn in list(topo.dns_cname_records.items()):
            # do the dig
            p = helpers.execute_in(n, 'dig %s.group1.ingi AAAA' % aaaa)
            # check the CNAME record
            contains = re.search("%s.group1.ingi.( |\t)*\d+( |\t)*IN( |\t)*CNAME( |\t)*%s.group1.ingi" % (aaaa, dn), p[0])
            if contains:
                result_array.append(["dig %s AAAA" % aaaa, "CNAME %s [V]" % dn])
            else:
                errors += 1
                result_array.append(["dig %s AAAA" % aaaa, "CNAME %s [X]" % dn])
        # verify that everything has gone well
        helpers.table(result_array, column_size)
        result_array = []

        helpers.information('testing the resolution of all the public NS records on %s' % n)
        # dig for NS records
        for dn, nss in list(topo.dns_ns_records.items()):
            p = helpers.execute_in(n, 'dig %s NS' % dn)
            for ns in nss:
                # check the NS record
                contains = re.search("%s( |\t)*\d+( |\t)*IN( |\t)*NS( |\t)*%s" % (dn, ns), p[0])
                if contains:
                    result_array.append(["dig %s NS" % dn, "%s [V]" % ns])
                else:
                    errors += 1
                    result_array.append(["dig %s NS" % dn, "%s [X]" % ns])
        # verify that everything has gone well
        helpers.table(result_array, column_size)
        result_array = []

helpers.information("dig all IPs for all services from 1 CLASSICAL_USERS")
do_the_dig()
dig_for_test()
node = None
while node is None:
    candidate_node = input("Please specify the DNS server to bring down [default: DNS1]")
    if candidate_node == "":
        node = "DNS1"
    elif candidate_node == "DNS1" or candidate_node == "DNS2":
        node = candidate_node
    else:
        print("Invalid choice.")

helpers.information("doing the same thing after killing %s" % node)
helpers.execute_in(node, "birdc6 -s /tmp/DNS1.ctl -e down && /etc/bind/bind_service.sh stop")
helpers.fancy_wait(30)
do_the_dig()
dig_for_test()

helpers.information("Tests done, re-activate bind9 and bird6.")
helpers.execute_in("DNS1", "bird6 -s /tmp/DNS1.ctl && /etc/bind/bind_service.sh start")
helpers.information("%d errors have been found !" % errors)
