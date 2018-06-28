#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

# TODO: we may need to distinguish between git tags (BUILD_XT_TAG) and the ServerVersion metric

if [ -z "$MOBILECLIENT_SH" ] ; then # {
MOBILECLIENT_SH=true

mwc_menu() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    log "Opened Web Client menu"

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --title "xTuple Utility v$_REV" \
                       --menu "$(menu_title Web Client Menu)" 0 0 10 --cancel-button "Cancel" --ok-button "Select" \
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

    select_database
    RET=$?
    if [ $RET -ne 0 ]; then
      log "There was an error selecting the database.. exiting"
      return $RET
    fi
  fi

  log "Chose database $DATABASE"

  if [ -z "$BUILD_XT_TAG" ] && [ "$MODE" = "manual" ]; then
    TAGVERSIONS=$(git ls-remote --tags git://github.com/xtuple/xtuple.git | grep -v '{}' | cut -d '/' -f 3 | sort -rV | head -10)
    HEADVERSIONS=$(git ls-remote --heads git://github.com/xtuple/xtuple.git | grep -Po '\d_\d+_x' | sort -rV | head -5)

    MENUVER=$(whiptail --backtitle "$( window_title )" --title "xTuple Utility v$_REV" \
                       --menu "Choose Web Client Version" 0 0 10 --cancel-button "Exit" --ok-button "Select" \
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
        BUILD_XT_TAG=${tagversionarray[$MENUVER]}
      else
        read -a headversionarray <<< $HEADVERSIONS
        BUILD_XT_TAG=${headversionarray[(($MENUVER-10))]}
      fi
    else
      return $RET
    fi
  elif [ -z "$BUILD_XT_TAG" ]; then
    return 127
  fi

  log "Chose version $BUILD_XT_TAG"

  if [ -z "$MWCNAME" ] && [ "$MODE" = "manual" ]; then
    MWCNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter a name for this xTuple instance.\nThis name will be used in several ways:\n- naming the service script in /etc/systemd/system, /etc/init, or /etc/init.d\n- naming the directory for the xTuple web-enabling source code - /opt/xtuple/$(BUILD_XT_TAG)/" 15 60 3>&1 1>&2 2>&3)
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
      get_github_token
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

  log_exec install_webclient $BUILD_XT_TAG $BUILD_XT_TAG $MWCNAME $PRIVATEEXT $DATABASE
}


# $1 is xtuple version
# $2 is the git refspec
# $3 is the instance name
# $4 is to install private extensions
# $5 is database name
install_webclient() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Web enabling"

  BUILD_XT_TAG="${1:-$BUILD_XT_TAG}"
  BUILD_XT_TAG="${2:-$BUILD_XT_TAG}"
  MWCNAME="${3:-$MWCNAME}"

  PRIVATEEXT="${4:-${PRIVATEEXT:-false}}"
  if [ ! "$PRIVATEEXT" = "true" ]; then
    PRIVATEEXT=false
  fi

  ERP_DATABASE_NAME="${5:-$ERP_DATABASE_NAME}"
  if [ -z "$ERP_DATABASE_NAME" ]; then
    die "No database name passed to install_webclient. exiting."
  fi

  local STARTDIR=$(pwd)

  # TODO: is this necessary?
  log_exec sudo mkdir --parents /etc/xtuple/${BUILD_XT_TAG}

  if [[ $ISXTAU ]]; then
    get_environment
    psql -At -U postgres -l | grep -q ${ERP_DATABASE_NAME} 2>/dev/null
    RET=$?

    if [[ $RET == 0 ]]; then
      echo "Database ${ERP_DATABASE_NAME} already exists, good!"
    else
      echo "Creating ${ERP_DATABASE_NAME}!"
      createdb -U admin -p ${PGPORT} ${ERP_DATABASE_NAME}
      psql -U admin -p ${PGPORT} ${ERP_DATABASE_NAME} -c "CREATE EXTENSION plv8;"
    fi
    export ERP_DATABASE=${ERP_DATABASE_NAME}
  fi

  cd $WORKDIR

  log "Installing n..."
  wget https://raw.githubusercontent.com/visionmedia/n/master/bin/n -qO n
  log_exec chmod +x n                                                  || die
  log_exec sudo mv n /usr/bin/n                                        || die
  log "Installing node 0.10.40..."
  log_exec sudo n 0.10.40                                              || die

  log_exec sudo npm install -g npm@2.x.x                               || die

  if [[ -f ${ERP_MWC_TARBALL} ]]; then
    ERPTARDIR=$(tar -tzf ${ERP_MWC_TARBALL} | head -1 | cut -f1 -d"/")

    if [ -z "$(ls -A ${ERPTARDIR})" ]; then
      echo "${ERPTARDIR} is empty or does not exist\nExtracting ${ERP_MWC_TARBALL}"
      tar xf ${ERP_MWC_TARBALL}
      turn_on_plv8
    else
      echo "${ERPTARDIR} exists and is not empty"
    fi
    if [ -z "$BUILD_XT_TAG" ] ; then
      BUILD_XT_TAG=$(cd ${ERPTARDIR}/xtuple && git describe --abbrev=0 --tags)
    fi
    log_exec sudo cp -R ${ERPTARDIR} /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME
  else
    log "Cloning xTuple Web Client Source Code to /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME/xtuple"
    log "Using version $BUILD_XT_TAG with the given name $MWCNAME"
    log_exec sudo mkdir --parents /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME  || die
    log_exec sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /opt/xtuple        || die
    gitco xtuple /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME $BUILD_XT_TAG     || die
  fi

  config_webclient_scripts                               || die
  npm install bower                                      || die

  if $PRIVATEEXT ; then
    # TODO: BUILD_XT_TAG is not always correct, as it might really be a commit hash
    gitco private-extensions /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME $BUILD_XT_TAG
  fi

  turn_on_plv8
  cd /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME/xtuple || die

  local HAS_XTEXT=$(psql -At -U admin ${ERP_DATABASE_NAME} <<EOF
    SELECT 1
      FROM pg_catalog.pg_class JOIN pg_namespace n ON n.oid = relnamespace
     WHERE nspname = 'xt' AND relname = 'ext';
EOF
)
  cd /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME/xtuple
  if [[ $HAS_XTEXT == 1 ]]; then
    echo "${ERP_DATABASE_NAME} has xt.ext so we can preload things that may not exist.  There may be exceptions to doing this."
    psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/preload.sql
  fi
  log_exec scripts/build_app.js -c ${CONFIGDIR}/config.js 2>&1 | tee buildapp_output.log
  RET=$?
  msgbox "$(cat buildapp_output.log)"
  if [[ $RET -ne 0 ]]; then
    main_menu
  fi

  if $PRIVATEEXT ; then
    case $ERP_EDITION in
      distribution)  EXT_DIR="inventory distribution"               ;;
      manufacturing) EXT_DIR="inventory manufacturing"              ;;
      enterprise)    EXT_DIR="inventory manufacturing distribution" ;;
      *)             EXT_DIR="inventory"                            ;;
    esac
    echo "Installing $EXT_DIR extensions" > buildapp_output.log
    for DIR in $EXT_DIR ; do
      scripts/build_app.js -c ${CONFIGDIR}/config.js -e /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME/private-extensions/source/$DIR  2>&1 | tee -a buildapp_output.log
    done
    msgbox "$(cat buildapp_output.log)"
  fi

  service_start xtuple-$ERP_DATABASE_NAME                || die

  IP="$(hostname -I)"
  msgbox "You should now be able to log on to this server at https://$IP:$WEBAPI_PORT with username admin and password admin. Make sure you change your password!"
  cd $STARTDIR
}

remove_mwc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  msgbox "Uninstalling the web client is not yet supported"
}
fi # }
