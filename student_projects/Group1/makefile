all: config network

config: 
	util/create_config.sh 

network: 
	sudo ./create_network.sh gr1_topo.sh

clean: 
	rm -rf gr1* 
	sudo ./cleanup.sh
	@sudo ip link del PYTH-eth2 >/dev/null 2>/dev/null || true
	@sudo ip link del HALL-eth1 >/dev/null 2>/dev/null || true

