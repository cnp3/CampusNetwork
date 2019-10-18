#! /usr/bin/env python3

import pexpect
import json

__PASSWD = 'put your password here'
# or use your private key


def trim_from_start(text, char):
    for i in range(0, len(text)):
        if text[i] == char:
            return text[i:]
    return text


def trim_from_end(text, char):
    str_len = len(text)
    j = 0
    for i in range(str_len - 1, -1, -1):
        if text[i] == char:
            return text[:-j]
        j += 1

    return text


if __name__ == '__main__':
    # open a new remote connection via ssh
    child = pexpect.spawn('ssh thomas@localhost', timeout=120)
    idx = child.expect('password:', r"The authenticity of host .+ can't be established")

    if idx == 1:
        child.sendline('yes')
    child.sendline(__PASSWD)

    idx = child.expect([r'-bash-4\.2\$', 'Permission denied', 'thomas@PC-1S0-297'])
    if idx == 1:
        print("Can't connect to the remote server, exiting")
        exit(0)

    child.sendline('ping 8.8.8.8 -c2')
    idx = child.expect(['0% packet loss', r'\d+% packet loss'])

    if idx == 0:
        # do sthg, all the ICMP echo reply messages have been answered back !
        pass
    else:
        print("The network is unreachable")
        child.sendline('exit')
        exit(0)

    # example to retrieve output of command
    child.sendline('sudo mtr -c5 --json 8.8.8.8')

    # trick to move the buffer to the beginning of output
    child.expect('mtr -c5 --json 8.8.8.8')
    # trick to remove the next line to type new command to remote host
    # and wait the completion of the command
    child.expect('thomas@PC-1S0-297 ~ %')

    # child.before contains the actual output with some garbage
    # (non printable character)
    output = child.before.decode()

    # remove garbage to parse the json
    output = trim_from_start(output, '{')
    output = trim_from_end(output, '}')

    # we don't need the ssh connection anymore, close it!
    child.sendline('exit')

    # Do whatever you want with the json
    results = json.loads(output)['report']
    nb_hops = len(results['hubs'])
    print("Total hops to reach %s: %d" % (results['hubs'][nb_hops-1]['host'], nb_hops))
