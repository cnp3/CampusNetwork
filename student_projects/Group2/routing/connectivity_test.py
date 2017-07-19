#!/usr/bin/python
import subprocess, sys, json, shlex, os
from setup_lan import build_ip

OUTPUT_AS = 200 #TODO
INTERNET_REMOTE = "fd00::d"

#subprocess.call = lambda x: sys.stdout.write(str(x)+'\n')

DEVNULL = open(os.devnull, 'wb')

f = open('routing/lans.conf')
conf = json.load(f)

# host => namespace used to execute the command
# src => IP address of source
# dst => IP address of destination
# nb => Number of requests
# returns => True if ping succeeded, False otherwise
def ping(host, src, dst, nb=1):
    if src == "dhcp":
        cmd = 'ip netns exec {host} timeout 0.5 ping6 -c {nb} {dst}'.format(host=host, nb=nb, dst=dst)
    else:
        cmd = 'ip netns exec {host} timeout 0.5 ping6 -I {src} -c {nb} {dst}'.format(host=host, src=src, nb=nb, dst=dst)
    ret = subprocess.call(shlex.split(cmd), stdout=DEVNULL, stderr=DEVNULL)
    return ret == 0

def internet_test(graph):
    print '=== Beginning Internet Connectivity Test ==='
    n = 0
    failed = 0

    for host, ips in graph.iteritems():
        for ip in ips:
            if ip[0] == OUTPUT_AS:
                n += 1
                if not ping(host, ip[1], INTERNET_REMOTE):
                    failed += 1
                    print '[INTERNET] Test failed for', host, 'with IP', ip[0]

    print '=== Results Internet Connectivity Test : {} failed out of {} ==='.format(failed, n)

# Full-mesh connectivity test
def internal_test(graph):
    print '=== Beginning Internal Full-Mesh Connectivity Test ==='
    n = 0
    failed = 0

    for src_host, src_ips in graph.iteritems():
        print "Testing", src_host, "..."
        for src_ip in src_ips:
            for dst_host, dst_ips in graph.iteritems():
                for dst_ip in filter(lambda ip: ip[1] != "dhcp", dst_ips):
                    n += 1
                    if not ping(src_host, src_ip[1], dst_ip[1]):
                        failed += 1
                        print '[INTERNAL] Test failed from {} ({}) to {} ({})'.format(src_host, src_ip[1], dst_host, dst_ip[1])

    print '=== Results Internal Full-Mesh Connectivity Test : {} failed out of {} ==='.format(failed, n)


### Building the graph of the internal network ###
graph = {}
for host in conf.iterkeys():
    ips = [] # list of (as, ip)
    for AS in conf[host]['as']:
        if not "sub_id" in conf[host] or conf[host]["sub_id"] != "dhcp":
            ips.append((AS, build_ip(host, AS, use=0)))
        else:
            ips.append((OUTPUT_AS, "dhcp"))

    graph[host] = ips

internet_test(graph)
internal_test(graph)
