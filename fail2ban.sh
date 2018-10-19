#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$FAIL2BAN_SH" ] ; then # {
FAIL2BAN_SH=true

fail2ban_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  log "Opened fail2ban menu"

  while true; do
    NGM=$(whiptail --backtitle "$(window_title)" --title "xTuple Utility v$_REV" \
                   --menu "$(menu_title fail2ban Menu)" 0 0 10 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Install fail2ban" \
            "2" "Configure fail2ban [default settings only]" \
            "3" "Remove fail2ban" \
            "4" "Return to main menu" \
            3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET -ne 0 ]; then
      break
    else
      case "$NGM" in
        "1") install_fail2ban
             ;;
        "2") configure_fail2ban
             ;;
        "3") remove_fail2ban
             ;;
        "4") break ;;
        *) msgbox "How did you get here? fail2ban_menu $NGM" && break ;;
      esac
    fi
  done
}

install_fail2ban() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Installing fail2ban"

  # cluster $POSTNAME using version $PGVER

  local OUTPUT="$(log_exec sudo apt-get --quiet --yes install fail2ban)"
  RET=$?
  if [ $RET -ne 0 ] ; then
    msgbox "fail2ban failed to install:\n$OUTPUT"
    return $RET
  fi
}

configure_fail2ban() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  F2B=`pgrep -f fail2ban`
  if [ -z $F2B ]; then
    install_fail2ban
  fi

  if [ -z "$PGPORT" ] && [ "$MODE" = "manual" ]; then
    PGPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter the PostgreSQL database post number" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$PGPORT" ]; then
    return 127
  fi

  sudo cat > /etc/fail2ban/filter.d/postgresql.conf <<EOF
[Definition]

failregex = <HOST> FATAL:  password authentication failed for user .+$
            <HOST> FATAL:  no pg_hba.conf entry for host .+$
            <HOST> FATAL:  pg_hba.conf rejects connection for host .+$
            <HOST> FATAL:  unsupported frontend protocol .+$
ignoreregex = : Successful su for (postgres) by root$
              New session \d+ of user (postgres)\.$
              Removed session \d+\.$
EOF

POSTFIX=""
  if type "postfix" > /dev/null 2>&1 ; then
read -d '' POSTFIX <<EOF
[postfix]
enabled = true
mode    = more
port    = smtp,465,submission
logpath = %(postfix_log)s
backend = %(postfix_backend)s
EOF
  fi

NGINX=""
  if type "nginx" > /dev/null 2>&1 ; then
read -d '' NGINX <<EOF
[nginx-http-auth]
enabled = true
port    = http,https
logpath = %(nginx_error_log)s
EOF
  fi

  sudo cat > /etc/fail2ban/jail.d/xtuple.conf <<EOF
[DEFAULT]
bantime = 5m
findtime = 5m
maxretry = 3

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

$NGINX

$POSTFIX

[postgresql-iptables]
enabled  = true
filter   = postgresql
action   = iptables[name=postgresql-iptables, port=$PGPORT, protocol=udp]
           sendmail-whois[name=Postgresql, dest=dest=cloudops@xtuple.com]
logpath  = /var/log/postgresql/*.log
EOF

  log "Reloading fail2ban configuration"
  service_reload fail2ban
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Reloading fail2ban configuration failed"
    return $RET
  fi
  msgbox "fail2ban installed and configured successfully."
}

remove_fail2ban() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if (whiptail --title "Are you sure?" --yesno "Uninstall fail2ban?" --yes-button "Yes" --no-button "No" 10 60) then
    log "Uninstalling fail2ban..."
    log_exec sudo apt-get --quiet -y remove fail2ban
    RET=$?
    return $RET
  fi
  return 0
}

fi # }
