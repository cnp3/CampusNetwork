#!/bin/bash

UPLINK=20000
DOWNLINK=20000

TC=/sbin/tc
IPT=/sbin/iptables

function voipFilter {
	$TC filter add dev $1 parent $2 prio 0 u32 \
		match u32 0x00004000 0x0000f000 at 12 \
		match ip6 sport 5060 0xfffe flowid $3
	$TC filter add dev $1 parent $2 prio 0 u32 \
		match u32 0x00004000 0x0000f000 at 12 \
		match ip6 sport 5060 0xfffe flowid $3
	$TC filter add dev $1 parent $2 prio 0 u32 \
		match u32 0x00004000 0x0000f000 at 12 \
		match ip6 sport 3478 0xfffe flowid $3
	$TC filter add dev $1 parent $2 prio 0 u32 \
		match u32 0x00004000 0x0000f000 at 12 \
		match ip6 sport 5004 0xffff flowid $3
}

function staffFilter { # TODO
	$TC filter add dev $1 parent $2 prio 0 u32 \
		match u32 0x00001000 0x0000f000 at 12 flowid $3
}

function sfq {
	$TC qdisc add dev $1 parent $2 handle $3 sfq limit 30 perturb 10 
}


while (( "$#" ))
do
	echo "[INFO] Init QoS toward $1 linked on $2"
	NETCARD="$2"
	
	# cleanup
	$TC qdisc del dev $NETCARD root 2> /dev/null
	$IPT -t mangle -F

	# define HTB root
	$TC qdisc add dev $NETCARD root handle 1: htb default 300 r2q 40 # TODO r2q
	$TC class add dev $NETCARD parent 1:0 classid 1:1 htb \
		rate $(($UPLINK))kbit ceil $(($UPLINK))kbit


	# Internal node ############################################################
	RATE100=$(( $UPLINK / 2 ))
	CEIL100=$(( $UPLINK ))
	$TC class add dev $NETCARD parent 1:1 classid 1:100 htb \
		rate $(( $RATE100 ))kbit ceil $(( $CEIL100 ))kbit burst 5k prio 0
	$TC qdisc add dev $NETCARD parent 1:100 handle 11: htb default 140
	$TC class add dev $NETCARD parent 11:0 classid 11:100 htb \
		rate $(( $RATE100 ))kbit ceil $(( $CEIL100 ))kbit burst 5k prio 0
	$TC filter add dev $NETCARD parent 1: prio 0 u32 \
		match u32 0xfd000300 0xffffefff at 24 \
		match u32 0x00020000 0xffff0000 at 28 \
		match u32 0xfd000300 0xffffefff at 8 \
		match u32 0x00020000 0xffff0000 at 12 flowid 1:100

		## VoIP 11:110
		RATE110=1
		CEIL110=$(( $CEIL100 / 10 ))
		$TC class add dev $NETCARD parent 11:100 classid 11:110 htb \
			rate $(( $RATE110 ))kbit ceil $(( $CEIL110 ))kbit prio 0
		$TC qdisc add dev $NETCARD parent 11:110 handle 1100: pfifo limit 100
		voipFilter $NETCARD 11: 11:110

		## CAM 11:120
		RATE120=1
		CEIL120=$(( $CEIL100 / 2 ))
		$TC class add dev $NETCARD parent 11:100 classid 11:120 htb \
			rate $(( $RATE120 ))kbit ceil $(( $CEIL120 ))kbit prio 1
		$TC qdisc add dev $NETCARD parent 11:120 handle 1200: pfifo limit 100
			
		$TC filter add dev $NETCARD parent 11: prio 0 \
			u32 match u32 0x00005000 0x0000f000 at 12 flowid 11:120

		## SSH 11:130
		RATE130=$(( ($CEIL100 - $CEIL110 -$CEIL120)/2 ))
		CEIL130=$(( $CEIL100 ))
		$TC class add dev $NETCARD parent 11:100 classid 11:130 htb \
			rate $(( $RATE130 ))kbit ceil $(( $CEIL130 ))kbit prio 2
		$TC qdisc add dev $NETCARD parent 11:130 handle 113: htb default 132
		$TC class add dev $NETCARD parent 113:0 classid 113:130 htb \
			rate $(( $RATE130 ))kbit ceil $(( $CEIL130 ))kbit prio 2
		
		$TC filter add dev $NETCARD parent 11: prio 0 \
			u32 match ip6 dport 80 0xffff flowid 11:130

			### Staff 113:131
			RATE131=$(( $RATE130 / 2 ))
			CEIL131=$(( $CEIL130 ))
			$TC class add dev $NETCARD parent 113:130 classid 113:131 htb \
				rate $(( $RATE131 ))kbit ceil $(( $CEIL131 ))kbit prio 0
			sfq $NETCARD 113:131 1310: $(( $CEIL131 ))
			staffFilter $NETCARD 113: 113:131

			### Other 113:132
			RATE132=$(( $RATE130 / 2 ))
			CEIL132=$(( $CEIL130 ))
			$TC class add dev $NETCARD parent 113:130 classid 113:132 htb \
				rate $(( $RATE132 ))kbit ceil $(( $CEIL132 ))kbit prio 1
			sfq $NETCARD 113:132 1320: $(( $CEIL132 ))
			
		## Other 11:140
		RATE140=$(( $CEIL100 - $CEIL110 - $CEIL120 - $RATE130 ))
		CEIL140=$(( $CEIL100 ))
		$TC class add dev $NETCARD parent 11:100 classid 11:140 htb \
			rate $(( $RATE140 ))kbit ceil $(( $CEIL140 ))kbit prio 3
		sfq $NETCARD 11:140 1400: $(( $CEIL140 ))

	# Research node ############################################################
	RATE200=$(( ($UPLINK - $RATE100) / 3 * 2))
	CEIL200=$(( $UPLINK ))
	$TC class add dev $NETCARD parent 1:1 classid 1:200 htb \
		rate $(( $RATE200 ))kbit ceil $(( $CEIL200 ))kbit burst 5k prio 1
	$TC qdisc add dev $NETCARD parent 1:200 handle 12: htb default 220
	$TC class add dev $NETCARD parent 12:0 classid 12:200 htb \
		rate $(( $RATE200 ))kbit ceil $(( $CEIL200 ))kbit burst 5k prio 1
	# TODO add filter toward research nodes
	$TC filter add dev $NETCARD parent 1: prio 0 u32 \
		match u32 0xaaaa0000 0xffff0000 at 8 flowid 1:200

		## VoIP 12:210
		RATE210=1
		CEIL210=$(( $CEIL200 / 10 ))
		$TC class add dev $NETCARD parent 12:200 classid 12:210 htb \
			rate $(( $RATE210 ))kbit ceil $(( $CEIL210 ))kbit prio 0
		$TC qdisc add dev $NETCARD parent 12:210 handle 2100: pfifo limit 100
		voipFilter $NETCARD 12: 12:210

		## Other 12:220
		RATE220=$(( $RATE200 - $CEIL210 ))
		CEIL220=$(( $CEIL200 ))
		$TC class add dev $NETCARD parent 12:200 classid 12:220 htb \
			rate $(( $RATE220 ))kbit ceil $(( $CEIL220 ))kbit prio 1
		$TC qdisc add dev $NETCARD parent 12:220 handle 122: htb default 222
		$TC class add dev $NETCARD parent 122:0 classid 122:220 htb \
			rate $(( $RATE220 ))kbit ceil $(( $CEIL220 ))kbit prio 1

			### Staff 122:221
			RATE221=$(( $RATE220 / 2 ))
			CEIL221=$(( $CEIL220 ))
			$TC class add dev $NETCARD parent 122:220 classid 122:221 htb \
				rate $(( $RATE221 ))kbit ceil $(( $CEIL221 ))kbit prio 0
			sfq $NETCARD 122:221 2210: $(( $CEIL221 ))
			staffFilter $NETCARD 122: 122:221

			### Other 122:222
			RATE222=$(( $RATE220 / 2 ))
			CEIL222=$(( $CEIL220 ))
			$TC class add dev $NETCARD parent 122:220 classid 122:222 htb \
				rate $(( $RATE222 ))kbit ceil $(( $CEIL222 ))kbit prio 1
			sfq $NETCARD 122:222 2220: $(( $CEIL222 ))



	# Commercial node ##########################################################
	RATE300=$(( $UPLINK - $RATE100 - $RATE200 ))
	CEIL300=$(( $UPLINK ))
	$TC class add dev $NETCARD parent 1:1 classid 1:300 htb \
		rate $(( $RATE300 ))kbit ceil $(( $CEIL300 ))kbit burst 5k prio 1
	$TC qdisc add dev $NETCARD parent 1:300 handle 13: htb default 320
	$TC class add dev $NETCARD parent 13:0 classid 13:300 htb \
		rate $(( $RATE300 ))kbit ceil $(( $CEIL300 ))kbit burst 5k prio 1

		## VoIP 13:310
		RATE310=1
		CEIL310=$(( $CEIL300 / 10 ))
		$TC class add dev $NETCARD parent 13:300 classid 13:310 htb \
			rate $(( $RATE310 ))kbit ceil $(( $CEIL310 ))kbit prio 0
		$TC qdisc add dev $NETCARD parent 13:310 handle 3100: pfifo limit 100
		voipFilter $NETCARD 13: 13:310

		## Other 13:320
		RATE320=$(( $RATE300 - $CEIL310 ))
		CEIL320=$(( $CEIL300 ))
		$TC class add dev $NETCARD parent 13:300 classid 13:320 htb \
			rate $(( $RATE320 ))kbit ceil $(( $CEIL320 ))kbit prio 1
		$TC qdisc add dev $NETCARD parent 13:320 handle 132: htb default 322
		$TC class add dev $NETCARD parent 132:0 classid 132:320 htb \
			rate $(( $RATE320 ))kbit ceil $(( $CEIL320 ))kbit prio 1

			### Staff 132:321
			RATE321=$(( $RATE320 / 2 ))
			CEIL321=$(( $CEIL320 ))
			$TC class add dev $NETCARD parent 132:320 classid 132:321 htb \
				rate $(( $RATE321 ))kbit ceil $(( $CEIL321 ))kbit prio 0
			sfq $NETCARD 132:321 3210: $(( $CEIL321 ))
			staffFilter $NETCARD 132: 132:321

			### Other 132:322
			RATE322=$(( $RATE320 / 2 ))
			CEIL322=$(( $CEIL320 ))
			$TC class add dev $NETCARD parent 132:320 classid 132:322 htb \
				rate $(( $RATE322 ))kbit ceil $(( $CEIL322 ))kbit prio 1
			sfq $NETCARD 132:322 3220: $(( $CEIL322 ))



#	watch  -dc  tc -p -s -d  qdisc show dev $NETCARD
#	tc -p class show dev $NETCARD
#	tc -p qdisc show dev $NETCARD
#	tc -p filter show dev $NETCARD


	shift 2
done
