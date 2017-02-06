# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "debian/jessie64"

  # We need 2 extra interfaces besides the one from
  config.vm.network "private_network", ip: "fd00:200::255"
  config.vm.network "private_network", ip: "fd00:300::255"

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
  end

  config.ssh.insert_key = "true"
  config.ssh.forward_x11 = "true"

  config.vm.provision "shell", inline: <<-EOD
    apt-get -y -qq --force-yes update
    apt-get -y -qq --force-yes install git bash vim-nox tcpdump nano\
                                              bird6 quagga inotify-tools

    update-rc.d quagga disable &> /dev/null || true
    update-rc.d bird disable &> /dev/null || true
    update-rc.d bird6 disable &> /dev/null || true

    (cd /sbin && ln -s /usr/lib/quagga/* .)

    su vagrant -c 'cd & git clone https://github.com/oliviertilmans/LINGI2142-setup.git'
  EOD
end
