# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
%for group in vm_config:

    config.vm.define "${group['name']}" do |${group['name']}|
        ${group['name']}.vm.box = "debian/jessie64"
        ${group['name']}.vm.hostname = '${group['name']}'
        ${group['name']}.vm.box_check_update = true
        
        ${group['name']}.ssh.insert_key = "true"
        ${group['name']}.ssh.forward_x11 = "true"
        ${group['name']}.vm.provision "shell", path: "provision.sh"
        ${group['name']}.vm.provision :shell, path: "nic.sh", run: 'always'

        ${group['name']}.vm.network "forwarded_port", guest: 22, host: ${group['ssh_fwd']}, id: "ssh"

        %for nic in group['nic']:
        ${group['name']}.vm.network "private_network", ip: "${nic['ip']}", netmask: ${nic['mask']}, auto_config: false
        %endfor

        ${group['name']}.vm.provider :virtualbox do |v|
            v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
            v.customize ["modifyvm", :id, "--memory", ${group['memory']}]
            v.customize ["modifyvm", :id, "--name", ${group['name']}]
        %for nic in group['nic']:
            v.customize ["modifyvm", :id, "--nicpromisc${nic['id']}", "${nic['promiscuous']}"]
        %endfor
        end
    end
%endfor
end
