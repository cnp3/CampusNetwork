#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mkdir -p "$DIR"/../ssh_keys/
rm -f "$DIR"/../ssh_keys/*

for SERVER_DIR in $(ls -d $DIR/../project_cfg/*/)
do
    SERVER=`basename $SERVER_DIR`

    # Server configuration
    mkdir -p "$SERVER_DIR/ssh/"
    chmod 700 "$SERVER_DIR/ssh"
    cp "$DIR/sshd_config" "$SERVER_DIR/ssh/"
    echo "PidFile /var/run/sshd-$SERVER.pid" >> "$SERVER_DIR/ssh/sshd_config"

    # Generating the server keys
    rm -f "$SERVER_DIR"/ssh/ssh_host_*

    ssh-keygen -f "$SERVER_DIR/ssh/ssh_host_rsa_key" -N '' -t rsa -q
    ssh-keygen -f "$SERVER_DIR/ssh/ssh_host_dsa_key" -N '' -t dsa -q

    # Generating the client keys and installing them into the server
    CLIENT_KEY="$DIR/../ssh_keys/$SERVER"
    ssh-keygen -f $CLIENT_KEY -N "" -q
    cat "$CLIENT_KEY.pub" > "$SERVER_DIR/ssh/authorized_keys"
    chmod 600 "$SERVER_DIR"/ssh/*

    echo "$SERVER configured and keys generated."
done

ln -f -s "$DIR/../ssh_keys/" "$DIR/../project_cfg/MON1/"
ln -f -s "$DIR/../ssh_keys/" "$DIR/../project_cfg/MON2/"
