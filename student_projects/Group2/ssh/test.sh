#!/bin/bash
# This test will try if it can connects over SSH to some machines in the network from MON1.
# THIS SCRIPT MUST BE RUN AS ROOT.

USERNAME="vagrant"
#List of Hosts to be tested
SUFFIX=".group2.ingi"
HOSTS="HALL PYTH MICH SH1C CARN STEV DHCP1 RNS1 LB1 WEB11 WEB12 DHCP2 RNS2 LB2 WEB12 WEB22"


for HOST in ${HOSTS} ; do
    HOSTNAME="$HOST$SUFFIX"
    
    ip netns exec MON1 ssh -oStrictHostKeyChecking=no -l ${USERNAME} -i /etc/ssh_keys/${HOST} ${HOSTNAME} "echo \"Connected through SSH to ${HOST}\""
    #Test ssh connectivity
    #ssh -l ${USERNAME} ${HOSTNAME} echo $HOSTNAME
done
