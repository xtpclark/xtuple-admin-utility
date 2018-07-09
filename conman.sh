#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$CONMAN_SH" ] ; then # {
CONMAN_SH=true

WORKDIR=$(pwd)

MYIPADDR=`arp $(hostname) | awk -F'[()]' '{print $2}'`

connectSSH() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

ssh $CONNECTION
RET=$?
if [ $RET -ne 0 ]; then
msgbox "Error Connecting to $CONNECTION"
fi

# selectServer

}

setEC2Data()
{
REMOTEEC2DATA=`ssh $CONNECTION ec2metadata`
}

setPGInfo()
{
setEC2Data
REMOTEIPV4=`ssh $CONNECTION ec2metadata --public-ipv4`
REMOTEPGINFO=`ssh $CONNECTION pg_lsclusters -h | head -1`
REMOTEPGVER=$(echo $REMOTEPGINFO | cut -d' ' -f1)
REMOTEPGCLUSTER=$(echo $REMOTEPGINFO | cut -d' ' -f2)
REMOTEPGPORT=$(echo $REMOTEPGINFO | cut -d' ' -f3)
REMOTEPGSTATE=$(echo $REMOTEPGINFO | cut -d' ' -f4)
REMOTEPGOWNER=$(echo $REMOTEPGINFO | cut -d' ' -f5)
REMOTEPGDATA=$(echo $REMOTEPGINFO | cut -d' ' -f6)
REMOTEPGLOG=$(echo $REMOTEPGINFO | cut -d' ' -f7)
REMOTEPGHOME=/etc/postgresql/${REMOTEPGVER}/${REMOTEPGCLUSTER}
REMOTEPGHBA=${REMOTEPGHOME}/pg_hba.conf
REMOTEPGCONF=${REMOTEPGHOME}/postgresql.conf
}

readHbaConf()
{
setPGInfo
PGHBAINFO=`ssh ${CONNECTION} "sudo cat ${REMOTEPGHBA}"`
msgbox "${PGHBAINFO}"

}

getEC2Info()
{
setEC2Data
msgbox "$REMOTEEC2DATA"
}

getDiskInfo()
{
DISKSTAT=`ssh $CONNECTION df -h`
msgbox "${DISKSTAT}"
}

createPGTunnel()
{
setPGInfo
RANDPORT=`shuf -i 5500-65000 -n 1`
SOCKETNAME=${CONNECTION}_ctrl-socket
ssh -M -S ${SOCKETNAME} -fnNT -L${RANDPORT}:localhost:$REMOTEPGPORT $CONNECTION
sleep 5
}



killPGTunnel()
{
ssh -S ${SOCKETNAME} -O exit $CONNECTION
}

createTunnel()
{
createPGTunnel
msgbox "Tunnel to $CONNECTION Created on ${RANDPORT} \n
Socket: ${WORKDIR}/${SOCKETNAME}\n

Kill the socket manually with: \n
ssh -S ${SOCKETNAME} -O exit ${CONNECTION} \n
You can close this message box."

cat << EOF >> cleansockets.sh
ssh -S ${SOCKETNAME} -O exit ${CONNECTION}
EOF

}

getPGInfo()
{

createPGTunnel

PGCONN="psql -At -U postgres -h localhost -p ${RANDPORT}"

msgbox "Created PG Tunnel to ${CONNECTION} on Port ${RANDPORT}"


NUMPGUSERS=`$PGCONN postgres -c "SELECT count(*) FROM pg_stat_activity;"`

TUNDATABASES=`$PGCONN postgres -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres','template1','template0') ORDER BY 1 LIMIT 10;"`

for TUNDATABASE in $TUNDATABASES; do
DBVERS+=`$PGCONN -d $TUNDATABASE -c "SELECT ' ${TUNDATABASE}: Ap: '||fetchmetrictext('Application')||' v'||fetchmetrictext('ServerVersion');"`
done

TUNPGTEST=`$PGCONN postgres -c "SELECT now();"`
RET=$?
if [ $RET -ne 0 ]; then
msgbox "Error connecting to PostgreSQL on $CONNECTION"
else
msgbox "While this window is SHOWING,\nYou can connect with: \n
Server: localhost (or ${MYIPADDR}) \n
Port: ${RANDPORT}  \n
User: admin \n
Password: None \n
Databases: \n
${TUNDATABASES}\n
Versions:\n
${DBVERS}\n

Other Info:\n
${REMOTEPGINFO}\n
User Count: ${NUMPGUSERS}\n

Remote Connection Info: \n
Server: $REMOTEIPV4 Port: $REMOTEPGPORT User: admin Pass: None"

fi

killPGTunnel
msgbox "Killed Tunnel to ${CONNECTION}"

}


getClusterInfo()
{
VAL=`ssh $CONNECTION psql -U postgres -l`
RET=$?
if [ $RET -ne 0 ]; then
msgbox "Error Connecting to $CONNECTION"
else
msgbox "PGInfo For $CONNECTION \n $VAL"
fi

}



conman_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  while true; do
    [ -n "$CONNECTION" ] || CONNECTION="?"
    DBM=$(whiptail --backtitle "$(window_title)" --title "xTuple Utility v$_REV" \
                   --menu "$(menu_title Actions on $CONNECTION)" 0 0 10 --cancel-button "Cancel" --ok-button "Select" \
          "1" "Select a server" \
          "2" "Connect SSH to $CONNECTION" \
          "3" "Inspect and connect to PG on $CONNECTION" \
          "4" "Create tunnel to $CONNECTION" \
          "5" "View pg_hba.conf on $CONNECTION" \
          "6" "View disk info on $CONNECTION" \
          "7" "View EC2 info for $CONNECTION" \
         "10" "Return to main menu" \
          3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET -ne 0 ]; then
      break
    else
      case "$DBM" in
        "1") selectServer ;;
        "2") connectSSH   ;;
        "3") getPGInfo    ;;
        "4") createTunnel ;;
        "5") readHbaConf  ;;
        "6") getDiskInfo  ;;
        "7") getEC2Info   ;;
       "10") break        ;;
          *) msgbox "How did you get here?" && break ;;
      esac
    fi
  done
}


selectServer()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  local CONNECTIONS=()

  while read -r line; do
    CONNECTIONS+=("$line" "$line")
  done < <(grep  '^Host ' ~/.ssh/config | grep -v '[?*]' | cut -d ' ' -f 2- | sort)

  CONNECTION=$(whiptail --backtitle "$(window_title)" --title "xTuple Utility v$_REV" \
                        --menu "XTN Servers from ${HOME}/.ssh/config\nSelect a server to connect to" 0 0 10 \
                        "${CONNECTIONS[@]}" --notags 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return 0
  fi
}

fi # }
