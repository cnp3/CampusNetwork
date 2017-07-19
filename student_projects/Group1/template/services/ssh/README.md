LINGI2142 - Olivier MARTIN

sshd should be running on node HTT1, HTT2, HTT3 and all CORE_ROUTERS.
To connect to one of this node with ssh, do for exemple (for HALL):

    ssh vagrant@hall.group1.ingi -i template/services/ssh/keys/hall_id_rsa
    
Or for HTT2:
    
    ssh vagrant@htt2.group1.ingi -i template/services/ssh/keys/htt2_id_rsa

The -i argument permit to choose where is the private key 
The password is (all letters in lowercase): 'oli' + node_name
For example, for HALL, the password is: olihall
For example, for HTT2, the password is: olihtt2

Files in this folder:
  +---------+
  | banners |
  +---------+
This contains all banners displayed to users in function of the node when they try to connect with ssh.
These banners are generated automatically when network is build.

  +------+
  | keys |
  +------+
All pairs of public/private key for all nodes. This is use to allow ssh authentication.
/!\ Keys were generated once manually. If you want to enable SSH on a new node, add a pair of public/private key in this folder.
Please follow the convention name: [[node]]_id_rsa.pub and [[node]]_id_rsa

  +----------+
  | start.sh |
  +----------+
Start custom sshd server. We did not modified any config files for configuation of sshd. We override config what we want with arguments in command line.
Arguments in use:
    -D
        When this option is specified, sshd will not detach and does not become a daemon.
    -6
        Forces sshd to use IPv6 addresses only.
    -o PermitRootLogin=no 
        Disable the root login with ssh.
    -o PasswordAuthentication=no 
        Disable the password authentication with ssh.
    -o AuthorizedKeysFile="/home/vagrant/.ssh/[[node]]_authorized_keys" 
        Path to the authorized_keys file. We used the full path because, in root mode (when connected to a node), ~/.ssh/ is not found.
    -o Banner="/home/vagrant/LINGI2142-setup/template/ssh/banners/[[node]].txt"
        Path to the displayed banner
    -o AllowUsers="vagrant"
        Users allowed to connect with ssh. (Here only vagrant user)
