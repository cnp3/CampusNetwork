import random, itertools, time


# Listing the nodes that will be inaccessible after removing a node
SHOULD_BE_DISCO = {
    "ADMI": ["ADMI", "NTOP", "QHUN", "ADC1","ADT1", "ADC2"],
    "SUD": ["SUD", "SUS1", "SUS2", "SUS3", "SUS4", "SUS5", "SUS6"],
    "SCES": ["SCES", "SCS1","SCS2", "SCT1", "SCT2"],
    "BARB": ["BARB", "BAS1", "BAS2", "BAT1", "BAT2"],
    "INGI": ["INGI", "FAB", "OBO", "OLIT", "MATH", "ALEX", "REMI", "FRA", "OLI", "ROB", "INC1", "INC2","INP1", "INP2", "INT1", "INT2"],
    "CARN": ["CARN", "DNS1", "HTT1", "HTT2", "QOS", "QOS2", "QOS3", "DHC1", "DHC2"],
    "BFLT": ["BFLT", "BFS1", "BFS2", "MENS", "PVR", "BFT1", "BFT2"]
}
SHOULD_BE_DISCO["SH1C"] = ["SH1C"] + SHOULD_BE_DISCO["ADMI"]
SHOULD_BE_DISCO["HALL"] = ["HALL"] + SHOULD_BE_DISCO["SUD"]
SHOULD_BE_DISCO["PYTH"] = ["PYTH"] + SHOULD_BE_DISCO["SCES"] + SHOULD_BE_DISCO["BARB"]
SHOULD_BE_DISCO["STEV"] = ["STEV"] + SHOULD_BE_DISCO["INGI"]
SHOULD_BE_DISCO["MICH"] = ["MICH"] + SHOULD_BE_DISCO["BFLT"]
DISCO = None


def ping_matrix(sources, destinations, column_size=7):
    '''
    Print a ping matrix betweeen 'sources' and 'destinations'
    '''

    numbered_sources = []
    numbered_dests = []
    for i, x in enumerate(sources):
        numbered_sources.append([i, x])
    for i, x in enumerate(destinations):
        numbered_dests.append([i, x])

    N = len(numbered_sources)
    M = len(numbered_dests)

    result_array = []
    result_array.append([""] + destinations)

    for i in range(N):
        line = []
        for j in range(M+1):
            if j != 0:
                line.append("[X]")
            else:
                line.append(sources[i])
        result_array.append(line)


    for a, b in itertools.product(numbered_sources, numbered_dests):
        numa, hosta = a
        numb, hostb = b


        if DISCO in SHOULD_BE_DISCO and (hostb in SHOULD_BE_DISCO[DISCO] or hosta in SHOULD_BE_DISCO[DISCO]):
            result_array[numa+1][numb+1] = "skip"
        else:

            if not hostb in topo.ALL_MACHINES:
                # host b is an ip
                out, err, code = helpers.execute_in(hosta, 'ping6 -c 1 -n -W2 ' + hostb)
            else:
                if not hostb in topo.ROUTERS:
                    # host b is not a router:
                    out, err, code = helpers.execute_in(hosta, 'ping6 -c 1 -n -W2 ' + random.choice(helpers.get_public_ips(hostb)))
                else:
                    # host b is a router: use loopback
                    out, err, code = helpers.execute_in(hosta, 'ping6 -c 1 -n -W2 ' + helpers.get_loopback(hostb))

            if code == 0:
                result_array[numa+1][numb+1] = "[V]"

        '''else:
            helpers.warning("Unable to ping " + hostb + " from " + hosta)
            helpers.information(out)
            helpers.information(err)'''

    helpers.table(result_array, COL_SIZE=column_size)


def local_connectivity():
    '''
    Check local connectivity
    '''
    helpers.subsubtitle("local connectivity")

    end_hosts = topo.CLASSICAL_USERS + topo.EQUIPMENTS
    random.shuffle(end_hosts)
    services = topo.STATIC_SERVICES + ["DNS1", "DNS2"]
    random.shuffle(services)
    routers = topo.ROUTERS
    random.shuffle(routers)

    print("host <-> host")
    ping_matrix(end_hosts[:5], end_hosts[5:10])

    print("host <-> service")
    ping_matrix(end_hosts[:5], services[:5])

    print("qhun <-> router (loopbacks)")
    ping_matrix(["QHUN"], routers)

def internet_connectivity():
    '''
    Check internet connectivity
    '''
    helpers.subsubtitle("internet connectivity")


    end_hosts = topo.CLASSICAL_USERS + topo.EQUIPMENTS
    random.shuffle(end_hosts)
    services = list(filter(lambda x: not "DNS" in x, topo.STATIC_SERVICES)) # Static services without internet
    # (anycast dns doesn't have internet because reply can be router to the other server)
    random.shuffle(services)
    routers = topo.ROUTERS
    random.shuffle(routers)

    internet = ["fd00::d", "2a00:1450:400e:804::2003", "www.google.be"]
    internet_noresolved = ["fd00::d", "2a00:1450:400e:804::2003"]

    print("         host <-> internet (can take 20sec)")
    ping_matrix(end_hosts[:5], internet, column_size=25)
    print("         service <-> internet (can take 20sec)")
    ping_matrix(services[:5], internet, column_size=25)
    print("         router <-> internet (ex: ICMP MTU too big) (can take 20sec)")
    ping_matrix(routers[:5], internet_noresolved, column_size=25)

def router_down(r):
    '''
    Disabling a router (and waiting to converge)
    '''
    global DISCO
    DISCO = r

    print("    Disabling routing on "+ r)
    helpers.execute_in(r, "birdc6 -s \"/tmp/"+r+".ctl\" \"down\"  > /dev/null 2>&1")
    helpers.fancy_wait(30)

def router_up(r):
    '''
    Re-enable a router
    '''
    global DISCO
    DISCO = None

    print("    Reenabling routing on "+r)
    helpers.execute_in(r, "bird6 -s \"/tmp/"+r+".ctl\"")

# ----------------------------------------------------------------------------------------------------------------------

print(" / ! \ Warning: finishing the test with Ctrl+C can left the network")
print(" in an unstable state (some routers down and never up)")

helpers.subtitle("advertised prefixes")
print("    Note: requires internet access to check on belneta and belnetb")
out, err, code = helpers.execute_in("QHUN", "curl -m 3 --retry 5 -s belneta.ingi | grep -i :1: | grep  -Po \"fd00:.00:1:[a-z0-9:/]*\"")
out2, err2, code2 = helpers.execute_in("QHUN", "curl -m 3 --retry 5 -s belnetb.ingi | grep -i :1: | grep  -Po \"fd00:.00:1:[a-z0-9:/]*\"")
out = out.strip()
out2 = out2.strip()
advertised_prefixes = set()
for x in out.split("\n"): advertised_prefixes.add(x.strip())
for x in out2.split("\n"): advertised_prefixes.add(x.strip())
good_prefixes = advertised_prefixes == set(["fd00:200:1::/50", "fd00:300:1::/50"])
helpers.print_condition(good_prefixes, "Advertised prefixes: " +",".join(advertised_prefixes))

helpers.subtitle("full connectivity")
local_connectivity()
internet_connectivity()

helpers.subtitle("connectivity with one link down")

r = None
while r is None or (r not in topo.ROUTERS or r == "CARN"):
    r = input('Router to bring down (anything except CARN): ')

router_down(r)
if "CARN" in r:
    print("    Warning: CARN cannot be removed because the extra link with")
    print("    MICH is not really implemented")

helpers.information("Don't forget, now " + r + " is down")

local_connectivity()
internet_connectivity()
router_up(r)

helpers.fancy_wait(30)