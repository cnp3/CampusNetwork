PATH_SRC='/home/vagrant/lingi2142'

for i in MI1 MI2 HA1 HA2 HA3 HA4 PY1 PY2 ST1 ST2 SH1 SH2 CA1 CA2
do
 mkdir -p $PATH_SRC/project_cfg/$i/rdnssd
 cp -r $PATH_SRC/end_user_management/rdnssd/src/* $PATH_SRC/project_cfg/$i/rdnssd
done 

