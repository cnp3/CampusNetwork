import os, re, subprocess, math, time, sys
import configuration_topology as topo


# --  Formatting functions  --------------------------------------------------------------------------------

class bcolors:
    OKGREEN = '\033[92m';
    WARNING = '\033[93m';
    FAIL = '\033[91m';
    ENDC = '\033[0m';
    BOLD = '\033[1m';
    OKBLUE = '\033[94m'


def success(message):
    print(bcolors.OKGREEN + "[Success] " + bcolors.ENDC, message)


def failure(message):
    print(bcolors.FAIL + "[Failure] " + bcolors.ENDC, message)


def warning(message):
    print(bcolors.WARNING + "      [!] " + bcolors.ENDC, message)


def information(message):
    print(bcolors.OKBLUE + "      [i] " + bcolors.ENDC, message)


def print_condition(condition, message):
    if (condition):
        success(message)
        return True
    else:
        failure(message)
        return False


def center(x, size, char=' '):
    xmodified = x
    if "[X]" in x:
        xmodified = bcolors.FAIL + x + bcolors.ENDC
    if "[V]" in x:
        xmodified = bcolors.OKGREEN + x + bcolors.ENDC

    return math.ceil((size - len(x)) / 2) * char + xmodified + math.floor((size - len(x)) / 2) * char


def title(x):
    SIZE = 80
    print("")
    print("+" + "-" * SIZE + "+")
    print("|" + " " * SIZE + "|")
    print("|" + center(x, SIZE - 1), "|")
    print("|" + " " * SIZE + "|")
    print("+" + "-" * SIZE + "+")
    print("")


def subtitle(x):
    SIZE = 80
    print("")
    print(center("  " + x + "  ", SIZE, '-'))


def subsubtitle(x):
    print("")
    print("------  " + x)


def table(arr, COL_SIZE=13):
    def internalprint(line, sep="|"):
        newline = [center(x, COL_SIZE) for
                   x in line]
        print(sep + sep.join(newline) + sep)

    for line in arr:
        internalprint([COL_SIZE * "-"] * len(line), sep="+")
        internalprint(line)
    line = arr[-1]
    internalprint([COL_SIZE * "-"] * len(line), sep="+")


# ---  Execute functions   ------------------------------------------------------------------------

def execute_in_bg(host, command):
    p = subprocess.Popen("sudo util/exec_command.sh %s %s" % (host, command), shell=True)
    return p


def execute(command):
    p = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output, err = p.communicate()

    return output.decode("utf-8"), err.decode("utf-8"), p.returncode


def execute_in(host, command):
    """
    Execute a command inside another host
    :param host:
    :param command:
    :return:
    """
    p = subprocess.Popen("sudo util/exec_command.sh %s %s" % (host, command), stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, shell=True)
    output, err = p.communicate()

    return output.decode("utf-8"), err.decode("utf-8"), p.returncode


def get_public_ips(host):
    """
    Make the list of all public ips of a host
    :param host:
    :return:
    """
    lines = os.popen('sudo util/exec_command.sh ' + host + ' ifconfig | grep  -E -w "f.00(.*)"').read()
    ips = re.findall(r"fd00[a-z0-9:]*", lines)
    if "fd00:200:1:400::ff" in ips:
        ips.remove("fd00:200:1:400::ff")
    return ips


def get_loopback(host):
    """
    Make the list of all public ips of a host
    :param host:
    :return:
    """
    for name, ip in topo.IPS.items():
        if host in name and "-lo" in name:
            return ip


def fancy_wait(t):
    print("Waiting {} sec for network to converge".format(t))
    for i in range(t, 0, -1):
        time.sleep(1)
        print("{}.".format(i), end="")
        sys.stdout.flush()

    print("Finished")
