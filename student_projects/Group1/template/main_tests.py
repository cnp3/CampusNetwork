'''
Main file used to launch all the network tests
Expect arguments:
    <target> <parameter> : target = the test to run, parameters = the paremeters of the test

    Special targets:
        all = all tests
        link-down = disable some links to prove network reundancy
            parameter: seed = the seed to use for RNG
'''

from configuration_engine import *
import configuration_topology as topo
import test.helpers as helpers
import random, glob, sys

# Listing target and files -----------------

main_dir = os.path.dirname(__file__) + '/test'

# List all the main tests
possible_targets = sorted(glob.glob(main_dir + "/main/*.py"))
possible_targets = [x.replace(main_dir + '/main/', '').replace('.py', '') for x in possible_targets]
possible_targets = list(filter(lambda x: x != "__init__", possible_targets))
possible_targets_files = [main_dir + "/main/" + x + ".py" for x in possible_targets]

def usage():
    print("Please specify one target in")
    print("    all")
    print("    " + ",".join(possible_targets))
    print("")
    print("You can also add a seed")
    sys.exit(1)



def test(file):
    # run a test
    exec (compile(open(file, "rb").read(), '/tmp/compiled_test.py', 'exec'), {"topo": topo, "helpers": helpers})

# Extracting target --------------------------

if len(sys.argv) <= 1:
    usage()

target = sys.argv[1]
print("Target detected: ", target)

if len(sys.argv) == 2:
    target = sys.argv[1]
else:
    target = sys.argv[1]
    random.seed(sys.argv[2])
    print("Seed set to", sys.argv[2])

if target == "all":
    for x in possible_targets:
        helpers.title(x)
        test(possible_targets_files[possible_targets.index(x)])
elif target in possible_targets:
    helpers.title(target)
    test(possible_targets_files[possible_targets.index(target)])
else:
    print("Invalid target: ", target)
    usage()

