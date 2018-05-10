#!/bin/bash

PROG=$0

DATE=$(date +%Y.%m.%d-%H:%M)
export _REV="1.0"
export WORKDIR=$(pwd)
export MODE="manual"

#set some defaults
source config.sh        || die
source common.sh        || die

mkdir --parents $DATABASEDIR
mkdir --parents $BACKUPDIR

# sets up sudoer.d
setup_sudo

# process command line arguments (see bash man page for getopts info)
while getopts ":acd:mip:n:H:D:qhx:t:-:" opt; do
  case $opt in
    a)
      INSTALLALL=true
      ;;
    d)
      DATABASE=$OPTARG
      log "Database name set to $DATABASE via command line argument -d"
      ;;
    m)
      MODE="auto"
      ;;
    p)
      PGVER=$OPTARG
      log "PostgreSQL Version set to $PGVER via command line argument -p"
      ;;
    H)
      NGINX_HOSTNAME=$OPTARG
      log "NGINX hostname set to $NGINX_HOSTNAME via command line argument -H"
      ;;
    D)
      NGINX_DOMAIN=$OPTARG
      log "NGINX domain set to $NGINX_DOMAIN via command line argument -D"
      ;;
    q)
      BUILDQT=true
      log "Building and installing Qt at the behest of -q"
      ;;
    x)
      # Use a specific version of xTuple (applies to web client and db)
      DBVERSION=$OPTARG
      DATABASE=${DBTYPE}${DBVERSION//./}
      log "xTuple version set to $DBVERSION via command line argument -x"
      ;;
    t)
      # type of database to install (demo/quickstart/empty)
      DBTYPE=$OPTARG
      log "xTuple database type set to $DBTYPE via command line argument -x"
      ;;
    h) cat <<-EOUsage
	Usage: $PROG [OPTION]
	$( menu_title )
	To get an interactive menu run $PROG with no arguments

	  -h	Show this message
	  -a	Install all:
                  PostgreSQL $(latest_version pg)
                  demo database $(latest_version db)
                  web API $(latest_version db)
                  xTupleCommerce
	  -d	Specify database name to create
	  -p	Override PostgreSQL version
	  -q	Build and Install Qt $(latest_version qt_sdk)
	  -n	Override instance name
	  -H	Set NGINX hostname
	  -D	Set NGINX domain
	  -x	Override xTuple version (web API and database)
	  -t	Specify the type of database to grab (demo/quickstart/empty)
EOUsage
      exit 0
      ;;
    \?)
      log "Invalid option: -$OPTARG"
      exit 1
      ;;
    :)
      log "Option -$OPTARG requires an argument."
      exit 1
      ;;
  esac
done

if [ $(uname -m) != "x86_64" ]; then
  die "$PROG only runs on 64bit servers"
fi

log "Starting xTuple Admin Utility..."

log "Checking for sudo..."
if ! which sudo > /dev/null ; then
  log "Please install sudo and grant yourself access to sudo:"
  log "   # apt-get install sudo"
  log "   # addgroup $USER sudo"
  exit 1
fi

test_connection
RET=$?
if [ $RET -ne 0 ]; then
  die "I can't tell if you have internet access or not. Please check that you have internet connectivity and that http://files.xtuple.org is online.  "
fi

# check what distro we are running.
export DISTRO=$(lsb_release -i -s | tr "[A-Z]" "[a-z]")
export CODENAME=$(lsb_release -c -s)
case "$DISTRO" in
  "ubuntu")
    case "$CODENAME" in
      "trusty") ;;
      "utopic") ;;
      "vivid") ;;
      "xenial") ;;
      *) die "We currently only support Ubuntu 14.04 LTS, 14.10, 15.04, and 16.04 LTS. Current release: $(lsb_release -r -s)"
         ;;
    esac
    ;;
  "centos")
    die "Maybe one day we will support CentOS..."
    ;;
  *)
    log "We do not currently support your distribution."
    log "Currently Supported: Ubuntu"
    log "distro info: "
    lsb_release -a
    do_exit
    ;;
esac

# Load the rest of the scripts
source postgresql.sh            || die
source database.sh              || die
source xdruple.sh               || die
source nginx.sh                 || die
source mobileclient.sh          || die
source devenv.sh                || die
source conman.sh                || die
source tokenmanagement.sh       || die
source functions/setup.fun      || die
source functions/gitvars.fun    || die
source functions/oatoken.fun    || die

log "Installing pre-requisite packages..."
if [[ ! -f .already_ran_update ]]; then
  install_prereqs
  touch .already_ran_update
else
  log ".already_ran_update exists - skipping."
  log "Remove the file if you want apt-get to update the system"
fi

# if we were given command line options for installation process them now
if [ $INSTALLALL ]; then
  log "Executing full provision..."
  MODE="auto"

  DBVERSION="${DBVERSION:-4.11.3}"
  EDITION="${EDITION:-demo}"
  DATABASE="${DATABASE:-xtuple}"
  MWCNAME="${MWCNAME:-web}"
  PGPORT=${PGPORT:-5432}
  PGUSER=${PGUSER:-postgres}

  NGINX_HOSTNAME="${NGINX_HOSTNAME:-myhost}"
  NGINX_DOMAIN="${NGINX_DOMAIN:-mydomain.com}"

  get_github_token
  [ -n "$GITHUBNAME" ]                       || die "Full provisioning needs your GITHUBNAME"
  [ -n "$GITHUBPASS" -o -n "$GITHUB_TOKEN" ] || die "Full provisioning needs either GITHUBPASS or GITHUB_TOKEN"

  install_postgresql "$PGVER"
  provision_cluster "$PGVER" "${POSTNAME:-xtuple}" $PGPORT "$LANG" "--start-conf=auto"
  download_database "$DATABASEDIR/$EDITION_$DBVERSION.backup" "$DBVERSION" "$EDITION"
  restore_database "$DATABASEDIR/$EDITION_$DBVERSION.backup" "$DATABASE"

  install_xtuple_xvfb

  log_exec rm -f "$WORKDIR/tmp.backup{,.md5sum}"
  install_webclient "v$DBVERSION" "v$DBVERSION" "$MWCNAME" false "$DATABASE"
  install_nginx
  log_exec sudo mkdir --parents $CONFIGDIR/ssl
  configure_nginx "$NGINX_HOSTNAME" "$NGINX_DOMAIN" "$MWCNAME" $CONFIGDIR/ssl/server.{crt,key}

  get_os_info
  prepare_os_for_xtc
  get_deployer_info
  deployer_setup
  php_setup
  xtc_pg_setup
  postfix_setup
  ruby_setup
  drupal_crontab
  xtc_code_setup
  setup_flywheel
  update_site
  webnotes
fi

# TODO: build qt in the background?
# build Qt before doing anything else because it takes *FOREVER*
if [ $BUILDQT ]; then
  log "Building and installing Qt5 from source"
  install_dev_prereqs
  build_qt5
fi

# we expect INSTALLALL and Qt builds to be run headlessly
if [ $BUILDQT ] || [ $INSTALLALL ]; then
  do_exit
fi

# load the user interface - mainmenu.sh - after we've set up the basics
source mainmenu.sh
