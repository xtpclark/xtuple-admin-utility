# Actions to take when the utility is run
ACTIONS=()

WORKING=$(pwd)
TMPDIR=${TMPDIR:-/tmp}

# default configurations
LOG_FILE=$(pwd)/install-$DATE.log

DATABASEDIR=$(pwd)/databases
BACKUPDIR=$(pwd)/backups

# leave these undefined. They should never be used in this utility because it would lead to hard to pinpoint easy to fix bugs that cause a disproportionate amount of wasted time.
PGNAME=
PGPORT=

# set these
PGVER=${PGVER:-9.6}
PGHOST=${PGHOST:-localhost}

# postgres user, required for all postgres/database actions
PGUSER=${PGUSER:-postgres}

# usually set to $LANG
POSTLOCALE=$LANG

# default nginx site to select
NGINX_SITE=
# auto populated if site exists, otherwise can be used to create a site
NGINX_DOMAIN=
NGINX_HOSTNAME=
NGINX_PORT=${NGINX_PORT:-8443}
NGINX_CERT=
NGINX_KEY=
# generate new certs if the specified ones don't exist
GEN_SSL=false

# default mobile web instance to use
MWCNAME=
# version tag
MWCVERSION=
# switch for private extensions to be installed
PRIVATEEXT=
# optional, but will prompt if missing
GITHUBNAME=
GITHUBPASS=

# Variables for xdruple-server
# Everything below here should be re-worked into it's
# own script because asking for git credentials at first init of xtau is ugly.
# git submodule update --init --recursive
# git submodule foreach git pull origin master

# export SCRIPTS_DIR=$(pwd)/xdruple-server/scripts
# export CONFIG_DIR=$(pwd)/xdruple-server/config

# export TYPE='server'
export DEPLOYER_NAME=$(whoami)
# export TIMEZONE=America/New_York

#sudo locale-gen en_US.UTF-8 && \
#export DEBIAN_FRONTEND=noninteractive
#sudo dpkg-reconfigure locales && \
#sudo echo ${TIMEZONE} > /etc/timezone
# sudo timedatectl set-timezone ${TIMEZONE}

# mkdir -p ~/.composer
