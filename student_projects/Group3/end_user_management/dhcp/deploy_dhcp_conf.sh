PATH_SRC='/home/vagrant/lingi2142'
for i in DHCP1 DHCP2
do 
 mkdir -p $PATH_SRC/project_cfg/$i/dhcp/
 cp $PATH_SRC/end_user_management/dhcp/src/* $PATH_SRC/project_cfg/$i/dhcp/
done

