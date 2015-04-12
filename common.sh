#!/bin/bash

do_exit() {
    if [ $REBOOT -eq 1 ]; then
        whiptail --backtitle "$( window_title )" --msgbox \
        "You need to reboot your server for the changes to take effect" 0 0
    fi
    log "Exiting xTuple Admin Utility"
    exit 0
}

# $1 is the URL
# $2 is the name of what is downloading to show on the window
# $3 is the output file name
dlf() {
    log "Downloading $1 to file $3 using wget"
    wget "$1" 2>&1 -O "$3"  | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | whiptail --backtitle "$( window_title )" --gauge $2 0 0 100;
}

# $1 is the URL
# $2 is the name of what is downloading to show on the window
# $3 is the output file name
dlf_fast() {
    log "Downloading $1 to file $3 using axel"
    axel -n 5 "$1" -o "$3" 2>&1 | stdbuf -o0 awk '/[0-9][0-9]?%+/ { print substr($0,2,3) }' | whiptail --backtitle "$( window_title )" --gauge "$2" 0 0 100;
}

# $1 is the msg
msgbox() {
    log "MessageBox >> ""$1"
    whiptail --backtitle "$( window_title )" --msgbox "$1" 0 0 0 
}

# $1 is the product
latest_version() {
    VER=`curl -s http://files.xtuple.org/latest_$1`
    echo $VER
}

window_title() {
    if [ -z $PGHOST ] && [ -z $PGPORT ] && [ -z $PGUSER ] && [ -z $PGPASSWORD ]; then
        echo "xTuple Admin Utility v$_REV -=- Current Connection Info: Not Connected"
    elif [ ! -z $PGHOST ] && [ ! -z $PGPORT ] && [ ! -z $PGUSER ] && [ -z $PGPASSWORD ]; then
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

# these are both the same currently, but the structure may change eventually
# as we add more supported distros
install_prereqs() {

    case "$DISTRO" in
        "ubuntu")
                install_pg_repo
                sudo apt-get update && sudo apt-get -y install axel git whiptail unzip bzip2 wget curl build-essential libssl-dev postgresql-client-9.3 cups python-software-properties openssl apt-show-versions libnet-ssleay-perl  libauthen-pam-perl libpam-runtime libio-pty-perl perl libavahi-compat-libdnssd-dev python 
                RET=$?
                if [ $RET -eq 1 ]; then
                    msgbox "Something went wrong installing prerequisites for $DISTRO. Check the output for more info. "
                    do_exit
                fi
                ;;
        "debian")
                sudo add-apt-repository -y "deb http://ftp.debian.org/debian wheezy-backports main"
                sudo apt-get update && sudo apt-get -y install axel git whiptail unzip bzip2 wget curl build-essential libssl-dev postgresql-client-9.3
                RET=$?
                if [ $RET -eq 1 ]; then
                    msgbox "Something went wrong installing prerequisites for $DISTRO. Check the output for more info. "
                    do_exit
                fi
                ;;
         "centos")
                log "Maybe one day we will support CentOS..."
                do_exit
                ;;
        *)
        log "Shouldn't reach here! Please report this on GitHub."
        exit 0
        ;;
    esac

}

install_pg_repo() {
    # check to make sure the PostgreSQL repo is already added on the system
    if [ ! -f /etc/apt/sources.list.d/pgdg.list ] || ! grep -q "apt.postgresql.org" /etc/apt/sources.list.d/pgdg.list; then
        sudo bash -c "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -"
        sudo bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
        sudo apt-get update
    fi
}

# $1 is the port
# $2 is protocol
is_port_open() {

    (echo >/dev/$2/localhost/$1) &>/dev/null && return 0 || return 1

}
