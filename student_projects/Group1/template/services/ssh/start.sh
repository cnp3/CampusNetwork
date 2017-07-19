#########################################################
#	               	Launch SSH server           		#
#########################################################

#Generate banner
echo '\n*******************\n* Welcome on [[node]] *\n*******************\n' > /home/vagrant/LINGI2142-setup/template/services/ssh/banners/[[node]].txt

#Add public key in authorized_keys
cat /home/vagrant/LINGI2142-setup/template/services/ssh/keys/[[node]]_id_rsa.pub > /home/vagrant/.ssh/[[node]]_authorized_keys

#Start server
/usr/sbin/sshd -D -6 -o PermitRootLogin=no -o PasswordAuthentication=no -o AuthorizedKeysFile="/home/vagrant/.ssh/[[node]]_authorized_keys" -o Banner="/home/vagrant/LINGI2142-setup/template/services/ssh/banners/[[node]].txt" -o AllowUsers="vagrant" &
