#!/bin/bash

sudo -s sh -c './cleanup.sh ; ip link delete HALL-eth1 ; ip link delete PYTH-eth2'
