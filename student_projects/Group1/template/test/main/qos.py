import time, math, re





def iperf(source, dest, port, file):
    '''
    Execute an iperf commmand from the source node to the dest node (designated by name)
    using a specified port and storing the result in a given file
    :return: A Popen instance to a running process
    '''
    return helpers.execute_in_bg(source, "iperf3 -c {} -p {} -l 10 -t 10 > {}".format(helpers.get_public_ips(dest)[0], port, file))

def get_result(file):
    '''
    Parse the output of a iperf command to a rate in kbits/sec
    '''
    f = open(file, "r")
    lines = f.read().split("\n")
    l1, l2 = lines[-4], lines[-5]
    deb1, debunit1 = re.findall(r"([0-9\\.]+) (.bits/sec)", l1)[0]
    deb2, debunit2 = re.findall(r"([0-9\\.]+) (.bits/sec)", l2)[0]
    deb1 = float(deb1)
    deb2 = float(deb2)
    f.close()

    if(debunit1 == "Mbits/sec"): deb1 *= 1000
    if(debunit2 == "Mbits/sec"): deb2 *= 1000

    avg = (deb1+deb2)/2
    return int(avg*100)/100


print("")
print("Launching the servers")
print("")
for h in ["QOS", "QOS2", "QOS3"]:
    for p in [5001, 80, 22, 2100]:
        helpers.execute_in(h, "iperf3 -s -p %d >/dev/null 2>&1 &" % p)

# Test 1: only backup
print("")
print("Launching backup")
print("")
p1 = iperf("ALEX", "QOS", "5001", "/tmp/BACKUP.txt")
p1.wait()
helpers.table([
    ["Type", "Rate", "Ceil", "Expect", "Actual"],
    ["backup", "0.1", "9", "9mbps", str(get_result("/tmp/BACKUP.txt")/1000) + "mbps"]
])

# Test 2: backup + HTTP
print("")
print("Backup + HTTP download")
print("")
p1 = iperf("ALEX", "QOS", "5001", "/tmp/BACKUP.txt")
p2 = iperf("ALEX", "QOS", "80", "/tmp/HTTP.txt")
p1.wait()
p2.wait()
helpers.table([
    ["Type", "Rate", "Ceil", "Expect", "Actual"],
    ["backup", "0.1", "9", "> 0.1mbps", str(get_result("/tmp/BACKUP.txt")/1000) + "mbps"],
    ["http", "6", "9", ">> 6mbps", str(get_result("/tmp/HTTP.txt")/1000) + "mbps"]
])

# Test 3: backup + HTTP + SSH
print("")
print("Backup + HTTP + SSH")
print("")
p1 = iperf("ALEX", "QOS", "5001", "/tmp/BACKUP.txt")
p2 = iperf("ALEX", "QOS", "80", "/tmp/HTTP.txt")
p3 = iperf("ALEX", "QOS", "22", "/tmp/SSH.txt")
p1.wait()
p2.wait()
p3.wait()
helpers.table([
    ["Type", "Rate", "Ceil", "Expect", "Actual"],
    ["backup", "0.1", "9", "~ 0.1mbps", str(get_result("/tmp/BACKUP.txt")/1000) + "mbps"],
    ["http", "6", "9", "> 6mbps", str(get_result("/tmp/HTTP.txt")/1000) + "mbps"],
    ["ssh", "1", "3", ">> 1mbps", str(get_result("/tmp/SSH.txt")/1000) + "mbps"]
])


# Test 4: backup + HTTP + SSH + VOIP
print("")
print("Backup + HTTP + SSH + VOIP")
print("")
p1 = iperf("ALEX", "QOS", "5001", "/tmp/BACKUP.txt")
p2 = iperf("ALEX", "QOS", "80", "/tmp/HTTP.txt")
p3 = iperf("ALEX", "QOS", "22", "/tmp/SSH.txt")
p4 = iperf("INT1", "QOS", "2100", "/tmp/VOIP.txt")
p1.wait()
p2.wait()
p3.wait()
p4.wait()
helpers.table([
    ["Type", "Rate", "Ceil", "Expect", "Actual"],
    ["backup",  "0.1",  "9", "~ 0.1 mbps", str(get_result("/tmp/BACKUP.txt")/1000) + "mbps"],
    ["http",    "6",    "9", "~ 6mbps", str(get_result("/tmp/HTTP.txt")/1000) + "mbps"],
    ["ssh",     "1",    "9", ">> 1mbps", str(get_result("/tmp/SSH.txt")/1000) + "mbps"],
    ["voip",    "0.1",  "1", ">>> 0.1mbps", str(get_result("/tmp/VOIP.txt")/1000) + "mbps"]
])

