#!/bin/bash

if [[ "$UID" != "0" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

# Update the apt-get
apt-get update -y && apt-get upgrade -y

# Install apache2 web server
apt-get install apache2 -y

# Stop apache2 service
/etc/init.d/apache2 stop

# Install haproxy
apt-get install haproxy

# Stop haproxy service
/etc/init.d/haproxy stop

# Install curl to test
apt-get install curl -y
