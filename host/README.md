# host

This directory contains the script used on the remote host that
emulate exchange points and hosts VMs running the virtual network from the
parent directory.

See `./net_manager.sh --help` for instructions.

Notable features:
* Port forward host TCP ports 40000+<group number> to guests port 22 (SSH forwarding)
* Guest are dual homed
* Partial Tear up/down is mostly safe (and a lot is reentrant)
* NAT64/DNS64 done by the host (DNS is operated at fd00::d)
* Dual-stack iptables masquerade
* IPv4 traffic is blocked at the POPs
* Guest VMs can peer between one another
* Sample BGP looking glass available within the emulated network to let groups
  examine the status of the BGP peerings (available at `http://belneta.ingi`
  and `http://belnetb.ingi`, provided the DNS servers are setup properly).

## DNS sub-domain delegation

You can delegate the subdomain of each group by filling the `dns_group.yaml`
and restarting the named daemon.

The format of the YAML file is the following:
```
5:  # List of servers for the group 5
        - server_name: "ns1.group5.ingi" 
          server_ip:   "fd00:300:5:2110::1"
        - server_name: "ns2.group5.ingi"
          server_ip:   "fd00:300:5:2220::1"
```

