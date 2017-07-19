#!/bin/python
# Olivier Martin, Group 1.

import os, time

#######*
# HTTP #
#######*
# These tests curl www.website.group1.ingi for all CLASSICAL_USERS and from outside the network (with node TEST).

# Choose here the HTTP server we shut down for test. (HTT1, HTT2 or HTT3)
HTTX = "HTT1"

helpers.subtitle("HTTP")
helpers.information("Test the reachability of http website www.website.group1.ingi on port 80")

# First round (i==1), normal test with all http servers.
# Second round (i==2), we stop lighttpd on HTT1
for i in range(1,3):
    if i == 2:
        helpers.warning("Stoping http server on " + HTTX)
        helpers.execute_in(HTTX, "/etc/lighttpd/service.sh stop")
        time.sleep(1) #Wait to be sure the service is down

    for n in topo.CLASSICAL_USERS + ["TEST"]:
    
        #Special print for TEST node
        if n in "TEST":
            helpers.information("Test the reachability of www.website.group1.ingi from outside the network")

        run = 'curl -m 4 --retry 5 -s www.website.group1.ingi'
        validation = "<p>This a website !</p>"

        # Run test and get result
        p = helpers.execute_in(n, run)
        status = validation in p[0]
    
        # Retry if fail
        if status == False:
            p = helpers.execute_in(n, run)
            status = validation in p[0]

        # Print success or failure
        helpers.print_condition(status, "curl via " + n)

    # Do not forget to restart lighttpd
    if i == 2:
        helpers.warning("Restarting http server on " + HTTX)
        helpers.execute_in(HTTX, "/etc/lighttpd/service.sh start")




#######
# SSH #
#######
# These tests check if the ssh servers are reacheable.

helpers.subtitle("SSH")
helpers.information("Test if QHUN can open an ssh connection on port 22 to HTT nodes and CORE_ROUTERS")
for n in topo.CORE_ROUTERS + ["HTT1", "HTT2", "HTT3"]:
    
    # We just check if we get the banner when we run ssh.
    # We need to produce an error with a wrong rsa key in order to not block these test.
    # If we set the right key, we need to enter the password for each hosts to connect but then, the tests will no longer be automatic...
    run = 'timeout 4 ssh vagrant@' + n.lower() + '.group1.ingi -6 -i /home/vagrant/.ssh/id_rsa_fake -o StrictHostKeyChecking=no'
    validation = "Welcome on " + n.lower()

    # Run test and get result
    p = helpers.execute_in("QHUN", run)
    status = validation in p[1]
    
    # Retry if fail
    if status == False:
        p = helpers.execute_in("QHUN", run)
        status = validation in p[1]

    # Print success or failure
    helpers.print_condition(status, "ssh from QHUN to " + n)





########
# SNMP #
########
# These tests run snmpwalk from QHUN to CORE_ROUTERS and L3_SWITCHES

helpers.subtitle("SNMP")
helpers.information("It tests that the administrator QHUN can perform a SNMP request on CORE_ROUTERS and L3_SWITCHES on port 161 with UDP.")
for n in topo.CORE_ROUTERS + topo.L3_SWITCHES:
    
    run = 'snmpwalk -v 2c -c public udp6:' + n.lower() + '.group1.ingi:161'
    validation = "Timeticks"
    
    # Run test and get result
    p = helpers.execute_in("QHUN", run)
    status = validation in p[0]
    
    # Retry if fail
    if status == False:
        p = helpers.execute_in("QHUN", run)
        status = validation in p[0]
    
    # Print success or failure
    helpers.print_condition(status, "snmpwalk from QHUN to " + n)

