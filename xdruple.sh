#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$XDRUPLE_H" ] ; then # {
XDRUPLE_H=true

source common.sh
source functions/setup.fun
source functions/oatoken.fun

drupal_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local MENU

  log "Opened drupal menu"

  while true ; do
    MENU=$(whiptail --backtitle "xTuple Utility v$_REV" \
                    --menu "$( menu_title Drupal\ Menu )" 0 0 10 \
                    --cancel-button "Cancel" --ok-button "Select" \
                    "1" "Quick Install"           \
                    "=" "======================"  \
                    "2" "Set up OS"               \
                    "3" "Set up Deployer"         \
                    "4" "Set up nginx"            \
                    "5" "Set up PHP"              \
                    "6" "Set up Postgres for xTC" \
                    "7" "Set up PostFix"          \
                    "8" "Set up Ruby"             \
                    "9" "Set up SSH keys"         \
                   "10" "Set up crontab"          \
                   "11" "Set up flywheel"         \
                   "12" "Update a site"           \
                   "13" "Return to main menu"     \
            3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      break
    fi
    case "$MENU" in
       "1") get_os_info
            source ${WORKDIR:-.}/CreatePackages.sh xtau_deploy_ecommerce
            ;;
       "2") get_os_info
            prepare_os_for_xtc
            ;;
       "3") get_deployer_info
            deployer_setup
            ;;
       "4") nginx_menu         ;;
       "5") php_setup          ;;
       "6") xtc_pg_setup       ;;
       "7") postfix_setup      ;;
       "8") ruby_setup         ;;
       "9") generate_p12       ;;
      "10") drupal_crontab     ;;
      "11") setup_flywheel     ;;
      "12") update_site        ;;
      "13") webnotes
            break
            ;;
       "=") ;;
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

  sudo mkdir --parents ${LOGDIR}/cron
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

get_deployer_info () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  export RUNTIMEENV=${1:-${RUNTIMEENV}}
  export DEPLOYER_NAME=${2:-${DEPLOYER_NAME}}
  export DEPLOYER_PASS=${3:-${DEPLOYER_PASS}}
  local  DEPLOYER_SHELL={$4:-${DEPLOYER_SHELL:-/bin/bash}}

  # TODO: is this really necessary?
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
}

deployer_setup () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  export RUNTIMEENV=${1:-${RUNTIMEENV}}
  export DEPLOYER_NAME=${2:-${DEPLOYER_NAME}}
  export DEPLOYER_PASS=${3:-${DEPLOYER_PASS}}
  local  DEPLOYER_SHELL={$4:-${DEPLOYER_SHELL:-/bin/bash}}

  if ! cut -f1 -d: /etc/passwd | grep --line-regexp --quiet "$DEPLOYER_NAME" ; then
    sudo useradd --base-dir /home --create-home \
                 --shell "$DEPLOYER_SHELL" --user-group ${DEPLOYER_NAME}
    if [ -n "$DEPLOYER_PASS" ] ; then
      echo ${DEPLOYER_NAME}:${DEPLOYER_PASS} | sudo chpasswd
    fi
  fi

  sudo mkdir --parents /home/${DEPLOYER_NAME}/.ssh
  back_up_file $HOME/.ssh/known_hosts
  sudo ssh-keyscan -H github.com    >> $HOME/.ssh/known_hosts
  sudo ssh-keyscan -H bitbucket.org >> $HOME/.ssh/known_hosts

  if [ ${RUNTIMEENV} = 'server' ] && [ -f $HOME/deployer_rsa.pub ] && [ -f $HOME/deployer_rsa ]; then
    back_up_file /home/${DEPLOYER_NAME}/.ssh/authorized_keys
    sudo cat $HOME/deployer_rsa.pub >> /home/${DEPLOYER_NAME}/.ssh/authorized_keys
    safecp $HOME/deployer_rsa     /home/${DEPLOYER_NAME}/.ssh/id_rsa
    safecp $HOME/deployer_rsa.pub /home/${DEPLOYER_NAME}/.ssh/id_rsa.pub
    rm -f $HOME/deployer_rsa $HOME/deployer_rsa.pub

  elif [ ${RUNTIMEENV} = 'vagrant' ] && [[ "$DEPLOYER_SHELL" =~ zsh ]] ; then
    safecp ${WORKDIR}/templates/zsh/zshrc.sh /home/${DEPLOYER_NAME}/.zshrc
    sed -i "s/{DEPLOYER_NAME}/${DEPLOYER_NAME}/g" /home/${DEPLOYER_NAME}/.zshrc
  fi

  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /home/${DEPLOYER_NAME}/.ssh

  if [ ${RUNTIMEENV} = 'server' ] && ! sudo grep --quiet --no-messages www-data /etc/sudoers.d/${DEPLOYER_NAME} ; then
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

  #TODO: remove if possible; this was called during apt-get install
  sudo dpkg-reconfigure postfix

  sudo sed -i -e "/^myhostname/ a\
    mydomain = ${SERVER_NAME}"          \
              -e '/^myorigin/ s/^/# /'  \
              -e '/^# myorigin/ a\
    myorigin = $mydomain' /etc/postfix/main.cf

  service_restart postfix
}

xtc_pg_setup () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  psql --username=postgres <<-EOF
      CREATE USER ${DEPLOYER_NAME} PASSWORD '${DEPLOYER_PASS}';
      CREATE USER development PASSWORD '${DEVELOPMENT_DB_PASS}';
      CREATE USER stage      PASSWORD '${STAGE_DB_PASS}';
      CREATE USER production PASSWORD '${PRODUCTION_DB_PASS}';

      CREATE DATABASE development WITH OWNER development;
      CREATE DATABASE stage       WITH OWNER stage;
      CREATE DATABASE production  WITH OWNER production;
EOF

  if [ "${RUNTIMEENV}" = 'server' ] ; then
    log_exec sudo --username postgres cat <<-EOF >> $POSTDIR/pg_hba.conf
      host         postgres       postgres       127.0.0.1/32              trust
      host         development    development    127.0.0.1/32              trust
      host         stage          stage          127.0.0.1/32              trust
      host         production     production     127.0.0.1/32              trust
      host         $DEPLOYER_NAME $DEPLOYER_NAME 127.0.0.1/32              trust
EOF
    RET=$?
  elif [ "${RUNTIMEENV}" = "vagrant" ] ; then
    log_exec sudo bash -c "echo 'host         all            all            127.0.0.1/32              trust' >> $POSTDIR/pg_hba.conf"
    RET=$?
  fi
  if [ $RET -ne 0 ] ; then
    die "Opening pg_hba.conf for xTupleCommerce failed. Check log file and try again. "
  fi
  sudo chown postgres $POSTDIR/pg_hba.conf

  service_restart postgresql
}

update_site () {
  msgbox 'ssh -t USER@SITE.xtuplecloud.com "cd /var/www/SITE.xd && ./console.php update:all"'
}

fi # }
