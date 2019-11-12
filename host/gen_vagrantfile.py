#! /usr/bin/env python3
import ipaddress
import sys
import json
from mako.template import Template
from argparse import FileType, ArgumentParser


def gen_mako_dict(conf):
    vms = []

    global_cnf = conf['global']

    ip = ipaddress.ip_address(global_cnf['ip'])
    ip += global_cnf['ip_start']

    ssh_port = global_cnf['ssh_fwd_start']

    for i in range(1, global_cnf['nb_groups'] + 1):

        nics = []

        for j in range(2, global_cnf['extra_nic'] + 2):
            if 'promiscuous' not in global_cnf:
                promiscuous = False
                promisc_type = None
            else:
                promiscuous = True
                promisc_type = "allow-all"

            nics.append({
                'id': j,
                'ip': str(ip),
                'mask': global_cnf['mask'],
                'promiscuous': promiscuous,
                'promisc_type': promisc_type,

            })

        vms.append({
            'box': global_cnf['box'],
            'name': "%s%d" % (global_cnf['prefix_name'], i),
            'ssh_fwd': ssh_port,
            'nic': nics,
            'memory': global_cnf['memory']
        })

        ip += 1
        ssh_port += 1

    return vms


def main(args):
    data = json.load(args.input)
    template = Template(filename=args.template)
    args.output.write(template.render(vm_config=gen_mako_dict(data)))


if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument('-i', '--input', type=FileType('r'), default=sys.stdin)
    parser.add_argument('-t', '--template', type=str, required=True)
    parser.add_argument('-o', '--output', type=FileType('w'), default=sys.stdout)

    _args = parser.parse_args()

    main(_args)
