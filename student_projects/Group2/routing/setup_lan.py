#!/usr/bin/python

import subprocess, sys, json

#subprocess.call = lambda x: sys.stdout.write(str(x)+'\n')

IP_BASE = "fd00:{AS}:2:{use}{location}{id}::{end}"
PREFIX_BASE = IP_BASE + '/64'
DHCP_AS = 200

def to_hex(n, width=1):
    h = hex(n).split('x')[1]
    return '0'*(width - len(h)) + h


# router => router name
# Sets different addresses for the router's (V)conf
def build_lans(router):
    lans = []
    for lan in conf[router]["lans"]:
	if lan == 0: # static LAN, used for servers
            for AS in conf[router]["as"]:
                ip = PREFIX_BASE.format(AS=AS,
                    use=to_hex(lan),
                    location=to_hex(conf[router]["location"]),
                    id=to_hex(conf[router]["id"], width=2),
                    end='0')

                subprocess.call(['ip', 'address', 'add', 'dev', interface, ip])

        else: # VLAN, used for dhcp
            subprocess.call(['vconfig', 'add', interface, str(lan)])
            subprocess.call(['ip', 'link', 'set', interface+'.'+str(lan), 'up'])
            ip = PREFIX_BASE.format(AS=DHCP_AS,
                use=to_hex(lan),
                location=to_hex(conf[router]["location"]),
                id=to_hex(conf[router]["id"], width=2),
                end='0')
            subprocess.call(['ip', 'address', 'add', 'dev', interface+'.'+str(lan), ip])

# node => node name
# AS => AS number
# base => IP_BASE or PREFIX_BASE
# use => LAN number (0/1/2/3/...)
# return => full IP or prefix, according to the parameters
def build_ip(node, AS, base=IP_BASE, use=None):
    if conf[node]['type'] == 'router':
        location = conf[node]['location']
        router_id = conf[node]['id']
        use = use
        end = 0
    elif conf[node]['type'] == 'host':
        router = conf[node]['router']
        location = conf[router]['location']
        router_id = conf[router]['id']
        use = conf[node]['lan']
        end = conf[node]['sub_id']

    return base.format(AS=AS,
            use=to_hex(use),
            location=to_hex(location),
            id=to_hex(router_id, width=2),
            end=to_hex(end))

# host => host name
# interface => interface name
# Sets a VLAN interface for the given host
def create_vlan_host(host, interface):
    if(conf[host]['lan'] != 0):
        subprocess.check_output(['vconfig', 'add', interface, str(conf[host]['lan'])])
        subprocess.check_output(['ip', 'link', 'set', 'dev', interface+'.'+ str(conf[host]['lan']), 'up'])
        return conf[host]['lan']
    return -1
         
    

f = open('routing/lans.conf')
conf = json.load(f)

if __name__ == '__main__':
    interface = sys.argv[1] #example : CARN-lan0 / CA1-eth0
    node = interface.split('-')[0]

    if conf[node]['type'] == 'router': #If it's a router, build the LANs
        build_lans(node)
    elif conf[node]['type'] == 'host': #If its a host, create the (V)LANs and assigns IP addresses and routes
        for AS in conf[node]['as']:
            vlan = create_vlan_host(node, interface)
            if(vlan == -1): # If it's not a DHCP client, assign an IP address	
                #ip address add dev HA1-eth0 fd00:2:1:b::1/64
                ip = build_ip(node, AS, base=PREFIX_BASE)
                subprocess.call(['ip', 'address', 'add', 'dev', interface, ip])

        if conf[node]['lan'] == 0: # Add default route via router if not DHCP client
            #ip -6 route add ::/0 via fd00:2:1:b::0
            router = conf[node]['router']
            gw = build_ip(router, conf[node]['as'][0], use=conf[node]['lan'])
            subprocess.call(['ip', '-6', 'route', 'add', '::/0', 'via', gw])
