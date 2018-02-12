# lingi2142

This repository contains:

  * the set of scripts to provision VMs, build a virtual exchange point and
    run a virtual campus networks on a VM for the course
    [LINGI2142 ](https://moodleucl.uclouvain.be/course/view.php?id=9209) at 
    [UCLouvain](https://uclouvain.be) in order to emulate campus networks and
    interconnect them.
  * Some of the student's implementation, showcasing various aspects of the 
    configuration and management of an IPv6-only multihomed network using
    provider-assigned prefixes, in the [student_projects](student_projects)
    folder. An overview of these project, as well as a feature highlight is
    available in the [README file](student_projects/README.md).
  * [host](host) defines the script to hosts a remote set of VMs for each
      group.

# Virtual machine

A sample virtual machine definition to run the script is provided and managed
using [Vagrant](https://www.vagrantup.com), using a
[VirtualBox](https://www.virtualbox.org) provider. 

You *need* to install *both* of these softwares on your machine in order to
run an emulated network.

## Commands summary

  * [./build_vm.sh](build_vm.sh) will create and provision the virtual machine.
  * `vagrant up` will boot the VM (once it has been built).
  * `vagrant ssh` (from this directory) will create an ssh connection to the
      VM.
  * `vagrant halt` will stop the VM (i.e. shutdown properly the guest OS).

# Virtual network

The main directory of this repository contains the set of scripts to start a
virtual network as well as loads and apply its configuration files.
You _should_ only run such a network within the VM.

## Description

  * [./create_network.sh](create_network.sh) will create a virtual network and
    execute startup scripts in every node. It takes one mandatory argument: 
    a bash script defining a `mk_topo` function to describe the topology
    (i.e., [example_topo](example_topo)). This scripts can also redefine the
    following environment variables: 
      * `CONFIGDIR` to specify which directory contains the configuration files
           for the topology,
      * `BOOT` to specify the prefix of the scripts to run when a network node
           has booted,
      * `STARTUP` to specify the prefix of the scripts to run when a node has
          an established connectivity.
    The script exposes various functions that can be used to create and connect
    a virtual network, such as 
      * `add_link $1 $2` to create and link nodes `$1` and `$2`,
      * `mk_LAN $router $@` to create a LAN (a network bridged at layer 2) 
           connecting a `$router` to one or more hosts (separated by space),
      * `bridge_node $node $itf $name` to bridge the physical interface
           `$itf` of the VM (i.e., one connected to the host machine) with the
           virtual interface named `$name` of the network node `$node`.

  When executed, the script creates the network according to the `mk_topo`
    function. For each network node, the directory named
    `$CONFIGDIR/<node name>` (i.e. `cfg/<node name>`) will be mounted on /etc
    (i.e., providing an overlay only visible to that node). 
    Two scripts are then executed on each node, if available and executable:
      * `$CONFIGDIR/<node name>_$BOOT` is executed right after the creation of
           the node, and before the creation of its links.
      * `$CONFIGDIR/<node name>_$STARTUP` is executed on every node once the
           whole network has been created (i.e. links, LANs, ...), thus once 
           the `mk_topo` function *returns* (i.e. do not make blocking calls
           in it ...).
  * [./connect_to.sh](connect_to.sh) takes two arguments, a configuration
      folder, and a node's name as defined in the `mk_topo` function (i.e., 
      `BXL` for the `example_topo`), and opens a shell in its environment. This
      is useful to access a node through an out of band channel (i.e., it will
      work even if the network itself is not working), thus for debug purposes.
  * [./cleanup.sh](cleanup.sh) will shutdown the network and attempt to clean
      all associated resources such as links, temp files, net NS, processes.
      *You should extend this script to account for you own tempfiles.*

Two topologies are pre-defined to be started with the create_topo script.
  1. [example_topo](example_topo) is a sample topology showing how to start a
     network, configure basic routing, as well as execute some tests in it. See
     the next section for a detailed description.
  2. [project_topo](project_topo) defines the base topology to use (and change
     if needed) for the course project itself).

By default, the `create_network.sh` script imports a few files from `/etc` in
the different nodes order to help you. If you need additional files,
edit the base array and append their names in `ETC_IMPORT` at the top of that
script.

## Example topology

[example_topo](example_topo) defines a small network topology,
running OSPF as IGP using two different software stacks.

### Description

```
BELNET --- BXL --- LLN
|                  |
+- B1          L1 -+- L3
|                  |
+- B2          L2 -+- L4
```

The [example_topo](example_topo) script defines a small topology with routers: 
`BXL`, `BELNET` and `LLN`.

It then attaches 2 LANs in the network: one on `BELNET` and one in `LLN`, 
with a variable number of hosts. 

### Scripts

The routers all define a boot script, which reloads the sysctl configuration
in every net NS (in this case: Enable IPv6 and IPv6 forwarding). Their startup
script then assign IPv6 addresses to the interfaces and/or start a routing
daemon.

More specifically:
  - `BXL` is the simplest node. It statically defines the IP addresses/prefixes
    on every interface, and then start the BIRD routing daemon with a minimal
    OSPFv3 configuration.
  - `LLN` leverages the features of its routing daemon, Quagga. As a result, its
    startup script only starts the zebra daemon, and then later ospf6d. The IPv6
    addresses, prefixes, ... of the interfaces are all managed by the zebra daemon,
    i.e. defined in
    [$CONFIGDIR/LLN/quagga/zebra.conf](example_cfg/LLN/quagga/zebra.conf).
  - `BELNET` is a (crude) example of a more generic configuration process. Based on
    network-wide settings defined in `example_topo`, it derives the IP addresses
    for its interfaces automatically. It then derives its BIRD configuration file
    from a template. (A *much* better way would to use a real templating engine
    and set of script, e.g. using python/mako, ...)

The `BELNET` node also configures two BGP sessions that are available on the 
remote VM.

Most hosts (`B2` `L2` `L3` `L4`) are not configured: without startup scripts
and no router advertisement daemons, no IPv6 addresses are assigned.
As a result, they only have IPv6 link-local addresses -- thus only have
connectivity in their LAN.

`L1` statically assigns its IPv6 address, and then starts an iperf server. `B1`
also assign itself an IPv6 address. Both hosts auto-assign a default route
to the closest router.

### Example test

  1. The following commands will instantiate the `example_topo` topology,
     then enter the node `B1` and execute an iperf throughput test with the IPv6
     address of the node `L1`.
     ```bash
     sudo ./create_network.sh example_topo
     sudo ./connect_to.sh example_cfg B1
     iperf -V -c fd00:255:11::1
     ```
  2. Use the `connect_to.sh` script to get a shell in different nodes.
     There, you can check the IPv6 addresses assigned to the various interfaces
     (`ip -6 address`), view the kernel routing table (`ip -6 route`), connect
     to the BIRD routing daemon if in use (e.g. `bird6c -s /tmp/LLN.ctl`, then
     type `?` to see the list of available commands), or Quagga 
     (`telnet localhost zebra` or `telnet localhost ospf6d` ), ...


## Concepts

We emulate networks on a single machine by leveraging Linux network
namespace, to which we interface using the `ip netns` command family (from
`iproute2`, see `man ip-netns`).

Conceptually, a net NS is a new instance of the kernel networking stack.
This enables to have multiple routing tables, set of interfaces, isolated 
across different namespaces.
We can thus emulate a new network node by representing it as a single network
namespace, with its local set of interfaces.

Connecting network namespaces is achieved using pairs of virtual ethernet 
interfaces (see `main ip-link` and look for the `veth` link type). Once a pair
of interfaces is created, we can then move each interface in the net NS of
the corresponding network node, such that:
  - the node 'sees' a new interface (its own end of the link)
  - the node has no visibility of the interfaces of other nodes.

The filesystem of the host machine is shared across all network namespace,
i.e. if two nodes try to write to a file named `/tmp/temp`, they will conflict
with eachother. Make sure to read to the documentation of the programs you want
to run in each namespace in order to figure out which file they create
(e.g. bird6 creates its control socket in `/var/run/bird6.ctl`, as a result,
we override this default value in the node BXL/BELNET's startup script). The
content of `$CONFIGDIR/$node_name` is 'overlaid' on top of `/etc` for each
node.

LAN are represented by creating a virtual switch (using the default linux
bridge implementation), connecting it to a router, then connecting multiple
hosts to the switch.


## MISC

  * The DNS server from the project setup authorize zone transfers originating
    from the project network (i.e., `dig -t AXFR ingi.` should work inside the
    emulated network if the setup is correct)
  * You can use your local web browser to access the emulated network web
      servers if you host any:
        1. Connect to the emulated network using ssh (possibly using ProxyJump
            if you need to first connect to the remote server) and use the `-D
            <port>`
            option to create a SOCKS proxy on a local port.
        2. Configure your web browser to use the new SOCKS proxy to access
           content from nodes in your virtual network (i.e. on Firefox you
           would go to Preferences / Advanced / Connection / Settings / Manual 
           Proxy / SOCKS host: localhost, port <port> / SOCKS 5 / Tick the 
           Proxy DNS option at the bottom of the pane).
