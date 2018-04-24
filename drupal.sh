#!/bin/bash

source common.sh

drupal_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local DRUPALMENU

  log "Opened drupal menu"

  while true ; do
    DRUPALMENU=$(whiptail --backtitle "xTuple Utility v$_REV" \
                          --menu "$( menu_title Drupal\ Menu )" 0 0 10 \
                          --cancel-button "Cancel" --ok-button "Select" \
                          "1" "Set up composer"         \
                          "2" "Set up crontab"          \
                          "3" "Set up deployment user"  \
                          "4" "Set up postfix"          \
                          "9" "Return to main menu"     \
            3>&1 1>&2 2>&3)
    RET=$?

    if [ $RET -ne 0 ]; then
      break
    fi
    case "$NGM" in
      "1") get_composer_token ;;
      "2") drupal_crontab     ;;
      "3") deployer_setup     ;;
      "4") postfix_setup      ;;
      "9") break              ;;
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
  if sudo crontab -l 2>/dev/null | grep --file=${TMPFILE} --quiet ; then
    log "Drupal crontab already contains $(cat ${TMPFILE})"
    return 0
  fi

  (sudo crontab -l 2>/dev/null; cat ${TMPFILE}) | sudo crontab -
}

# TODO: do we really need this?
deployer_setup () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  export RUNTIMEENV=${1:-${RUNTIMEENV}}
  export DEPLOYER_NAME=${2:-${DEPLOYER_NAME}}
  export DEPLOYER_PASS=${3:-${DEPLOYER_PASS}}
  local  DEPLOYER_SHELL={$4:-${DEPLOYER_SHELL:-/bin/bash}}

  if [ -z "$DEPLOYER_NAME" -o -z "$DEPLOYER_PASS" ] ; then
    if [ ${RUNTIMEENV} = 'vagrant' ] && ! command -v zsh > /dev/null 2>&1 ; then
      sudo su -c 'curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh'
    fi

    local SHELLLIST
    SHELLLIST=$(sed -e 's/#.*//' -e 's/$/off/' -e '/^.bin.bash/s/off/on/' /etc/shells | cat -n)
    dialog --ok-label  "Submit"                 \
           --backtitle "Drupal User Setup"      \
           --title     "User Information"       \
           --begin    0 0                       \
                        --inputbox    Username: 1 1 "${DEPLOYER_NAME}" \
           --and-widget --insecure --passwordbox Password: 2 1         \
           --and-widget --radiolist Shell: 10 40 10 $SHELLLIST         \
           3>&1 1>&2 2> user.ini
    RET=$?
    case $RET in
      $DIALOG_OK)
        read -d "\n" DEPLOYER_NAME DEPLOYER_PASS DEPLOYER_SHELL <<<$(cat user.ini)
        export DEPLOYER_NAME DEPLOYER_PASS DEPLOYER_SHELL
        ;;
      *)
        return 1
        ;;
    esac
  fi

  if ! cut -f1 -d: /etc/passwd | grep --line-regexp --quiet "$DEPLOYER_NAME" ; then
    sudo useradd --base-dir /home --create-home \
                 --shell "$DEPLOYER_SHELL" --user-group ${DEPLOYER_NAME}
    if [ -n "$DEPLOYER_PASS" ] ; then
      echo ${DEPLOYER_NAME}:${DEPLOYER_PASS} | sudo chpasswd
    fi
  fi

  sudo mkdir -p /home/${DEPLOYER_NAME}/.ssh
  sudo ssh-keyscan -H github.com    >> $HOME/.ssh/known_hosts
  sudo ssh-keyscan -H bitbucket.org >> $HOME/.ssh/known_hosts
  sudo cp $HOME/.ssh/known_hosts /home/${DEPLOYER_NAME}/.ssh/

  if [ ${RUNTIMEENV} = 'server' ] && [ -f $HOME/deployer_rsa.pub ] && [ -f $HOME/deployer_rsa ]; then
    sudo cat $HOME/deployer_rsa.pub >> /home/${DEPLOYER_NAME}/.ssh/authorized_keys
    sudo mv $HOME/deployer_rsa     /home/${DEPLOYER_NAME}/.ssh/id_rsa
    sudo mv $HOME/deployer_rsa.pub /home/${DEPLOYER_NAME}/.ssh/id_rsa.pub
  elif [ ${RUNTIMEENV} = 'vagrant' ] && [[ "$DEPLOYER_SHELL" =~ zsh ]] ; then
    safecp -U ${DEPLOYER_NAME} ${WORKDIR}/templates/zsh/zshrc.sh /home/${DEPLOYER_NAME}/.zshrc
    sed -i "s/{DEPLOYER_NAME}/${DEPLOYER_NAME}/g" /home/${DEPLOYER_NAME}/.zshrc
  fi

  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /home/${DEPLOYER_NAME}/.ssh

  if [ ${RUNTIMEENV} = 'server' ] && ! grep --quiet --no-messages www-data /etc/sudoers.d/${DEPLOYER_NAME} ; then
    sudo printf "%%${DEPLOYER_NAME} ALL=(www-data) NOPASSWD: ALL\n" > /etc/sudoers.d/${DEPLOYER_NAME}
    sudo chmod 440 /etc/sudoers.d/${DEPLOYER_NAME}
  fi
}

postfix_setup () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  export DEPLOYER_NAME=${1:-${DEPLOYER_NAME}}
  export SERVER_NAME=${2:-${SERVER_NAME}}

  sudo apt-get --quiet -y install postfix
  back_up_file /etc/postfix/main.cf

  cat <<-EOF | sudo debconf-set-selections
	postfix postfix/root_address      string ${DEPLOYER_NAME}"
	postfix postfix/rfc1035_violation boolean false
	postfix postfix/mynetworks        string 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
	postfix postfix/mailname          string ${SERVER_NAME}
	postfix postfix/recipient_delim   string +
	postfix postfix/main_mailer_type  select Internet Site
	postfix postfix/destinations      string localhost
EOF

  sudo dpkg-reconfigure postfix

  sudo sed -i -e "/^myhostname/ a\
    mydomain = ${SERVER_NAME}"          \
              -e '/^myorigin/ s/^/# /'  \
              -e '/^# myorigin/ a\
    myorigin = $mydomain' /etc/postfix/main.cf

  sudo service postfix restart
}
