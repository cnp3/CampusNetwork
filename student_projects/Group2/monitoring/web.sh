#!/bin/bash

FILE='/etc/nginx/static/index.html';
ROUTERS=("sh1c" "hall" "pyth" "stev" "carn" "mich");

while true
do

    echo "<h1>Monitoring status</h1>" > "$FILE";
    date >> ${FILE};
    echo "<b>Current network state :</b> `cat /etc/network_state` <br/><br/>" >> "$FILE";

    echo "<h2>www DNS request from ns1.group2.ingi</h2>" >> "$FILE";

    echo "<pre>" >> ${FILE};
    dig @ns1.group2.ingi www.group2.ingi AAAA >> "$FILE";
    echo "</pre>" >> ${FILE};

    echo "<h2>Bird protocols states per router</h2>" >> "$FILE";
    for router in "${ROUTERS[@]}"
    do
        echo "<h3>$router.group2.ingi</h3>" >> "$FILE";
        ROUTER=`echo $router | awk '{print toupper($0)}'`
        cmd="'echo \"show protocols all\" | sudo birdc -s /tmp/$ROUTER.ctl'"
        echo "<pre>" >> ${FILE};
        ssh "vagrant@$router.group2.ingi" -oStrictHostKeyChecking=no -i "/etc/ssh_keys/$ROUTER" "echo \"show protocols all\" | sudo birdc -s /tmp/${ROUTER}.ctl" >> ${FILE} 2> /dev/null;
        ssh "vagrant@$router.group2.ingi" -oStrictHostKeyChecking=no -i "/etc/ssh_keys/$ROUTER" "echo \"show ospf neighbors\" | sudo birdc -s /tmp/${ROUTER}.ctl" >> ${FILE} 2> /dev/null;
        if [ $? -ne 0 ]; then
            echo "<b>Couldn't connect to Bird daemon.</b>" >> ${FILE};
        fi
        echo "</pre>" >> ${FILE};
    done

    sleep 60
done

