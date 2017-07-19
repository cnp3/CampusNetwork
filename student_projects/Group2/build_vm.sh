#!/bin/sh

MINVER="1.5"
VAGRANTVER=$(vagrant -v | awk '/Vagrant/ { print $NF }')
CMP=$(echo "$MINVER\n$VAGRANTVER" | sort -V | head -n 1)

vagrant plugin install vagrant-vbguest

if [ "$MINVER" <= "$CMP" ]; then
    BOXNAME=$(awk -F "=" '/config.vm.box/ { gsub(/ *"*/, "", $NF); print $NF }' Vagrantfile)
    echo "Detected Vagrant version < 1.5 ($VAGRANTVER), manually importing the base box $BOXNAME"
    vagrant box add $BOXNAME 
else
    echo "Vagrant version is >= 1.5 ($VAGRANTVER), it will honour the vm.config.box parameter"
fi

vagrant up --provision
