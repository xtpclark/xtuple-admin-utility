#!/bin/bash

REBOOT=0
DATE=`date +%Y.%m.%d-%H.%M`
export _REV="0.1Alpha"
export WORKDIR=`pwd`

# import supporting scripts
source logging.sh
source common.sh

if [ `uname -i` != "x86_64" ]; then
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

#alias sudo='sudo env PATH=$PATH $@'

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
        case "$_CODENAME" in
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

# process command line arguments
while getopts ":d:ipnhmx-:" opt; do
  case $opt in
    d)
        PG_VERSION=$OPTARG
        log "PostgreSQL Version set to $PG_VERSION via command line argument"
        ;;
    i)
        # Install packages
        RUNALL=
        INSTALL=true
        ;;
    p)
        # Configure postgress
        RUNALL=
        POSTGRES=true
        ;;
    n)
        # iNitialize the databases and stuff
        RUNALL=
        INIT=true
        ;;
    m)
        RUNALL=
        NPM_INSTALL=true
        ;;
    x)
        # Checkout a specific version of the xTuple repo
        XT_VERSION=$OPTARG
        log "xTuple MWC Version set to $XT_VERSION via command line argument"
        ;;
    node)
        # select the version to use for nodejs
        NODE_VERSION=$OPTARG
        log "NodeJS Version set to $NODE_VERSION via command line argument"
        ;;
    h)
        echo "Usage: xtuple-utility [OPTION]"
        echo "$( menu_title )"
        echo "To get an interactive menu run xtuple-utility.sh with no arguments"
        echo ""
        echo -e "  -h\tshow this message"
        echo -e "  -i\tinstall packages"
        echo -e "  -p\tinstall PostgreSQL"
        echo -e "  -n\tinit database"
        echo -e "  -m\tnpm install"
        echo -e "  -x\tspecify xTuple version"
        echo -e "  -d\tspecify PostgreSQL version"
        exit 0;
      ;;
  esac
done

# Load the rest of the scripts
source postgresql.sh
source database.sh
source provision.sh
source nginx.sh
source mobileclient.sh

# kind of hard to build whiptail menus without whiptail installed
log "Installing pre-requisite packages..."
install_prereqs

# we load mainmenu.sh last since it calls its menu once it builds it
# and this is the initial interface for the user
source mainmenu.sh
