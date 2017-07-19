#!/usr/bin/python
from jinja2 import Template
import json

BASE_PREFIX_LAN = "fd00:{AS}:2:{use}{location}{id}::/64"

def to_hex(n, width=1):
    h = hex(n).split('x')[1]
    return '0'*(width - len(h)) + h

def build_lans(location, id, ASes, uses):
    lans = []
    for lan in uses:
        for AS in ASes:
            ip = BASE_PREFIX_LAN.format(AS=AS,
                use=to_hex(lan),
                location=to_hex(location),
                id=to_hex(id, width=2),
                end='0')
            lans.append(ip)

    return lans 

BIRD_CFG_PATH = 'project_cfg/{name}/bird/bird6{suffix}.conf'
BIRD_TEMPLATE = open('routing/bird6.conf.tpl').read()


f = open('routing/lans.conf')
conf = json.load(f)

for name, args in conf.iteritems():
    if args['type'] != 'router': # pass if not a router
        continue

    neighbors = ['{}-eth{}'.format(name, i) for i in range(args['links'])]
    subnets = build_lans(args['location'], args['id'], args['as'], args['lans'])
    bgp_config = None

    if 'bgp' in args:
        # Generating failover state config for BGP
        bgp_config = args['bgp']
        if bgp_config['use'] == 'default':
            bgp_config['export'] = False
        else:
            bgp_config['export'] = True

        cfg_path = BIRD_CFG_PATH.format(name=name, suffix="-failover")
        cfg = Template(BIRD_TEMPLATE).render(router_id=args['id'], neighbors=neighbors, networks=subnets, bgp=bgp_config)

        f = open(cfg_path, 'w')
        f.write(cfg)
        f.close()
        print "[INFO] Bird6 failover config for {} written".format(name)

        # Setting BGP configuration for default state
        if bgp_config['use'] == 'default':
            bgp_config['export'] = True
        else:
            bgp_config['export'] = False


    cfg_path = BIRD_CFG_PATH.format(name=name, suffix="")
    cfg = Template(BIRD_TEMPLATE).render(router_id=args['id'], neighbors=neighbors, networks=subnets, bgp=bgp_config)

    f = open(cfg_path, 'w')
    f.write(cfg)
    f.close()
    print "[INFO] Bird6 config for {} written".format(name)
