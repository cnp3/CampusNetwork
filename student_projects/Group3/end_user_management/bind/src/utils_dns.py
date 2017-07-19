#!/usr/bin/env python3
import os
from datetime import datetime
from ipaddress import IPv6Address

def reverse_pointer(self):
    """
    Return the reverse DNS pointer name for the IPv6 address.
    taken from http://hg.python.org/cpython/file/default/Lib/ipaddress.py
    """
    reverse_chars = self.exploded[::-1].replace(':', '')
    return '.'.join(reverse_chars) + '.ip6.arpa'

setattr(IPv6Address, 'reverse_pointer', property(reverse_pointer))


def translate_addr(addr) :
    return IPv6Address(addr).reverse_pointer


def serial_update() :
    date = datetime.now()
    return(date.strftime('%Y%m%d%H'))
