#!/bin/bash

LOG_FILE="/etc/log/services_status_log"
exec &>> $LOG_FILE

declare -A DNS # Dictionary
DNS+=( ["NS1"]="fd00:200:3:100::53" ["NS2"]="fd00:200:3:101::53" )

declare -A DNS_REACHABILITY
DNS_REACHABILITY+=( ["NS1"]=true ["NS2"]=true )

declare -A LOADBALANCER
LOADBALANCER+=( ["DC1LB"]="fd00:200:3:100::80" ["DC2LB"]="fd00:200:3:101::80" )

PREVIOUS_UNREACHABLE=()

# Wait for one minute at the creation of the network
sleep 60

while true
do
  UNREACHABLE=()

  # Check the reachability of DNSs
  for DNS_NAME in "${!DNS[@]}";
  do
    ping6 -c 2 ${DNS[$DNS_NAME]} > /dev/null

    if [ $? != 0 ] # not reachable
    then
      UNREACHABLE+=("$DNS_NAME")
      DNS_REACHABILITY[$DNS_NAME]=false
      echo "[WARN] $DNS_NAME is unreachable at ${DNS[$DNS_NAME]} from MONIT" >> $LOG_FILE
    else
      DNS_REACHABILITY[$DNS_NAME]=true
    fi
  done

  # Check the reachability of load balancers
  for LB_NAME in "${!LOADBALANCER[@]}";
  do
    ping6 -c 2 ${LOADBALANCER[$LB_NAME]} > /dev/null

    if [ $? != 0 ]
    then
      UNREACHABLE+=("$LB_NAME")
      echo "[WARN] $LB_NAME is unreachable at ${LOADBALANCER[$LB_NAME]} from MONIT" >> $LOG_FILE
    fi
  done

  if [ "${UNREACHABLE[*]}" != "${PREVIOUS_UNREACHABLE[*]}" ]
  then
    echo "[INFO] services reachability has changed" >> $LOG_FILE
    echo "[INFO] unreachable : ${UNREACHABLE[*]}" >> $LOG_FILE

    # Create string containing all unreachable addresses
    ADDRESSES=""
    for NAME in "${UNREACHABLE[@]}";
    do
      ADDRESS=""
      if [ -n "${DNS[$NAME] + 1}" ] # Check if $NAME is a key of DNS dictionary
      then
        ADDRESS="${DNS[$NAME]}"
      else
        ADDRESS="${LOADBALANCER[$NAME]}"
      fi
      # Add the 200 address but also the 300 address
      ADDRESSES="$ADDRESSES $ADDRESS ${ADDRESS:0:5}3${ADDRESS:6}"
    done

    # Launch updating script on DNSs
    for DNS_NAME in "${!DNS[@]}";
    do
      if [ "${DNS_REACHABILITY[$DNS_NAME]}" = true ] # Only contact DNS if it is reachable
      then
        sudo ip netns exec $DNS_NAME sudo /etc/bind/update_dns.py --dns "${DNS_NAME:2:3}" --addr $ADDRESSES
        sudo ip netns exec $DNS_NAME sudo kill --signal SIGHUP "$(< /var/run/named_ns${DNS_NAME:2:3}.pid)"
      fi
    done
  fi

  PREVIOUS_UNREACHABLE=(${UNREACHABLE[*]})

  sleep 5
done

exit
