#!/bin/bash


STATE="default";
echo "DEFAULT" > /etc/network_state;

while true
do
    RET=`ssh vagrant@pyth.group2.ingi -oStrictHostKeyChecking=no  -i /etc/ssh_keys/PYTH 'echo "show protocols eBGP" | sudo birdc -s /tmp/PYTH.ctl 2> /dev/null'`

    echo "$RET" | grep "Established" &> /dev/null
    RES=$?;

    if   [ $RES == 0 ] && [ "$STATE" == "failover" ]; then 
        STATE="default";
        echo "DEFAULT" > /etc/network_state;
        nsupdate monitoring/nsupdate.default.txt;

        ssh vagrant@pyth.group2.ingi -oStrictHostKeyChecking=no -i /etc/ssh_keys/PYTH 'echo "configure \"/etc/bird/bird6.conf\"" | sudo birdc -s /tmp/PYTH.ctl 2> /dev/null'
        ssh vagrant@hall.group2.ingi -oStrictHostKeyChecking=no -i /etc/ssh_keys/HALL 'echo "configure \"/etc/bird/bird6.conf\"" | sudo birdc -s /tmp/HALL.ctl 2> /dev/null'

        echo "New state of the network : DEFAULT";
    elif [ $RES != 0 ] && [ "$STATE" == "default" ]; then 
        STATE="failover";
        echo "FAILOVER" > /etc/network_state;
        nsupdate monitoring/nsupdate.failover.txt;

        ssh vagrant@pyth.group2.ingi -oStrictHostKeyChecking=no -i /etc/ssh_keys/PYTH 'echo "configure \"/etc/bird/bird6-failover.conf\"" | sudo birdc -s /tmp/PYTH.ctl 2> /dev/null'
        ssh vagrant@hall.group2.ingi -oStrictHostKeyChecking=no -i /etc/ssh_keys/HALL 'echo "configure \"/etc/bird/bird6-failover.conf\"" | sudo birdc -s /tmp/HALL.ctl 2> /dev/null'

        echo "New state of the network : FAILOVER";
    fi
    
    sleep 10
done
