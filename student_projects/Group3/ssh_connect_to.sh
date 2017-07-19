if (( $# < 1 )); then
    warn "This script takes one mandatory argument:"
    warn "The IPv6 address of the host you want to connect"
    exit 1
fi

ssh -i /etc/ssh_key/monitor $1
