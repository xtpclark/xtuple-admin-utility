#!/bin/bash

REBOOT=0
DATE=`date +%Y.%m.%d-%H.%M`
export _REV="0.2Alpha"
export WORKDIR=`pwd`

#set some defaults
export PGVERSION=9.3
export XTVERSION=4.9.2
_XTVERSION=${XTVERSION//./}
export INSTANCE=xtuple
export DBTYPE=demo
export PGDATABASE="$DBTYPE""$_XTVERSION"
# import supporting scripts
source common.sh
source logging.sh

# process command line arguments
while getopts ":ad:ip:n:hx:-:" opt; do
  case $opt in
    a)
        INSTALLALL=true
        ;;
    d)
        PGDATABASE=$OPTARG
        log "Database name set to $PGDATABASE via command line argument -d"
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
    t)
        # Specify the type of database to grab (demo/quickstart/empty)
        DBTYPE=$OPTARG
        log "xTuple Database Type set to $DBTYPE via command line argument -x"
        ;;
    h)
        echo "Usage: xtuple-utility [OPTION]"
        echo "$( menu_title )"
        echo "To get an interactive menu run xtuple-utility.sh with no arguments"
        echo ""
        echo -e "  -h\tShow this message"
        echo -e "  -a\tInstall all (PostgreSQL (currently $( latest_version pg )), demo database (currently $( latest_version db )) and web client (currently $( latest_version db )))"
        echo -e "  -d\tSpecify database name to create"
        echo -e "  -p\tOverride PostgreSQL version"
        echo -e "  -n\tOverride instance name"
        echo -e "  -x\tOverride xTuple version (applies to web client and database)"
        echo -e "  -t\tSpecify the type of database to grab (demo/quickstart/empty)"
        exit 0;
        ;;
    \?)
        log "Invalid option: -$OPTARG"
        ;;
  esac
done

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

test_connection
RET=$?
if [ $RET -eq 1 ]; then
    log "I can't seem to tell if you have internet access or not. Please check that you have internet connectivity and that http://files.xtuple.org is online.  "
    do_exit
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
            "vivid") ;;
            *) log "We currently only support Ubuntu 14.04 LTS,14.10 and 15.04. Current release: `lsb_release -r -s`" 
               do_exit
               ;;
        esac
        ;;
    "Debian")
        export DISTRO="debian"
        export CODENAME=$_CODENAME
        case "$_CODENAME" in
            "wheezy") ;;
            "jessie") ;;
            *) log "We currently only support Debian 7 and 8 Current release: `lsb_release -r -s`" 
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
source openrpt.sh

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
    rm -f $WORKDIR/tmp.backup{,.md5sum}
    install_mwc $XTVERSION $INSTANCE false $PGDATABASE
    do_exit
fi


# we load mainmenu.sh last since it calls its menu once it builds it
# and this is the initial interface for the user
source mainmenu.sh
