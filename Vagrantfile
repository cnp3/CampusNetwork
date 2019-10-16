# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "debian/jessie64"
  config.vm.hostname = 'group-vm'
  config.vm.box_check_update = true

  config.ssh.insert_key = "true"
  config.ssh.forward_x11 = "true"
  config.vm.provision "shell", path: "./host/provision.sh"
  config.vm.provision :shell, path: "./host/nic.sh", run: 'always'

  config.vm.network "forwarded_port", guest: 22, host: 40001, id: "ssh"

  config.vm.network "private_network", ip: "fde4:1::12", netmask: 16, auto_config: false
  config.vm.network "private_network", ip: "fde4:1::13", netmask: 16, auto_config: false
  config.vm.network "private_network", ip: "fde4:1::14", netmask: 16, auto_config: false
  config.vm.network "private_network", ip: "fde4:1::15", netmask: 16, auto_config: false
  config.vm.network "private_network", ip: "fde4:1::16", netmask: 16, auto_config: false
  config.vm.network "private_network", ip: "fde4:1::17", netmask: 16, auto_config: false
  config.vm.network "private_network", ip: "fde4:1::18", netmask: 16, auto_config: false

  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--memory", 2048]
    v.customize ["modifyvm", :id, "--name", "group-vm"]
    v.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
    v.customize ["modifyvm", :id, "--nicpromisc3", "allow-all"]
    v.customize ["modifyvm", :id, "--nicpromisc4", "allow-all"]
    v.customize ["modifyvm", :id, "--nicpromisc5", "allow-all"]
    v.customize ["modifyvm", :id, "--nicpromisc6", "allow-all"]
    v.customize ["modifyvm", :id, "--nicpromisc7", "allow-all"]
    v.customize ["modifyvm", :id, "--nicpromisc8", "allow-all"]
  end
end
