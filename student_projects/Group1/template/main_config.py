
import configuration_topology as topo
from configuration_description import *
from configuration_engine import *

print("")
print("")
print("===== Creating configuration files ======")
print("")
print("")

print("Making topology")
quiet_remove(topology())
add_text(topology(), topo.TOPO_TEXT)

print("Making boot & sysctl")
quiet_remove(configuration())
print("    boot")
make_boot()
print("    sysctl")
make_sysctl()

print("Adding preconfiguration")
make_staticinit()

print("Adding routing")
make_routing()

print("Adding QOS")
make_qos()

print("Adding security")
make_security()

print("Adding addressing")
make_addressing()

print("Adding services")
make_services()

os.system('chmod -R +x ' + configuration())




print("")
print("")
print("========================================")
print("")
print("")
