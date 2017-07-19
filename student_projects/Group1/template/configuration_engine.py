'''
    Template engine version 3, which contains all shared tools used to translate template
    file to real files

    By Group 01

    Should not be edited to change the network settings. @see template.py instead
'''

import os, shutil, math


# force removing a file or a dir with no error messages
def quiet_remove(f):
    try:
        os.remove(f);
    except:
        pass

    try:
        shutil.rmtree(f)
    except:
        pass


# location of the parent directory (related to configuration_description.py)
def parent(): return os.path.dirname(os.path.dirname(__file__))


# location of the topology file (relative to configuration_description.py)
def topology(): return os.path.join(parent(), "gr1_topo.sh")


# location of the configuration directory (related to configuration_description.py)
def configuration(): return os.path.join(parent(), "gr1_config")


# location of the startup script of "node" (related to configuration_description.py)
def startup(node): return os.path.join(configuration(), node + "_start")


# location of the boot script of "node" (related to configuration_description.py)
def boot(node): return os.path.join(configuration(), node + "_boot")


# location of the sysctl.conf file of "node" (related to configuration_description.py)
def sysctl(node): return os.path.join(configuration(), node, "sysctl.conf")


# location of a file not shared between the different nodes, configuration specific for "node"
def unshared(node, location):
    if location.startswith("/etc"):
        return os.path.join(parent(), "gr1_config", node, location.replace('/etc/', ''))
    else:
        raise Exception("unshared should start with /etc")


# location of a shared file among all nodes
def shared(location):
    if not location.startswith("/etc"):
        return location
    else:
        raise Exception("shared should not start with /etc")


# parse a file with some parameters
def __parse(filename, parameters={}, cr=True):
    # default parameters
    parameters["prefix_a"] = "fd00:0200:0001"
    parameters["prefix_b"] = "fd00:0300:0001"
    parameters["local_as"] = "0001"

    # parsing
    f = open(os.path.join(os.path.dirname(__file__), filename), "r")
    ctn = f.read()
    f.close()
    if cr:
        return ctn.replace("{", "{{").replace("}", "}}").replace("[[", "{").replace("]]", "}").format(**parameters) +"\n"
    else:
        return ctn.replace("{", "{{").replace("}", "}}").replace("[[", "{").replace("]]", "}").format(**parameters)

# add row text to a given location
def add_text(location, text):
    created = False
    if "_start" in location:
        if not os.path.exists(location):
            created = True

    try:
        dirname =os.path.dirname(location)
        if dirname != '':
            os.makedirs(dirname)
    except FileExistsError:
        pass

    f = open(location, "a+")
    if created:
        f.write("#!/bin/sh\n")
    f.write(text)
    f.close()


# append a persed file to a given location
def append(location, source, parameters={}, log=False, cr=True):
    if log:
        print(location.replace(parent(), ''), " <- ", source)
    add_text(location, __parse(source, parameters, cr=cr))

def banner(text):
    n = len("#########################################################")
    ret = "#"*n
    ret += "\n"
    ret += "#"
    ret += math.ceil((n-2-len(text))/2) * " " + text + " " *math.floor((n-2-len(text))/2)
    ret += "#"
    ret += "\n"
    ret += "#"*n
    ret += "\n"

    return ret