#!/bin/bash

# This script adjust the route used to redirect traffic from HALL to PYTH using a prefix 200.
# Check if the primary link is up, if it is not it switches the route to use backup link.
# It does the opposite when the backup link is used and the primary link becomes available.

LOG_FILE="/etc/log/backup_link_log"
exec &>> $LOG_FILE

USE_BACKUP_LINK=false

while true
do
  if [[ $(< /sys/class/net/HALL-eth1/operstate) = "up" ]] # primary interface is up
  then
    if [ "$USE_BACKUP_LINK" = true ] # interface was down => switch link and use primary link
    then
      echo "[WARN] Backup => Primary"
      ip -6 route del ::/0 via fd00:200:3:2::2 dev HALL-eth2 metric 1 table 10
      ip -6 route add ::/0 via fd00:200:3:1::2 dev HALL-eth1 metric 1 table 10
      USE_BACKUP_LINK=false
    fi
  else # interface is down
    if [ "$USE_BACKUP_LINK" = false ] # interface was up => switch link and use backup link
    then
      echo "[WARN] Primary => Backup"
      ip -6 route del ::/0 via fd00:200:3:1::2 dev HALL-eth1 metric 1 table 10
      ip -6 route add ::/0 via fd00:200:3:2::2 dev HALL-eth2 metric 1 table 10
      USE_BACKUP_LINK=true
    fi
  fi

  sleep 5
done

exit
