#!/bin/sh
### BEGIN INIT INFO
# Provides:          lighttpd
# Required-Start:    $local_fs $remote_fs $network $syslog
# Required-Stop:     $local_fs $remote_fs $network $syslog
# Should-Start:      fam
# Should-Stop:       fam
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start the lighttpd web server.
# Description:       Fast and smalle webserver with minimal memory footprint
#                    developed with security in mind HTTP/1.1 compliant caching
#                    proxy server.
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=/usr/sbin/lighttpd
NAME=lighttpd
DESC="HTTP Server"
PIDFILE=/var/run/[[node]]_$NAME.pid
DAEMON_OPTS="-f /etc/lighttpd/lighttpd.conf" #Our custom config file

# ------------------ not modified ------------------------

test -x $DAEMON || exit 0

set -e

check_syntax()
{
	$DAEMON -t $DAEMON_OPTS > /dev/null || exit $?
}

if [ "$1" != status ]; then
	# be sure there is a /var/run/lighttpd, even with tmpfs
	# The directory is defined as volatile and may thus be non-existing
	# after a boot (DPM par9.3.2)
	mkdir -p /etc/htt
	if ! dpkg-statoverride --list /etc/htt >/dev/null 2>&1; then
		install -d -o www-data -g www-data -m 0750 "/etc/htt"
	fi
fi

. /lib/lsb/init-functions

case "$1" in
    start)
	check_syntax
        log_daemon_msg "Starting $DESC" $NAME
        if ! start-stop-daemon --start --oknodo --quiet \
             --make-pidfile --pidfile $PIDFILE --exec $DAEMON -- $DAEMON_OPTS
        then
            log_end_msg 1
        else
            log_end_msg 0
        fi
        ;;
    stop)
        log_daemon_msg "Stopping $DESC" $NAME
        if start-stop-daemon --stop --retry 30 --oknodo --quiet \
            --pidfile $PIDFILE --exec $DAEMON
        then
            rm -f $PIDFILE
            log_end_msg 0
        else
            log_end_msg 1
        fi
        ;;
    reload|force-reload)
	check_syntax
        log_daemon_msg "Reloading $DESC configuration" $NAME
        if start-stop-daemon --stop --signal INT --quiet \
            --pidfile $PIDFILE --exec $DAEMON \
            --retry=TERM/60/KILL/5
        then
            rm $PIDFILE
            if start-stop-daemon --start --quiet  \
                --pidfile $PIDFILE --exec $DAEMON -- $DAEMON_OPTS ; then
                log_end_msg 0
            else
                log_end_msg 1
            fi
        else
            log_end_msg 1
        fi
        ;;
    reopen-logs)
        log_daemon_msg "Reopening $DESC logs" $NAME
        if start-stop-daemon --stop --signal HUP --oknodo --quiet \
            --pidfile $PIDFILE --exec $DAEMON
        then
            log_end_msg 0
        else
            log_end_msg 1
        fi
        ;;
    restart)
	check_syntax
        $0 stop
        $0 start
        ;;
    status)
        status_of_proc -p "$PIDFILE" "$DAEMON" lighttpd && exit 0 || exit $?
        ;;
    *)
        echo "Usage: $SCRIPTNAME {start|stop|restart|reload|force-reload|status}" >&2
        #exit 1
        ;;
esac
