PATH_SRC='/home/vagrant/lingi2142/end_user_management'
sh $PATH_SRC/bind/deploy_bind_conf.sh
sh $PATH_SRC/dhclient/deploy_dhclient_conf.sh  
sh $PATH_SRC/dhcp/deploy_dhcp_conf.sh
sh $PATH_SRC/rdnssd/deploy_rdnssd_conf.sh
sh $PATH_SRC/radvd_update/deploy_radvd_update.sh


