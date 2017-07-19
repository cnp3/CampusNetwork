#!/usr/bin/python
from jinja2 import Template
import json

BASE_PREFIX_LAN = "fd00:{AS}:2:{use}{location}{id}::/64"

def to_hex(n, width=1):
    h = hex(n).split('x')[1]
    return '0'*(width - len(h)) + h

def build_lans(location, id, uses):
    lans = []
    for lan in uses:
        ip = BASE_PREFIX_LAN.format(AS=200,
            use=to_hex(lan),
            location=to_hex(location),
            id=to_hex(id, width=2),
            end='0')
        lans.append(ip)

    return lans 

DHCP_CFG_PATH = 'project_cfg/{name}/dhcp/dhcp6.conf'
DHCP_TEMPLATE = open('routing/dhcp6.conf.tpl').read()

IP_RANGES = ( (1, 10), (11, 20) )

f = open('routing/lans.conf')
conf = json.load(f)


# Build all possible subnets where DHCP is used
subnets = []
for name, args in conf.iteritems():
    if args['type'] != 'router':
        continue

    subnets += build_lans(args['location'], args['id'], (n for n in args['lans'] if n != 0))

# Create configuration file for each DHCP server
i = 0
for name, args in conf.iteritems():
    if not name.startswith('DHCP'): # Only generate configuration file for DHCP servers
        continue

    router = args['router']
    own_subnet = build_lans(conf[router]['location'], conf[router]['id'], [0])[0]
    restricted_subnets = []
    for sub in subnets:
        low_ip = sub[:-3] + str(IP_RANGES[i][0])
        high_ip = sub[:-3] + str(IP_RANGES[i][1])

        restricted_subnets.append({'net':sub, 'low':low_ip, 'high':high_ip})

    cfg_path = DHCP_CFG_PATH.format(name=name)
    cfg = Template(DHCP_TEMPLATE).render(own_subnet=own_subnet, subnets=restricted_subnets)

    f = open(cfg_path, 'w')
    f.write(cfg)
    f.close()
    print "[INFO] dhcpd config for {} written".format(name)
    i += 1
