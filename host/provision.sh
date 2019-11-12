sed -i '/#PasswordAuthentication yes/c\PasswordAuthentication no' /etc/ssh/sshd_config
systemctl restart sshd

apt update
DEBIAN_FRONTEND=noninteractive apt upgrade -y
DEBIAN_FRONTEND=noninteractive apt install -y git autoconf automake libtool make \
    libreadline-dev texinfo libjson-c-dev pkg-config bison flex \
    libc-ares-dev python3-dev python3-pytest python3-sphinx build-essential \
    libsnmp-dev libsystemd-dev libcap-dev libyang-dev cmake libssh-dev \
    sqlite3 libsqlite3-dev libczmq-dev libzmq3-dev python3-zmq

addgroup --system --gid 92 frr
addgroup --system --gid 85 frrvty
adduser  --system --ingroup frr --home /var/opt/frr --gecos "FRR Suite" --shell /bin/false frr

cd /tmp && git clone https://github.com/traviscross/mtr.git && cd mtr && ./bootstrap.sh \
	&& ./configure --prefix=/usr && make && sudo make install && cd

git clone --depth 1 --single-branch --branch v0.7.0 https://github.com/rtrlib/rtrlib.git /tmp/rtrlib
cd /tmp/rtrlib && mkdir build && cd build && \
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr .. && make && make install

git clone --depth 1 --single-branch --branch stable/7.2 https://github.com/FRRouting/frr.git /opt/frr
cd /opt/frr || exit
./bootstrap.sh
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
  --enable-sharpd \
  --enable-config-rollbacks \
  --with-moduledir=/usr/lib/frr/modules \
  --with-libyang-pluginsdir=/usr/lib/frr/libyang_plugins \
  --with-pkg-extra-version=-lingi2142 \
  --enable-systemd=yes \
  --enable-rpki \
  --enable-zeromq && \
  make && make check && make install

install -m 755 -o frr -g frr -d /var/log/frr
install -m 755 -o frr -g frr -d /var/opt/frr
install -m 775 -o frr -g frrvty -d /etc/frr
install -m 640 -o frr -g frr /dev/null /etc/frr/zebra.conf
install -m 640 -o frr -g frr /dev/null /etc/frr/bgpd.conf
install -m 640 -o frr -g frr /dev/null /etc/frr/ospfd.conf
install -m 640 -o frr -g frr /dev/null /etc/frr/ospf6d.conf
install -m 640 -o frr -g frr /dev/null /etc/frr/isisd.conf
install -m 640 -o frr -g frr /dev/null /etc/frr/ripd.conf
install -m 640 -o frr -g frr /dev/null /etc/frr/ripngd.conf
install -m 640 -o frr -g frr /dev/null /etc/frr/pimd.conf
install -m 640 -o frr -g frr /dev/null /etc/frr/ldpd.conf
install -m 640 -o frr -g frr /dev/null /etc/frr/nhrpd.conf
install -m 640 -o frr -g frrvty tools/etc/frr/vtysh.conf /etc/frr/vtysh.conf
install -m 640 -o frr -g frr tools/etc/frr/daemons.conf /etc/frr/daemons.conf
install -m 640 -o frr -g frr tools/etc/frr/daemons /etc/frr/daemons
install -m 644 tools/frr.service /etc/systemd/system/frr.service
rm -rf /opt/frr