!
! OSPF configuration for ${data['name']}
!
hostname ${data['hostname']}
password ${data['passwd']}
log stdout
service advanced-vty
!
debug ospf6 neighbor state
!
%for interface in data['interfaces']:
interface ${interface['name']}
    ipv6 ospf6 cost ${interface['cost']}
    %if interface['active']:
    ipv6 ospf6 hello-interval ${interface['hello_time']}
    ipv6 ospf6 dead-interval ${interface['dead_time']}
    %else:
    ipv6 ospf6 passive
    %endif
    ipv6 ospf6 instance-id ${interface['instance_id']}
!
%endfor
router ospf6
    router-id ${data['router_id']}
    %for nic in data['interfaces']:
    interface ${nic['name']} area ${nic['area']}
    %endfor
!
