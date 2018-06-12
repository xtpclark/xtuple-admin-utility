#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$CONFIG_SH" ] ; then # {
CONFIG_SH=true

# Actions to take when the utility is run
ACTIONS=()

export TMPDIR=${TMPDIR:-/tmp}
export DEBIAN_FRONTEND=noninteractive

WORKDIR=$(pwd)
DEPLOYER_NAME=$(whoami)
LOG_FILE=$(pwd)/install-$DATE.log
XTAU_CONFIG=

IS_DEV_ENV=${IS_DEV_ENV:-false}
XTC_HOST_IS_REMOTE=${XTC_HOST_IS_REMOTE:-false}
DATABASEDIR=${WORKDIR}/databases
BACKUPDIR=${WORKDIR}/backups
DBTYPE=${DBTYPE:-empty}
ERP_EDITION=${ERP_EDITION:-postbooks}
ERP_ISS="${ERP_ISS:-xTupleCommerceID}"

export PGVER=${PGVER:-9.6}
export PGHOST=${PGHOST:-localhost}
export PGUSER=${PGUSER:-postgres}
export POSTLOCALE=$LANG

# leave these undefined. otherwise we may waste lots of time looking for avoidable bugs
export PGNAME=
export PGPORT=

# TODO: what's the difference between NGINX_DOMAIN and DOMAIN?
export DOMAIN=flywheel.xd

export NGINX_SITE=
export NGINX_HOSTNAME="${NGINX_HOSTNAME:-myhost}"
export NGINX_DOMAIN="${NGINX_DOMAIN:-mydomain.com}"
export WEBAPI_PORT=${WEBAPI_PORT:-8443}
export NGINX_CERT=
export NGINX_KEY=

# generate new certs if the specified ones don't exist
GEN_SSL=false

# default mobile web instance to use
MWCNAME=
BUILD_XT_TAG=
# switch for private extensions to be installed
PRIVATEEXT=${PRIVATEEXT:-false}

# optional, but will prompt if missing
GITHUBNAME=${GITHUBNAME}
GITHUBPASS=${GITHUBPASS}

# return values from `dialog`
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_HELP=2
DIALOG_EXTRA=3
DIALOG_ITEM_HELP=4
DIALOG_ESC=255

[ -z "$TZ" -a -e ${WORKDIR}/.timezone ] && source ${WORKDIR}/.timezone
if [ -z "${TZ}" ] ; then
  export TZ=$(tzselect) || exit 1
  echo "export TZ=${TZ}" > ${WORKDIR}/.timezone
  if ! grep --quiet --word-regexp --no-messages TZ= \
            ${HOME}/.bashrc ${HOME}/.bash_profile ${HOME}/.profile ${HOME}/.zprofile ; then
    echo "export TZ=${TZ}" > ${HOME}/.profile
  fi
  echo "Remove ${WORKDIR}/.timezone and unset TZ to reset the timezone"
  sudo locale-gen en_US.UTF-8          || exit 1
  sudo timedatectl set-timezone ${TZ}  || exit 1
fi

fi # }
