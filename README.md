# LINGI2142-setup

This repository contains the set of scripts to provision VMs, build a virtual
exchange point and run virtual campus networks on VM for the course
[LINGI2142 ](https://moodleucl.uclouvain.be/course/view.php?id=9209)
at [UCLouvain](uclouvain.be) in order to emulate campus networks and interconnect
them.

# Virtual machine

A sample virtual machine definition to run the script is provided and managed
using [Vagrant](www.vagrantup.com).

Once vagrant is installed on your machine, run the `build_vm.sh` script to 
create and provision the virtual machine. `vagrant ssh` can then
be used to access the VM.

`vagrant halt` will stop the VM.
`vagrant up` will start the VM (to be used instead of the build script once the
VM has been built once).

# Introduction

This directory contains the set of script to start a virtual network as well
as its the configuration files.

*example_topo* defines the network topology, as well as some settings, e.g. the
group number.

*create_network.sh* is a script that will create a virtual network and execute
various scripts in every node. It takes one mandatory argument: a script
providing a mk_topo function to describe the topology (i.e. example_topo).
It then creates the network according to the topology definition. For each
network node, files and directory present in $CONFIGDIR/<node name> (i.e. cfg)
will be available in their view /etc (e.g. sysctl.conf).
Two scripts are executed on each node, if available:
- $CONFIGDIR/<node name>_boot is executed right after the creation of the node,
and before the creation of its links.
- $CONFIGDIR/<node name>_start is executed on every node once the whole
network has been created (i.e. links, LANs, ...), thus once the mk_topo
functionr returns.

*connect_to.sh* is a script that takes one argument, a node's name (e.g. BXL),
and that will open a shell in its environment.

*cleanup.sh* will shutdown the network and attempt to clean all associated
resources such as links, temp files, net NS, processes, ...

# Concepts

We emulate networks on a single machine by leveraging Linux network namespace.
Conceptually, a net NS is a new instance of the kernel networking stack.
This enables to have multiple routing tables, interfaces, ... isolated across
different namespaces.
We can thus emulate a new network node by representing it in its network
namespace.

In order to build a complete network, we then need to add links between nodes.
A link is a pair of virtual ethernet interfaces. Once created, we can then
move the interfaces in the net NS of the corresponding nodes, such that:
- the node 'sees' a new interface (its own end of the link)
- the node has no visibility of the interfaces of other nodes.

The filesystem of the host machine is shared across all network namespace,
i.e. if two nodes try to write to a file named /tmp/temp, they will conflict with
eachother. Make sure to read to the documentation of the programs you want
to run in each namespace in order to figure out which file they create
(e.g. bird6 creates its control socket in /var/run/bird6.ctl, as a result,
we override this default value in the node BXL/BELNET's startup script).

LAN are represented by creating a virtual switch, connecting it to a router,
then connecting multiple hosts to the switch.

# Example_topo

## Description
The example_topo script defines a small topology with routers: BXL, BELNET and LLN
It then attaches 2 LANs in the network: one on BELNET and one in LLN, with a
variable number of hosts. See how the topology is created in example_topo to
understand which interface is part of which link.

```
BELNET --- BXL --- LLN
|                  |
+- B1          L1 -+- L3
|                  |
+- B2          L2 -+- L4
```

## Scripts

The routers all define a boot script, which reloads the sysctl configuration
in every net NS (in this case: Enable IPv6 and IPv6 forwarding). Their startup
script then assign IP addresses to the interfaces and/or start a routing daemon.
More specifically:

- BXL is the simplest node. It statically defines the IP addresses/prefixes
on every interface, and then start the BIRD routing daemon with a minimal
OSPFv3 configuration.

- LLN leverages the features of its routing daemon, Quagga. As a result, its
startup script only starts the zebra daemon, and then later ospf6d. The IPv6
addresses, prefixes, ... of the interfaces are all managed by the zebra daemon,
i.e. defined in $CONFIGDIR/LLN/quagga/zebra.conf

- BELNET is a (crude) example of a more generic configuration process. Based on
network-wide settings defined in example_topo, it derives the IP addresses
for its interfaces automatically. It then derives its BIRD configuration file
from a template. (A *much* better way would to use a real templating engine
and set of script, e.g. python/mako, ...)

The BELNET node also configures two BGP session that are available on the 
remote VM.


Most hosts (B2 L2 L3 L4) are not configured: without startup scripts, no
IPv6 addresses are assigned. As a result, they only have IPv6 link-local
addresses -- thus only have connectivity in their LAN.

L1 statically assigns its IPv6 address, and then starts an iperf server. B1
also assign itself an IPv6 address. Both hosts auto-assign a default route
to the closest router.

# Example test

The following commands will instantiate the example_topo topology,
then enter the node 'B1' and execute an iperf throughput test with the IPv6
address of the node L1.

```bash
sudo ./create_network.sh example_topo
sudo ./connect_to.sh B1
iperf -V -c fd00:255:11::1
```

Use the connect_to.sh script to get a shell in different nodes.
There, you can check the IPv6 addresses assigned to the various interfaces
(`ip -6 address`), view the kernel routing table (`ip -6 route`), connect
to the BIRD routing daemon if in use (e.g. `bird6c -s /tmp/LLN.ctl`, then
use '?' to see the list of available commands), or Quagga
(`telnet localhost zebra` or `telnet localhost ospf6d` to), ...
