#!/bin/bash

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

safecp() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local USAGE="$FUNCNAME[0] [ -U username | --username=username ] source target"
  local USER=
  if [[ "$1" =~ ^-U(.*) ]] ; then
    USER=$BASH_REMATCH[1]
    shift
    if [ -z "$USER" ] ; then
      USER="$1"
    fi
    shift
  elif [[ "$1" =~ ^--username=(.*) ]] ; then
    USER="$1"
    shift
  fi

  if [ $# -lt 2 ] ; then
    die "$USAGE\n$FUNCNAME[0]: needs a source and target"
  elif [ $# -gt 2 ] ; then
    die "$USAGE\n$FUNCNAME[0]: cannot handle more than one source"
  fi

  local SRC="$1"
  local TGT="$2"
  if [ -d "$TGT" ] ; then
    TGT="$TGT/$(basename $SRC)"
  fi

  if [ -e "${TGT}" ] ; then
    sudo mv "${TGT}" "${TGT}.${WORKDATE}"
  fi
  sudo cp "${SRC}" "${TGT}" || die "Error copying ${SRC} to ${TGT}; look for ${TGT}.${WORKDATE}"
  if [ -n "$USER" ] ; then
    sudo chown ${USER} "${TGT}"
  fi
}

# $1 is the URL
# $2 is the name of what is downloading to show on the window
# $3 is the output file name
dlf() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Downloading $1 to file $3 using wget"
  wget "$1" 2>&1 -O "$3"  | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | whiptail --backtitle "$( window_title )" --gauge $2 0 0 100;
  return ${PIPESTATUS[0]}
}

# $1 is the URL
# $2 is the name of what is downloading to show on the window
# $3 is the output file name
dlf_fast() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Downloading $1 to file $3 using axel"
  axel -n 5 "$1" -o "$3" 2>&1 | stdbuf -o0 awk '/[0-9][0-9]?%+/ { print substr($0,2,3) }' | whiptail --backtitle "$( window_title )" --gauge "$2" 0 0 100;
  return ${PIPESTATUS[0]}
}

# $1 is the URL
# $2 is the output file name
dlf_fast_console() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  if [ $# -lt 2 ] ; then
    die "$FUNCNAME[0]: url dest [ file-mode ]"
  fi
  local URL="$1"
  local FILE="$(basename $URL)"
  local DEST="$2"
  local MODE="$3"

  # TODO: why axel?
  #wget "$URL" && chmod +x "$FILE" && sudo mv "$FILE" "$DEST"
  log "Downloading $URL to file $DEST"
  sudo axel --num-connections=5 --output="$DEST" "$URL" > /dev/null
  [ -z "$MODE" ] || chmod "$MODE" ${DEST}
}

# $1 is the msg
msgbox() {
  log "MessageBox >> ""$1"
  [ $MODE = "manual" ] && whiptail --backtitle "$( window_title )" --msgbox "$1" 0 0 0
}

# $1 is the product
latest_version() {
  VER=`curl -s http://files.xtuple.org/latest_$1`
  echo $VER
}

window_title() {
  if [ -z "$PGHOST" ] && [ -z "$PGPORT" ] && [ -z "$PGUSER" ]; then
    echo "xTuple Admin Utility v$_REV -=- Current Connection Info: Not Connected"
  elif [ ! -z "$PGHOST" ] && [ ! -z "$PGPORT" ] && [ ! -z "$PGUSER" ]; then
    echo "xTuple Admin Utility v$_REV -=- Current Server $PGUSER@$PGHOST:$PGPORT -=- Password Is Not Set"
  else
    echo "xTuple Admin Utility v$_REV -=- Current Server $PGUSER@$PGHOST:$PGPORT -=- Password Is Set"
  fi
}

# $1 is text to display
menu_title() {
  cat "$WORKDIR"/xtuple.asc
  echo "$1"
}

# used whenever a command needs elevated privileges as we can't always rely on sudo
runasroot() {
  if [[ $UID -eq 0 ]]; then
    "$@"
  elif sudo -v &>/dev/null && sudo -l "$@" &>/dev/null; then
    sudo -E "$@"
  else
    echo -n "root "
    su -c "$(printf '%q ' "$@")"
  fi
}

# these are both the same currently, but the structure may change eventually
# as we add more supported distros
install_prereqs() {

    case "$DISTRO" in
        "ubuntu")
                install_pg_repo
                sudo apt-get update
                sudo apt-get -y install axel git whiptail unzip bzip2 wget curl build-essential libssl-dev postgresql-client-$PGVER cups python-software-properties openssl libnet-ssleay-perl libauthen-pam-perl libpam-runtime libio-pty-perl perl libavahi-compat-libdnssd-dev python xvfb jq s3cmd python-magic dialog xsltproc

                RET=$?
                if [ $RET -ne 0 ]; then
                    msgbox "Something went wrong installing prerequisites for $DISTRO/$CODENAME. Check the log for more info. "
                    do_exit
                fi

                # Install LE prerequsites
                source letsencrypt/installLE.sh

                # fix the background color
                sudo sed -i 's/magenta/blue/g' /etc/newt/palette.ubuntu
                ;;
        "debian")
                install_pg_repo
                sudo apt-get update
                sudo apt-get -y install python-software-properties software-properties-common xvfb
                if [ ! "$(find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep backports)" ]; then
                    sudo add-apt-repository -y "deb http://ftp.debian.org/debian $(lsb_release -cs)-backports main"
                    sudo apt-get update
                fi
                sudo apt-get -y install axel git whiptail unzip bzip2 wget curl build-essential libssl-dev postgresql-client-$PGVER
                RET=$?
                if [ $RET -ne 0 ]; then
                    msgbox "Something went wrong installing prerequisites for $DISTRO/$CODENAME. Check the log for more info. "
                    do_exit
                fi
                ;;
         "centos")
                log "Maybe one day we will support CentOS..."
                do_exit
                ;;
        *)
        log "Shouldn't reach here! Please report this on GitHub. install_prereqs"
        do_exit
        ;;
    esac

}

install_pg_repo() {

    case "$CODENAME" in
        "trusty") ;&
        "utopic") ;&
        "wheezy") ;&
        "jessie") ;&
        "xenial")
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
  NGINX_PORT=$((seq 8443 8500 ; \
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
  echo "In: ${BASH_SOURCE} ${FUNCNAME[@]}"

  if [[ ! -f "/etc/sudoers.d/${DEPLOYER_NAME}" ]] || ! grep -q "${DEPLOYER_NAME}" /etc/sudoers.d/${DEPLOYER_NAME}; then
    printf "${DEPLOYER_NAME} ALL=(ALL) NOPASSWD: ALL\n" | sudo tee -a /etc/sudoers.d/${DEPLOYER_NAME}
    sudo chmod 440 /etc/sudoers.d/${DEPLOYER_NAME}
  else
    echo "User: $DEPLOYER_NAME already setup in sudoers.d"
  fi
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

