#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$SETUP_FUN" ] ; then # {
SETUP_FUN=true

export WORKDATE=${WORKDATE:-$(date "+%m%d%y")}

source ${WORKDIR:-.}/functions/oatoken.fun

# read_config [ -s section ] [ -f ] [ config-file-to-process ]
# -s only read the named section of the config JSON
# -f force overwriting all runtime configuration to this point
#    (default is to ignore parts of the config that have already been set)
read_config() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  local FORCE=false
  local SCRIPT SECTION
  local STARTDIR=$(pwd)

  cd ${WORKDIR}

  while [[ "$1" =~ - ]] ; do
    case $1 in
      -s) SECTION=$2  ; shift ;;
      -f) FORCE=true          ;;
    esac
    shift
  done

  if [ -z "$XTAU_CONFIG" ] ; then
    XTAU_CONFIG=${4:-${MWCNAME:-xtau}_config.json}
  fi
  if [ ! -f $XTAU_CONFIG ] ; then
    cp templates/xtau_config.json $XTAU_CONFIG
  fi

  # TODO: There's got to be a better way to express this
  if [ -n "$SECTION" ] && $FORCE ; then
    SCRIPT=.${SECTION}' | to_entries[] | select(.value[0] != "") | .key + "=\"" + .value[0] + "\" ;"'
  elif [ -n "$SECTION" ] ; then
    SCRIPT=.${SECTION}' | to_entries[] | select(.value[0] != "") | "[ -n \"$" + .key + "\" ] || " + .key + "=\"" + .value[0] + "\" ;"'
  elif [ -z "$SECTION" ] && $FORCE ; then
    SCRIPT='to_entries[] | .value | to_entries[] | select(.value[0] != "") | .key + "=\"" + .value[0] + "\" ;"'
  else
    SCRIPT='to_entries[] | .value | to_entries[] | select(.value[0] != "") | "[ -n \"$" + .key + "\" ] || " + .key + "=\"" + .value[0] + "\" ;"'
  fi

  log "Reading from $XTAU_CONFIG"
  eval $(jq --raw-output "$SCRIPT" $XTAU_CONFIG)
  RET=$?

  cd $STARTDIR
  return $RET
}

# ideally: write_config -s git GITHUBNAME GITHUB_TOKEN
# would rewrite the entire file but only changing the GITHUBNAME & GITHUB_TOKEN
# and add them to the `git` section if none existed
write_config() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  local REPLACESECTION=false
  local SCRIPT SECTION
  local STARTDIR=$(pwd)
  if [ -z "$XTAU_CONFIG" ] ; then
    XTAU_CONFIG=${4:-${MWCNAME:-xtau}_config.json}
  fi

  cd ${WORKDIR}

  while [[ "$1" =~ - ]] ; do
    case $1 in
      -s) SECTION=$2  ; shift ;;
      -r) REPLACESECTION=true ;;
    esac
    shift
  done
  if [ ! -f $XTAU_CONFIG ] ; then
    cp templates/xtau_config.json $XTAU_CONFIG
  fi
  jq --raw-output 'def getenv(f): { "key": (.key), "value": [ env[.key], .value[1]] } ; def extract(f): { "key": (.key), "value": .value | with_entries(getenv(.)) } ; with_entries(extract(.value))' $XTAU_CONFIG > $TMPDIR/$XTAU_CONFIG.$$
  safecp $TMPDIR/$XTAU_CONFIG.$$ $XTAU_CONFIG || die
  log "xTAU configuration saved in $XTAU_CONFIG"

  cd $STARTDIR
}

# replace_params_in [ --[no-]backup ] file [ file ... ]
replace_params () {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local RET=0
  local RESULT=0
  local MAKE_BACKUP=true
  case "$1" in
    --no-backup) MAKE_BACKUP=false ; shift ;;
    --backup)    MAKE_BACKUP=true  ; shift ;;
  esac

  if [ -d "$ERP_KEY_FILE_PATH" ] ; then
    ERP_KEY_FILE_PATH="${ERP_KEY_FILE_PATH}/${NGINX_ECOM_DOMAIN}.p12"
  fi

  for FILE in $@ ; do
    if $MAKE_BACKUP ; then
      back_up_file "$FILE"
    fi
    log_exec sudo sed -i \
                      -e "s#LOGDIR#$LOGDIR#g"                                       \
                      -e "s#WEBROOT#$WEBROOT#g"                                     \
                      -e "s#{BUILD_XT_TAG}#$BUILD_XT_TAG#g"                         \
                      -e "s#{CONFIGDIR}#$CONFIGDIR#g"                               \
                      -e "s#{DEPLOYER_NAME}#$DEPLOYER_NAME#g"                       \
                      -e "s#{DOMAIN_ALIAS}#$DOMAIN_ALIAS#g"                         \
                      -e "s#{DOMAIN_NAME}#$NGINX_DOMAIN#g"                          \
                      -e "s#{ECOMM_DB_NAME}#$ECOMM_DB_NAME#g"                       \
                      -e "s#{ECOMM_DB_USERNAME}#$ECOMM_DB_USERNAME#g"               \
                      -e "s#{ECOMM_DB_USERPASS}#$ECOMM_DB_USERPASS#g"               \
                      -e "s#{ECOMM_EMAIL}#$ECOMM_EMAIL#g"                           \
                      -e "s#{ECOMM_SITE_NAME}#$ECOMM_SITE_NAME#g"                   \
                      -e "s#{ENVIRONMENT}#$WORKFLOW_ENV#g"                          \
                      -e "s#{ERP_APPLICATION}#$ERP_APPLICATION#g"                   \
                      -e "s#{ERP_DATABASE_NAME}#$ERP_DATABASE_NAME#g"               \
                      -e "s#{ERP_DATABASE}#$ERP_DATABASE_NAME#g"                    \
                      -e "s#{ERP_DEBUG}#${ERP_DEBUG:-true}#g"                       \
                      -e "s#{WEBAPI_HOST}#$WEBAPI_HOST#g"                                 \
                      -e "s#{ERP_ISS}#$ERP_ISS#g"                                   \
                      -e "s#{ERP_KEY_FILE_PATH}#$ERP_KEY_FILE_PATH#g"               \
                      -e "s#{ESCAPED_TIMEZONE}#$ESCAPED_TIMEZONE#g"                 \
                      -e "s#{GITHUB_TOKEN}#$GITHUB_TOKEN#g"                         \
                      -e "s#{HOSTNAME}#$NGINX_HOSTNAME#"                            \
                      -e "s#{MAX_EXECUTION_TIME}#$MAX_EXECUTION_TIME#g"             \
                      -e "s#{MWCNAME}#$MWCNAME#g"                                   \
                      -e "s#{WEBAPI_PORT}#$WEBAPI_PORT#g"                           \
                      -e "s#{SERVER_CRT}#$NGINX_CERT#g"                             \
                      -e "s#{SERVER_KEY}#$NGINX_KEY#g"                              \
                      -e "s#{SYSLOGID}#$SYSLOGID#g"                                 \
                      -e "s#{TIMEZONE}#$TZ#g"                                       \
                      -e "s#{TZ}#$TZ#g"                                             \
                      -e "s#{WORKFLOW_ENV}#$WORKFLOW_ENV#g"                         \
                      -e "s#{XTDIR}#/opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME#g" \
                      $FILE

    RET=$?
    if [ $RET -ne 0 ] ; then
      RESULT=$RET
    fi
  done
  return $RESULT
}

check_pgdep() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if type -p "pg_config" > /dev/null; then
    echo "pg_config found. Good!"
  else
    die "pg_config not found; please install postgresql-devel package."
  fi
}

install_npm_node() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  cd $WORKDIR

  wget https://raw.githubusercontent.com/visionmedia/n/master/bin/n -qO n
  chmod +x n
  sudo mv n /usr/bin/n
  sudo n 0.10.40
  sudo npm install -g npm@2.x.x
  sudo npm install -g browserify
}

# $1 is pg version (9.3, 9.4, etc)
install_postgresql() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  PGVER="${1:-$PGVER}"

  if [[ -z "${PGVER}" ]]; then
    die "Need to set PGVER before running, e.g.: export PGVER=9.6"
  fi

  # check to make sure the PostgreSQL repo is already added on the system
  if [ ! -f /etc/apt/sources.list.d/pgdg.list ] || ! grep -q "apt.postgresql.org" /etc/apt/sources.list.d/pgdg.list; then
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main"
  fi

  # get postgresql-common first - if create_main_cluster is true, we might run into problems
  sudo apt-get --quiet --yes install postgresql-common
  sudo sed -i -e s/'#create_main_cluster = true'/'create_main_cluster = false'/g /etc/postgresql-common/createcluster.conf

  sudo apt-get --quiet --yes install \
                          postgresql-${PGVER}         postgresql-client-${PGVER}     \
                          postgresql-contrib-${PGVER} postgresql-server-dev-${PGVER} \
       || die "apt-get failed to install PostgreSQL"
  RET=$?
  if [ $RET -eq 0 ]; then
    export PGUSER=postgres
    export PGHOST=localhost
    export PGPORT=5432
  fi

  install_plv8
}

install_plv8() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local STARTDIR=$(pwd)
  cd "${WORKDIR}"
  wget http://updates.xtuple.com/updates/plv8/linux64/xtuple_plv8.tgz
  tar xf xtuple_plv8.tgz
  cd xtuple_plv8
  log_exec echo '' | sudo ./install_plv8.sh || die
  cd "${WORKDIR}"
  rm -f xtuple_plv8.tgz
  cd "${STARTDIR}"
}

setup_postgresql_cluster() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  PGVER=${1:-${PGVER:-9.6}}
  POSTNAME=${2:-$POSTNAME}
  PGPORT=${3:-${PGPORT:-5432}}
  local POSTLOCALE=${4:-${POSTLOCALE:-en_US.UTF8}}
  local POSTSTART=${5:-${POSTSTART:-"--start-conf=auto"}}

  local CLUSTERINFO=$(pg_lsclusters -h)
  echo "$CLUSTERINFO" | grep -q "${PGPORT}"
  RET=$?

  if [[ $RET == 0 ]]; then
    echo "Already have a cluster on ${PGPORT}"
    echo "$CLUSTERINFO"
    return
  fi
  log "Creating database cluster $POSTNAME using version $PGVER on port $PGPORT encoded with $POSTLOCALE"

  log_exec sudo pg_createcluster --locale $POSTLOCALE -p $PGPORT       \
                                 --start $POSTSTART $PGVER $POSTNAME   \
                                 -o listen_addresses='*'               \
                                 -o log_line_prefix='%t %d %u '        \
                                 -- --auth=trust --auth-host=trust --auth-local=trust

  POSTDIR=/etc/postgresql/$PGVER/$POSTNAME
  back_up_file $POSTDIR/pg_hba.conf
  log "Opening pg_hba.conf for internet access with passwords"
  cat <<-EOF | sudo tee -a $POSTDIR/pg_hba.conf > /dev/null
      hostnossl  all           all             0.0.0.0/0                 reject
      hostssl    all           postgres        0.0.0.0/0                 reject
      hostssl    all           +xtrole         0.0.0.0/0                 md5
EOF
  RET=$?
  if [ $RET -ne 0 ] ; then
    die "Opening pg_hba.conf for internet access failed. Check log file and try again. "
  fi
  sudo chown postgres $POSTDIR/pg_hba.conf

  # rewrite postgresql.conf, fixing the max_locks_per_transaction if necessary
  # and commenting out the plv8.start_proc
  log "Customizing postgresql.conf"
  back_up_file $POSTDIR/postgresql.conf
  cp $POSTDIR/postgresql.conf ${TMPDIR:=/tmp}/postgresql.conf.$$
  awk '/^[[:blank:]]*max_locks_per_transaction/ {
         if ($2 < 256) { print "#" $0 } ; MAXLOCKS_FOUND = 1 ; next
       }
       /^[[:blank:]]*plv8.start_proc/ {
         print "#" $0 ; STARTPROC_FOUND = 1 ; next
       }
         { print }
       END {
         if (! MAXLOCKS_FOUND)  { print "max_locks_per_transaction = 256" }
         if (! STARTPROC_FOUND) { print "#plv8.start_proc           = ''xt.js_init''" }
       }' $TMPDIR/postgresql.conf.$$ | \
       sudo tee $POSTDIR/postgresql.conf > /dev/null
  RET=$?
  rm -f ${TMPDIR}/postgresql.conf.$$
  if [ $RET -ne 0 ] ; then
    die "Customizing postgresql.conf failed. Check the log file for any issues."
  fi
  sudo chown postgres $POSTDIR/postgresql.conf

  service_restart postgresql

  log "Deploying init.sql, creating admin user and xtrole group"
  psql -q -h $PGHOST -U postgres -d postgres -p $PGPORT -f $WORKDIR/sql/init.sql
  RET=$?
  if [ $RET -ne 0 ]; then
    die "Error deploying init.sql. Check for errors and try again"
  fi

  msgbox "Initializing cluster successful."
}

turn_on_plv8() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local POSTGRESQL_CONF=/etc/postgresql/${PGVER}/xtuple/postgresql.conf

  sudo sed -i '/^#plv8.start_proc/c\plv8.start_proc='\'xt.js_init\''' ${POSTGRESQL_CONF}
  service_restart postgresql
}

turn_off_plv8() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local POSTGRESQL_CONF=/etc/postgresql/${PGVER}/xtuple/postgresql.conf

  sudo sed -i '/^plv8.start_proc/c\#plv8.start_proc='\'xt.js_init\''' ${POSTGRESQL_CONF}
  service_restart postgresql
}

setup_erp_db() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  psql -U postgres -c "CREATE ROLE xtrole;" 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    echo "Warning or Fail on: CREATE ROLE xtrole. Already exists?"
  fi

  psql -U postgres -c "CREATE USER admin SUPERUSER PASSWORD 'admin' IN GROUP xtrole;" 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    echo "Warning or Fail on: CREATE USER admin. Already exists?"
  fi

  psql -At -U postgres -l | grep -q ${ERP_DATABASE_NAME} 2>/dev/null
  RET=$?
  if [[ $RET == 0 ]]; then
    echo "Database ${ERP_DATABASE_NAME} already exists"
  else
    echo "Creating ${ERP_DATABASE_NAME}!"
    createdb -U admin -p ${PGPORT} ${ERP_DATABASE_NAME}
    psql -U admin ${ERP_DATABASE_NAME} -c "CREATE EXTENSION plv8;"

    if [[ ! -f ${WORKDIR}/db/${ERP_DATABASE_BACKUP} ]]; then
      echo "File not found! ${WORKDIR}/db/${ERP_DATABASE_BACKUP}"
      echo "Don't know what you want me to restore!"
    else
      turn_off_plv8

      # Let's stop this service if running.
      echo "Stopping any node.js for this instance"
      service_stop xtuple-${ERP_DATABASE_NAME}
      pg_restore -U admin -d ${ERP_DATABASE_NAME} ${WORKDIR}/db/${ERP_DATABASE_BACKUP} 2>/dev/null
      RET=$?
      if [[ $RET != 0 ]]; then
        echo "Something messed up with restore of ${ERP_DATABASE_BACKUP}."
        echo "May not be critical..."
      fi

      turn_on_plv8

    fi
  fi
}

get_os_info() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if [ -z "${DOMAIN}" -o -z "${ERP_DATABASE_NAME}" -o -z "${WEBAPI_HOST}" ] ; then
    get_environment
  fi

  dialog --ok-label  "Submit"                           \
         --backtitle "$(window_title)"                  \
         --title     "xTupleCommerce OS Setup"          \
         --form      "Enter basic OS information" 0 0 7 \
         "Email Address:"          1 1 "${ECOMM_ADMIN_EMAIL:-admin@${DOMAIN}}" 1 25 50 0 \
         "URL:"                    2 1 "${ERP_SITE_URL:-${DOMAIN}}"            2 25 50 0 \
         "xTC Domain:"             3 1 "${NGINX_ECOM_DOMAIN:-${DOMAIN}}"       3 25 50 0 \
         3>&1 1>&2 2> osinfo.ini
  RET=$?
  case $RET in
    $DIALOG_OK)
      read -d "\n" ECOMM_ADMIN_EMAIL ERP_SITE_URL NGINX_ECOM_DOMAIN <<<$(cat osinfo.ini)
      export       ECOMM_ADMIN_EMAIL ERP_SITE_URL NGINX_ECOM_DOMAIN
      ;;
    *) return 1
       ;;
   esac
}

prepare_os_for_xtc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log_exec sudo apt-get --quiet update
  log_exec sudo apt-get --quiet --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --fix-missing upgrade
  log_exec sudo apt-get --quiet --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --fix-missing dist-upgrade

  if $IS_DEV_ENV && [ -n "$HOST_USERNAME" ] && \
       ! cut -f1 -d: /etc/passwd | grep --line-regexp --quiet "$HOST_USERNAME" ; then
    eval $(stat --printf 'NFS_UID=%u
                          NFS_GROUP=%G' /var/www)
    sudo adduser --system --no-create-home --uid ${NFS_UID} --ingroup ${NFS_GROUP} ${HOST_USERNAME}
    # TODO: HOST_USERNAME is never defined so we'll never get here
  fi

  if [ "${NGINX_ECOM_DOMAIN}.p12" = ".p12" -a ! -f ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.crt ] ; then
    generate_p12
  fi
}

setup_xtuplecommerce_db() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  psql -U postgres -c "CREATE USER xtuplecommerce SUPERUSER PASSWORD 'xtuplecommerce' IN GROUP xtrole;" 2>/dev/null
  psql -U postgres -c "ALTER USER xtuplecommerce SUPERUSER;" 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    echo "Warning or Fail on: CREATE USER xtuplecommerce. Already exists?"
  fi

  psql -At -U postgres -l | grep -q ${ECOMM_DB_NAME} 2>/dev/null
  RET=$?
  if [[ $RET == 0 ]]; then
    echo "Database ${ECOMM_DB_NAME} already exists"
  else
    echo "Creating ${ECOMM_DB_NAME}!"
    createdb -U postgres -O xtuplecommerce -p ${PGPORT} ${ECOMM_DB_NAME}

    if [[ ! -f ${WORKDIR}/db/${XTC_DATABASE_BACKUP} ]]; then
      echo "Could not find ${WORKDIR}/db/${XTC_DATABASE_BACKUP}"
      echo "Don't know what you want me to restore!"
    else
      pg_restore -U xtuplecommerce -d ${ECOMM_DB_NAME} ${WORKDIR}/db/${XTC_DATABASE_BACKUP} 2>/dev/null
      RET=$?
      if [[ $RET != 0 ]]; then
        echo "Something messed up with restore of ${XTC_DATABASE_BACKUP}"
        echo "May not be critical"
      fi
    fi
  fi
}

encryption_setup() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  CONFIGDIR="${1:-${CONFIGDIR:-/etc/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME}}"
  BUILD_XT="${2:-${BUILD_XT}}"
  BUILD_XT_TARGET_NAME=${BUILD_XT_TARGET_NAME:-xTupleREST}
  DATABASE="${3:-${DATABASE:-${ERP_DATABASE_NAME}}}"
  local KEYDIR="${CONFIGDIR}/private"

  if [ ! -d "${BUILD_XT}" ] ; then
    BUILD_XT="${WORKDIR}/${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}"
  fi
  mkdir --parents "${BUILD_XT}"

  log_exec sudo mkdir --parents "${KEYDIR}"

  log_exec sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} ${CONFIGDIR}
  log_exec chmod -R ug+rwX ${CONFIGDIR}

  log_exec touch ${KEYDIR}/salt.txt
  log_exec touch ${KEYDIR}/encryption_key.txt

  cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > ${KEYDIR}/salt.txt
  cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > ${KEYDIR}/encryption_key.txt

  log_exec openssl genrsa -des3 -out ${KEYDIR}/server.key -passout pass:xtuple 4096
  log_exec openssl rsa -in ${KEYDIR}/server.key -passin pass:xtuple -out ${KEYDIR}/key.pem -passout pass:xtuple
  log_exec openssl req -batch -new -key ${KEYDIR}/key.pem -out ${KEYDIR}/server.csr -subj '/CN='$(hostname)
  log_exec openssl x509 -req -days 365 -in ${KEYDIR}/server.csr -signkey ${KEYDIR}/key.pem -out ${KEYDIR}/server.crt

  safecp ${BUILD_XT}/node-datasource/sample_config.js ${CONFIGDIR}/config.js

  # use jq instead of sed
  log "Updating ${CONFIGDIR}/config.js"
  sudo sed -i \
         -e "/encryptionKeyFile/c\      encryptionKeyFile: \"$KEYDIR/encryption_key.txt\"," \
         -e "/keyFile/c\      keyFile: \"$KEYDIR/key.pem\","      \
         -e "/certFile/c\      certFile: \"$KEYDIR/server.crt\"," \
         -e "/saltFile/c\      saltFile: \"$KEYDIR/salt.txt\","   \
         -e "/databases:/c\      databases: [\"$DATABASE\"],"     \
         -e "/port: 5432/c\      port: $PGPORT,"                  \
         -e "/port: 8443/c\      port: $WEBAPI_PORT,"              \
         ${CONFIGDIR}/config.js         || die

  log "
Wrote out keys:
   ${KEYDIR}/salt.txt
   ${KEYDIR}/encryption_key.txt
   ${KEYDIR}/server.key
   ${KEYDIR}/key.pem
   ${KEYDIR}/server.csr
   ${KEYDIR}/server.crt

Wrote out web client config:
   ${CONFIGDIR}/config.js"
}

config_webclient_scripts() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if [[ -z "$WEBAPI_PORT" ]]; then
    export WEBAPI_PORT=8443
    echo "Using port 8443 for Node.js https requests"
  fi

  if [[ -z "$PGPORT" ]]; then
    export PGPORT=5432
    echo "Using port 5432 for PostgreSQL"
  fi

  if [ ! -f /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME/xtuple/node-datasource/sample_config.js ]; then
    die "Cannot find sample_config.js. Check the output or log and try again"
  fi

  CONFIGDIR="/etc/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME"
  log_exec sudo rm -rf $CONFIGDIR
  encryption_setup $CONFIGDIR /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME/xtuple
  log_exec sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /etc/xtuple

  if [ $DISTRO = "ubuntu" ]; then
    local SERVICEFILE=
    case "$CODENAME" in
      "trusty") ;&
      "utopic")
        SERVICEFILE="/etc/init/xtuple-$ERP_DATABASE_NAME.conf"
        log "Creating upstart script using filename $SERVICEFILE"
        safecp $WORKDIR/templates/ubuntu-upstart $SERVICEFILE
        ;;
      "vivid") ;&
      "xenial")
        SERVICEFILE="/etc/systemd/system/xtuple-$ERP_DATABASE_NAME.service"
        log "Creating systemd service unit using filename $SERVICEFILE"
        safecp $WORKDIR/templates/xtuple-systemd.service $SERVICEFILE
        ;;
    esac
    replace_params --no-backup $SERVICEFILE
  else
    die "Do not know how to configure_web_client_scripts on $DISTRO $CODENAME"
  fi
}

get_environment() {
  webenable_database

  ERP_DATABASE_NAME=${DATABASE}
  DOMAIN=${DOMAIN:-flywheel.xd}
  WEBAPI_HOST=https://${DOMAIN}:${WEBAPI_PORT}

  [ -n "${GITHUB_TOKEN}" ] || get_github_token || return 1

  dialog --ok-label  "Submit"                        \
         --backtitle "$(window_title)"               \
         --title     "Configuration"                 \
         --form      "Configure Web API Environment" \
         0 0 0 \
           "ERP Host:"  1 1          "${WEBAPI_HOST}"   1 20 50 0 \
       "ERP Database:"  2 1 "${ERP_DATABASE_NAME}"   2 20 50 0 \
             "Domain:"  3 1            "${DOMAIN}"   3 20 50 0 \
  3>&1 1>&2 2>&3 2> xtuple_webclient.ini
  RET=$?

  case $RET in
    $DIALOG_OK)
      read -d "\n" WEBAPI_HOST ERP_DATABASE_NAME DOMAIN <<<$(cat xtuple_webclient.ini);
      export WEBAPI_HOST ERP_DATABASE_NAME DOMAIN
      export ECOMM_ADMIN_EMAIL=admin@${DOMAIN}
      ;;
    $DIALOG_CANCEL)    main_menu                       ;;
    $DIALOG_HELP)      echo "Help pressed"             ;;
    $DIALOG_EXTRA)     echo "Extra button pressed"     ;;
    $DIALOG_ITEM_HELP) echo "Item-help button pressed" ;;
    $DIALOG_ESC)       main_menu                       ;;
  esac
}

get_xtc_environment() {
  if [ -z "${DOMAIN}" -o -z "${ERP_DATABASE_NAME}" -o -z "${WEBAPI_HOST}" ] ; then
    get_environment
  fi

  ECOMM_EMAIL=admin@${DOMAIN}
  ECOMM_SITE_NAME="${ECOMM_SITE_NAME:-xTupleCommerceSite}"
  ECOMM_DB_NAME=${ERP_DATABASE_NAME}_xtc
  ECOMM_DB_USERNAME="${ECOMM_DB_USERNAME:-admin}"
  ECOMM_DB_USERPASS="${ECOMM_DB_USERPASS:-admin}"
  DEPLOYER_NAME=${DEPLOYER_NAME:-$(whoami)}
  ERP_ISS="${ERP_ISS:-xTupleCommerceID}"
  ERP_APPLICATION="${ERP_APPLICATION:-xTupleCommerce}"
  ERP_DEBUG="${ERP_DEBUG:-true}"
  WORKFLOW_ENV="${WORKFLOW_ENV:-stage}"
  HTTP_AUTH_NAME="${HTTP_AUTH_NAME:-Developer}"
  HTTP_AUTH_PASS="${HTTP_AUTH_PASS:-admin}"

  if [ -z "$SITE_TEMPLATE" -a -n "$DOMAIN" ] && [[ "$DOMAIN" =~ ^[^.]+\. ]] ; then
    SITE_TEMPLATE=${BASH_REMATCH[1]}
  fi
  SITE_TEMPLATE="${SITE_TEMPLATE:-flywheel}"
  DOMAIN_ALIAS=${DOMAIN_ALIAS:-${SITE_TEMPLATE}.xtuple.net}

  dialog --ok-label  "Submit"                               \
         --backtitle "$(window_title)"                      \
         --title     "Configuration"                        \
         --form      "Configure xTupleCommerce Environment" \
         0 0 0 \
            "Site Email:" 1 1       "${ECOMM_EMAIL}"  1 25 50 0 \
             "Site Name:" 2 1   "${ECOMM_SITE_NAME}"  2 25 50 0 \
  "Drupal Database Name:" 3 1     "${ECOMM_DB_NAME}"  3 25 50 0 \
  "Drupal Postgres User:" 4 1 "${ECOMM_DB_USERNAME}"  4 25 50 0 \
  "Drupal Postgres Pass:" 5 1 "${ECOMM_DB_USERPASS}"  5 25 50 0 \
       "OAuth Token Id:"  6 1           "${ERP_ISS}"  6 25 50 0 \
          "Application:"  7 1   "${ERP_APPLICATION}"  7 25 50 0 \
         "Website Repo:"  8 1     "${SITE_TEMPLATE}"  8 25 50 0 \
            "ERP Debug:"  9 1         "${ERP_DEBUG}"  9 25 50 0 \
          "Environment:" 10 1      "${WORKFLOW_ENV}" 10 25 50 0 \
         "Domain Alias:" 11 1      "${DOMAIN_ALIAS}" 11 25 50 0 \
       "HTTP Auth User:" 12 1    "${HTTP_AUTH_NAME}" 12 25 50 0 \
       "HTTP Auth Pass:" 13 1    "${HTTP_AUTH_PASS}" 13 25 50 0 \
        "Deployer Name:" 14 0     "${DEPLOYER_NAME}" 14 25 50 0 \
  3>&1 1>&2 2>&3 2> xtuple_commerce.ini
  RET=$?

  case $RET in
    $DIALOG_OK)
      read -d "\n" ECOMM_EMAIL     ECOMM_SITE_NAME                                   \
                   ECOMM_DB_NAME   ECOMM_DB_USERNAME ECOMM_DB_USERPASS ERP_ISS       \
                   ERP_APPLICATION SITE_TEMPLATE     ERP_DEBUG         WORKFLOW_ENV  \
                   DOMAIN_ALIAS    HTTP_AUTH_NAME    HTTP_AUTH_PASS    DEPLOYER_NAME \
                   <<<$(cat xtuple_commerce.ini)

      export ECOMM_EMAIL     ECOMM_SITE_NAME
      export ECOMM_DB_NAME   ECOMM_DB_USERNAME ECOMM_DB_USERPASS ERP_ISS
      export ERP_APPLICATION SITE_TEMPLATE     ERP_DEBUG         WORKFLOW_ENV
      export DOMAIN_ALIAS    HTTP_AUTH_NAME    HTTP_AUTH_PASS    DEPLOYER_NAME
      ;;
    $DIALOG_CANCEL)     main_menu                       ;;
    $DIALOG_HELP)       echo "Help pressed."            ;;
    $DIALOG_EXTRA)      echo "Extra button pressed."    ;;
    $DIALOG_ITEM_HELP)  echo "Item-help button pressed.";;
    $DIALOG_ESC)        main_menu                       ;;
  esac
}

load_oauth_site() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  generate_p12  || die
  generateoasql || die

  psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/oa2client.sql || die
  psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/xd_site.sql || die
}

# needed by the "headless" updater and possibly openrpt
install_xtuple_xvfb() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  case "$CODENAME" in
    "trusty") ;&
    "utopic") ;&
    "wheezy")
      log "Installing xtuple-Xvfb to /etc/init.d..."
      safecp $WORKDIR/templates/xtuple-Xvfb /etc/init.d
      log_exec sudo chmod 755 /etc/init.d/xtuple-Xvfb
      log_exec sudo update-rc.d xtuple-Xvfb defaults
      log_exec sudo service xtuple-Xvfb start
      ;;
  esac
}

ruby_setup() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  sudo apt-get --quiet --yes install rubygems rubygems-integration ruby-dev

  # required for theme CSS generation
  sudo gem install compass

  if $IS_DEV_ENV ; then
    # ASCIIDoc, required for documentation generation
    sudo gem install asciidoctor coderay --quiet
  fi
}

xtc_code_setup() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  local STARTDIR=$(pwd)
  local BUILDTAG TESTDIR

  # look for the most recently INSTALLED code dir
  if [ -z "$BUILD_XT" ] ; then
    for TESTDIR in $(ls -td /opt/xtuple/*/*/xtuple) ; do
      if [ -d $TESTDIR/.git ] ; then
        BUILD_XT="$TESTDIR"
        BUILT_XT_TAG=$(basename $(dirname $(dirname $BUILD_XT)))
        break
      fi
    done
  fi

  # if we can't find that, look for the most recently created build dir
  if [ -z "$BUILD_XT" ] ; then
    for TESTDIR in $(ls -td "${WORKDIR}/${BUILD_XT_TARGET_NAME:=xTupleREST}*") ; do
      if [ -d $TESTDIR ] && [[ $TESTDIR =~ ${BUILD_XT_TARGET_NAME}-(.*) ]] ; then
        BUILD_XT="$TESTDIR"
        BUILD_XT_TAG=${BASH_REMATCH[1]}
        break
      fi
    done
  fi
  CONFIGDIR=${CONFIGDIR:-$(dirname $(ls -td /etc/xtuple/$BUILD_XT_TAG/*/config.js | head --lines=1))}

  [ -n "$GITHUB_TOKEN" ] || get_github_token || die "Cannot set up xTupleCommerce without a GitHub access token"

  local REPOS=" enhanced-pricing
                nodejsshim
                payment-gateways
                xdruple-extension
                xtuple
                private-extensions
              "

  for REPO in $REPOS ; do
    # TODO: read the BUILDTAG from an external source
    if [ "$REPO" = "private-extensions" ] ; then
      BUILDTAG=${BUILD_XT_TAG:-TAG}
    else
      BUILDTAG="TAG"
    fi
    gitco ${REPO} $(dirname ${BUILD_XT}) ${BUILDTAG} || die
    cd ${BUILD_XT}
    scripts/build_app.js -c ${CONFIGDIR}/config.js -e ../${REPO}
  done
  cd ${STARTDIR}
}

# update_progress [ -s # ] percentDone [ message-to-display ]
update_progress() {
  local SLEEP=1
  if [ "$1" = -s ] ; then
    SLEEP="$2"
    shift 2
  fi
  local PCT="$1"
  shift
  echo "===== ${PCT}% - $@"
  # echo -e "XXX\n${PCT}\n$@\nXXX" # for use with whiptail --gauge
  if [ -n "$SLEEP" ] ; then
    sleep $SLEEP
  fi
}

setup_flywheel() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  get_github_token

  if [   -z "${DEPLOYER_NAME}"     -o -z "${DOMAIN_ALIAS}"      \
      -o -z "${ERP_APPLICATION}"   -o -z "${ECOMM_DB_NAME}"     \
      -o -z "${ECOMM_DB_USERNAME}" -o -z "${ECOMM_DB_USERPASS}" \
      -o -z "${ECOMM_EMAIL}"       -o -z "${ECOMM_SITE_NAME}"   \
      -o -z "${ERP_DEBUG}"         -o -z "${ERP_ISS}"           \
      -o -z "${HTTP_AUTH_NAME}"    -o -z "${HTTP_AUTH_PASS}"    \
      -o -z "${SITE_TEMPLATE}"     -o -z "${WORKFLOW_ENV}" ] ; then
    get_xtc_environment
  fi

  service_restart xtuple-${ERP_DATABASE_NAME} || die

  local SITE_ROOT=/var/www
  local SITE_WEBROOT=${SITE_ROOT}/${WORKFLOW_ENV}

  if [ "${NGINX_ECOM_DOMAIN}.p12" != ".p12" ]; then
    load_oauth_site
  fi

  log_exec sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} ${SITE_ROOT}

  update_progress 0 "Cloning ${SITE_TEMPLATE} to ${SITE_WEBROOT}"
  sudo rm -rf ${SITE_WEBROOT}
  gitco ${SITE_TEMPLATE} ${SITE_ROOT} TAG > /dev/null 2>&1
  cd ${SITE_ROOT}
  sudo mv ${SITE_TEMPLATE} ${SITE_WEBROOT} || die "Error moving ${SITE_TEMPLATE} to ${SITE_WEBROOT}"

  update_progress 10 "Running composer install (takes a while)"
  # TODO: are these 2 files supposed to be identical?
  if $IS_DEV_ENV ; then
    safecp ${WORKDIR}/templates/php/composer/config-vagrant.json /home/${DEPLOYER_NAME}/.composer/config.json
  else
    safecp ${WORKDIR}/templates/php/composer/config-server.json /home/${DEPLOYER_NAME}/.composer/config.json
  fi
  replace_params --no-backup /home/${DEPLOYER_NAME}/.composer/config.json
  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /home/${DEPLOYER_NAME}/.composer
  cd ${SITE_WEBROOT}
  log "Running composer install"
  composer install > $WORKDIR/composer.log 2>&1 || \
    die "Error running composer install; see $WORKDIR/composer.log"

  update_progress 40 "Updating environment.xml"
  mkdir --parents ${SITE_WEBROOT}/application/config
  replace_params ${SITE_WEBROOT}/application/config/environment.xml

  update_progress 45 "Setting /etc/hosts"
  (echo '127.0.0.1' ${DOMAIN} ${DOMAIN_ALIAS} dev.${DOMAIN_ALIAS} stage.${DOMAIN_ALIAS} live.${DOMAIN_ALIAS}) | sudo tee -a /etc/hosts >/dev/null

  update_progress 50 "Running installation script ${SITE_WEBROOT}/console_cmd.sh"
  safecp ${WORKDIR}/templates/php/cli/console_cmd.sh ${SITE_WEBROOT}/console_cmd.sh
  replace_params --no-backup ${SITE_WEBROOT}/console_cmd.sh
  cd ${SITE_WEBROOT}
  sudo chown ${DEPLOYER_NAME}:${DEPLOYER_NAME} console_cmd.sh
  sudo chmod 744 console_cmd.sh
  log "Running console_cmd.sh"
  ./console_cmd.sh > ${WORKDIR}/console_cmd.log 2>&1 || \
    die"./console_cmd.sh failed in $SITE_WEBROOT; see ${WORKDIR}/console_cmd.log"

  update_progress 90 "Setting ownership and permissions in ${SITE_WEBROOT}"
  log_exec sudo chown -R www-data:www-data ${SITE_WEBROOT}/web    || die "Could not chown ${SITE_WEBROOT}/web"
  log_exec sudo chown -R www-data:www-data ${SITE_WEBROOT}/drupal || die "Could not chown ${SITE_WEBROOT}/drupal"
  log_exec sudo chmod -R 775 ${SITE_WEBROOT}/web/files || die "Could not chmod ${SITE_WEBROOT}/web/files"

  update_progress -s 5 100 "Installation Complete!"
}

# TODO: this isn't called anywhere. should it be?
setup_xtuplecommerce() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if [[ ! -f ${WORKDIR}/${XTC_WWW_TARBALL} ]]; then
    die "Could not find ${XTC_WWW_TARBALL} to install"
  fi

  log_exec sudo mkdir --parents /var/www

  cd $WORKDIR
  XTCTARDIR=$(tar -tzf ${XTC_WWW_TARBALL} | head -1 | cut -f1 -d"/")

  echo "Extracting ${XTC_WWW_TARBALL}"
  log_exec tar xf ${XTC_WWW_TARBALL}
  back_up_file /var/www/${WORKFLOW_ENV}

  sudo mv ${WORKDIR}/${XTCTARDIR} /var/www/${WORKFLOW_ENV}
  sudo chown -R www-data:www-data /var/www/${WORKFLOW_ENV}
}

webnotes() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local RET=0

  # prefer this if we have it and we're on EC2...
  # TODO: how can we tell if we're "on EC2"?
  #if type -p "ec2metadata" > /dev/null; then
  #  IP=$(ec2metadata --public-ipv4)
  #  RET=$?
  #fi
  #if [ -z "$IP" -o "${RET}" -ne 0 ] ; then
    IP=$(hostname -I)
  #fi

  if [[ -z ${IP} ]] ; then
    IP="The IP address of this machine"
  fi

  back_up_file xtuplecommerce_connection.log
  cat <<-EOF | tee xtuplecommerce_connection.log
	************************************"
	***** IMPORTANT!!! PLEASE READ *****"
	************************************"

	Here is the information to get logged in!

	First, Add the following to your system's hosts file
	Windows: %SystemRoot%\System32\drivers\etc\hosts
	OSX/Linux: /etc/hosts

	${IP} ${ERP_SITE_URL}

	Here is where you can login:
	  xTuple version ${BUILD_XT_TAG}
	  Server    ${IP}
	  Port      ${PGPORT}
	  Database  ${ERP_DATABASE_NAME}
	  User      admin
	  Pass      admin

	Web API:
	  Login at http://${DOMAIN}:8888
	  Login at ${WEBAPI_HOST}
	  User     admin
	  Pass     admin

	xTupleCommerce Site Login:
	  Login at http://${WORKFLOW_ENV}.${DOMAIN_ALIAS}/login
	  User     ${HTTP_AUTH_NAME}
	  Pass     ${HTTP_AUTH_PASS}

	Nginx Config:
	  Webroot: /var/www/${WORKFLOW_ENV}/drupal/core

	Please set your nginx config for the xTupleCommerce webroot to:
	  root /var/www/xTupleCommerce/drupal/core;
EOF
}

xtau_deploy_mwc() {
  read_config ${WORKDIR}/${XTAU_CONFIG}
}

php_setup() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  mkdir --parents $HOME/.composer

  export TZ=${1:-${TZ:-$(tzselect)}}
  export DEPLOYER_NAME=${2:-${DEPLOYER_NAME:-$(whoami)}}
  export GITHUB_TOKEN=${3:-${GITHUB_TOKEN:-$(git config --get github.token)}}

  export MAX_EXECUTION_TIME=60
  if $IS_DEV_ENV ; then
    export MAX_EXECUTION_TIME=600
  fi

  sudo add-apt-repository -y ppa:ondrej/php && \
  sudo apt-get --quiet -y update       || die
  sudo apt-get --quiet -y upgrade      || die
  sudo apt-get --quiet -y install \
                          php-common     php7.1-common   php7.1-json \
                          php7.1-opcache php7.1-readline php7.1-fpm  \
                          php7.1         php7.1-cli      php7.1-xml  \
                          php-pear       php7.1-dev      php7.1-gd   \
                          php7.1-pgsql   php7.1-curl     php7.1-intl \
                          php7.1-mcrypt  php7.1-mbstring php7.1-soap \
                          php7.1-zip     || die

  if $IS_DEV_ENV ; then
    sudo apt-get --quiet -y install php-xdebug || die
    safecp ${WORKDIR}/templates/php/mods/xdebug.ini /etc/php/7.1/mods-available || die
  fi

  safecp ${WORKDIR}/templates/php/fpm/php-fpm.conf.ini /etc/php/7.1/fpm
  safecp ${WORKDIR}/templates/php/fpm/www.conf.ini /etc/php/7.1/fpm/pool.d

  ESCAPED_TIMEZONE=$(echo ${TZ} | sed -e 's/[]\/$*.^|[]/\\&/g')
  safecp ${WORKDIR}/templates/php/fpm/php.ini /etc/php/7.1/fpm
  safecp ${WORKDIR}/templates/php/cli/php.ini /etc/php/7.1/cli
  replace_params --no-backup /etc/php/7.1/fpm/php.ini /etc/php/7.1/cli/php.ini

  # Composer
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" || die
  php composer-setup.php                                || die
  php -r "unlink('composer-setup.php');"                || die
  sudo mv composer.phar /usr/local/bin/composer         || die
  sudo mkdir --parents /home/${DEPLOYER_NAME}/.composer || die

  if [[ -f /home/"${DEPLOYER_NAME}"/.bashrc ]]; then
    echo "export PATH=\"./vendor/bin:${PATH}\"" >> /home/"${DEPLOYER_NAME}"/.bashrc
  fi

  # Restart PHP and Nginx
  sudo service php7.1-fpm restart
  sudo service nginx restart
}

fi # }
