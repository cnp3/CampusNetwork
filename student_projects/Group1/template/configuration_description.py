import configuration_topology as topo
from config_helpers.IPy import IP
from configuration_engine import *


def make_boot():
    '''
    Making boot script
    '''
    for r in topo.ALL_MACHINES:
        append(boot(r), "config_helpers/boot.sh", {"node": r})


def make_sysctl():
    '''
    Adding sysctls, to allow forward, ...
    '''
    for r in topo.ROUTERS:
        append(sysctl(r), "config_helpers/sysctl.conf", {"node": r})


def make_staticinit():
    '''
    Preinitialisation of the system: assigning static IPs, ...
    (everything that isn't routing, security, ...)
    '''

    # Adding global shared files across all nodes
    print("    Adding static files")
    global_files = [
        ("/var/www/html/chien/index.html", "services/http/chien/index.html"),
        ("/var/www/html/website/index.html", "services/http/website/index.html"),
        ("/var/www/html/grading/index.html", "services/http/grading/index.html"),
        ('/var/automatic_advertised_ip.sh', 'addressing/router_advertisement/automatic_advertised_ip.sh'),
        ('/var/automatic_source_ip.sh', 'config_helpers/automatic_source_ip.sh'),
    ]
    append(unshared("TEST", "/etc/resolv.conf"), "config_helpers/resolv_test.conf");

    for destfile, sourcefile in global_files:
        quiet_remove(destfile)
        append(shared(destfile), sourcefile)

    # Adding static IPS to routers
    print("    Adding router static IPS")
    for m in topo.ROUTERS + ["DNS1", "DNS2"]:
        add_text(startup(m), banner("Static routes and ips"))

        # For every link
        for interface in topo.get_interfaces(m):
            prefix =  topo.IPS[interface]
            prefix_len = "/64"
            if interface in ["DNS1-eth0", "DNS2-eth0", "MICH-eth3", "CARN-eth3"]:
                prefix_len = "/127" # most restrained link for DNS

            append(
                startup(m),
                "config_helpers/assignation_dual_prefixed.sh",
                {"interface": interface, "ip":prefix+ prefix_len}
            )

        # And for loopback
        append(startup(m), "config_helpers/assignation_loopback.sh", {"ip": topo.IPS["[" + m + "]-lo"]})

    # Adding static IPS to services
    print("    Adding datacenter static IPS")
    for m in topo.STATIC_SERVICES:
        if not m in ["DNS1", "DNS2"]:
            for interface in topo.get_interfaces(m):
                append(startup(m), "config_helpers/assignation_dual_prefixed.sh",
                       {"interface": interface, "ip": topo.IPS[interface] + "/64"})

    # Adding static routes to services
    print("    Adding datacenter static routes")
    for m in topo.STATIC_SERVICES:
        if not m in ["DNS1", "DNS2"]:
            append(startup(m), "routing/static/default_route.sh", {"gateway": "via fd00:0200:0001:" + topo.IPS["CARN-lan0"]})

    # Adding a test host (external to the network)
    print("    Adding TEST node")
    #       ip address
    append(startup("TEST"), "config_helpers/assignation_single_noprefix.sh",
           {"interface": "output", "ip": "fd00:face::b00c"});
    #       default route
    append(startup("TEST"), "routing/static/direct_route.sh", {"target": "fd00:200::1", "dev": "output"})
    append(startup("TEST"), "routing/static/default_route.sh", {"gateway": "via fd00:0200::1"})
    #       additional route on PYTH
    append(startup("PYTH"), "routing/static/direct_route.sh", {"target": "fd00:face::b00c", "dev": "belnetb"})

    # Adding link to BGP peers
    append(startup("PYTH"), "config_helpers/assignation_single_noprefix.sh", {"interface": "belnetb", "ip": topo.IPS["belnetb"] + "/64"})
    append(startup("HALL"), "config_helpers/assignation_single_noprefix.sh", {"interface": "belneta", "ip": topo.IPS["belneta"] + "/64"})


    # Adding automatic source selection on statically assigned IP machines
    print("    Setting source IP selection on routers & machines")
    for m in topo.ROUTERS + topo.STATIC_SERVICES:
        add_text(startup(m), banner("Automatic source selection"))
        append(startup(m), "config_helpers/periodic.sh", {"script": "/var/automatic_source_ip.sh"})


def make_routing():
    for i, r in enumerate(topo.ROUTERS + ["DNS1", "DNS2"]):
        print("    Configuring router", r)

        # Starting bird
        append(startup(r), "routing/start_bird.sh", {"node": r})

        # OSPF
        lo = None
        for ifname, ip in topo.IPS.items():
            if "[" + r + "]" in ifname:
                lo = ip

        if r not in ["HALL", "PYTH"]:
            append(unshared(r, "/etc/bird/bird6.conf"), "routing/ospf/main.conf", {"node": r, "id": i, "loopback": lo})
        else:
            append(unshared(r, "/etc/bird/bird6.conf"), "routing/ospf/main_"+r.lower()+".conf", {"node": r, "id": i, "loopback": lo})

        # Blackhole
        append(startup(r), "routing/static/blackhole.sh")

    # BGP
    append(unshared("PYTH", "/etc/bird/bird6.conf"), "routing/bgp/PYTH.conf")
    append(unshared("HALL", "/etc/bird/bird6.conf"), "routing/bgp/HALL.conf")


def make_security():
    for i, r in enumerate(topo.ROUTERS):
        print("    Firewall on", r)
        # Security with ip6tables
        #
        # the ip6tables rules are splitted in 12 different files, located in template/security/iptable.
        # We made this repartition because some files will be used several time in for loops,
        # other will be used just one time, other will be used only on border routers
        # (where BGP is established) ...
        # Furthumore, the order of the files is important as as when scanning a packet, the firewall stops
        # soon as it founds a rule matching this packet.

        append(startup(r), "security/iptables/1_router_all.sh", {"router": r})
        if r == "PYTH":
            append(startup(r), "security/iptables/2_router_border_block_hop_limit.sh",
                   {"interface": "belnetb", "prefix": "fd00:0300:0001"})
        if r == "HALL":
            append(startup(r), "security/iptables/2_router_border_block_hop_limit.sh",
                   {"interface": "belneta", "prefix": "fd00:0200:0001"})
        append(startup(r), "security/iptables/3_router_all.sh")
        for interface in topo.get_interfaces(r):
            if "lan" in interface:
                append(startup(r), "security/iptables/4_router_spoofing_and_ospf_restrictions.sh",
                       {"interface": interface, "suffix": topo.IPS[interface]})
        if r == "PYTH":
            append(startup(r), "security/iptables/5_router_border_network.sh",
                   {"interface": "belnetb", "prefix": "fd00:0300:0001", "router":r})
        if r == "HALL":
            append(startup(r), "security/iptables/5_router_border_network.sh",
                   {"interface": "belneta", "prefix": "fd00:0200:0001", "router":r})
        append(startup(r), "security/iptables/6_comments.txt", cr=False)
        for z in range(0x0, 0x10):
            z = format(z, 'x')
            append(startup(r), "security/iptables/6_router_forward_user0.sh", {"zone": z}, cr=False)

        append(startup(r), "security/iptables/7_router_all.sh")
        append(startup(r), "security/iptables/8_comments.txt", cr=False)
        for z in range(0x0, 0x10):
            z = format(z, 'x')
            append(startup(r), "security/iptables/8_router_avoid_students_server_lan.sh", {"zone": z}, cr=False)
        append(startup(r), "security/iptables/9_comments.txt", cr=False)
        for z in range(0x0, 0x10):
            z = format(z, 'x')
            append(startup(r), "security/iptables/9_router_forward_user1.sh", {"zone": z}, cr=False)
        append(startup(r), "security/iptables/10_comments.txt", cr=False)
        for z in range(0x0, 0x10):
            z = format(z, 'x')
            append(startup(r), "security/iptables/10_router_forward_user2.sh", {"zone": z}, cr=False)
        append(startup(r), "security/iptables/11_comments.txt", cr=False)
        for z in range(0x0, 0x10):
            z = format(z, 'x')
            append(startup(r), "security/iptables/11_router_forward_user3.sh", {"zone": z}, cr=False)
        append(startup(r), "security/iptables/12_comments.txt", cr=False)
        for z in range(0x0, 0x10):
            z = format(z, 'x')
            append(startup(r), "security/iptables/12_router_forward_user4.sh", {"zone": z}, cr=False)
        append(startup(r), "security/iptables/13_router_forward_last_rules.sh")


def make_services():
    for h in topo.STATIC_SERVICES:
        if "HTT" in h:
            # web server
            print("    Adding web server to", h)
            append(startup(h), "services/http/httpd_start.sh", {"node": h})
            append(unshared(h, "/etc/lighttpd/service.sh"), "services/http/httpd_service.sh", {"node": h})
            append(unshared(h, "/etc/lighttpd/lighttpd.conf"), "services/http/lighttpd.conf", {"node": h})

    for h in topo.CORE_ROUTERS + ["HTT1", "HTT2", "HTT3"]:
        print("    Adding SSH to", h)
        append(startup(h), "services/ssh/start.sh", {"node": h.lower()})

    #for n in ["HALL"]:
    #    print("    Adding NTOP to", n)
    #    all_interface_string = ",".join(topo.get_interfaces(n))

    #    append(startup(n), "services/ntop/ntop_start.sh", {"node": n})
    #    append(unshared(n, "/etc/ntop/service.sh"), "services/ntop/ntop_service.sh", {"node": n})
    #    append(unshared(n, "/etc/ntop/ntop_config/init.cfg"), "services/ntop/ntop_config/init.cfg",
    #           {"interface": all_interface_string})

    for m in topo.CORE_ROUTERS + topo.L3_SWITCHES:
        print("    Adding SNMP to", m)
        append(startup(m), "services/snmpd/start.sh", {"node": m})


def make_qos():
    for i, r in enumerate(topo.ROUTERS):
        print("    Adding QOS to ", r)
        for interface in topo.get_interfaces(r):
            append(startup(r), "qos/shaping.sh", {"interface": interface})


def make_addressing():
    # 1) Infrastructure: DHCP server, client, DNS, router config

    print("    Adding DHCP (server & relay)")
    for r in topo.ROUTERS: __dhcp_relay(r)
    for r in filter(lambda x: "DHC" in x, topo.STATIC_SERVICES): __dhcp_server(r)

    print("    Configuring router advertisement")
    for r in filter(lambda x: not "CARN" in x, topo.ROUTERS): __router_advertisement(r)

    print("    Adding DNS server")
    for r in filter(lambda x: "DNS" in x, topo.ALL_MACHINES): __dns_server(r)

    # 2) Client: enabling DHCP client, rddns client

    print("    Cleaning resolv.conf")
    for r in topo.CLASSICAL_USERS + topo.EQUIPMENTS + topo.STATIC_SERVICES:
        append(unshared(r, "/etc/resolv.conf"), "config_helpers/resolv.conf", {"node": r})

    print("    Adding DHCP client")
    for m in topo.CLASSICAL_USERS + topo.STATIC_SERVICES:
        append(unshared(m, "/etc/dhcp/dhclient-enter-hooks.d/changeresolv"), "addressing/dhcp/changeresolv_hook.sh", {"node": m})
        append(startup(m), "addressing/dhcp/dhcp_client.sh", {"node": m})

    print("    Adding RDNSSD client")
    for h in topo.EQUIPMENTS:
        append(startup(h), "addressing/rdnss/rdnssd_start.sh", {"node": h})
        append(unshared(h, "/etc/rdnssd/rdnssd_" + h + "_service.sh"), "addressing/rdnss/rdnssd_service.sh",
               {"node": h})
        append(unshared(h, "/etc/rdnssd/merge-hook"), "addressing/rdnss/merge-hook", {"node": h})


# ---- internal (non exposed functions): = parts of the addressing ----------------------------

def __dns_server(h):
    def union(dict1, dict2):
        return dict(list(dict1.items()) + list(dict2.items()))

    # loopback addresses of the routers
    los = {"sh1c_lo": topo.IPS["[SH1C]-lo"], "hall_lo": topo.IPS["[HALL]-lo"], "mich_lo": topo.IPS["[MICH]-lo"],
           "pyth_lo": topo.IPS["[PYTH]-lo"], "stev_lo": topo.IPS["[STEV]-lo"], "carn_lo": topo.IPS["[CARN]-lo"]}
    aaaa_records_public = {200: [], 300: []}
    aaaa_records_private = {200: [], 300: []}
    reverse_name_f00 = IP("fd00:200:1:f00::/64").reverseName()
    reverse_name_200 = IP("fd00:200:1::/48").reverseName()
    reverse_name_300 = IP("fd00:300:1::/48").reverseName()
    reverse_records_200 = []    # contains all the lines of the zone file for the prefix 200
    reverse_records_300 = []    # contains all the lines of the zone file for the prefix 300
    reverse_records_200_private = []    # contains all the lines of the zone file for the prefix 200
    reverse_records_300_private = []    # contains all the lines of the zone file for the prefix 300
    reverse_records_hidden = []
    for name, addresses in topo.dns_aaaa_hidden_records.items():
        for address in addresses:
            if "fd00:200:1:f00" in address:
                # if the the address is not 200 nor 300, append it in the two files
                # build the AAAA record in the config file for the prefix 200, then 300
                aaaa_records_private[200].append("%s\tIN\tAAAA\t%s" % (name, address))
                aaaa_records_private[300].append("%s\tIN\tAAAA\t%s" % (name, address))
                # build the reverse (PTR) record
                reverse_records_hidden.append('%s\tIN\tPTR\t%s.group.ingi.' % (IP(address).reverseName(), name))
            if "fd00:200" in address:
                # if the address is 200, append it only to the 200 config file
                aaaa_records_private[200].append("%s\tIN\tAAAA\t%s" % (name, address))
                reverse_records_200_private.append('%s\tIN\tPTR\t%s.group.ingi.' % (IP(address).reverseName(), name))
            elif "fd00:300" in address:
                # if the address is 300, append it only to the 200 config file
                aaaa_records_private[300].append("%s\tIN\tAAAA\t%s" % (name, address))
                reverse_records_300_private.append('%s\tIN\tPTR\t%s.group.ingi.' % (IP(address).reverseName(), name))

    for name, addresses in topo.dns_aaaa_records.items():
        for address in addresses:
            if "fd00:200" in address:
                # if the address is 200, append it only to the 200 config file
                # build the AAAA record in the config file for the prefix 200
                aaaa_records_public[200].append("%s\tIN\tAAAA\t%s" % (name, address))
                reverse_records_200.append('%s\tIN\tPTR\t%s.group.ingi.' % (IP(address).reverseName(), name))
            elif "fd00:300" in address:
                # if the address is 300, append it only to the 300 config file
                # build the AAAA record in the config file for the prefix 200
                aaaa_records_public[300].append("%s\tIN\tAAAA\t%s" % (name, address))
                reverse_records_300.append('%s\tIN\tPTR\t%s.group.ingi.' % (IP(address).reverseName(), name))
            else:
                # if the the address is not 200 nor 300, append it in the two files
                # build the AAAA record in the config file for the prefix 200, then 300
                aaaa_records_public[200].append("%s\tIN\tAAAA\t%s" % (name, address))
                aaaa_records_public[300].append("%s\tIN\tAAAA\t%s" % (name, address))
    for name, cname in topo.dns_cname_records.items():
        aaaa_records_public[200].append("%s\tIN\tCNAME\t%s" % (name, cname))
        aaaa_records_public[300].append("%s\tIN\tCNAME\t%s" % (name, cname))

    for name, nss in topo.dns_ns_records.items():
        for ns in nss:
            # build the NS record in the config file for the prefix 200, then 300 and for the reverse config file
            aaaa_records_public[200].append("%s\tIN\tNS\t%s" % (name, ns))
            aaaa_records_public[300].append("%s\tIN\tNS\t%s" % (name, ns))

    name = "ns"

    dirs = [x for x in os.listdir('template/addressing/dns/bind-config/')]
    dirs.remove('reverse')
    dirs = dirs + [('reverse/' + x) for x in os.listdir('template/addressing/dns/bind-config/reverse/')]
    # append all the files in the 200/ dir to the host
    for c in dirs:
        # append the files as a initial config file for bindd

        append(
            unshared(h, "/etc/bind/" + c),
            "addressing/dns/bind-config/" + c,
            union({"private_records_list": '\n'.join(aaaa_records_private[200]),
                   "public_records_list": '\n'.join(aaaa_records_public[200]),
                   "private_reverse_list": '\n'.join(reverse_records_hidden),
                   "reverse_records_200": '\n'.join(reverse_records_200),
                   "reverse_records_300": '\n'.join(reverse_records_300),
                   "reverse_records_200_private": '\n'.join(reverse_records_200_private),
                   "reverse_records_300_private": '\n'.join(reverse_records_300_private),
                   "reverse_name_f00": reverse_name_f00,
                   "reverse_name_200": reverse_name_200,
                   "reverse_name_300": reverse_name_300,
                   "name": name}, los)
        )
        # also append it in the 200/ dir to handle dynamic changes
        append(
            unshared(h, "/etc/bind/200/" + c),
            "addressing/dns/bind-config/" + c,
            union({"private_records_list": '\n'.join(aaaa_records_private[200]),
                   "public_records_list": '\n'.join(aaaa_records_public[200]),
                   "private_reverse_list": '\n'.join(reverse_records_hidden),
                   "reverse_records_200": '\n'.join(reverse_records_200),
                   "reverse_records_300": '\n'.join(reverse_records_300),
                   "reverse_records_200_private": '\n'.join(reverse_records_200_private),
                   "reverse_records_300_private": '\n'.join(reverse_records_300_private),
                   "reverse_name_f00": reverse_name_f00,
                   "reverse_name_200": reverse_name_200,
                   "reverse_name_300": reverse_name_300,
                   "name": name}, los)
        )
        append(
            unshared(h, "/etc/bind/300/" + c),
            "addressing/dns/bind-config/" + c,
            union({"private_records_list": '\n'.join(aaaa_records_private[300]),
                   "public_records_list": '\n'.join(aaaa_records_public[300]),
                   "private_reverse_list": '\n'.join(reverse_records_hidden),
                   "reverse_records_200": '\n'.join(reverse_records_200),
                   "reverse_records_300": '\n'.join(reverse_records_300),
                   "reverse_records_200_private": '\n'.join(reverse_records_200_private),
                   "reverse_records_300_private": '\n'.join(reverse_records_300_private),
                   "reverse_name_f00": reverse_name_f00,
                   "reverse_name_200": reverse_name_200,
                   "reverse_name_300": reverse_name_300,
                   "name": name}, los)
        )

    # Adding DNS bind service (and starting it)
    append(
        unshared(h, "/etc/bind/bind_service.sh"),
        "addressing/dns/bind_service.sh", {"node": h}
    )

    append(
        startup(h),
        "addressing/dns/start_bind.sh",
        {"node": h}
    )

    # Adapting DNS advertised source
    append(
        unshared(h, "/etc/bind/automatic_dns_adaptation.sh"),
        "addressing/dns/automatic_dns_adaptation.sh", {"node": h}
    )

    add_text(startup(h), banner("Automatic DNS adaptation"))
    append(startup(h), "config_helpers/periodic.sh", {"script": "/etc/bind/automatic_dns_adaptation.sh"});


def __dhcp_server(h):
    append(startup(h), "addressing/dhcp/dhcp_server.sh", {"node": h})

    config_scripts = ["default/isc-dhcp-server", "dhcp/dhcpd.conf"]
    for c in config_scripts:
        append(unshared(h, '/etc/' + c), "addressing/dhcp/" + c,
               {
                   "node": h,
                   "dns": topo.IPS["[DNS1]-lo"],
               })


def __router_advertisement(r):
    append(unshared(r, "/etc/bird/bird6.conf"), "addressing/router_advertisement/radvd_head.conf", {})

    for f in topo.get_interfaces(r):
        if "lan" in f:
            append(unshared(r, "/etc/bird/bird6.conf"), "addressing/router_advertisement/radvd_copy.conf", {
                "iface": f,
                "ip": topo.IPS[f].replace('::ff', '::0/64')
            })

    append(unshared(r, "/etc/bird/bird6.conf"), "addressing/router_advertisement/radvd_foot.conf",
           {
                   "dns": topo.IPS["[DNS1]-lo"]
           })

    append(startup(r), "config_helpers/periodic.sh", {"script": "/var/automatic_advertised_ip.sh"});


def __dhcp_relay(r):
    interfaces_list_dhcp_forward_to = []
    interfaces_list_dhcp_listen_on = []

    dhcp_ip = topo.IPS["DHC1-eth0"]
    dhcp2_ip = topo.IPS["DHC2-eth0"]

    for interf_name in topo.get_interfaces(r):
        interfaces_list_dhcp_listen_on.append('-l ' + interf_name)
        if "eth" in interf_name:
            interfaces_list_dhcp_forward_to.append("-u " + topo.PREFIX_A + ":" + dhcp_ip + "%" + interf_name)
            interfaces_list_dhcp_forward_to.append("-u " + topo.PREFIX_B + ":" + dhcp_ip + "%" + interf_name)
            interfaces_list_dhcp_forward_to.append("-u " + topo.PREFIX_A + ":" + dhcp2_ip + "%" + interf_name)
            interfaces_list_dhcp_forward_to.append("-u " + topo.PREFIX_B + ":" + dhcp2_ip + "%" + interf_name)
        if "lan" in interf_name:
            if r == "CARN" and interf_name == "CARN-lan1":
                interfaces_list_dhcp_forward_to.append("-u " + topo.PREFIX_A + ":" + dhcp_ip + "%" + interf_name)
                interfaces_list_dhcp_forward_to.append("-u " + topo.PREFIX_B + ":" + dhcp_ip + "%" + interf_name)
                interfaces_list_dhcp_forward_to.append("-u " + topo.PREFIX_A + ":" + dhcp2_ip + "%" + interf_name)
                interfaces_list_dhcp_forward_to.append("-u " + topo.PREFIX_B + ":" + dhcp2_ip + "%" + interf_name)

    append(startup(r), "addressing/dhcp/dhcp_relay.sh",
           {"node": r, "forward_to": " ".join(interfaces_list_dhcp_forward_to),
            "listen_on": " ".join(interfaces_list_dhcp_listen_on)})
