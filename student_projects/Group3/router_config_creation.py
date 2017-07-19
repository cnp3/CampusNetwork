#!/usr/bin/env python3
import json
import os
import sys
import stat

# from pprint import pprint

from constants import PREFIXES, PATH, VLAN_USES

with open(PATH+'router_configuration.json') as data_file:
    data = json.load(data_file)

dhcp_addr = ["100::547","101::547"]

for router, configs in data.items():

    #######################
    # router_start config #
    #######################

    router_start_config = open(PATH+"project_cfg/"+router+"_start", "w")
    router_start_config.write("#!/bin/bash \n\n")
    router_start_config.write("# This file has been generated automatically, see router_config_creation.py for details. \n\n")

    #  ISP's interfaces
    #
    # JSON format
    # "isp": {
    #   <name_interface>: {
    #     "asn": <ASN>,
    #     "name_bgp": <name>,
    #     "prefix_to_advertise": <prefix_to_advertise/prefix>,
    #     "self_address": <address_of_interface/prefix>,
    #     "peer_address": <peer_address>
    #
    # }
    for isp, isp_configs in configs["isp"].items():
        router_start_config.write("ip link set dev "+isp+" up \n")
        router_start_config.write("ip address add dev "+isp+" "+isp_configs["self_address"]+"  \n")

    router_start_config.write("\n")

    # Point-to-point link's interfaces
    #
    # JSON format :
    # "eths": {
    #   <ethX>: <link_location>
    # }
    #
    # addresses created : prefix:00LL::000R/64 (LL: location, R: router id)
    # an address is created for each prefix
    for eth, location in configs["eths"].items():
        router_start_config.write("ip link set dev "+router+"-"+eth+" up \n")
        for prefix in PREFIXES:
            router_start_config.write("ip address add dev "+router+"-"+eth+" "+prefix+location+"::"+configs["router_id"]+"/64 \n")

    router_start_config.write("\n")

    # Lans interfaces for services
    #
    # JSON format
    # "lans": {
    #   "services": {
    #       <lanX>: <link_location>
    #   }
    # }
    #
    # addresses created : prefix:01LL::/64 (LL: location)
    # an address is created for each prefix
    for lan_type, lans in configs["lans"].items():
        for lan_id, location in lans.items():
            router_start_config.write("ip link set dev "+router+"-"+lan_id+" up \n")
            if(lan_type == "infrastructure"):
                use = "0"
            elif(lan_type == "services"):
                use = "1"
            else:
                print("ERROR : "+lan_type+" is not a valid lan type")
                sys.exit()

            for prefix in PREFIXES:
                router_start_config.write("ip address add dev "+router+"-"+lan_id+" "+prefix+use+location+"::/64 \n")

    router_start_config.write("\n")

    # VLANs' interfaces
    #
    # JSON format
    # "vlans": {
    #   <lanX>: <link_location>
    # }
    #
    # For each lanX, a <router>-lanX interface is set and vlans are created
    # (one per vlan_use).
    #
    # addresses created : prefix:0SLL::/64 (S: service, LL: location)
    # an address is created for each prefix and for each vlan_use
    for vlan, location in configs["vlans"].items():
        router_start_config.write("ip link set dev "+router+"-"+vlan+" up \n")
        for vlan_use in VLAN_USES:
            router_start_config.write("ip link add link "+router+"-"+vlan+" name "+router+"-"+vlan+"."+vlan_use+location+" type vlan id 0x"+vlan_use+location+" \n")
            router_start_config.write("ip link set dev "+router+"-"+vlan+"."+vlan_use+location+" up \n")
            for prefix in PREFIXES:
                router_start_config.write("ip address add dev "+router+"-"+vlan+"."+vlan_use+location+" "+prefix+vlan_use+location+"::/64 \n")
        router_start_config.write("\n")

    router_start_config.write("\n")

    if "extra_ip_commands" in configs:
        for command in configs["extra_ip_commands"]:
            router_start_config.write(command+"\n")

    router_start_config.write("\n")

    ####################
    # Launch DHCP relay#
    ####################
    dhcp_command = "dhcrelay -q -pf /var/run/"+router+"_dhcrel -6 "

    for vlan, location in configs["vlans"].items():
        for vlan_use in VLAN_USES:
            dhcp_command = dhcp_command + " -l "+router+"-"+vlan+"."+vlan_use+location
    if "services" in configs["lans"] :
        for prefix in PREFIXES :
            for addr in dhcp_addr :
                dhcp_command = dhcp_command +" -u "+prefix+addr+"%"+router+"-"+list(configs["lans"]["services"])[0]
    for eth, location in configs["eths"].items() :
        for prefix in PREFIXES :
            for addr in dhcp_addr :
                dhcp_command = dhcp_command + " -u "+prefix+addr+"%"+router+"-"+eth
    router_start_config.write(dhcp_command + "\n")

    router_start_config.write("bird6 -s /tmp/"+router+".ctl -P /tmp/"+router+"_bird.pid \n")
    router_start_config.write("radvd -p /var/run/radvd/"+router+"_radvd.pid -C /etc/radvd/"+router+".conf -m logfile -l /var/log/radvd/"+router+".log\n")

    router_start_config.close()

    # Add execution right to new file
    file_stat = os.stat("project_cfg/"+router+"_start")
    os.chmod("project_cfg/"+router+"_start", file_stat.st_mode | stat.S_IEXEC)


    ######################
    # Router BIRD config #
    ######################

    router_sysctl_config = open(PATH+"project_cfg/"+router+"/sysctl.conf", "w")
    router_sysctl_config.write("""
    net.ipv6.conf.all.disable_ipv6=0
    net.ipv6.conf.all.forwarding=1
    net.ipv6.conf.default.disable_ipv6=0
    net.ipv6.conf.default.forwarding=1
    """)
    router_sysctl_config.close()

    router_bird_config = open(PATH+"project_cfg/"+router+"/bird/bird6.conf", "w")
    router_bird_config.write("router id 0.0.0."+configs["router_id"]+"; \n\n")

    # log
    router_bird_config.write("""log "/etc/log/bird_log" all; \n""")
    router_bird_config.write("debug protocols all; \n")

    router_bird_config.write("""
    protocol kernel {
        learn;
        scan time 20;
        export all;
    }

    protocol device {
        scan time 10;
    }
    """)


    # Creation of a default prefix to be advertised to ISPs and BGP peers.
    # It is useful when a prefix provided by an ISP is advertised to another BGP peer.
    #
    # 'default_bgp_prefix_to_advertise' must exist if no 'prefix_to_advertise'
    # is defined for an isp or a bgp_peer
    if "default_bgp_prefix_to_advertise" in configs:
        router_bird_config.write("""
        protocol static static_default_bgp_out{
           import all;

           route """+configs["default_bgp_prefix_to_advertise"]+""" reject;
        }
        """)

    if(any(configs["isp"])):
        default_routes = []
        for isp, isp_configs in configs["isp"].items():
            # propagating default route to OSPF
            default_routes += "route ::/0 via "+isp_configs["peer_address"]+"; \n"

            export_bgp_prefix_name = "static_default_bgp_out"

            # Creation of a specific prefix to advertise for this ISP
            if "prefix_to_advertise" in isp_configs:
                export_bgp_prefix_name = "static_bgp_out_"+isp_configs["name_bgp"]
                router_bird_config.write("""
                protocol static static_bgp_out_"""+isp_configs["name_bgp"]+"""{
                   import all;
                   route """+isp_configs["prefix_to_advertise"]+""" reject;
                }
                """)

            # BGP peering with ISP
            router_bird_config.write("""
            protocol bgp """+isp_configs["name_bgp"]+""" {
                local as 3;
                neighbor """+isp_configs["peer_address"]+""" as """+isp_configs["asn"]+""";
                export where proto = \""""+export_bgp_prefix_name+"""";
                import filter {
                    if(net = ::/0) then {
                        accept;
                    }
                    reject;
                };
            }
            """)

        # OSPF
        router_bird_config.write("""
        protocol static static_ospf {
           import all;

           """)

        for route in default_routes:
            router_bird_config.write(route)

        # OSPF Hello message sent with 1 second interval
        # Stub 1 is used on interfaces to disable OSPF them
        router_bird_config.write("""
        }
        protocol ospf {
            import all;
            export where proto = "static_ospf";

            area 0.0.0.0 {
                interface "*eth*" {
                    hello 1;
                    dead 3;
                };
                interface "*lan*" {
                   stub 1;
                };
                interface "lo" {
                   stub 1;
                };
            };
        }
        """)

    # router without ISP
    else:
        router_bird_config.write("""
        protocol ospf {
            area 0.0.0.0 {
                interface "*eth*" {
                    hello 1;
                    dead 3;
                };
                interface "*lan*" {
                   stub 1;
                };
                interface "lo" {
                   stub 1;
                };
            };
        }
        """)

    # Configuration for BGP peers that are not ISPs
    if(any(configs["bgp_peers"])):
        for peer, peer_configs in configs["bgp_peers"].items():

            # Default prefix to be advertise to the BGP peer
            # 'default_bgp_prefix_to_advertise' must be declare as field in the json for this router
            export_bgp_prefix_name = "static_default_bgp_out"

            # Creation of a specific prefix to advertise for this ISP
            if "prefix_to_advertise" in peer_configs:
                export_bgp_prefix_name = "static_bgp_out_"+peer_configs["name_bgp"]
                router_bird_config.write("""
                protocol static """+export_bgp_prefix_name+"""{
                   import all;
                   route """+peer_configs["prefix_to_advertise"]+""" reject;
                }
                """)

            # Creation of a filter for the prefixes that are advertised by the BGP peer
            # and creation of the BGP protocol
            router_bird_config.write("""
            filter bgp_in_"""+peer+"""
            {
                if(net ~ ["""+peer_configs["accepted_prefix"]+"""+]) then
                {
                    accept;
                }
                reject;
            }

            protocol bgp """+peer+""" {
                local as 3;
                neighbor """+peer_configs["peer_address"]+""" as """+peer_configs["asn"]+""";
                export where proto = \""""+export_bgp_prefix_name+"""";
                import filter bgp_in_"""+peer+""";
            }
            """)


    router_bird_config.close()


    # Creation of the radvd confirguration
    for vlan, location in configs["vlans"].items() :
        radvd_config = open("project_cfg/"+router+"/radvd/"+router+".conf", "w")
        for vlan_use in VLAN_USES:
            radvd_config.write("""
                  interface """+router+"-"+vlan+"."+vlan_use+location+
"""
                  {
                     # We are sending advertisments (route)
                     AdvSendAdvert on;

                     # When set, host use the administered (stateful) protocol
                     # for address autoconfiguration. The use of this flag is
                     # described in RFC 4862
                     AdvManagedFlag off;

                     # When set, host use the administered (stateful) protocol
                     # for address autoconfiguration. For other (non-address)
                     # information.
                     # The use of this flag is described in RFC 4862
                     AdvOtherConfigFlag on;

                     # Suggested Maximum Transmission setting for using the
                     # Hurricane Electric Tunnel Broker.
                     AdvLinkMTU 1480;

                     # Netmask length must be &quot;/64&quot;
                     # (see RFC 2462, sect 5.5.3, page 18)

                     RDNSS fd00:200:3:101::53 fd00:200:3:100::53
                     {

                     };
                  """)


            for prefix in PREFIXES:
                radvd_config.write("""
                # Netmask length must be &quot;/64&quot;
          	    # (see RFC 2462, sect 5.5.3, page 18)
              	 prefix """+prefix+vlan_use+location+"""::/64
              	 {
              		  # Says to hosts:
              		  # &quot;Everything sharing this prefix is on the
              		  # same link as you.&quot;
              		  AdvOnLink on;

              		  # Says to hosts:
              		  # &quot;Use the prefix to autoconfigure your address&quot;
              		  AdvAutonomous on;


              	 };
                """)
            radvd_config.write("""
            };
            """)
        radvd_config.close()
