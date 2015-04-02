#!/bin/bash

# Some variables.
REBOOT=0
DATE=`date +%Y.%m.%d-%H.%M`
export _REV="0.1Alpha"

if [ `whoami` != "root" ]; then
    echo "You must run the app as root."
    echo "sudo $0"
    exit 0
fi

# check what distro we are running.
_R=`lsb_release -i -s`

case "$_R" in
    "Ubuntu")
        export DISTRO="ubuntu"
        ;;
    "Debian")
        export DISTRO="debian"
        ;;
    "CentOS")
        echo "Maybe one day we will support CentOS..."
        do_exit
        ;;
    *)
        echo "I couldn't identify your distribution."
        echo "Please report this error on GitHub"
        echo "distro info: "
        lsb_release -a
        exit 0
        ;;
esac

# Load the scripts
source common.sh
source postgresql.sh
source database.sh
source provision.sh
source nginx.sh

# kind of hard to build whiptail menus without whiptail installed
install_prereqs

# we load mainmenu.sh last since it calls its menu once it builds it
# and this is the initial interface for the user
source mainmenu.sh

