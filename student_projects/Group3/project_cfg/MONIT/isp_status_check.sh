#!/bin/bash

LOG_FILE="/etc/log/isp_status_log"
exec &>> $LOG_FILE

ROUTERS=("HALL" "PYTH" "STEV" "CARN" "MICH" "SH1C")
ROUTERS_TO_CHECK=("HALL" "PYTH")
BGP=("pop300" "pop200")

# BGP protocol name for which status is 'Established'
PREVIOUS_REACHABLE=""
REACHABLE=""

declare -A PREFIXES # Dictionary
PREFIXES+=( ["pop200"]="fd00:200:3:" ["pop300"]="fd00:300:3:" )

# Wait one minute at network creation before checking ISPs status
sleep 60

while true
do

	REACHABLE=""

	# Check connectivity with ISP on each router
	for (( i=0; i<${#ROUTERS_TO_CHECK[@]}; i++ ));
	do
		sudo ip netns exec "${ROUTERS_TO_CHECK[$i]}" sudo /etc/check_bgp_status.sh ${ROUTERS_TO_CHECK[$i]} ${BGP[$i]}

		# The ISP is reachable
		if [ $? -eq 1 ]
		then
			REACHABLE="$REACHABLE ${BGP[$i]}"
		else
			echo "[WARN] ${BGP[$i]} BGP peering is not established" >> $LOG_FILE
		fi
	done

	# If the connectivity with ISP changed, inform other routers
	if [ "$REACHABLE" != "$PREVIOUS_REACHABLE" ]
	then

		# Creation of the string of reachable prefixes
		IFS=' ' read -r -a BGP_NAME_ARRAY <<< $REACHABLE # Split string REACHABLE in the array BGP_NAME_ARRAY
		PREFIXES_TO_ANNOUNCE=""
		for (( i=0; i<${#BGP_NAME_ARRAY[@]}; i++ ));
		do
			PREFIXES_TO_ANNOUNCE="$PREFIXES_TO_ANNOUNCE ${PREFIXES[${BGP_NAME_ARRAY[$i]}]}"
		done

		# Update radvd configuration on other routers, in order to change the prefix advertisment
		for (( i=0; i<${#ROUTERS[@]}; i++ ));
		do
			sudo ip netns exec ${ROUTERS[$i]} sudo /etc/radvd/update_radvd_conf.py ${ROUTERS[$i]} $PREFIXES_TO_ANNOUNCE
			sudo ip netns exec "${ROUTERS[$i]}" sudo kill --signal SIGHUP "$(< /run/radvd/${ROUTERS[$i]}_radvd.pid)"
		done

		# Update DNS configuration in order to advertise reachable addresses for services (webservers, DNS, ...)
		DNS=( "NS1" "NS2" )
		for (( i=0; i<${#DNS[@]}; i++ ));
		do
			sudo ip netns exec ${DNS[$i]} sudo /etc/bind/update_dns.py --dns "${DNS[$i]:2:3}" --prefix $PREFIXES_TO_ANNOUNCE
			sudo ip netns exec ${DNS[$i]} sudo kill --signal SIGHUP "$(< /var/run/named_ns${DNS[$i]:2:3}.pid)"
		done
	fi

	PREVIOUS_REACHABLE=$REACHABLE

	sleep 5
done

exit
