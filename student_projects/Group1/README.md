# How to run this network 

This document will explain how to run the network. 
Notice that if some scripts are missing because the dependencies aren't well installed, you can see section @dependdencies. 

## Building the vm
You need virtualbox, vagrant and the plugin vagrant-vbguest installed on your computer.
Open a terminal in the directory LINGI2142-setup and launch the command:

	vagrant up

When it is done you can connect to the virtual machine with ssh:
	
	vagrant ssh

The first time you log in, you need to install the package isc-dhcp-relay manually with:
	
	sudo apt-get -y --force-yes install isc-dhcp-relay
Several windows will appears to ask for informations during the installation. Simply press escape at every request for information.

If the script warns about an encoding problem, check the beginning of the provision.sh how to set up the LANG variables. 

## Generating the scripts 

To generate (and run the network), just move in the LINGI2142-setup directory inside the vm (`cd LINGI2142-setup`) and then do `sudo make`. 
It will call our templater and generate gr1_config from the template. Then it will run the network.

`make clean` can be used to clean the entire network

## Using the generated script 

If you have already the generated config but you did not call `sudo make` to run the network, you can run it with the following command:

	sudo ./create_network.sh gr1_topo.sh

And to clean the network: 

	sudo ./cleanup.sh

## Using the network 

To use the network, there are some helpers scripts in util/ directory. 

	sudo util/exec_command.sh NODE command

		Executes a command in a node

	util/open_xterm.sh NODE 
	
		Opens a new terminal (requires X forwarding)

## Testing the network 

To test the network, just run `sudo util/run_tests.sh all` (or specify a target like "routing"). 
Warning: you may have to wait around 1 minute for the network to converge. 

## Dependencies 

Normally, the network provisions should download all the necessary files (except `isc-dhcp-relay` that must be installed manually, see section `Building the vm`). If it is not the case, please install manually: 

	iperf3 xterm bind9 netcat6 nmap curl lighttpd radvd isc-dhcp-server
	python3 rdnssd snmp snmpd isc-dhcp-relay
	
## Warning

### UnicodeDecodeError: 'ascii' codec can't decode byte 0xc3 

If the error `UnicodeDecodeError: 'ascii' codec can't decode byte 0xc3` appears, the provision file was probably badly started. This error is related to the default character encoding of the machine. To fix it, just run: 

    echo "export LANGUAGE=en_US.UTF-8" >> ~/.bashrc
    echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
    echo "export LANG=en_US.UTF-8" >> ~/.bashrc
    echo "export LC_TYPE=en_US.UTF-8" >> ~/.bashrc

And, don't forget to reload the bashrc with the "dot" command: 

    . ~/.bashrc


### recipe for target 'network' failed

If build fails with error below: 
	
	RTNETLINK answers: File exists
	makefile:7: recipe for target 'network' failed
	make: *** [network] Error 2

You may need to delete some "waste" links on the host VM. 
To do so, after make clean, run "sudo ip link" and delete each link that should come from the guest VM (like HALL-eth1, PYTH-eth2), 
that should have been deleted after cleanup. 

