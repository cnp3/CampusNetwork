import os
import sys
import yaml


YAML_FILE = os.path.join(os.path.dirname(__file__), "group_dns.yaml")
DNS_TTL = 300

if len(sys.argv) < 2:
	print("Usage: python3 group_dns.py ingi_zone_file_path")
	sys.exit(1)

if not os.path.isfile(sys.argv[1]):
	print("%s is not a file" % sys.argv[1])
	sys.exit(1)

ZONE_FILE = sys.argv[1]

dns_data = None
with open(YAML_FILE, "r") as yaml_file:
	try:
		dns_data = yaml.load(yaml_file)
	except yaml.YAMLError as e:
		print("Cannot parse yaml file %s - error %s" % (YAML_FILE, str(e)))

lines = []
if len(dns_data) > 0:
	lines.append("\n$TTL    %d\n" % DNS_TTL)
for group in dns_data.keys():
	dns_domain = "group%d" % group
	for server in dns_data[group]:
		server_name = server["server_name"]
		server_ip = server["server_ip"]
		lines.append("\n%s    IN    NS      %s\n" % (dns_domain, server_name))
		lines.append("%s    IN    AAAA    %s\n" % (server_name, server_ip))

with open(ZONE_FILE, "a") as ingi_zone:
	print("Writing to %s:" % ZONE_FILE)
	for line in lines:
		ingi_zone.write(line)
		sys.stdout.write(line)

