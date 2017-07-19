TOPO_TEXT = """
#!/bin/bash
CONFIGDIR=gr1_config/
function mk_topo {

# Default links

add_link MICH SH1C # mich-eth0 sh1c-eth0
add_link SH1C HALL  # sh1c-eth1 hall-eth0
add_link HALL PYTH  # hall-eth1 pyth-eth0
add_link STEV PYTH  # stev-eth0 pyth-eth1
add_link STEV CARN  # stev-eth1 carn-eth0
add_link CARN MICH  # carn-eth1 mich-eth1
add_link PYTH CARN  # pyth-eth2 carn-eth2

# New links

add_link SH1C ADMI # sh1C-eth2 admin-eth0
add_link HALL SUD # hall-eth2 sud-eth0
add_link PYTH SCES # pyth-eth3 sces-eth0
add_link PYTH BARB # pyth-eth4 barb-eth0
add_link STEV INGI # stev-eth2 ingi-eth0
add_link MICH BFLT # mich-eth2 bflt-eth0

add_link MICH DNS1
add_link CARN DNS2

# New lans

mk_LAN ADMI NTOP QHUN
mk_LAN ADMI ADC1 ADC2 ADT1
mk_LAN SUD SUS1 SUS2 SUS3
mk_LAN SUD SUS4 SUS5 SUS6
mk_LAN SCES SCS1 SCS2
mk_LAN SCES SCT1 SCT2
mk_LAN BARB BAS1 BAS2
mk_LAN BARB BAT1 BAT2
mk_LAN INGI ALEX REMI FRA OLI ROB
mk_LAN INGI FAB OBO MATH OLIT
mk_LAN INGI INC1 INC2 INP1 INP2 INT1 INT2
mk_LAN BFLT BFS1 BFS2
mk_LAN BFLT MENS PVR
mk_LAN BFLT BFT1 BFT2
mk_LAN CARN DHC1 DHC2 HTT1 HTT2 HTT3 QOS QOS2 QOS3

bridge_node HALL eth1 belneta
bridge_node PYTH eth2 belnetb

mk_node TEST
bridge_node TEST eth2 output
}
"""

IPS = {
    "belneta": "fd00:0300::1",
    "belnetb": "fd00:0200::1",
    # looopbacks
    "[SH1C]-lo": "fd00:200:1:f00::1",
    "[HALL]-lo": "fd00:200:1:f00::2",
    "[PYTH]-lo": "fd00:200:1:f00::3",
    "[STEV]-lo": "fd00:200:1:f00::4",
    "[CARN]-lo": "fd00:200:1:f00::5",
    "[MICH]-lo": "fd00:200:1:f00::6",
    "[ADMI]-lo": "fd00:200:1:f00::7",
    "[SUD]-lo":  "fd00:200:1:f00::8",
    "[SCES]-lo": "fd00:200:1:f00::9",
    "[BARB]-lo": "fd00:200:1:f00::10",
    "[INGI]-lo": "fd00:200:1:f00::11",
    "[BFLT]-lo": "fd00:200:1:f00::12",
    "[DNS1]-lo" :"fd00:200:1:400::ff",
    "[DNS2]-lo": "fd00:200:1:400::ff",
    # interouters
    "SH1C-eth0": "f16::1",
    #"SH1C-eth0": "f16::1",
    "SH1C-eth1": "f12::1",
    "SH1C-eth2": "f17::1",
    "HALL-eth0": "f12::2",
    "HALL-eth1": "f23::2",
    "HALL-eth2": "f28::2",
    "PYTH-eth0": "f23::3",
    "PYTH-eth1": "f34::3",
    "PYTH-eth2": "f35::3",
    "PYTH-eth3": "f39::3",
    "PYTH-eth4": "f3a::3",
    "STEV-eth0": "f34::4",
    "STEV-eth1": "f45::4",
    "STEV-eth2": "f4b::4",
    "CARN-eth0": "f45::5",
    "CARN-eth1": "f56::5",
    "CARN-eth2": "f35::5",
    "MICH-eth0": "f16::6",
    "MICH-eth1": "f56::6",
    "MICH-eth2": "f6c::6",
    "ADMI-eth0": "f17::7",
    "SUD-eth0" : "f28::8",
    "SCES-eth0": "f39::9",
    "BARB-eth0": "f3a::10",
    "INGI-eth0": "f4b::11",
    "BFLT-eth0": "f6c::12",
    # DNS anycasted links
    "DNS1-eth0": "1410::1",
    "MICH-eth3": "1410::0",
    "DNS2-eth0": "1421::1",
    "CARN-eth3": "1421::0",
    # others
    "ADMI-lan0": "20::ff",
    "ADMI-lan1": "320::ff",
    "SUD-lan0": "2130::ff",
    "SUD-lan1": "2131::ff",
    "SCES-lan0": "2140::ff",
    "SCES-lan1": "2340::ff",
    "BARB-lan0": "2150::ff",
    "BARB-lan1": "2350::ff",
    "INGI-lan0": "3120::ff",
    "INGI-lan1": "3220::ff",
    "INGI-lan2": "3320::ff",
    "CARN-lan0": "1420::ff",
    "BFLT-lan0": "1130::ff",
    "BFLT-lan1": "1230::ff",
    "BFLT-lan2": "1330::ff",
    # CARN services
    "DHC1-eth0": "1420::1",
    "DHC2-eth0": "1420::2",
    "HTT1-eth0": "1420::3",
    "HTT2-eth0": "1420::4",
    "HTT3-eth0": "1420::5",
    "QOS-eth0": "1420::6",
    "QOS2-eth0": "1420::7",
    "QOS3-eth0": "1420::8"
}
PREFIX_A = "fd00:200:1"
PREFIX_B = "fd00:300:1"
dns_ns_records = {
    "group1.ingi.": ["ns1", "ns2"],
}
dns_aaaa_hidden_records = {
    "sh1c": [IPS['[SH1C]-lo'] ],
    "sh1c-eth0": [PREFIX_A + ':' + IPS['SH1C-eth0'], PREFIX_B + ':' + IPS['SH1C-eth0']],
    "sh1c-eth1": [PREFIX_A + ':' + IPS['SH1C-eth1'], PREFIX_B + ':' + IPS['SH1C-eth1']],
    "sh1c-eth2": [PREFIX_A + ':' + IPS['SH1C-eth2'], PREFIX_B + ':' + IPS['SH1C-eth2']],
    "hall": [IPS['[HALL]-lo'] ],
    "hall-eth0": [PREFIX_A + ':' + IPS['HALL-eth0'], PREFIX_B + ':' + IPS['HALL-eth0']],
    "hall-eth1": [PREFIX_A + ':' + IPS['HALL-eth1'], PREFIX_B + ':' + IPS['HALL-eth1']],
    "hall-eth2": [PREFIX_A + ':' + IPS['HALL-eth2'], PREFIX_B + ':' + IPS['HALL-eth2']],
    "pyth": [IPS['[PYTH]-lo'] ],
    "pyth-eth0": [PREFIX_A + ':' + IPS['PYTH-eth0'], PREFIX_B + ':' + IPS['PYTH-eth0']],
    "pyth-eth1": [PREFIX_A + ':' + IPS['PYTH-eth1'], PREFIX_B + ':' + IPS['PYTH-eth1']],
    "pyth-eth2": [PREFIX_A + ':' + IPS['PYTH-eth2'], PREFIX_B + ':' + IPS['PYTH-eth2']],
    "pyth-eth3": [PREFIX_A + ':' + IPS['PYTH-eth3'], PREFIX_B + ':' + IPS['PYTH-eth3']],
    "pyth-eth4": [PREFIX_A + ':' + IPS['PYTH-eth4'], PREFIX_B + ':' + IPS['PYTH-eth4']],
    "carn": [IPS['[CARN]-lo'] ],
    "carn-lan0": [PREFIX_A + ':' + IPS['CARN-lan0'], PREFIX_B + ':' + IPS['CARN-lan0']],
    "carn-eth0": [PREFIX_A + ':' + IPS['CARN-eth0'], PREFIX_B + ':' + IPS['CARN-eth0']],
    "carn-eth1": [PREFIX_A + ':' + IPS['CARN-eth1'], PREFIX_B + ':' + IPS['CARN-eth1']],
    "carn-eth2": [PREFIX_A + ':' + IPS['CARN-eth2'], PREFIX_B + ':' + IPS['CARN-eth2']],
    "mich": [IPS['[MICH]-lo'] ],
    "mich-eth0": [PREFIX_A + ':' + IPS['MICH-eth0'], PREFIX_B + ':' + IPS['MICH-eth0']],
    "mich-eth1": [PREFIX_A + ':' + IPS['MICH-eth1'], PREFIX_B + ':' + IPS['MICH-eth1']],
    "mich-eth2": [PREFIX_A + ':' + IPS['MICH-eth2'], PREFIX_B + ':' + IPS['MICH-eth2']],
    "stev": [IPS['[STEV]-lo'] ],
    "stev-eth0": [PREFIX_A + ':' + IPS['STEV-eth0'], PREFIX_B + ':' + IPS['STEV-eth0']],
    "stev-eth1": [PREFIX_A + ':' + IPS['STEV-eth1'], PREFIX_B + ':' + IPS['STEV-eth1']],
    "stev-eth2": [PREFIX_A + ':' + IPS['STEV-eth2'], PREFIX_B + ':' + IPS['STEV-eth2']],
    "sud": [IPS['[SUD]-lo'] ],
    "sud-eth0": [PREFIX_A + ':' + IPS['SUD-eth0'], PREFIX_B + ':' + IPS['SUD-eth0']],
    "sud-lan0": [PREFIX_A + ':' + IPS['SUD-lan0'], PREFIX_B + ':' + IPS['SUD-lan0']],
    "sud-lan1": [PREFIX_A + ':' + IPS['SUD-lan1'], PREFIX_B + ':' + IPS['SUD-lan1']],
    "sces": [IPS['[SCES]-lo'] ],
    "sces-eth0": [PREFIX_A + ':' + IPS['SCES-eth0'], PREFIX_B + ':' + IPS['SCES-eth0']],
    "sces-lan0": [PREFIX_A + ':' + IPS['SCES-lan0'], PREFIX_B + ':' + IPS['SCES-lan0']],
    "sces-lan1": [PREFIX_A + ':' + IPS['SCES-lan1'], PREFIX_B + ':' + IPS['SCES-lan1']],
    "barb": [IPS['[BARB]-lo'] ],
    "barb-eth0": [PREFIX_A + ':' + IPS['BARB-eth0'], PREFIX_B + ':' + IPS['BARB-eth0']],
    "barb-lan0": [PREFIX_A + ':' + IPS['BARB-lan0'], PREFIX_B + ':' + IPS['BARB-lan0']],
    "barb-lan1": [PREFIX_A + ':' + IPS['BARB-lan1'], PREFIX_B + ':' + IPS['BARB-lan1']],
    "admi": [IPS['[ADMI]-lo'] ],
    "admi-eth0": [PREFIX_A + ':' + IPS['ADMI-eth0'], PREFIX_B + ':' + IPS['ADMI-eth0']],
    "admi-lan0": [PREFIX_A + ':' + IPS['ADMI-lan0'], PREFIX_B + ':' + IPS['ADMI-lan0']],
    "admi-lan1": [PREFIX_A + ':' + IPS['ADMI-lan1'], PREFIX_B + ':' + IPS['ADMI-lan1']],
    "ingi": [IPS['[INGI]-lo'] ],
    "ingi-eth0": [PREFIX_A + ':' + IPS['INGI-eth0'], PREFIX_B + ':' + IPS['INGI-eth0']],
    "ingi-lan0": [PREFIX_A + ':' + IPS['INGI-lan0'], PREFIX_B + ':' + IPS['INGI-lan0']],
    "ingi-lan1": [PREFIX_A + ':' + IPS['INGI-lan1'], PREFIX_B + ':' + IPS['INGI-lan1']],
    "ingi-lan2": [PREFIX_A + ':' + IPS['INGI-lan2'], PREFIX_B + ':' + IPS['INGI-lan2']],
    "bflt": [IPS['[BFLT]-lo'] ],
    "bflt-eth0": [PREFIX_A + ':' + IPS['BFLT-eth0'], PREFIX_B + ':' + IPS['BFLT-eth0']],
    "bflt-lan0": [PREFIX_A + ':' + IPS['BFLT-lan0'], PREFIX_B + ':' + IPS['BFLT-lan0']],
    "bflt-lan1": [PREFIX_A + ':' + IPS['BFLT-lan1'], PREFIX_B + ':' + IPS['BFLT-lan1']],
    "bflt-lan2": [PREFIX_A + ':' + IPS['BFLT-lan2'], PREFIX_B + ':' + IPS['BFLT-lan2']]
}
dns_aaaa_records = {
  "htt1": [
    "fd00:200:1:1420::3",
    "fd00:300:1:1420::3"
  ],
  "htt2": [
  "fd00:200:1:1420::4",
  "fd00:300:1:1420::4"
  ],
  "htt3": [
    "fd00:200:1:1420::5",
    "fd00:300:1:1420::5"
  ],
  "chien": [
    "fd00:200:1:1420::4",
    "fd00:300:1:1420::4",
    "fd00:200:1:1420::5",
    "fd00:300:1:1420::5",
    "fd00:200:1:1420::6",
    "fd00:300:1:1420::6"
  ],
 "website": [
     "fd00:200:1:1420::4",
     "fd00:300:1:1420::4",
     "fd00:200:1:1420::5",
     "fd00:300:1:1420::5",
     "fd00:200:1:1420::6",
     "fd00:300:1:1420::6"
 ],
  "ns1": [
    "%s:%s" % (PREFIX_A, IPS["DNS1-eth0"]),
    "%s:%s" % (PREFIX_B, IPS["DNS1-eth0"])
  ],
  "ns2": [
    "%s:%s" % (PREFIX_A, IPS["DNS2-eth0"]),
    "%s:%s" % (PREFIX_B, IPS["DNS2-eth0"])
  ],
   "ns": [
     "%s:%s" % (PREFIX_A, IPS["DNS1-eth0"]),
     "%s:%s" % (PREFIX_B, IPS["DNS1-eth0"]),
     "%s:%s" % (PREFIX_A, IPS["DNS2-eth0"]),
     "%s:%s" % (PREFIX_B, IPS["DNS2-eth0"])
  ],
  "grading": [
    "fd00:200:1:1420::4",
    "fd00:300:1:1420::4",
    "fd00:200:1:1420::5",
    "fd00:300:1:1420::5",
    "fd00:200:1:1420::6",
    "fd00:300:1:1420::6"
  ]
}

dns_cname_records = {
    "www.chien": "chien",
    "www.website": "website",
    "www.grading": "grading"
}


CORE_ROUTERS = ["MICH", "SH1C", "HALL", "PYTH", "STEV", "CARN"]
L3_SWITCHES = ["ADMI", "SUD", "SCES", "BARB", "INGI", "BFLT"]
ROUTERS = CORE_ROUTERS + L3_SWITCHES

CLASSICAL_USERS = [
"NTOP", "QHUN",
"SUS1", "SUS2", "SUS3", "SUS4", "SUS5", "SUS6",
"SCS1", "SCS2",
"BAS1", "BAS2",
"FAB", "OBO", "MATH", "OLIT",
"ALEX", "REMI", "FRA", "OLI", "ROB",
"BFS1", "BFS2",
"MENS", "PVR",
]

#Only Camera, Telephone and Printer
EQUIPMENTS = [
"ADC1", "ADC2", "ADT1",
"SCT1", "SCT2",
"BAT1", "BAT2",
"INC1", "INC2", "INP1", "INP2", "INT1", "INT2",
"BFT1", "BFT2"
]

STATIC_SERVICES = ["DHC1","DHC2","HTT1","HTT2","HTT3","QOS","QOS2", "QOS3", "DNS1", "DNS2"]

ALL_MACHINES = ROUTERS + CLASSICAL_USERS + EQUIPMENTS + STATIC_SERVICES

def get_interfaces(node):
    for interf, ip in IPS.items():
        if interf not in ("belneta", "belnetb"):
            base, end = interf.split("-")
            if base == node:
                yield interf
