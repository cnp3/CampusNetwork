#!/bin/bash

# usage : ./connectivity_test_on_machine.sh <machine_name> <list_addresses>
# Check the connectivity from a machine to a list of addresses
# Connectivity is checked by sending ping to the specified addresses

if [ $# != 2 ]
then
    echo "wrong number of parameters !"
    echo "usage : ./connectivity_test_on_machine.sh <machine_name> <list_addresses>"
    exit
fi

NAME=$1
LIST_ADDR=$2

echo "" > /tmp/"${NAME}_test.txt"

while read line
do
   # 1 ping with 1 sec timeout
   ping6 -c 1 -W 1 $line > /dev/null # Will return '0' if ping was successful

   if [ $? != 0 ]
   then
        echo "${line} can not be reached from ${NAME}" >> /tmp/"${NAME}_test.txt"
   fi
done < $LIST_ADDR

exit
