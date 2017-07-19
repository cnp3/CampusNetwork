#!/usr/bin/env python3
import json
import os
import sys

from pprint import pprint

sys.path.append('/home/vagrant/lingi2142')
from constants import PREFIXES, PATH, VLAN_USES

with open(PATH+'router_configuration.json') as data_file:
    data = json.load(data_file)

# prefixes = ["fd00:200:3:", "fd00:300:3:"]
dhcp_addr = ["100::547", "101::547"]
# vlan_uses = ["2", "3"]
# service_use = "1"

router = sys.argv[1]
up_prefix = sys.argv[2::]
radvd_config = open("/etc/radvd/"+router+".conf", "w")


if router not in data :
    sys.exit(router + " is not a router")

for prefix in up_prefix :
    if prefix not in PREFIXES :
        sys.exit("Your arg prefix doesn't exit")


for vlan, location in data[router]["vlans"].items() :
        for vlan_use in VLAN_USES:
            radvd_config.write(
            "interface """+router+"-"+vlan+"."+vlan_use+location+"\n"
                "{\n"
                "    # We are sending advertisments (route)\n"
                "    AdvSendAdvert on;\n"
                "\n"
                "    # When set, host use the administered (stateful) protocol\n"
                "    # for address autoconfiguration. The use of this flag is\n"
                "    # described in RFC 4862\n"
                "    AdvManagedFlag off;\n"
                "\n"
                "    # When set, host use the administered (stateful) protocol\n"
                "    # for address autoconfiguration. For other (non-address)\n"
                "    # information.\n"
                "    # The use of this flag is described in RFC 4862\n"
                "    AdvOtherConfigFlag on;\n"
                "\n"
                "    # Suggested Maximum Transmission setting for using the\n"
                "    # Hurricane Electric Tunnel Broker.\n"
                "    AdvLinkMTU 1480;\n"
                "\n"
                "    # Netmask length must be &quot;/64&quot;\n"
                "    # (see RFC 2462, sect 5.5.3, page 18)\n"
                "    RDNSS fd00:200:3:101::53 fd00:200:3:100::53{ \n"
                "    \n"
                "    };\n")


            for prefix in PREFIXES:
                radvd_config.write(
              	"    prefix "+prefix+vlan_use+location+"::/64\n"
              	"    {\n"
                "       # Says to hosts:\n"
                "       # &quot;Everything sharing this prefix is on the\n"
              	"       # same link as you.&quot;\n"
              	"       AdvOnLink on;\n"
                "\n"
              	"       # Says to hosts:\n"
              	"       # &quot;Use the prefix to autoconfigure your address&quot;\n"
              	"       AdvAutonomous on;\n"
                "\n"
                "\n")
                if prefix not in up_prefix :
                    radvd_config.write(
                    "       AdvPreferredLifetime 0;\n"
                    "\n")

                radvd_config.write("    };\n")

            radvd_config.write("};\n")
radvd_config.close()
