#!/bin/bash

gitco() {
  local DESTDIR="$1"
  local REPO="$(basename $2 .git)"
  local REFSPEC="$3"
  local GITHUBNAME="${4:-$GITHUBNAME}"
  local GITHUBPASS="${5:-$GITHUBPASS}"

  local STARTDIR=$(pwd)
  local GHUSERSPEC=

  if [ -n "$GITHUBPASS" ] ; then
    GHUSERSPEC="$GITHUBNAME:$GITHUBPASS@"
  elif [ -n "$GITHUBNAME" ] ; then
    GHUSERSPEC="$GITHUBNAME@"
  fi

  mkdir -p "$DESTDIR"
  cd "$DESTDIR"
  ls $REPO || echo "$REPO not found"
  if [ ! -d $REPO/.git ] ; then
    git clone https://${GHUSERSPEC}github.com/xtuple/$REPO.git || die
  fi
  cd $REPO
  if ! git remote -v | grep -q xtuple/$REPO ; then
    git remote add XTUPLE https://github.com/xtuple/$REPO.git
    git fetch https://${GHUSERSPEC}github.com/xtuple/$REPO.git
  fi

  git checkout $REFSPEC                           || die
  git submodule update --init --recursive         || die
  npm install                                     || die
  cd "$STARTDIR"
}

mwc_menu() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    log "Opened Web Client menu"

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Web\ Client\ Menu )" 0 0 10 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Install xTuple Web Client" \
            "2" "Remove xTuple Web Client" \
            "3" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -ne 0 ]; then
            break
        else
            case "$PGM" in
            "1") install_webclient_menu ;;
            "2") log_exec remove_mwc ;;
            "3") break ;;
            *) msgbox "Error. How did you get here? >> mwc_menu / $PGM" && break ;;
            esac
        fi
    done
}

install_webclient_menu() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    if [ -z "$DATABASE" ]; then
        check_database_info
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi

        get_database_list

        if [ -z "$DATABASES" ]; then
            msgbox "No databases detected on this system"
            return 1
        fi

        DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "List of databases on this cluster" 16 60 10 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            log "There was an error selecting the database.. exiting"
            return $RET
        fi
    fi

    log "Chose database $DATABASE"

    if [ -z "$MWCVERSION" ] && [ "$MODE" = "manual" ]; then
        TAGVERSIONS=$(git ls-remote --tags git://github.com/xtuple/xtuple.git | grep -v '{}' | cut -d '/' -f 3 | cut -d v -f2 | sort -rV | head -10)
        HEADVERSIONS=$(git ls-remote --heads git://github.com/xtuple/xtuple.git | grep -Po '\d_\d+_x' | sort -rV | head -5)

        MENUVER=$(whiptail --backtitle "$( window_title )" --menu "Choose Web Client Version" 15 60 10 --cancel-button "Exit" --ok-button "Select" \
            $(paste -d '\n' \
            <(seq 0 9) \
            <(echo $TAGVERSIONS | tr ' ' '\n')) \
            $(paste -d '\n' \
            <(seq 10 14) \
            <(echo $HEADVERSIONS | tr ' ' '\n')) \
            "15" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 0 ]; then
            if [ $MENUVER -eq 16 ]; then
                return 0;
            elif [ $MENUVER -lt 10 ]; then
                read -a tagversionarray <<< $TAGVERSIONS
                MWCVERSION=${tagversionarray[$MENUVER]}
                MWCREFSPEC=v$MWCVERSION
            else
                read -a headversionarray <<< $HEADVERSIONS
                MWCVERSION=${headversionarray[(($MENUVER-10))]}
                MWCREFSPEC=$MWCVERSION
            fi
        else
            return $RET
        fi
    elif [ -z "$MWCVERSION" ]; then
        return 127
    fi

    log "Chose version $MWCVERSION"

    if [ -z "$MWCNAME" ] && [ "$MODE" = "manual" ]; then
        MWCNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter a name for this xTuple instance.\nThis name will be used in several ways:\n- naming the service script in /etc/systemd/system, /etc/init, or /etc/init.d\n- naming the directory for the xTuple web-enabling source code - /opt/xtuple/$(MWCVERSION)/" 15 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    elif [ -z "$MWCNAME" ]; then
        return 127
    fi

    log "Chose mobile name $MWCNAME"

    if [ -z "$PRIVATEEXT" ] && [ "$MODE" = "manual" ]; then
        if (whiptail --title "Private Extensions" --yesno --defaultno "Would you like to install the commercial extensions? You will need a commercial database or this step will fail." 10 60) then
            log "Installing the commercial extensions"
            PRIVATEEXT=true
            GITHUBNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter your GitHub username" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -ne 0 ]; then
                return $RET
            fi

            GITHUBPASS=$(whiptail --backtitle "$( window_title )" --passwordbox "Enter your GitHub password" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -ne 0 ]; then
                return $RET
            fi
        else
            log "Not installing the commercial extensions"
            PRIVATEEXT=false
        fi
    elif [ -z "$PRIVATEEXT" ]; then
        return 127
    fi

    log_exec install_webclient $MWCVERSION $MWCREFSPEC $MWCNAME $PRIVATEEXT $DATABASE $GITHUBNAME $GITHUBPASS
}


# $1 is xtuple version
# $2 is the git refspec
# $3 is the instance name
# $4 is to install private extensions
# $5 is database name
# $6 is github username
# $7 is github password
# TODO: merge into function with same name in setup.fun
install_webclient() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Web enabling"

  MWCVERSION="${1:-$MWCVERSION}"
  MWCREFSPEC="${2:-$MWCREFSPEC}"
  MWCNAME="${3:-$MWCNAME}"

  PRIVATEEXT="${4:-${PRIVATEEXT:-false}}"
  if [ ! "$PRIVATEEXT" = "true" ]; then
    PRIVATEEXT=false
  fi

  ERP_DATABASE_NAME="${5:-$ERP_DATABASE_NAME}"
  if [ -z "$ERP_DATABASE_NAME" ]; then
    die "No database name passed to install_webclient. exiting."
  fi

  GITHUBNAME="${6:-$GITHUBNAME}"
  GITHUBPASS="${7:-$GITHUBPASS}"

  setup_webprint

  log "Installing n..."
  cd $WORKDIR
  wget https://raw.githubusercontent.com/visionmedia/n/master/bin/n -qO n
  log_exec chmod +x n                                                  || die
  log_exec sudo mv n /usr/bin/n                                        || die
  # use it to set node to 0.10
  log "Installing node 0.10.40..."
  log_exec sudo n 0.10.40                                              || die

  log_exec sudo npm install -g npm@2.x.x                               || die

  log "Cloning xTuple Web Client Source Code to /opt/xtuple/$MWCVERSION/xtuple"
  log "Using version $MWCVERSION with the given name $MWCNAME"
  log_exec sudo mkdir -p /opt/xtuple/$MWCVERSION/"$MWCNAME"            || die
  log_exec sudo chown -R ${DEPLOYER_NAME}.${DEPLOYER_NAME} /opt/xtuple || die

  # main code
  gitco /opt/xtuple/$MWCVERSION/$MWCNAME xtuple $MWCREFSPEC
  cd /opt/xtuple/$MWCVERSION/$MWCNAME/xtuple
  npm install bower                                                    || die

  if $PRIVATEEXT ; then
    log "Installing the commercial extensions"
    gitco /opt/xtuple/$MWCVERSION/$MWCNAME private-extensions $MWCREFSPEC $GITHUBNAME $GITHUBPASS
  else
    log "Not installing the commercial extensions"
  fi

  if [ ! -f /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource/sample_config.js ]; then
    die "Cannot find sample_config.js. Check the log and try again."
  fi

  export XTDIR=/opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple

  log_exec sudo rm -rf /etc/xtuple/$MWCVERSION/"$MWCNAME"
  encryption_setup /etc/xtuple/$MWCVERSION/$MWCNAME $ERP_DATABASE_NAME $XTDIR

  log_exec sudo chown -R ${DEPLOYER_NAME}.${DEPLOYER_NAME} /etc/xtuple
  turn_on_plv8

  if [ $DISTRO = "ubuntu" ]; then
    case "$CODENAME" in
      "trusty") ;&
      "utopic")
          log "Creating upstart script using filename /etc/init/xtuple-$MWCNAME.conf"
          sudo cp $WORKDIR/templates/ubuntu-upstart /etc/init/xtuple-"$MWCNAME".conf
          log_exec sudo bash -c "echo \"chdir /opt/xtuple/$MWCVERSION/\"$MWCNAME\"/xtuple/node-datasource\" >> /etc/init/xtuple-\"$MWCNAME\".conf"
          log_exec sudo bash -c "echo \"exec ./main.js -c /etc/xtuple/$MWCVERSION/\"$MWCNAME\"/config.js > /var/log/node-datasource-$MWCVERSION-\"$MWCNAME\".log 2>&1\" >> /etc/init/xtuple-\"$MWCNAME\".conf"
          ;;
      "vivid") ;&
      "xenial")
          log "Creating systemd service unit using filename /etc/systemd/system/xtuple-$MWCNAME.service"
          sudo cp $WORKDIR/templates/xtuple-systemd.service /etc/systemd/system/xtuple-"$MWCNAME".service
          log_exec sudo bash -c "echo \"SyslogIdentifier=xtuple-$MWCNAME\" >> /etc/systemd/system/xtuple-\"$MWCNAME\".service"
          log_exec sudo bash -c "echo \"ExecStart=/usr/local/bin/node /opt/xtuple/$MWCVERSION/\"$MWCNAME\"/xtuple/node-datasource/main.js -c /etc/xtuple/$MWCVERSION/\"$MWCNAME\"/config.js\" >> /etc/systemd/system/xtuple-\"$MWCNAME\".service"
          ;;
    esac
  else
    die "Seriously? We made it all the way to where I need to write out the init script and suddenly I can't detect your distro -> $DISTRO codename -> $CODENAME"
  fi

  log_exec cd $XTDIR                                                             || die
  log_exec scripts/build_app.js -c /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js  || die

  service_start xtuple-"$MWCNAME"

  # assuming eth0 for now... hostname -I will give any non-local address if we wanted
  IP=$(ip -f inet -o addr show | grep -vw lo | awk '{print $4}' | cut -d/ -f 1)
  log "All set! You should now be able to log on to this server at https://$IP:$NGINX_PORT with username admin and password admin. Make sure you change your password!"
}

remove_mwc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  msgbox "Uninstalling the mobile client is not yet supported"
}
