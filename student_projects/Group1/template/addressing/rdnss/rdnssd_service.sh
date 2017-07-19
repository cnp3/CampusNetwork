#! /bin/sh
# $Id: rdnssd.init 254 2011-02-20 09:02:15Z remi $
#
# rdnssd start/stop script for Debian GNU/Linux
# Author: Rémi Denis-Courmont
#
### BEGIN INIT INFO
# Provides:          rdnssd
# Required-Start:    $local_fs
# Required-Stop:     $local_fs
# X-Start-Before:    networking
# Short-Description: IPv6 Recursive DNS Server discovery
# Description:       RDNSS daemon for autoconfiguration of IPv6 DNS
#                    resvolers.
# Default-Start:     S
# Default-Stop:      0 1 6
### END INIT INFO


PATH=/sbin:/bin
DESC="IPv6 Recursive DNS Server discovery Daemon"
NAME=rdnssd_[[node]]
DAEMON=/sbin/rdnssd
PIDFILE=/var/run/$NAME_[[node]].pid
SCRIPTNAME=/etc/rdnssd/$NAME_service.sh
OPTIONS="-u rdnssd"

[ -x "$DAEMON" ] || exit 0

# Source defaults.
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

if [ -n "$MERGE_HOOK" ]; then
	OPTIONS="$OPTIONS -H $MERGE_HOOK"
fi

. /lib/lsb/init-functions

check_run_dir() {
	if [ ! -d "/var/run/$NAME" ]; then
		mkdir -p "/var/run/$NAME"
		chown rdnssd:nogroup "/var/run/$NAME"
		chmod 0755 "/var/run/$NAME"
	fi
}

case "$1" in
  "")
	check_run_dir
	log_daemon_msg "Starting $DESC" "$NAME"
	/sbin/rdnssd -p /var/run/rdnssd_[[node]].pid -H /etc/rdnssd/merge-hook -u rdnssd
	log_end_msg $?
	;;
  start)
	check_run_dir
	log_daemon_msg "Starting $DESC" "$NAME"
	/sbin/rdnssd -p /var/run/rdnssd_[[node]].pid -H /etc/rdnssd/merge-hook -u rdnssd
	log_end_msg $?
	;;
  stop)
	log_daemon_msg "Stopping $DESC" "$NAME"
	start-stop-daemon --stop --quiet --pidfile "$PIDFILE" \
		--retry 1 --oknodo
	log_end_msg $?
	;;
  restart|force-reload)
	$0 stop
	sleep 1
	$0 start
	;;
  *)
	echo "Usage: $SCRIPTNAME {start|stop|restart|force-reload}" >&2
	exit 1
	;;
esac

exit $?

