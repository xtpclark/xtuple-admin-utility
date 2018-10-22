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

  cat ./templates/postgresql-fail2ban > /etc/fail2ban/filter.d/postgresql.conf

  if [ -z "$PGPORT" ] && [ "$MODE" = "manual" ]; then
    PGPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter the PostgreSQL database port number" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$PGPORT" ]; then
    return 127
  fi

export ZPGPORT=$PGPORT

export ZPOSTFIX=""
  if type "postfix" > /dev/null 2>&1 ; then
export ZPOSTFIX="[postfix]
enabled = true
mode    = more
port    = smtp,465,submission
logpath = %(postfix_log)s
backend = %(postfix_backend)s"
  fi

export ZNGINX=""
  if type "nginx" > /dev/null 2>&1 ; then
export ZNGINX="[nginx-http-auth]
enabled = true
port    = http,https
logpath = %(nginx_error_log)s"
  fi

  envsubst < ./templates/xtuple.jail > /etc/fail2ban/jail.d/xtuple.conf

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
