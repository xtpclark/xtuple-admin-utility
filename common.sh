#!/bin/bash

do_exit() {
	if [ $REBOOT -eq 1 ]; then
		whiptail --backtitle "$( window_title )" --msgbox \
		"You need to reboot your server for the changes to take effect" 0 0
	fi
	exit 0
}

dlf() {
	# $1 is the URL
	# $2 is the name of what is downloading to show on the window
	# $3 is the output file name
	wget "$1" 2>&1 -O $3  | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | whiptail --gauge "$2" 0 0 100
}

dlf_fast() {
	# $1 is the URL
	# $2 is the name of what is downloading to show on the window
	# $3 is the output file name
	axel -n 5 "$1" -o $3 2>&1 | stdbuf -o0 awk '/[0-9][0-9]?%+/ { print substr($0,2,3) }' | whiptail --backtitle "xTuple Server v$_REV" --gauge "$2" 0 0 100
}

msgbox() {
	# $1 is the msg
	whiptail --backtitle "$( window_title )" --msgbox "$1" 0 0 0 
}

latest_version() {
    # $1 is the product
    echo `curl -s http://files.xtuple.org/latest_$1`
}

window_title() {

    if [ -z $PGHOST ] && [ -z $PGPORT ] && [ -z $PGUSER ] && [ -z $PGPASSWORD ]; then
        echo "xTuple Utility v$_REV -=- Current Connection Info: Not Connected"
    elif [ ! -z $PGHOST ] && [ ! -z $PGPORT ] && [ ! -z $PGUSER ] && [ -z $PGPASSWORD ]; then
        echo "xTuple Utility v$_REV -=- Current Server $PGUSER@$PGHOST:$PGPORT -=- Password Is Not Set"
    else
        echo "xTuple Utility v$_REV -=- Current Server $PGUSER@$PGHOST:$PGPORT -=- Password Is Set"
    fi
}
# $1 is text to display
menu_title() {
    cat xtuple.asc
    echo "$1"
}

# these are both the same currently, but the structure may change eventually
# as we add more supported distros
install_prereqs() {
case "$DISTRO" in
	"ubuntu")
			apt-get update && apt-get -y install axel git whiptail unzip bzip2 wget curl postgresql-client-9.3
			;;
	 "debian")
			apt-get update && apt-get -y install axel git whiptail unzip bzip2 wget curl postgresql-client-9.3
			;;
     "centos")
            echo "Maybe one day we will support CentOS..."
            do_exit
            ;;
	*)
	echo "Shouldn't reach here! Please report this on GitHub."
	exit 0
	;;
esac
}
