#!/usr/bin/env python3
import sys
import subprocess
import shlex
from subprocess import Popen, PIPE

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

prefixes = ["fd00:200:3", "fd00:300:3"]
DNS_addr = [":100::53",":101::53"]

def dhcpd(host, interface) :
  F = open("/home/vagrant/lingi2142/end_user_management/end_user_test/result/dhcpd/"+host,"w")
  command = "dhclient -6 -1 -v -S "+interface
  try :
    output = subprocess.check_output(command.split(),stderr=subprocess.STDOUT)
    F.write("Host : "+host+"\n")
    F.write( OK() + "["+host+"] ALL IS OK \n")
  except subprocess.CalledProcessError as error:
    print(error.returncode)
    F.write("Host : "+host+"\n")
    F.write(WARN()+" ["+host+"] ERROR \n")
  F.close()

dhcpd(sys.argv[1], sys.argv[2])

