#! /bin/sh
### BEGIN INIT INFO
# Provides:          ntop
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Should-Start:      $network
# Should-Stop:       $network
# Short-Description: Start ntop daemon
# Description:       Enable services provided by ntop
### END INIT INFO

DAEMON="/usr/sbin/ntop"
NAME="ntop"
DESC="network top daemon"
INIT="/etc/default/$NAME"

#DEBCONFINIT="/var/lib/ntop/init.cfg"
#HOMEDIR="/var/lib/ntop"
#LOGDIR="/var/log/ntop"

DEBCONFINIT="/etc/ntop/ntop_config/init.cfg"
HOMEDIR="/etc/ntop/ntop_config"
LOGDIR="/etc/ntop/ntop_config"

SCRIPTNAME="/etc/ntop/service.sh"

# Workaround for a rrd problem, see #471862.
export LANG=C
# end of workaround

test -f $DAEMON || exit 0

. /lib/lsb/init-functions

test -f $INIT || exit 0

. $INIT

test -f $DEBCONFINIT || exit 0

. $DEBCONFINIT

[ "$ENABLED" = "0" -o "$ENABLED" = "no" -o "$ENABLED" = "n" ] && exit 0

sanity_check() {
# Sanity check, we expect USER And INTERFACES to be defined
# (we could also set defaults for them before calling INIT...)
	if [ -z "$USER" ] ; then
		log_failure_msg "$NAME: USER is not defined, please run 'dpkg-reconfigure ntop'" >&2
		return 1
	fi
	if [ -z "$INTERFACES" ] ; then
		log_failure_msg "$NAME: INTERFACES is not defined, please run 'dpkg-reconfigure ntop'" >&2
		return 1
	fi
	return 0
}

check_log_dir() {
# Does the logging directory belong to the User running the application
        # If we cannot determine the logdir return without error
        # (we will not check it)
        [ -n "$LOGDIR" ] || return 0
        [ -n "$USER" ] || return 0
        if [ ! -e "$LOGDIR" ] ; then
                log_failure_msg "$NAME: logging directory $LOGDIR does not exist"
                return 1
        elif [ ! -d "$LOGDIR" ] ; then
                log_failure_msg "$NAME: logging directory $LOGDIR does not exist"
                return 1
        else
                real_log_user=`stat -c %U $LOGDIR`
        # An alternative way is to check if the the user can create
        # a file there...
                if [ "$real_log_user" != "$USER" ] ; then
                        log_failure_msg "$NAME: logging directory $LOGDIR does not belong to the user $USER"
                        return 1
                fi
        fi
        return 0
}

check_interfaces() {
# Check the interface status, abort with error if a configured one is not
# available
	[ -z "$INTERFACES" ] && return 0
	for iface in $(echo $INTERFACES | awk -F , '{ for(i=1;i<=NF;i++) print $i }')
	do
		if [ "$iface" != "none" ] && ! netstat -i | grep "^$iface " >/dev/null; then
			log_warning_msg "$NAME: interface $iface is down"
		fi
	done
	return 0
}

##
# From OLI: I add that:
# --make-pidfile --pidfile "/etc/ntop/ntop_config/ntop.pid"
# -6
##
ntop_start() {
  retval=$(
    {
      { /sbin/start-stop-daemon --start --quiet --make-pidfile --pidfile "/etc/ntop/ntop_config/ntop.pid" --name $NAME --exec $DAEMON -- \
	  -d -L -6 -u $USER -P $HOMEDIR \
	  --access-log-file=$LOGDIR/access.log -i "$INTERFACES" \
	  -p /etc/ntop/protocol.list \
	  -O $LOGDIR $GETOPT 2>&1; echo -n $? >&2 ;
      } | logger -p daemon.info -t ntop;
    } 2>&1 )
  if [ "$retval" -eq 1 ]; then
    log_progress_msg "already running"
    return 0
  fi
  if pidof $DAEMON > /dev/null ; then
    return 0
  else
  # WARNING: This might introduce a race condition in some (fast) systems
  # Wait for a sec an try again
    sleep 1
    if pidof $DAEMON > /dev/null ; then
      return 0
    else
      return 1
    fi
  fi
}

ntop_stop() {
  /sbin/start-stop-daemon --stop --quiet --oknodo --name $NAME --user $USER --retry 9
  if pidof $DAEMON > /dev/null ; then
  # WARNING: This might introduce a race condition in some (fast) systems
  # Wait for a sec an try again
    sleep 1
    if pidof $DAEMON > /dev/null ; then
      return 1
    else
      return 0
    fi
  else
    return 0
  fi
}

case "$1" in
start)
  if ! sanity_check || ! check_log_dir || ! check_interfaces; then
    exit 1
  fi
  log_daemon_msg "Starting $DESC" "$NAME"
  if ntop_start; then
    log_end_msg 0
  else
    log_end_msg 1
  fi
  ;;
stop)
  log_daemon_msg "Stopping $DESC" "$NAME"
  if ntop_stop; then
    log_end_msg 0
  else
    log_end_msg 1
  fi
  ;;
restart | force-reload)
  if ! sanity_check || ! check_log_dir || ! check_interfaces; then
    exit 1
  fi
  log_daemon_msg "Restarting $DESC" "$NAME"
  if ntop_stop && ntop_start; then
    log_end_msg 0
  else
    log_end_msg 1
  fi
  ;;
reload | try-restart)
  log_action_msg "Usage: $SCRIPTNAME {start|stop|restart|force-reload|status}"
  exit 3
  ;;
status)
  status_of_proc $DAEMON $NAME
  ;;
*)
  log_action_msg "Usage: $SCRIPTNAME {start|stop|restart|force-reload|status}"
  exit 1
  ;;
esac
exit 0
