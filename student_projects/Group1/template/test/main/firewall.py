# Test for checking services allowed for the different type of users 
# I also check that:
# - traceroute and ping are blocked from outside
# - no ospf packet are seen on non router-to-router links
# - users cannot spoof their ips or contact routers directly (sending packet destined to routers).
# I used this documentation/tutorial to read xml in pyton :
# - https://docs.python.org/3/library/xml.etree.elementtree.html
# - http://stackoverflow.com/questions/29266605/getting-child-node-using-xml-etree-elementtree
# (consulted on 19/02/2017).
#
# LINGI2142 group 1
# Remi Floriot - February 2017

import subprocess
import xml.etree.ElementTree as etree
import random
import time

# first resolve website.group1.ingi
SERVER = "ns1.group1.ingi"

# define the allowed ports for the different users, and complete the allowed_port array.
all_tested_ports = [20, 21, 22, 25, 53, 80, 110, 143, 220, 443, 993, 995, 2100, 2300, 5060, 5061, 6881]
admin_ports_output = [20, 21, 22, 25, 53, 80, 110, 143, 220, 443, 993, 995, 2100, 2300, 5060, 5061, 6881]
student_ports_output = [22, 25, 53, 80, 110, 143, 220, 443, 993, 995]
teacher_ports_output = [22, 25, 53, 80, 110, 143, 220, 443, 993, 995]
server_ports_output = [22, 25, 53, 80, 110, 143, 220, 443, 993, 995]
other_devices_ports_output = [53, 2100, 5060, 5061]
users_from_outside_ucl_ports = [22, 25, 53, 80, 443]
allowed_ports = [admin_ports_output, student_ports_output, teacher_ports_output, other_devices_ports_output, server_ports_output, users_from_outside_ucl_ports]
udp_allowed_ports_inside_network = [53,547]
udp_allowed_ports_from_outside   = [53]

# get a string version of the ports to scan with nmap
PORTS = ""
for i in all_tested_ports:
    if len(PORTS) != 0:
        PORTS += ","
    PORTS += str(i)
PORTS_UDP = ""
for i in udp_allowed_ports_inside_network:
    if len(PORTS_UDP) != 0:
        PORTS_UDP += ","
    PORTS_UDP += str(i)

TMP_DIR = "/tmp/nmap_tests/"

# the name of the users :
users = ['admin', 'student', 'teacher', 'other devices', 'server', 'users outside UCL network']

# add here the different sources to test
MACHINES = []
MACHINES.append(["NTOP", "QHUN"])  # infrastructure
MACHINES.append(["REMI", "SCS1", "SUS3", "BFS1", "FRA", "SUS6"])  # student
MACHINES.append(["MENS", "OLIT", "FAB"])  # teacher
MACHINES.append(["ADC1", "INP2", "SCT1", "BAT1", "BFT1"])  # other devices
MACHINES.append(["DHC1","DHC2"])  # servers
MACHINES.append(["TEST"])  # from outside of UCL

CORE_ROUTERS = ["MICH", "SH1C", "HALL", "PYTH", "STEV", "CARN"]
L3_SWITCHES = ["ADMI", "SUD", "SCES", "BARB", "INGI", "BFLT", "DNS1", "DNS2"]
ROUTERS = CORE_ROUTERS + L3_SWITCHES

# init tests : create a new empty directory TMP_DIR
output, err, returncode = helpers.execute("rm -rf {}".format(TMP_DIR))
if returncode != 0:
    helpers.failure("Error when launching the tests (rm)")
    exit(-1)

output, err, returncode = helpers.execute("mkdir {}".format(TMP_DIR))
if returncode != 0:
    helpers.failure("Error when launching the tests (mkdir)")
    exit(-1)

helpers.information("This test checks what services are allowed/denied for each user type.")

# launch some tcpdump for test 8 (see at the bottom of this script for the results).
# It will be used to verify that no ospf packets are seen on non router-to-router link for example.
# We launch these tcpdump in background while showing other tests to the user.
rnd = random.randint(0,len(ROUTERS)-1)
router_listening = ROUTERS[rnd]
rnd1 = random.randint(0,4)
rnd = random.randint(0,len(MACHINES[rnd1])-1)
end_host_listening = MACHINES[rnd1][rnd]
helpers.execute_in_bg(router_listening, "timeout 10s tcpdump -i any proto ospf -w "+TMP_DIR+"tcpdump_router >/dev/null 2>/dev/null")
helpers.execute_in_bg(end_host_listening, "timeout 10s tcpdump -i any proto ospf -w "+TMP_DIR+"tcpdump_host >/dev/null 2>/dev/null")
# launch nmap on random user with spoofed ip + tcpdump on receiver to see if spoofed packet can go trhough the network
helpers.execute_in_bg("HTT3", "timeout 10s tcpdump -i any -nn host fd00:300:1:2020:bad:bad:bad:bad -w "+TMP_DIR+"tcpdump_spoof >/dev/null 2>/dev/null")
rnd2 = random.randint(1,4)
rnd3 = random.randint(0,len(MACHINES[rnd2])-1)
host_doing_spoofing = MACHINES[rnd2][rnd3]
# now launch tcpdump on a router to discover if it is possible to target a router from a random host.
users_not_used = ["MATH", "ROB", "INT1", "SUS1", "ADC2"] # avoid interferences with other tests
rnd4 = random.randint(0,len(users_not_used)-1)
host_targetting_router = users_not_used[rnd4]
rnd5 = random.randint(0,len(CORE_ROUTERS)-1)
router_targetted = CORE_ROUTERS[rnd5]
ip_router_targetted = helpers.get_public_ips(router_targetted)[0]
ip_host_targetting_router = helpers.get_public_ips(host_targetting_router)[0]
helpers.execute_in_bg(router_targetted, "timeout 10s tcpdump -i any -nn host "+ip_host_targetting_router+" -w "+TMP_DIR+"tcpdump_target_router >/dev/null 2>/dev/null")

# launch the nmaps when tcpdumps are ready
time.sleep(1)
helpers.execute_in_bg(host_doing_spoofing, "nmap -6 -p 80 -S fd00:300:1:2020:bad:bad:bad:bad -e "+host_doing_spoofing+"-eth0 -Pn htt3.group1.ingi >/dev/null 2>/dev/null")
helpers.execute_in_bg(host_targetting_router, "nmap -6 -p 80 -S "+ip_host_targetting_router+" -e "+host_targetting_router+"-eth0 -Pn "+ip_router_targetted+" >/dev/null 2>/dev/null")
# a timer to ensure that 10 seconds at least will elapse before to read the restults of these listenings:
start = int(round(time.time() * 1000))

'''
Launch nmap to [[domain]] from the client specified.

This method will write a xml file with nmap and then parse it to check what services 
are allowed and what services are filtered.
'''
def try_nmap(user_type, numbertest, client, dest=SERVER):
    result = []
    output, err, returncode = helpers.execute_in(client, "nmap -6 -oX {} -Pn -sT -sU -p U:{},T:{} {}".format(TMP_DIR + str(numbertest), PORTS_UDP, PORTS, dest))
    if returncode != 0:
        helpers.warning("User type '" + users[user_type] + "', test " + str(numbertest) + " : cannot launch nmap")
        return None
    tree = etree.parse(TMP_DIR + str(numbertest))
    root = tree.getroot()
    host = root.findall('host')

    count = 0
    for h in host:
        for node in h.getiterator():
            if node.tag == 'status':
                if node.attrib['state'] != 'up':
                    helpers.warning("User type '" + users[user_type] + "', test " + str(
                        numbertest) + " : destination seems down")
                    return None
            elif node.tag == 'port':
                port_number = int(node.attrib['portid'])
                protocol = node.attrib['protocol']
                state = node.findall('state')
                for s in state:
                    for s_node in s.getiterator():
                        if s_node.tag == 'state':
                            port_state = s_node.attrib['state']
                service = node.findall('service')
                for s in service:
                    for s_node in s.getiterator():
                        if s_node.tag == 'service':
                            port_service = s_node.attrib['name']
                count += 1
                result.append((port_number, port_state, port_service, protocol))

    if count == 0:
        helpers.warning("User type '" + users[user_type] + "', test " + str(
            numbertest) + " : destination might be unreachable")
        return None
    return result


"""
This methods verify the results of the nmap test to check what services are allowed/not allowed
and to verify if it corresponds to the specifications written for each type of user.
"""
def do_verifications_ports(user_type, nmap_results):
    list_ports = allowed_ports[user_type]
    result = True
    tcp_tested = []
    udp_tested = []
    result_array = []
    header = []
    header.append(users[user_type]+' can contact')
    header.append(users[user_type]+' cannot contact')
    result_array.append(header)
    col_left = []
    col_right = []
    
    for port_number, port_state, port_service, protocol in nmap_results:
        if protocol == 'tcp':
            tcp_tested.append((port_number, port_state, port_service, protocol))
        else:
            udp_tested.append((port_number, port_state, port_service, protocol))
    list_to_show = [tcp_tested, udp_tested]
    for a in range(0,2):
        if a == 1:
            protocol = 'tcp'
        else:
            protocol = 'udp'
        for port_number, port_state, port_service, protocol in list_to_show[a]:
            if protocol == 'tcp':        
                if port_number not in list_ports:
                    if port_state == 'filtered':
                        col_right.append("[V] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                    else:
                        result = False 
                        col_left.append("[X] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                else:
                    if port_state == 'filtered':
                        result = False
                        col_right.append("[X] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                    else:
                        col_left.append("[V] "+port_service+" ("+str(port_number)+"/"+protocol+")")
            else:
                if users[user_type] != 'users outside UCL network':
                    if port_state == 'open' or port_state =='closed' :
                        col_left.append("[V] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                    else:
                        result = False
                        col_right.append("[X] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                else:
                    if port_state == 'open' or port_state =='closed' :
                        if port_number in udp_allowed_ports_from_outside:
                            col_left.append("[V] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                        else:
                            col_left.append("[X] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                            result = False
                    else:
                        if port_number not in udp_allowed_ports_from_outside:
                            col_right.append("[V] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                        else:
                            col_right.append("[X] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                            result = False


    
    len_left  = len(col_left)
    len_right = len(col_right)
    len_table = max(len_left, len_right)
    index_left = 0
    index_right = 0
    for i in range(len_table):
        if index_left < len_left and index_right < len_right:
            row = [col_left[index_left], col_right[index_right]]
            result_array.append(row)
        elif index_left < len_left:
            row = [col_left[index_left], '']
            result_array.append(row)
        elif index_right < len_right:
            row = ['',col_right[index_right]]
            result_array.append(row)
        index_left += 1
        index_right += 1
        
    print('')
    helpers.table(result_array, COL_SIZE=42)
    print('')
    return result

"""
This methods verify the results of the nmap test to check what services are allowed/not allowed to be hosted
by a student. Now, all services are not allowed to be hosted by a student.
"""
def do_verification_student_host_services(nmap_results):
    list_ports = [] # no services allowed towards a student
    result = True
    tcp_tested = []
    result_array = []
    header = []
    header.append('student can host')
    header.append('student cannot host')
    result_array.append(header)
    col_left = []
    col_right = []
    for port_number, port_state, port_service, protocol in nmap_results:
        if protocol == 'tcp':
            tcp_tested.append((port_number, port_state, port_service, protocol))
    for port_number, port_state, port_service, protocol in tcp_tested:
        if protocol == 'tcp':
            if port_number not in list_ports:
                if port_state == 'filtered':
                    col_right.append("[V] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                else:
                    col_left.append("[X] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                    result = False        
            else:
                if port_state == 'filtered':
                    result = False
                    col_right.append("[X] "+port_service+" ("+str(port_number)+"/"+protocol+")")
                else:
                    col_left.append("[V] "+port_service+" ("+str(port_number)+"/"+protocol+")")
    
    len_left  = len(col_left)
    len_right = len(col_right)
    len_table = max(len_left, len_right)
    index_left = 0
    index_right = 0
    for i in range(len_table):
        if index_left < len_left and index_right < len_right:
            row = [col_left[index_left], col_right[index_right]]
            result_array.append(row)
        elif index_left < len_left:
            row = [col_left[index_left], '']
            result_array.append(row)
        elif index_right < len_right:
            row = ['',col_right[index_right]]
            result_array.append(row)
        index_left += 1
        index_right += 1
        
    print('')
    helpers.table(result_array, COL_SIZE=42)
    print('')
    return result

"""
Launch all the tests
"""
numbertest = 0
for i in range(len(users)):
    print('')
    if len(MACHINES[i]) == 0:
        helpers.information("Test coverage info : no test for user type '" + users[i] + "'")
    else:
        helpers.information("["+str(numbertest+1)+"/"+str(len(users)+2)+"] Collecting data for user type '"+users[i]+"' ...")
        if len(MACHINES[i]) == 1:
            end_host = MACHINES[i][0]
        else:
            rnd = random.randint(0,len(MACHINES[i])-1)
            end_host = MACHINES[i][rnd]
        numbertest += 1
        result = try_nmap(i, numbertest, end_host)
        if (result == None or len(result) == 0):
            helpers.failure("> Failed firewall tests for user type '" + users[i] + "'")
            if i == 1:
                helpers.information("["+str(numbertest+1)+"/"+str(len(users)+2)+"] Second test on student skipped as the first one failed.")
                numbertest += 1
        else:
            user_result = do_verifications_ports(i, result)
            if i == 1:
                helpers.information("["+str(numbertest+1)+"/"+str(len(users)+2)+"] Verifying that a student cannot host any service ...")
                numbertest += 1
                dest = helpers.get_public_ips("BAS1")[0]
                result_student = try_nmap(i, numbertest, end_host, dest=dest)
                if(result == None or len(result) == 0):
                    helpers.failure("> Failed firewall tests for checking that student cannot host any service")
                else:
                    user_result2 = do_verification_student_host_services(result_student)
            if (user_result == True and i != 1) or (i == 1 and user_result == True and user_result2 == True):
                helpers.success("> All tests passed for user type '" + users[i] + "'")
            else:
                helpers.failure("> Failed firewall tests for user type '" + users[i] + "'")

# Other tests : verify that an host outside the network cannot ping or traceroute towards our network, 
# verifying that ospf does not reach end users
print('')
helpers.information("["+str(numbertest+1)+"/"+str(len(users)+2)+"] Running some additional tests ...\n")
numbertest += 1
out, err, code = helpers.execute_in('TEST', 'ping6 -c 1 -W 2 '+SERVER)
if code == 0:
    helpers.failure("ping6 should be blocked from outside of the network")
else:
    helpers.success("ping6 is blocked from outside of the network")

out, err, code = helpers.execute_in('TEST', "traceroute6 -m 10 -w 0.2 "+SERVER)
ok = True
for i in range(1,11):
    if str(i)+'  * * *' not in str(out) and str(i)+'  * * *' not in str(err):
        ok = False
if not ok:
    helpers.failure("traceroute6 should be blocked from outside of the network")
else:
    helpers.success("traceroute6 is blocked from outside of the network")


while ((int(round(time.time() * 1000))) - start) < 10000:
    time.sleep(.2)# sleep while there is not 10 seconds ellapsed since the beginning of tcpdump listening

# we launched tcpdump on a random router and on a random host to verify that routers receives ospf and hosts does not
out,_,code2 = helpers.execute("sudo tcpdump -nr "+TMP_DIR+"tcpdump_router | wc -l")
if code2 != 0:
    helpers.failure("Test: listening ospf packets on router-to-router link: error with tcpdump")
elif int(out) > 0:
    helpers.success("Some ospf packets are seen when listening on a random router-to-router link")
else:
    helpers.failure("No ospf packet seen on a random router-to-router link after 10 seconds listening")


out,_,code2 = helpers.execute("sudo tcpdump -nr "+TMP_DIR+"tcpdump_host | wc -l")
if code2 != 0:
    helpers.failure("Test: listening ospf packets on non router-to-router link: error with tcpdump")
elif int(out) > 0:
    helpers.failure("Some ospf packets are seen when listening a random non router-to-router link")
else:
    helpers.success("No ospf packet seen on a random non router-to-router link after 10 seconds listening")

# verify that spoofing is forbiden (we listened 10 seconds on a server and we whould not see 
# any packets send with a spoofed source ip (we set user type = admin (=0) from non-admin user).
out,_,code2 = helpers.execute("sudo tcpdump -nr "+TMP_DIR+"tcpdump_spoof | wc -l")
if code2 != 0:
    helpers.failure("Test: listening packets on server to verify that spoofing is not allowed: error with tcpdump")
elif int(out) > 0:
    helpers.failure("A user chosen randomly inside our network has successfully spoofed his source ip")
else:
    helpers.success("A user chosen randomly inside our network did not manage to spoof his source ip")

# verify that a random user cannot address a message destined to one of our router
out,_,code2 = helpers.execute("sudo tcpdump -nr "+TMP_DIR+"tcpdump_target_router port 80 | wc -l")
if code2 != 0:
    helpers.failure("Test: listening packets on router to verify that user cannot contact it directly: error with tcpdump")
elif int(out) > 0:
    helpers.failure("A non-admin user chosen randomly in our network succeed to contact a router. This should be forbidden.")
else:
    helpers.success("A non-admin user chosen randomly in our network cannot contact directly a router")


# clean TMP_DIR after tests
# p = subprocess.Popen(["rm", "-rf", TMP_DIR], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
# output, err = p.communicate()
# if p.returncode != 0:
#    print("cleaning temporary files :")
#    helpers.warning("Problem when cleaning data allocated for the test")
