#! /bin/bash

apt-get -y -qq --force-yes update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq --force-yes
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -qq --force-yes

DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --force-yes \
  git bash vim htop tcpdump nano curl wget apt-transport-https ca-certificates \
  bird6 inotify-tools iperf binutils binfmt-support software-properties-common \
  python-pexpect python3-pexpect python-pexpect-doc netcat-openbsd \
  python-mako python3-mako

### build update and install FRRouting suite (official deb repo don't seem to work...)
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --force-yes \
  git autoconf automake libtool make \
  libreadline-dev texinfo libjson-c-dev pkg-config bison flex python3-pip \
  libc-ares-dev python3-dev python3-sphinx build-essential libsystemd-dev \
  libsnmp-dev libcap-dev python3-pytest python-pytest libpcre++-dev \
  libpcre++0 libpcre3 libpcre3-dev cmake

cd /tmp && git clone https://github.com/traviscross/mtr.git && cd mtr && ./bootstrap.sh \
	&& ./configure && make && sudo make install && cd

wget https://github.com/CESNET/libyang/archive/debian/libyang-0.16.105-1.tar.gz -O - \
    | tar -C /opt -xz && \
    cd /opt/libyang-debian-libyang-0.16.105-1 && mkdir build && cd build && \
    cmake -DENABLE_LYD_PRIV=ON -DCMAKE_INSTALL_PREFIX:PATH=/usr \
      -D CMAKE_BUILD_TYPE:String="Release" -DENABLE_CACHE=OFF .. && \
    make && make install

addgroup --system --gid 92 frr
addgroup --system --gid 85 frrvty
adduser --system --ingroup frr --home /var/run/frr/ \
   --gecos "FRRouting suite" --shell /bin/false frr
usermod -a -G frrvty frr

git clone --depth 1 --single-branch --branch stable/7.2 https://github.com/FRRouting/frr.git /opt/frr
cd /opt/frr || exit

./bootstrap.sh && \
./configure \
    --enable-exampledir=/usr/share/doc/frr/examples/ \
    --localstatedir=/var/run/frr \
    --sbindir=/usr/lib/frr \
    --sysconfdir=/etc/frr \
    --enable-multipath=64 \
    --enable-user=frr \
    --enable-group=frr \
    --enable-vty-group=frrvty \
    --enable-configfile-mask=0640 \
    --enable-logfile-mask=0640 \
    --enable-snmp=agentx \
    --enable-fpm \
    --with-moduledir=/usr/lib/frr/modules \
    --with-libyang-pluginsdir=/usr/lib/frr/libyang_plugins \
    --with-pkg-git-version \
    --with-pkg-extra-version=-lingi2142 \
    --enable-systemd=yes && \
make && make check && make install

install -m 775 -o frr -g frr -d /var/log/frr
install -m 775 -o frr -g frrvty -d /etc/frr
install -m 640 -o frr -g frrvty tools/etc/frr/vtysh.conf /etc/frr/vtysh.conf
install -m 640 -o frr -g frr tools/etc/frr/frr.conf /etc/frr/frr.conf.sample
install -m 640 -o frr -g frr tools/etc/frr/daemons.conf /etc/frr/daemons.conf
install -m 640 -o frr -g frr tools/etc/frr/daemons /etc/frr/daemons

install -m 644 tools/frr.service /etc/systemd/system/frr.service

cd || exit

# Remove src and build files
rm -rf /opt/libyang-debian-libyang-0.16.105-1
rm -rf /opt/frr

### end FRRouting installation

# dependencies for puppet
apt-get -y -qq --force-yes install puppet

update-rc.d bird disable &> /dev/null || true
update-rc.d bird6 disable &> /dev/null || true

service bird stop
service bird6 stop

su vagrant -c 'cd && git clone https://github.com/cnp3/CampusNetwork.git && cd CampusNetwork && git checkout isp_net'
