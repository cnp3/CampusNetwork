#!/usr/bin/env python3
import sys
import subprocess
import shlex
from subprocess import Popen, PIPE
import json

class bcolors:
  HEADER = '\033[95m'
  OKBLUE = '\033[94m'
  OKGREEN = '\033[92m'
  WARNING = '\033[93m'
  FAIL = '\033[91m'
  ENDC = '\033[0m'
  BOLD = '\033[1m'
  UNDERLINE = '\033[4m'

def WARN() :
    return bcolors.FAIL +"[WARN]"+ bcolors.ENDC
def OK() :
    return bcolors.OKGREEN + "[OK]" +bcolors.ENDC


with open('/home/vagrant/lingi2142/service_configuration.json') as data_file:
    data = json.load(data_file)

prefixes = ["fd00:200:3:", "fd00:300:3:"]

def ping_service(host) :
    F = open("/home/vagrant/lingi2142/end_user_management/end_user_test/result/service/"+host,"w")
    for service, configs in data.items() :
        for prefix in prefixes :
            command = "ping6 -c  1 "+ prefix+configs["use_type"]+configs["location"]+configs["forced_address"]
        try :
            output = subprocess.check_output(command.split(),stderr=subprocess.STDOUT)
            F.write("Host : "+host+" / Test "+service+" with address "+prefix+configs["use_type"]+configs["location"]+configs["forced_address"]+" \n")
            F.write(OK()+" ALL IS OK \n")
        except subprocess.CalledProcessError as error:
            print(error.returncode)
            F.write("Host : "+host+" / Test "+service+" with address "+prefix+configs["use_type"]+configs["location"]+configs["forced_address"]+" \n")
            F.write(WARN() + "ERROR \n")
    F.close()

ping_service(sys.argv[1])

