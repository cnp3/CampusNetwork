#!/bin/bash

# Check whether the VM are reachable over SSH
# Run this in the background, i.e. using nohup

while "true"; do
	results="[$(date)] Connectivity check results "
	for i in 1 2 3 5 6 7 10; do
		if echo "" | nc -6 nostromo.info.ucl.ac.be $((40000+i)) 2>&1 | grep "SSH-2.0" &> /dev/null; then
			results+="/\e[32m${i}:up\e[39m"
		else
			results+="/\e[31m${i}:down\e[39m"
		fi
	done
	echo -e "$results"
	sleep 60
done
