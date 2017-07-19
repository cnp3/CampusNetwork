#!/bin/bash 

if [[ "$UID" != "0" ]]; then
    echo "This script must be run as root!"
    exit 1
fi

python3 template/main_config.py

