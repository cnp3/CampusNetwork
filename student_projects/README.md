This directory contains a subset of the student projects. The key elements of
each of these are highlighted below.

Keep in mind that each group's project directory contains a copy of the scripts
provided in this directory (possibly adapted for their own use). Reading their
project report is a good starting point to understand their code structure,
especially if it involves a templating engine and/or a network configuration
database.

# Group 1

  * This group used a templating approach to generate the configuration files
    for all nodes, _before_ starting the network (see 
    [Group1/template](Group1/template) and its subdirectory)
  * They defined an exhaustive test suite which checks that the running network
    behaves as expected: Checking the availability of services, the result of
    DNS queries, whether the QoS rules were effective when congesting the
    network using iperf, whether all nodes were able to connect to each other
    and finally if the firewall was working as expected (see
    [Group1/template/test](Group1/template/test)).
  * They defined several DNS views, depending on the client's origin network
    (see [Group1/template/addressing/dns](Group1/template/addressing/dns)
  * They solve the issue arising from BCP38 in a multihomed network using
      provider-assigned addresses by:
      * Breaking the routing symmetry in the IGP using OSPF weight to control
          which egress router would be used by which node (see
          [Group1/template/routing/ospf/main_hall.conf](Group1/template/routing/ospf/main_hall.conf))
      * Configuring the preferred lifetime of prefixes in router
            advertisement to influence the source address selection of the
            hosts (i.e. make the preferred address be from the prefix of the
            closest egress), and monitor the availability of the providers to
            revert the preference if one fails (see
            [Group1/template/addressing/router_advertisement/automatic_advertised_ip.sh](Group1/template/addressing/router_advertisement/automatic_advertised_ip.sh))
      * Reconfigure the DNS entries for the servers depending on the
            availability of the providers using an ad-hoc script.


# Group 2

  * This group used some templating to generate basic configuration, then
      edited them as needed (e.g. to tweak the configuration of the border
      routers).
  * They solve the issues arising from multihoming by:
      * Assigning multiple addresses to each end-host
      * Configuring the egress routers to use multiple routing tables, and
          choosing the right one depending the source and destination addresses
          of the packing using `ip rule` (see
          [Group2/project_cfg/HALL_start](Group2/project_cfg/HALL_start))
  * They implemented a monitoring server that (see
      [Group2/monitoring](Group2/monitoring)):
      * Generate a status report on the network by querying/connecting to the
          various servers
      * Dynamically update the DNS configuration using `nsupdate`.

# Group 3

  * This group defined a model of the configuration of each node as JSON
      objects, and derive the configuration for them in a generic fashion (e.g.
      [Group3/router_configuration.json](Group3/router_configuration.json) and
      [Group3/router_config_creation.py](Group3/router_config_creation.py)).
  * This group used policy-based routing at the edges routers to route according the
      source/destination address using different routing tables in order to
      be BCP38 compliant (see the `extra_ip_commands` nodes in the
      `router_configuration.json`)
