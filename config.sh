# Actions to take when the utility is run
ACTIONS=()

WORKING=$(pwd)
TMPDIR=${TMPDIR:-/tmp}

# default configurations
LOG_FILE=$(pwd)/install-$DATE.log

ISDEVELOPMENTENV=${ISDEVELOPMENTENV:-false}
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

NGINX_SITE=
NGINX_DOMAIN=
NGINX_HOSTNAME=
NGINX_PORT=${NGINX_PORT:-8443}
NGINX_CERT=
NGINX_KEY=

# generate new certs if the specified ones don't exist
GEN_SSL=false

# default mobile web instance to use
MWCNAME=
MWCVERSION=
# switch for private extensions to be installed
PRIVATEEXT=

# optional, but will prompt if missing
GITHUBNAME=
GITHUBPASS=

# return values from `dialog`
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_HELP=2
DIALOG_EXTRA=3
DIALOG_ITEM_HELP=4
DIALOG_ESC=255

# server | vagrant
export RUNTIMEENV=${RUNTIMEENV:-server}
export DEPLOYER_NAME=$(whoami)

export DEBIAN_FRONTEND=noninteractive

[ -z "$TZ" -a -e ${WORKDIR}/.timezone ] && source ${WORKDIR}/.timezone
if [ -z "${TZ}" ] ; then
  export TZ=$(tzselect) || die
  echo "export TZ=${TZ}" > ${WORKDIR}/.timezone
  if ! grep --quiet --word-regexp --no-messages TZ= \
            ${HOME}/.bashrc ${HOME}/.bash_profile ${HOME}/.profile ${HOME}/.zprofile ; then
    echo "export TZ=${TZ}" > ${HOME}/.profile
  fi
  echo "Remove ${WORKDIR}/.timezone and unset TZ to reset the timezone"
  sudo timedatectl set-timezone ${TZ}
fi
