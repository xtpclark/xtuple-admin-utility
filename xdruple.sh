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

  log "Opened xTupleCommerce menu"

  while true ; do
    MENU=$(whiptail --backtitle "$(window_title)" --title "xTuple Utility v$_REV" \
                    --menu "$(menu_title xTupleCommerce Menu)" 0 0 10 \
                    --cancel-button "Cancel" --ok-button "Select" \
                    "1" "Quick Install"           \
                    "=" "======================"  \
                    "2" "OS setup"                \
                    "3" "Deployer setup"          \
                    "4" "nginx setup"             \
                    "5" "PHP setup"               \
                    "6" "Database server setup"   \
                    "7" "Mail server setup"       \
                    "8" "Ruby setup"              \
                    "9" "crontab setup"           \
                   "10" "xTupleCommerce code"     \
                   "11" "Flywheel setup"          \
                   "12" "Update a site"           \
                   "13" "Return to main menu"     \
            3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      break
    fi
    case "$MENU" in
       "1") get_os_info        && \
            prepare_os_for_xtc && \
            get_deployer_info  && \
            deployer_setup     && \
            nginx_menu         && \
            php_setup          && \
            xtc_pg_setup       && \
            postfix_setup      && \
            ruby_setup         && \
            drupal_crontab     && \
            xtc_code_setup     && \
            setup_flywheel     && \
            update_site        && \
            webnotes
            RET=$?
            if [ $RET -ne 0 ] ; then
              msgbox "Quick Install failed or was cancelled"
            fi
            ;;
      "==") ;;
       "2") get_os_info       && prepare_os_for_xtc ;;
       "3") get_deployer_info && deployer_setup     ;;
       "4") nginx_menu         ;;
       "5") php_setup          ;;
       "6") xtc_pg_setup       ;;
       "7") postfix_setup      ;;
       "8") ruby_setup         ;;
       "9") drupal_crontab     ;;
      "10") xtc_code_setup     ;;
      "11") setup_flywheel     ;;
      "12") update_site        ;;
      "13") msgbox "$(cat webnotes)" ; break ;;
      "==") ;;
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
  WEBROOT="${1:-/var/www}"
  LOGDIR="${2:-/var/log/xtuple}"

  sudo mkdir --parents ${LOGDIR}/cron
  cp templates/druple.crontab ${TMPFILE}
  if ! replace_params --no-backup ${TMPFILE} ; then
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
  export DEPLOYER_NAME=${1:-${DEPLOYER_NAME}}
  export DEPLOYER_PASS=${2:-${DEPLOYER_PASS}}
  export DEPLOYER_SHELL={$3:-${DEPLOYER_SHELL:-/bin/bash}}

  if [ "$MODE" = "manual" ] ; then
    # TODO: is robbyrussell really necessary?
    if $IS_DEV_ENV && ! command -v zsh > /dev/null 2>&1 ; then
      sudo apt-get install --quiet --yes zsh
      sudo su -c 'curl -L https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh | sh'
    fi

    local SHELLLIST
    # get the list of legal shells & default to bash
    SHELLLIST=$(awk 'BEGIN  { print "/bin/bash" }
                     /bash/ { next }
                            { sub(" *#.*", "");
                              if (length) { print }}' /etc/shells)
    dialog --ok-label  "Submit"                 \
           --backtitle "$(window_title)"        \
           --form      "Enter information about the Drupal user" 0 0 7  \
           "Username:"   1 1 "${DEPLOYER_NAME}" 1 25 50 0               \
           "Password":   2 1 ""                 2 25 50 0               \
           --and-widget --menu Shell: 15 20  5 $(echo $SHELLLIST | tr " " "\n" | cat -n) \
           3>&1 1>&2 2> user.ini
    RET=$?
    case $RET in
      $DIALOG_OK)
        read -d "\n" DEPLOYER_NAME DEPLOYER_PASS DEPLOYER_SHELL <<<$(cat user.ini)
        DEPLOYER_SHELL=$(cut --fields=$DEPLOYER_SHELL  --delimiter=" " <<< $SHELLLIST)
        export DEPLOYER_NAME DEPLOYER_PASS DEPLOYER_SHELL
        ;;
      *)
        return 1
        ;;
    esac
  fi
}

deployer_setup () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  export DEPLOYER_NAME=${1:-${DEPLOYER_NAME}}
  export DEPLOYER_PASS=${2:-${DEPLOYER_PASS}}
  local  DEPLOYER_SHELL={$3:-${DEPLOYER_SHELL:-/bin/bash}}

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

  if ! $IS_DEV_ENV && [ -f $HOME/deployer_rsa.pub ] && [ -f $HOME/deployer_rsa ]; then
    back_up_file /home/${DEPLOYER_NAME}/.ssh/authorized_keys
    sudo cat $HOME/deployer_rsa.pub >> /home/${DEPLOYER_NAME}/.ssh/authorized_keys
    safecp $HOME/deployer_rsa     /home/${DEPLOYER_NAME}/.ssh/id_rsa
    safecp $HOME/deployer_rsa.pub /home/${DEPLOYER_NAME}/.ssh/id_rsa.pub
    rm -f $HOME/deployer_rsa $HOME/deployer_rsa.pub

  elif $IS_DEV_ENV && [[ "$DEPLOYER_SHELL" =~ zsh ]] ; then
    safecp ${WORKDIR}/templates/zsh/zshrc.sh /home/${DEPLOYER_NAME}/.zshrc
    replace_params --no-backup /home/${DEPLOYER_NAME}/.zshrc
  fi

  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /home/${DEPLOYER_NAME}/.ssh

  if ! $IS_DEV_ENV && ! sudo grep --quiet --no-messages www-data /etc/sudoers.d/${DEPLOYER_NAME} ; then
    echo "%${DEPLOYER_NAME} ALL=(www-data) NOPASSWD: ALL" | sudo tee -a /etc/sudoers.d/${DEPLOYER_NAME} > /dev/null
    sudo chmod 440 /etc/sudoers.d/${DEPLOYER_NAME}
  fi
}

postfix_setup () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  DEPLOYER_NAME=${1:-${DEPLOYER_NAME}}
  local SERVER_NAME=${2:-${SERVER_NAME:-$(hostname)}}

  # -qq avoids prompts
  sudo apt-get --quiet --quiet --yes install postfix
  back_up_file /etc/postfix/main.cf

  # TODO: why debconf-set-selections instead of >> /etc/postfix/main.conf
  cat <<-EOF | sudo debconf-set-selections
	postfix postfix/root_address      string ${DEPLOYER_NAME}"
	postfix postfix/rfc1035_violation boolean false
	postfix postfix/mynetworks        string 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
	postfix postfix/mailname          string ${SERVER_NAME}
	postfix postfix/recipient_delim   string +
	postfix postfix/main_mailer_type  select Internet Site
	postfix postfix/destinations      string localhost
EOF

  #TODO: why is this separate from debconf_set_selections above?
  sudo sed -i -e "/^myhostname/ a\
    mydomain = ${SERVER_NAME}"          \
              -e '/^myorigin/ s/^/# /'  \
              -e '/^# myorigin/ a\
    myorigin = $mydomain' /etc/postfix/main.cf

  service_restart postfix
}

xtc_pg_setup () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local RET=0

  psql --username=postgres <<-EOF
      CREATE USER ${DEPLOYER_NAME} PASSWORD '${DEPLOYER_PASS}';
      CREATE USER development PASSWORD '${DEVELOPMENT_DB_PASS}';
      CREATE USER stage      PASSWORD '${STAGE_DB_PASS}';
      CREATE USER production PASSWORD '${PRODUCTION_DB_PASS}';

      CREATE DATABASE development WITH OWNER development;
      CREATE DATABASE stage       WITH OWNER stage;
      CREATE DATABASE production  WITH OWNER production;
EOF

  log_exec sudo bash -c "echo 'host         all            all            127.0.0.1/32              trust' >> $POSTDIR/pg_hba.conf"
  RET=$?
  if [ $RET -ne 0 ] ; then
    die "Opening $POSTDIR/pg_hba.conf for xTupleCommerce failed. Check log file and try again."
  fi
  sudo chown postgres $POSTDIR/pg_hba.conf

  service_restart postgresql
}

update_site () {
  msgbox 'ssh -t USER@SITE.xtuplecloud.com "cd /var/www/SITE.xd && ./console.php update:all"'
}

fi # }
