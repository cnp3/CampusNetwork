import ipaddress
import logging
import os
import shutil
import socket
import subprocess
import sys
import threading
import time

import dns.resolver
import validators
import yaml

prefix = sys.argv[1]
groups = [x + 1 for x in range(9)]


class GroupTestThread(threading.Thread):
    def __init__(self, group):
        super().__init__()
        self.group = group
        self.log = logging.getLogger("group%d" % self.group)
        handler = logging.FileHandler(self._file())
        handler.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
        self.log.addHandler(handler)
        self.log.setLevel(logging.DEBUG)

    def _file(self):
        return self._file_backup() + ".current"

    def _file_backup(self):
        return "%s_group%d.log" % (prefix, self.group)

    def run(self):
        print("Starting thread for group %d" % self.group)
        while True:
            self.log.info("Starting tests")
            self.test_network()
            self.log.info("All tests were performed")

            if os.path.isfile(self._file()):
                shutil.copy(self._file(), self._file_backup())
                with open(self._file(), "w") as _:
                    pass

            time.sleep(10)

    def check_ip_address(self, ip):
        try:
            addr = ipaddress.ip_address(ip)
            if addr not in ipaddress.ip_network("fd00:200:%d::/48" % self.group) and \
                    addr not in ipaddress.ip_network("fd00:300:%d::/48" % self.group) and \
                    addr != ipaddress.ip_address("fd00:200::%d" % self.group) and \
                    addr != ipaddress.ip_address("fd00:300::%d" % self.group):
                self.log.error("The IP address %s is not in the range of the group addresses\n", ip)
                return False
            return True
        except ValueError:
            self.log.error("The parameter %s cannot be parsed as an IP address\n", ip)
            return False

    def check_port(self, port):
        try:
            if int(port) < 0 or int(port) > 2**16:
                self.log.error("The port %s is not in the range of acceptable port numbers\n", port)
                return False
            return True
        except ValueError:
            self.log.error("The parameter %s is not an integer and therefore not a port number\n", port)
            return False

    def test_reachability(self, dest_ip):
        try:
            ping_response = subprocess.check_output(["ping6", "-c", "1", "-w", "1", str(dest_ip)],
                                                    universal_newlines=True, timeout=2, stderr=subprocess.STDOUT)
            self.log.info("%s is reachable\n", dest_ip)
            self.log.debug("Output: %s\n", str(ping_response))
            return True
        except subprocess.CalledProcessError as e:
            self.log.error("Cannot ping address %s - output: %s\n", dest_ip, e.output)
            return False
        except subprocess.TimeoutExpired as e:
            self.log.error("Timeout while pinging the address %s\n", dest_ip)
            return False

    def test_dns_server(self, server_ip):
        resolver = dns.resolver.Resolver()
        resolver.nameservers = [server_ip]
        resolver.timeout = 1
        resolver.lifetime = 1
        try:
            resolver.query("group%d.ingi" % self.group, "NS")
            self.log.info("The DNS name server %s is working\n", server_ip)
        except dns.resolver.NoNameservers as e:
            self.log.error("Cannot query the name server %s - %s\n", server_ip, str(e))

    def test_netcat(self, dest_ip, dest_port, tcp=True, message=None):
        msg = None
        if message is not None:
            try:
                msg = bytes(bytearray.fromhex(message))
            except ValueError:
                self.log.error("Message %s is not an hexadecimal string\n", message)
                return False

        try:
            s = socket.socket(socket.AF_INET6, socket.SOCK_STREAM if tcp else socket.SOCK_DGRAM)
            s.settimeout(2)
            s.connect((dest_ip, int(dest_port)))
            if msg is not None:
                s.sendall(msg)
                self.log.debug("Sending message %s to %s:%s in %s", msg, dest_ip, dest_port,
                                      "TCP" if tcp else "UDP")
                time.sleep(1)
            s.close()
            if tcp:
                self.log.info("Successful connection to %s:%s in TCP", dest_ip, dest_port)
            else:
                self.log.info("No error when sending UDP packet to %s:%s", dest_ip, dest_port)
            return True
        except socket.error as e:
            self.log.error("Cannot reach %s:%s in %s - %s", dest_ip, dest_port, "TCP" if tcp else "UDP", str(e))
            return False
        except socket.timeout as e:
            self.log.error("Timeout when connection to %s:%s in %s - %s", dest_ip, dest_port,
                                  "TCP" if tcp else "UDP", str(e))
            return False

    def test_dns_record(self, dest_ip, dns_name):
        resolver = dns.resolver.Resolver()
        resolver.nameservers = [dest_ip]
        resolver.timeout = 1
        resolver.lifetime = 1
        try:
            answer = resolver.query(dns_name, "AAAA")
            self.log.info("The DNS server %s translated %s to %s\n", dest_ip, dns_name, ", ".join(answer))
        except dns.resolver.NoNameservers as e:
            self.log.error("Cannot get the AAAA record for %s - %s\n", dns_name, str(e))

    def test_network(self):
        resolver = dns.resolver.Resolver()
        resolver.nameservers = ["fd:200::d"]
        resolver.timeout = 1
        resolver.lifetime = 1

        answer = None
        try:
            answer = resolver.query("group%d.ingi" % self.group, "NS")
            for ip in answer:
                self.log.info("Name server found at %s\n", ip)
                if self.test_reachability(ip):
                    self.test_dns_server(ip)
        except dns.exception.Timeout as e:
            self.log.error("Timeout when contacting DNS resolver : %s\n", str(e))
        except dns.resolver.NoNameservers as e:
            self.log.error("Cannot get any name server : %s\n", str(e))

        try:
            with open("/common/scripts/group%d.yaml" % self.group) as file:
                data = yaml.load(file)
                self.log.debug("YAML data correctly parsed\n")
                if not isinstance(data, dict):
                    self.log.error("YAML data is not a hash\n")
                    return

            if len(data.get("ping6", [])) > 0:
                self.log.debug("Testing ping6 reachability\n")
                for ip in data["ping6"]:
                    if self.check_ip_address(ip):
                        self.test_reachability(ip)

            if len(data.get("ssh", [])) > 0:
                self.log.debug("Testing ssh reachability\n")
                for ip in data["ssh"]:
                    if self.check_ip_address(ip):
                        self.test_netcat(ip, 22)  # TODO Send the first bytes of an SSH connection

            if len(data.get("tcp", [])) > 0:
                self.log.debug("Testing tcp reachability\n")
                for elem in data["tcp"]:
                    if elem.get("ip", None) is None:
                        self.log.error("No IP parameter for tcp data")
                        continue
                    if elem.get("port", None) is None:
                        self.log.error("No port parameter for tcp data")
                        continue
                    if elem.get("message", None) is None:
                        self.log.debug("No message parameter for tcp data - only the connection is tested")
                    if self.check_ip_address(elem["ip"]) and self.check_port(elem["port"]):
                        self.test_netcat(elem["ip"], elem["port"], True, elem.get("message", None))

            if len(data.get("udp", [])) > 0:
                self.log.debug("Testing udp reachability\n")
                for elem in data["udp"]:
                    if elem.get("ip", None) is None:
                        self.log.error("No IP parameter for udp data")
                        continue
                    if elem.get("port", None) is None:
                        self.log.error("No port parameter for udp data")
                        continue
                    if elem.get("message", None) is None:
                        self.log.error("No message parameter for udp data")
                        continue
                    if self.check_ip_address(elem["ip"]) and self.check_port(elem["port"]):
                        self.test_netcat(elem["ip"], elem["port"], False, elem["message"])

            if len(data.get("dnsnames", [])) > 0 and answer is not None:
                self.log.debug("Testing dns record availability\n")
                for ip in answer:
                    for name in data["dnsnames"]:
                        try:
                            validators.domain(name)
                            self.test_dns_record(ip, name)
                        except validators.ValidationFailure as e:
                            self.log.error("Cannot parse %s as a domain name : %s\n", name, str(e))

        except yaml.YAMLError as e:
            self.log.error("Cannot parse YAML of the group : %s\n", str(e))
        except FileNotFoundError as e:
            self.log.error("Cannot find YAML file of the group : %s\n", str(e))


threads = [GroupTestThread(group) for group in groups]
for thread in threads:
    thread.daemon = True
    thread.start()
for thread in threads:
    thread.join()
