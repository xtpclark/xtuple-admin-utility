#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$CONFIG_SH" ] ; then # {
CONFIG_SH=true
PROG=${PROG:-$0}

# Actions to take when the utility is run
ACTIONS=()

export TMPDIR=${TMPDIR:-/tmp}
export DEBIAN_FRONTEND=noninteractive

WORKDIR=$(pwd)
DEPLOYER_NAME=$(whoami)
DATE=${DATE:-$(date +%Y.%m.%d-%H:%M)}
LOG_FILE=$(pwd)/install-${DATE}
XTAU_CONFIG=

IS_DEV_ENV=${IS_DEV_ENV:-false}
DATABASEDIR=${WORKDIR}/databases
BACKUPDIR=${WORKDIR}/backups
DBTYPE=${DBTYPE:-empty}

export PGHOST=${PGHOST:-localhost}
export PGUSER=${PGUSER:-postgres}
export POSTLOCALE=$LANG

# leave these undefined. otherwise we may waste lots of time looking for avoidable bugs
export PGNAME=
export PGPORT=

export NGINX_SITE=
export NGINX_HOSTNAME="${NGINX_HOSTNAME:-flywheel}"
export NGINX_DOMAIN="${NGINX_DOMAIN:-flywheel.xd}"
export NGINX_CERT
export NGINX_KEY

# generate new certs if the specified ones don't exist
GEN_SSL=false

# variables stored in XTAU_CONFIG files must be exported
export BUILD_XT_TAG
export CONFIGDIR
export SITE_TEMPLATE=${SITE_TEMPLATE:-flywheel}
export DOMAIN_ALIAS=${DOMAIN_ALIAS:-${SITE_TEMPLATE}.xtuple.net}
export ECOMM_DB_NAME
export ECOMM_DB_USERNAME
export ECOMM_DB_USERPASS
export ECOMM_EMAIL
export ECOMM_SITE_NAME
export ERP_APPLICATION
export ERP_DATABASE_NAME
export ERP_DEBUG="${ERP_DEBUG:-false}"
export ERP_EDITION=${ERP_EDITION:-postbooks}
export ERP_ISS="${ERP_ISS:-xTupleCommerceID}"
export ERP_KEY_FILE_PATH=${ERP_KEY_FILE_PATH:-/var/xtuple/keys}
export GITHUBNAME=${GITHUBNAME}
export GITHUBPASS=${GITHUBPASS}
export GITHUB_TOKEN
export HOSTNAME
export LOGDIR
export MAX_EXECUTION_TIME
export MWCNAME
export PGVER=${PGVER:-9.6}
export SERVER_CRT
export SERVER_KEY
export SYSLOGID
export TZ
export WEBAPI_HOST
export WEBAPI_PORT=${WEBAPI_PORT:-8443}
export WEBROOT
export WORKFLOW_ENV


PRIVATEEXT=${PRIVATEEXT:-false}

# return values from `dialog`
DIALOG_OK=0
DIALOG_CANCEL=1
DIALOG_HELP=2
DIALOG_EXTRA=3
DIALOG_ITEM_HELP=4
DIALOG_ESC=255

fi # }
