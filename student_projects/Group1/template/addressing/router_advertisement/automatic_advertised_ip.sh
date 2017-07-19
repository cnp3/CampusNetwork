IFACE200="$(ip addr | grep -i fd00:200 | grep  -Po "fd00([a-f0-9:]*)" | head -n 1)"
NAME="$(ip netns identify $$)"

ping6 -I $IFACE200 fd00::d -W1 -c2  > /dev/null 2>&1
if [ $? -ne 0 ]
then
    # Cannot reach from 200
    cat /etc/bird/bird6.conf | grep "lifetime 3600" > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        # and configuration is for AS 200
        #echo "RADVD reconfigure: AS 200 -> AS 300"
        sed -i.bak -e 's/lifetime 0/lifetime 1800/g; s/lifetime 3600/lifetime 0/g;' /etc/bird/bird6.conf
    fi

else
    # Can reach from 200
    cat /etc/bird/bird6.conf | grep "lifetime 1800" > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        #echo "RADVD reconfigure: AS 300 -> AS 200"
        # and configuration is for AS 300
        sed -i.bak -e 's/lifetime 0/lifetime 3600/g; s/lifetime 1800/lifetime 0/g;' /etc/bird/bird6.conf
    fi

fi
birdc6 -s "/tmp/$NAME.ctl" "configure \"/etc/bird/bird6.conf\""  > /dev/null 2>&1
