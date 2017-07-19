#!/bin/bash
#This script tests the load-balancing techniques as well as
#a direct connection to every web server (check connectivity
#with every single server)
#If you wish to test several Hosts, you would see ssh_loop.bash
#to apply this script to a given group

declare web="www.group2.ingi"
echo "Starting test..."
echo "Fetching 12 requests from domain address" $web
echo "Alternating between 4 different servers is expected !"
echo

#Testing the load balancing : because it uses round-robin
#The resulting web page should be alternating every time
for i in {1..12}
do
	wget -qO - $web
done

echo

echo "Now fetching from the web servers directly ..."
declare -a arr=("web11.group2.ingi" "web12.group2.ingi" "web21.group2.ingi" "web22.group2.ingi")

#Attempting direct connection to each server
for address in "${arr[@]}"
do 
	echo "Getting from" $address
	wget -qO - $address
done
