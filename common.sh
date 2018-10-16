#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$COMMON_H" ] ; then # {
COMMON_H=true

log_exec() {
  "$@" | tee -a $LOG_FILE 2>&1
  RET=${PIPESTATUS[0]}
  return $RET
}

log() {
  echo "$( date +"%T" ) xtuple >> $@" | tee -a $LOG_FILE
}

LOG_FILE=$(pwd)/install-$DATE.log
log "Logging initialized. Current session will be logged to $LOG_FILE"

do_exit() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[@]}"

  log "Exiting xTuple Admin Utility"
  exit 0
}

die() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[@]}"

  TRAPMSG="$@"
  log $@
  exit 1
}

# catch user hitting control-c during operation, exit gracefully.
trap ctrlc INT
ctrlc() {
  log "Breaking due to user CTRL-C"
  do_exit
}

back_up_file() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local TGT="$1"
  [ -e $TGT ] || return

  local SUFFIX="${WORKDATE}"

  # move then copy back preserves the file timestamp
  eval $(stat --printf 'OWNER=%U
                        GROUP=%G' ${TGT})
  while [ -e ${TGT}.${SUFFIX} ] ; do
    sleep 10
    SUFFIX="${WORKDATE}-$(date +'%H-%M')"
  done

  log_exec sudo mv    "${TGT}"           "${TGT}.${SUFFIX}"        || die
  log_exec sudo cp -R "${TGT}.${SUFFIX}" "${TGT}"                  || die
  log_exec sudo chmod a-w "${TGT}.${SUFFIX}"
  log_exec sudo chown -R $OWNER:$GROUP "${TGT}" "${TGT}.${SUFFIX}" || die
}

safecp() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if [ $# -lt 2 ] ; then
    die "$FUNCNAME[0]: needs a source and target"
  elif [ $# -gt 2 ] ; then
    die "$FUNCNAME[0]: cannot handle more than one source"
  fi

  local SRC="$1"
  local TGT="$2"
  local SUFFIX="${WORKDATE}"
  local OWNER GROUP

  if [ -f "${SRC}" -a -d "${TGT}" ] ; then
    TGT="${TGT}/$(basename ${SRC})"
  fi

  if [ -e "$TGT" ] ; then
    while [ -e ${TGT}.${SUFFIX} ] ; do
      SUFFIX="${WORKDATE}-$(date +'%H-%M')"
      ! [ -e ${TGT}.${SUFFIX} ] || sleep 10
    done

    eval $(stat --printf 'OWNER=%U GROUP=%G' ${TGT})
    sudo mv "${TGT}" "${TGT}.${SUFFIX}"
    sudo chmod a-w "${TGT}.${SUFFIX}"
  fi

  sudo cp -R "${SRC}" "${TGT}" || die "Error copying ${SRC} to ${TGT}; look for ${TGT}.${SUFFIX}"
  if [ -n "${OWNER}" ] ; then
    sudo chown -R ${OWNER}:${GROUP:-${OWNER}} "${TGT}"
  fi
}

# $1 is the URL
# $2 is the output file name
download() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  if [ $# -lt 2 ] ; then
    die "$FUNCNAME[0]: url dest [ file-mode ]"
  fi
  local URL="$1"
  local FILE="$(basename $URL)"
  local DEST="$2"
  local FILEMODE="$3"

  log "Downloading $URL to file $DEST"
  if [ "$MODE" = manual ] ; then
    log_exec sudo wget --output-document="$DEST" --progress=dot:force "$URL" 2>&1 | \
             awk '/K.*%/ { pct=$(NF-2) ; sub("%", "", pct); print pct }' | \
             whiptail --backtitle "$( window_title )" --gauge "$2" 0 0 100
    RET=${PIPESTATUS[0]}
  else
    log_exec sudo wget --output-document="$DEST" "$URL"
    RET=$?
  fi
  if [ "$RET" -ne 0 ] ; then
    msgbox "Downloading $URL to file $DEST failed"
    return 1
  fi
  [ -z "$FILEMODE" ] || sudo chmod "$FILEMODE" ${DEST}
}

# $1 is the msg
msgbox() {
  log "MessageBox >> ""$1"
  [ $MODE = "manual" ] && whiptail --backtitle "$( window_title )" --msgbox "$1" 0 0 0
  return 0
}

# $1 is the product
latest_version() {
  VER=`curl -s http://files.xtuple.org/latest_$1`
  echo $VER
}

window_title() {
  echo "xTuple Admin Utility v$_REV -=- ${PGUSER:-¿user?}@${PGHOST:-¿host?}:${PGPORT:-¿port?} ${PGPASS:+-=- Password is set}"
}

# $1 is text to display
menu_title() {
  cat "$WORKDIR"/xtuple.asc
  echo "$*"
}

install_prereqs() {
  case "$DISTRO" in
    "ubuntu")
      if $IS_DEV_ENV ; then
        install_dev_prereqs
      fi
      install_pg_repo
      sudo apt-get --yes --quiet update
      # TODO: prune this list if possible (e.g. build-essential?)
      sudo apt-get --quiet -y install \
                              build-essential bzip2 cups curl dialog git jq       \
                              libauthen-pam-perl libavahi-compat-libdnssd-dev     \
                              libc++1 libio-pty-perl libnet-ssleay-perl libpam-runtime \
                              libssl-dev openssl ntp perl postgresql-client-$PGVER     \
                              python python-magic s3cmd     \
                              unzip wget whiptail xsltproc xvfb
      RET=$?
      if [ $RET -ne 0 ]; then
        die "Something went wrong installing prerequisites for $DISTRO/$CODENAME. Check the log for more info. "
      fi

      if $IS_DEV_ENV ; then
        sudo apt-get --quiet -y install g++ gcc make vim zsh
      fi

      if [ "$CODENAME" != "bionic"]; then
        sudo apt-get --quiet -y install python-software-properties
      fi

      # Install LE prerequsites
      sudo add-apt-repository -y ppa:certbot/certbot
      sudo apt-get --yes --quiet update
      sudo apt-get --yes --quiet install software-properties-common python-certbot-nginx

      # fix the background color
      sudo sed -i 's/magenta/blue/g' /etc/newt/palette.ubuntu
      ;;
    "centos")
      die "Maybe one day we will support CentOS..."
      ;;
    *)
      die "Please report a bug that install_prereqs tried to process $DISTRO"
      ;;
  esac
}

install_pg_repo() {
  case "$CODENAME" in
    "trusty") ;&
    "utopic") ;&
    "xenial") ;&
    "bionic")
        # check to make sure the PostgreSQL repo is already added on the system
        if [ ! -f /etc/apt/sources.list.d/pgdg.list ] || ! grep -q "apt.postgresql.org" /etc/apt/sources.list.d/pgdg.list; then
          sudo bash -c "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -"
          sudo bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
        fi
        ;;
  esac
}

# $1 is the port
# $2 is protocol
is_port_open() {
  (echo >/dev/$2/localhost/$1) &>/dev/null && return 0 || return 1
}

new_postgres_port() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  PGPORT=$((seq 5432 5500 ; sudo pg_lsclusters -h | awk '{print $3}') | \
           sort --numeric-sort | head --lines 1)
}

new_nginx_port() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  WEBAPI_PORT=$((seq 8443 8500 ; \
                sudo head --lines 2 /etc/nginx/sites-available/* | \
                   grep --only-matching '8[0-9]{3}') | \
               sort --numeric-sort | head --lines 1)
}

test_connection() {
  log "Testing internet connectivity..."
  wget --quiet --tries=5 --timeout=10 -O - http://files.xtuple.org > /dev/null
  if [[ $? -eq 0 ]]; then
    log "Internet connectivity detected."
    return 0
  else
    log "Internet connectivity not detected."
    return 1
  fi
}

setup_sudo() {
# echo "In: ${BASH_SOURCE} ${FUNCNAME[@]}"

  if [[ ! -f "/etc/sudoers.d/${DEPLOYER_NAME}" ]] || ! grep -q "${DEPLOYER_NAME}" /etc/sudoers.d/${DEPLOYER_NAME}; then
    printf "${DEPLOYER_NAME} ALL=(ALL) NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers.d/${DEPLOYER_NAME} >/dev/null
    sudo chmod 440 /etc/sudoers.d/${DEPLOYER_NAME}
  else
    echo "User: $DEPLOYER_NAME already setup in sudoers.d"
  fi
}

service_start () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[@]} $@"
  local SERVICE="$1"

  # shutdown node datasource
  if [ $DISTRO = "ubuntu" ]; then
    case "$CODENAME" in
      "trusty") ;&
      "utopic")
        log_exec sudo service $SERVICE start
        ;;
      "vivid") ;&
      "xenial") ;&
      "bionic")
        log_exec sudo systemctl enable $SERVICE
        log_exec sudo systemctl start  $SERVICE
        ;;
    esac
  else
    die "Don't know how to stop a service on $DISTRO $CODENAME"
  fi
}

service_stop () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[@]} $@"
  local SERVICE="$1"

  # shutdown node datasource
  if [ $DISTRO = "ubuntu" ]; then
    case "$CODENAME" in
      "trusty") ;&
      "utopic")
        log_exec sudo service $SERVICE stop
        ;;
      "vivid") ;&
      "xenial") ;&
      "bionic")
        log_exec sudo systemctl stop    $SERVICE
        log_exec sudo systemctl disable $SERVICE
        ;;
    esac
  else
    die "Don't know how to stop a service on $DISTRO $CODENAME"
  fi
}

service_restart () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[@]} $@"
  local SERVICE="$1"

  if [ "$SERVICE" = postgresql -a -n "$PGVER" -a -n "$POSTNAME" ] ; then
    log_exec sudo pg_ctlcluster $PGVER "$POSTNAME" stop --force
    log_exec sudo pg_ctlcluster $PGVER "$POSTNAME" start
    RET=$?
  elif [ $DISTRO = "ubuntu" ]; then
    case "$CODENAME" in
      "trusty") ;&
      "utopic")
        log_exec sudo service $SERVICE restart
        RET=$?
        ;;
      "vivid") ;&
      "xenial") ;&
      "bionic")
        log_exec sudo systemctl enable  $SERVICE
        log_exec sudo systemctl restart $SERVICE
        RET=$?
        ;;
    esac
  else
    die "Don't know how to stop a service on $DISTRO $CODENAME"
  fi
  if [ $RET -eq 0 ] ; then
    msgbox "Service $SERVICE restarted successfully"
  else
    msgbox "Could not restart $SERVICE"
    return $RET
  fi
}

service_reload () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[@]} $@"
  local SERVICE="$1"
  local RET=0

  # TODO: why is this different?
  if [ "$SERVICE" = nginx ] ; then
    log_exec sudo nginx -s reload
    RET=$?
  elif [ $DISTRO = "ubuntu" ]; then
    case "$CODENAME" in
      "trusty") ;&
      "utopic")
        log_exec sudo service $SERVICE reload
        RET=$?
        ;;
      "vivid") ;&
      "xenial") ;&
      "bionic")
        log_exec sudo systemctl reload $SERVICE
        RET=$?
        ;;
    esac
  else
    die "Don't know how to reload $SERVICE on $DISTRO $CODENAME"
  fi
  return $RET
}

gitco() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[@]} $@"

  local REPO="$(basename $1 .git)"
  local DESTDIR="$2"
  local REFSPEC="$3"
  GITHUBNAME="${4:-$GITHUBNAME}"
  GITHUBPASS="${5:-${GITHUBPASS:-${GITHUB_TOKEN}}}"

  local STARTDIR=$(pwd)
  local GHUSERSPEC=

  if [ -z "$REFSPEC" ] ; then
    # TODO: use jq
    REFSPEC=$(curl https://api.github.com/repos/xtuple/$REPO | \
             awk -v FS='"' '/default_branch/ { print $4 }')
    [ -n "$REFSPEC" ] || REFSPEC=master
  fi

  if [ -n "$GITHUBPASS" ] ; then
    GHUSERSPEC="$GITHUBNAME:$GITHUBPASS@"
  elif [ -n "$GITHUBNAME" ] ; then
    GHUSERSPEC="$GITHUBNAME@"
  fi

  log_exec mkdir --parents "$DESTDIR"
  cd "$DESTDIR"
  if [ ! -d $REPO/.git ] ; then
    log_exec git clone https://${GHUSERSPEC}github.com/xtuple/$REPO.git || die
  fi
  cd $REPO
  log_exec git fetch
  if ! git remote -v | grep -q xtuple/$REPO ; then
    git remote add XTUPLE https://github.com/xtuple/$REPO.git
    git fetch https://${GHUSERSPEC}github.com/xtuple/$REPO.git
  fi

  if [ "$REFSPEC" = "TAG" ] ; then
    git fetch --tags
    REFSPEC=$(git describe --tags $(git rev-list --tags --max-count=1))
  fi

  log_exec git checkout $REFSPEC                           || die
  log_exec git submodule update --init --recursive         || die

  if [[ -f package.json ]] ; then
    log_exec npm install                          || die "npm failure"
  fi

  repo_setup $REPO
  cd "$STARTDIR"
}

# perform any special handling required for particular repositories after checkout
repo_setup() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local REPO="${1}"

  case "$REPO" in
    xtuple)
      export BUILD_XT_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))
      ;;
    payment-gateways)
      git clean -d -f -x
      log_exec make
      ;;
    *) echo $REPO does not need special treatment
      ;;
  esac
}

# define some colors if the tty supports it
if [[ -t 1 && ! $COLOR = "NO" ]]; then
  COLOR1='\e[1;39m'
  COLOR2='\e[1;32m'
  COLOR3='\e[1;35m'
  COLOR4='\e[1;36m'
  COLOR5='\e[1;34m'
  COLOR6='\e[1;33m'
  COLOR7='\e[1;31m'
  ENDCOLOR='\e[0m'
  S='\\'
fi

fi # }
