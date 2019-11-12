# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
%for group in vm_config:

    config.vm.define "${group['name']}" do |${group['name']}|
        ${group['name']}.vm.box = "${group['box']}"
        ${group['name']}.vm.hostname = '${group['name']}'
        ${group['name']}.vm.box_check_update = true
        
        ${group['name']}.ssh.insert_key = "true"
        ${group['name']}.ssh.forward_x11 = "true"
        ${group['name']}.vm.provision "shell", path: "provision.sh"

        ${group['name']}.vm.network "forwarded_port", guest: 22, host: ${group['ssh_fwd']}, id: "ssh"

        config.vm.provision :shell, run: 'always' , inline: <<-SHELL
         sysctl -w net.ipv6.conf.all.forwarding=1
         sysctl -w net.ipv4.ip_forward=1
        SHELL

        %for nic in group['nic']:
        ${group['name']}.vm.network "private_network", ip: "${nic['ip']}", netmask: "${nic['mask']}", auto_config: false
        %endfor

        ${group['name']}.vm.provider :virtualbox do |v|
            v.gui = false
            v.memory = ${group['memory']}
            v.name = "${group['name']}"
            v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        %for nic in group['nic']:
            %if nic['promiscuous']:
            v.customize ["modifyvm", :id, "--nicpromisc${nic['id']}", "${nic['promisc_type']}"]
            %endif
        %endfor
        end
    end
%endfor
end
