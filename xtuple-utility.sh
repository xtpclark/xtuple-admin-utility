#!/bin/bash

# process command line arguments
while getopts ":ad:ip:n:hx-:" opt; do
  case $opt in
    a)
        INSTALLALL=true
        ;;
    d)
        PGDATABASE=$OPTARG
        log "Database name set to $PGDATABASE via command line argument -d"
        ;;
    i)
        # Install pre-requisite packages
        PREREQS=true
        ;;
    p)
        PGVERSION=$OPTARG
        log "PostgreSQL Version set to $PGVERSION via command line argument -p"
        ;;
    n)
        # Name this instance
        INSTANCE=$OPTARG
        log "Instance name set to $INSTANCE via command line argument -n"
        ;;
    x)
        # Use a specific version of xTuple (applies to web client and db)
        XTVERSION=$OPTARG
        log "xTuple MWC Version set to $XTVERSION via command line argument -x"
        ;;
    e)
        # select the version to use for nodejs
        NODEVERSION=$OPTARG
        log "NodeJS Version set to $NODE_VERSION via command line argument"
        ;;
    h)
        echo "Usage: xtuple-utility [OPTION]"
        echo "$( menu_title )"
        echo "To get an interactive menu run xtuple-utility.sh with no arguments"
        echo ""
        echo -e "  -a\tinstall all (PostgreSQL, demo database (currently 4.8.1) and web client)"
        echo -e "  -h\tshow this message"
        echo -e "  -i\tinstall packages"
        echo -e "  -p\tinstall PostgreSQL"
        echo -e "  -n\tinit database"
        echo -e "  -x\tspecify xTuple version (applies to web client and database)"
        echo -e "  -d\tspecify PostgreSQL version"
        exit 0;
      ;;
  esac
done

REBOOT=0
DATE=`date +%Y.%m.%d-%H.%M`
export _REV="0.1Alpha"
export WORKDIR=`pwd`

#set some defaults
PGVERSION=9.3
XTVERSION=4.8.1
INSTANCE=xtuple
DBTYPE=demo

# import supporting scripts
source logging.sh
source common.sh

if [ `uname -m` != "x86_64" ]; then
    log "You must run this on a 64bit server only"
    do_exit
fi

log "Starting xTuple Admin Utility..."

log "Checking for sudo..."
if ! which sudo > /dev/null;
then
  log "Please install sudo and grant yourself access to sudo:"
  log "   # apt-get install sudo"
  log "   # addgroup $USER sudo"
  exit 1
fi

# check what distro we are running.
_DISTRO=`lsb_release -i -s`
_CODENAME=`lsb_release -c -s`
case "$_DISTRO" in
    "Ubuntu")
        export DISTRO="ubuntu"
        export CODENAME=$_CODENAME
        case "$_CODENAME" in
            "trusty") ;;
            "utopic") ;;
            *) log "We currently only support Ubuntu 14.04 LTS and 14.10. Current release: `lsb_release -r -s`" 
               do_exit
               ;;
        esac
        ;;
    "Debian")
        export DISTRO="debian"
        export CODENAME=$_CODENAME
        case "$_CODENAME" in
            "wheezy") ;;
            *) log "We currently don't support Debian (not quite yet!) Current release: `lsb_release -r -s`" 
               do_exit
               ;;
        esac
        ;;
    "CentOS")
        log "Maybe one day we will support CentOS..."
        do_exit
        ;;
    *)
        log "We do not currently support your distribution."
        log "Currently Supported: Ubuntu or Debian"
        log "distro info: "
        lsb_release -a
        do_exit
        ;;
esac

# Load the rest of the scripts
source postgresql.sh
source database.sh
source provision.sh
source nginx.sh
source mobileclient.sh

# kind of hard to build whiptail menus without whiptail installed
log "Installing pre-requisite packages..."
install_prereqs

# if we were given command line options for installation process them now
if [ $INSTALLALL ]; then
    log "Executing full provision..."
    install_postgresql $PGVERSION
    drop_cluster $PGVERSION main auto
    provision_cluster $PGVERSION $INSTANCE 5432 "$LANG" true auto
    prepare_database auto 
    download_demo auto $WORKDIR/tmp.backup $XTVERSION $DBTYPE
    restore_database $WORKDIR/tmp.backup $PGDATABASE
    install_mwc $XTVERSION $INSTANCE false $PGDATABASE
    do_exit
fi


# we load mainmenu.sh last since it calls its menu once it builds it
# and this is the initial interface for the user
source mainmenu.sh
