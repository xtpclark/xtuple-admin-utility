#!/bin/bash

do_exit() {
	if [ $REBOOT -eq 1 ]; then
		whiptail --backtitle "xTuple Utility v$_REV" --msgbox \
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
	whiptail --backtitle "xTuple Utility v$_REV" --msgbox "$1" 0 0 0 
}

latest_version() {
    # $1 is the product
    echo `curl -s http://files.xtuple.org/latest_$1`
}

install_prereqs() {
case "$DISTRO" in
	"ubuntu")
			apt-get update && apt-get -y install axel git xz-utils whiptail unzip wget curl postgresql-client-9.3
			;;
	 "debian")
			apt-get update && apt-get -y install axel wget curl unzip whiptail git postgresql-client-9.3
			;;
	*)
	echo "Shouldn't reach here! Please report this on GitHub."
	exit 0
	;;
esac
}