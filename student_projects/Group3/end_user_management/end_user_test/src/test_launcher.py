#!/usr/bin/env python3
import json
import os
import sys
import subprocess
import shlex
from subprocess import Popen, PIPE

with open('/home/vagrant/lingi2142/host_configuration.json') as data_file:
    data = json.load(data_file)

def launch_command_on_host(host, command) :
    cmd = "ip netns exec "+host+" python3 "+command
    try :
        output = subprocess.check_output(cmd.split())
    except subprocess.CalledProcessError as error:
        print(error.returncode)

for host, configs in data.items():
    print("[INFO] Launching on "+host)
    interface = host+"-eth0"
    launch_command_on_host(host,sys.argv[1] +" "+host+" "+interface+"."+configs["vlan"] ) 
