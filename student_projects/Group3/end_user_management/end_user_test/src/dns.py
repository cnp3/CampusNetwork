# -*- coding: utf-8 -*-
#!/usr/bin/env python3
import sys
import subprocess
import shlex
import json
from subprocess import Popen, PIPE
import re

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

with open('/home/vagrant/lingi2142/router_configuration.json') as data_file:
    data_router = json.load(data_file)

with open('/home/vagrant/lingi2142/service_configuration.json') as data_file:
    data_service = json.load(data_file)

prefixes = ["fd00:200:3", "fd00:300:3"]
DNS_addr = [":100::53",":101::53"]

def dig_intern_router(host) :
  F = open("/home/vagrant/lingi2142/end_user_management/end_user_test/result/dns/intern/service/"+host,"w")
  for router, configs in data_router.items():
    for prefix in prefixes :
      for dns in DNS_addr :
          command = "dig AAAA @"+prefix+dns+" "+router+".router.group3.ingi +time=1"
          try :
              output = subprocess.check_output(command.split(),stderr=subprocess.STDOUT)
              if re.search("AAAA\s*fd00",output.decode('utf-8')):
                 F.write("Host : "+host+" / command : "+command+"\n")
                 F.write( OK() + "["+host+"_"+prefix+dns+"] ALL IS OK \n")
              else : 
                 F.write("Host : "+host+" / command : "+command+"\n")
                 F.write(WARN()+" ["+host+"_"+prefix+dns+"] ERROR \n")
          except subprocess.CalledProcessError as error:
              print(error.returncode)
              F.write("Host : "+host+" / command : "+command+"\n")
              F.write(WARN()+" ["+host+"_"+prefix+dns+"] ERROR \n")
   
  F.close()



def dig_intern_service(host) :
  F = open("/home/vagrant/lingi2142/end_user_management/end_user_test/result/dns/intern/router/"+host,"w")
  for service, configs in data_service.items():
    if service != "MONIT" :
      for prefix in prefixes :
        for dns in DNS_addr :
            command = "dig AAAA @"+prefix+dns+" "+service+".service.group3.ingi +time=1"
            try :
                output = subprocess.check_output(command.split(),stderr=subprocess.STDOUT)
                if re.search("AAAA\s*fd00",output.decode('utf-8')):
                   F.write("Host : "+host+" / command : "+command+"\n")
                   F.write( OK() + "["+host+"_"+prefix+dns+"] ALL IS OK \n")
                else :
                   F.write("Host : "+host+" / command : "+command+"\n")
                   F.write(WARN()+" ["+host+"_"+prefix+dns+"] ERROR \n")
            except subprocess.CalledProcessError as error:
                print(error.returncode)
                F.write("Host : "+host+" / command : "+command+"\n")
                F.write(WARN()+" ["+host+"_"+prefix+dns+"] ERROR \n")

  F.close()

def dig_reverse_service(host) :
  F = open("/home/vagrant/lingi2142/end_user_management/end_user_test/result/dns/intern/reverse/"+host,"w")
  for service, configs in data_service.items():
    for prefix in prefixes :
      for dns in DNS_addr :
         if service != "MONIT" :
            print(service)
            command = "dig @"+prefix+dns+" -x  "+prefix+":"+configs["use_type"]+configs["location"]+configs["forced_address"] + " +time=1"
            try :
                output = subprocess.check_output(command.split(),stderr=subprocess.STDOUT)
                if re.search("PTR\s*"+service,output.decode('utf-8')) or (re.search("PTR\s*website",output.decode('utf-8')) and configs["forced_address"] == "::80"):
                   F.write("Host : "+host+" / command : "+command+"\n")
                   F.write( OK() + "["+host+"_"+prefix+dns+"] ALL IS OK \n")
                else :
                   F.write("Host : "+host+" / command : "+command+"\n")
                   F.write(WARN()+" ["+host+"_"+prefix+dns+"] ERROR \n")
            except subprocess.CalledProcessError as error:
                print(error.returncode)
                F.write("Host : "+host+" / command : "+command+"\n")
                F.write(WARN()+" ["+host+"_"+prefix+dns+"] ERROR \n")

  F.close()

def dig_extern(host) :
  F = open("/home/vagrant/lingi2142/end_user_management/end_user_test/result/dns/extern/"+host,"w")    
  for prefix in prefixes :
    for dns in DNS_addr :
        command = "dig AAAA @"+prefix+dns+" google.com +time=1"
        try :
            output = subprocess.check_output(command.split(),stderr=subprocess.STDOUT)
            F.write("Host : "+host+" / command : "+command+"\n")
            F.write( OK() + "["+host+"_"+prefix+dns+"] ALL IS OK \n")
        except subprocess.CalledProcessError as error:
            print(error.returncode)
            F.write("Host : "+host+" / command : "+command+"\n")
            F.write(WARN()+" ["+host+"_"+prefix+dns+"] ERROR \n")
  F.close()


dig_intern_service(sys.argv[1])
dig_intern_router(sys.argv[1])
dig_reverse_service(sys.argv[1])
dig_extern(sys.argv[1])
