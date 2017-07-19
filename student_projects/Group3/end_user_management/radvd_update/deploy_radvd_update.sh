PATH_SRC='/home/vagrant/lingi2142'
for i in MICH PYTH CARN STEV SH1C HALL
do 
 cp $PATH_SRC/end_user_management/radvd_update/src/* $PATH_SRC/project_cfg/$i/radvd/
 chmod +x $PATH_SRC/project_cfg/$i/radvd/update_radvd_conf.py
done
