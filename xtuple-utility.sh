#!/bin/bash

# Some variables.
REBOOT=0
DATE=`date +%Y.%m.%d-%H.%M`
export _REV="0.1Alpha"

if [ `whoami` != "root" ]; then
    echo "You must run xtuple-utility as root."
    echo "sudo $0"
    exit 0
fi

# check what distro we are running.
_DISTRO=`lsb_release -i -s`
_CODENAME=`lsb_release -c -s`
case "$_DISTRO" in
    "Ubuntu")
        export DISTRO="ubuntu"
        case "$_CODENAME" in
            "trusty") ;;
            "utopic") ;;
            *) echo "We currently only support Ubuntu 14.04 LTS and 14.10. Current release: `lsb_release -r -s`" 
               exit 0
               ;;
        esac
        ;;
    "Debian")
        export DISTRO="debian"
        ;;
    "CentOS")
        echo "Maybe one day we will support CentOS..."
        exit 0
        ;;
    *)
        echo "We do not currently support your distribution."
        echo "Currently Supported: Ubuntu or Debian"
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
source logging.sh

# kind of hard to build whiptail menus without whiptail installed
install_prereqs

# we load mainmenu.sh last since it calls its menu once it builds it
# and this is the initial interface for the user
source mainmenu.sh

