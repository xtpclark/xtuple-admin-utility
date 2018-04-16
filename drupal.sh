#!/bin/bash

source common.sh

drupal_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local DRUPALMENU

  log "Opened drupal menu"

  while true ; do
    DRUPALMENU=$(whiptail --backtitle "xTuple Utility v$_REV" \
                          --menu "$( menu_title Drupal\ Menu )" 0 0 3 \
                          --cancel-button "Cancel" --ok-button "Select" \
                          "1" "Set up composer"         \
                          "2" "Set up crontab"          \
                          "3" "Return to main menu"     \
            3>&1 1>&2 2>&3)
    RET=$?

    if [ $RET -ne 0 ]; then
      break
    fi
    case "$NGM" in
      "1") get_composer_token ;;
      "2") drupal_crontab     ;;
      "3") break ;;
      *) msgbox "How did you get here? drupal_menu $DRUPALMENU" && break ;;
    esac
  done
}

get_composer_token() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  loadadmin_gitconfig

  if ! type "composer" > /dev/null 2>&1 ; then
    if whiptail --backtitle "$( window_title )" \
                --yesno "Composer not found. Do you want to install it?" 8 60 \
                --cancel-button "Exit" --ok-button "Select"  3>&1 1>&2 2>&3 ; then
      install_composer
      RET=$?
      if [ $RET -ne 0 ]; then
        return $RET
      fi
    else
      return
    fi
  fi

  composer config --global github-oauth.github.com ${GITHUB_TOKEN}

  AUTHKEYS+=$(composer config -g --list | grep '\[github-oauth.github.com\]' | cut -d ' ' -f2)
  COMPOSER_HOME=$(composer config -g --list | grep '\[home\]' | cut -d ' ' -f2)
}

drupal_crontab() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  local TMPFILE="${TMPDIR}/crontab.$$"
  local WEBROOT="${1:-/var/www}"
  local LOGDIR="${2:-/var/log/xtuple}"

  sudo mkdir -p ${LOGDIR}/cron
  if ! sed -e "s#WEBROOT#${WEBROOT}#g" -e "s#LOGDIR#${LOGDIR}#g" templates/druple.crontab > ${TMPFILE} ; then
    msgbox "Error configuring Drupal crontab. Could not create ${TMPFILE}."
    return 1
  fi
  if sudo crontab -l 2>/dev/null | grep --file ${TMPFILE} --quiet ; then
    log "Drupal crontab already contains $(cat ${TMPFILE})"
    return 0
  fi

  (sudo crontab -l 2>/dev/null; cat ${TMPFILE}) | sudo crontab -
}
