#! /usr/bin/env python3

import sys
import json
from mako.template import Template
from argparse import FileType, ArgumentParser


def main(args):
    data = json.load(args.input)
    template = Template(filename=args.template)
    args.output.write(template.render(vm_config=data))
    

if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument('-i', '--input', type=FileType('r'), default=sys.stdin)
    parser.add_argument('-t', '--template', type=str, required=True)
    parser.add_argument('-o', '--output', type=FileType('w'), default=sys.stdout)

    _args = parser.parse_args()

    main(_args)
