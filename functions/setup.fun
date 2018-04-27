#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$SETUP_FUN" ] ; then # {
SETUP_FUN=true

export CONFIG_DIR=${CONFIG_DIR:-${BUILD_WORKING}/xdruple-server/config}
export GITHUB_TOKEN=${GITHUB_TOKEN:-$(git config --get github.token)}
export KEY_P12_PATH=${KEY_P12_PATH:-${WORKDIR}/private}
export KEYTMP=${KEYTMP:-${KEY_P12_PATH}/tmp}
export SCRIPTS_DIR=${SCRIPTS_DIR:-${BUILD_WORKING}/xdruple-server/scripts}
export TZ=${TZ:-$(tzselect)}
export RUNTIMEENV=${RUNTIMEENV:-'server'}
export WORKDATE=${WORKDATE:-$(date "+%m%d%y")}

source ${BUILD_WORKING:-${WORKING:-.}}/functions/oatoken.fun

read_configs() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  local CONFIGFILE="${1:-${WORKDIR}/CreatePackages-${WORKDATE}.config}"
  local CONFIGVAR

  if [[ -f "$CONFIGFILE" ]]; then
    source "$CONFIGFILE"
  fi

  rm -f ${WORKDIR}/setup.bak

  for CONFIGVAR in NODE_ENV PGVER BUILD_XT_TAG ERP_MWC_TARBALL XTC_WWW_TARBALL ; do
    if [[ ${!CONFIGVAR} ]]; then
     echo "${CONFIGVAR}=${!CONFIGVAR}" | tee -a ${WORKDIR}/setup.bak
    fi
  done

  if [[ -f ${WORKDIR}/setup.ini ]]; then
    source ${WORKDIR}/setup.ini
  else
    echo "Missing setup.ini file."
    echo "We'll create a sample for you. Please review."

    #TODO: should TIMEZONE be TZ? why export only that one?
    cat >> ${WORKDIR}/setup.ini <<EOSETUP
export TIMEZONE=${TIMEZONE}
       PGVER=${PGVER}
       BUILD_XT_TAG=v${BUILD_XT_TAG}
       ERP_DATABASE_NAME=xtupleerp
       ERP_DATABASE_BACKUP=manufacturing_demo-${BUILD_XT_TAG}.backup
       ERP_MWC_TARBALL=${BUILD_XT_TARGET_NAME}-v${BUILD_XT_TAG}.tar.gz
       XTC_DATABASE_NAME=xtuplecommerce
       XTC_DATABASE_BACKUP=xTupleCommerce-v${BUILD_XT_TAG}.backup
       XTC_WWW_TARBALL=xTupleCommerce-v${BUILD_XT_TAG}.tar.gz
       # payment-gateway config
       # See https://github.com/bendiy/payment-gateways/tree/initial/gateways
       GATEWAY_NAME='Example'
       GATEWAY_HOSTNAME='api.example.com'
       GATEWAY_BASE_PATH='/v1'
       GATEWAY_NODE_LIB_NAME='example' "
EOSETUP

  fi
}

initial_update() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  sudo apt-get --quiet update
  RET=$?
  if [[ $RET != 0 ]]; then
    echo "apt-get returned $RET trying to update"
    echo "Log out and back in and try again"
    exit 2
  fi
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

install_postgresql() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if [[ -z "${PGVER}" ]]; then
    die "Need to set PGVER before running, e.g.: export PGVER=9.6"
  fi

  # check to make sure the PostgreSQL repo is already added on the system
  if [ ! -f /etc/apt/sources.list.d/pgdg.list ] || ! grep -q "apt.postgresql.org" /etc/apt/sources.list.d/pgdg.list; then
    sudo bash -c "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -"
    sudo bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  fi

  # We handle this package separately - if create_main_cluster is true, then it can cause issues for our purposes.
  sudo apt-get --quiet --yes install postgresql-common
  sudo sed -i -e s/'#create_main_cluster = true'/'create_main_cluster = false'/g /etc/postgresql-common/createcluster.conf

  # TODO: do we really want to install plv8?
  sudo apt-get --quiet --yes install \
                          postgresql-${PGVER}         postgresql-client-${PGVER}     \
                          postgresql-contrib-${PGVER} postgresql-server-dev-${PGVER} \
                          postgresql-client-${PGVER}  postgresql-${PGVER}-plv8       \
       || die "apt-get failed to install PostgreSQL"
}

setup_postgresql_cluster() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  PGVER=${1:-${PGVER:-9.6}}
  local POSTNAME=${2:-$POSTNAME}
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

  local POSTDIR=/etc/postgresql/$PGVER/$POSTNAME
  back_up_file $POSTDIR/pg_hba.conf
  log "Opening pg_hba.conf for internet access with passwords"
  cat <<-EOF | sudo tee -a $POSTDIR/pg_hba.conf
      hostnossl  all           all             0.0.0.0/0                 reject
      hostssl    all           postgres        0.0.0.0/0                 reject
      hostssl    all           +xtrole         0.0.0.0/0                 md5
EOF
  RET=$?
  if [ $RET -ne 0 ] ; then
    msgbox "Opening pg_hba.conf for internet access failed. Check log file and try again. "
    do_exit
  fi
  sudo chown postgres $POSTDIR/pg_hba.conf

  # rewrite postgresql.conf, fixing the max_locks_per_transaction if necessary
  # and commenting out the plv8.start_proc
  # alternatively use sed -i, which may be less robust
  log "Customizing postgresql.conf"
  back_up_file $POSTDIR/postgresql.conf
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
       }' $POSTDIR/postgresql.conf | \
       sudo tee $POSTDIR/postgresql.conf
  RET=$?
  if [ $RET -ne 0 ] ; then
    msgbox "Customizing postgresql.conf failed. Check the log file for any issues."
    do_exit
  fi
  sudo chown postgres $POSTDIR/postgresql.conf

  service_restart postgresql

  log "Deploying init.sql, creating admin user and xtrole group"
  psql -q -h $PGHOST -U postgres -d postgres -p $PGPORT -f $WORKDIR/sql/init.sql
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Error deploying init.sql. Check for errors and try again"
    do_exit
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

  dialog --ok-label  "Submit"                   \
         --backtitle "xTupleCommerce OS Setup"  \
         --title     "xTupleCommerce OS Setup"  \
         --form      "Enter basic OS information" \
         --begin 0 0  --inputbox "Email Address:" 1 1 "$ECOMM_ADMIN_EMAIL" \
         --add-widget --inputbox "URL:"           1 1 "$ERP_SITE_URL"      \
         --add-widget --inputbox "xTC Domain:"    1 1 "$NGINX_ECOM_DOMAIN" \
         --add-widget --insecure --passwordbox "New Root Password:"      2 1    \
         --add-widget --insecure --passwordbox "Root Cert Password:"     2 1    \
         --add-widget --insecure --passwordbox "Deployer Cert Password:" 2 1    \
         3>&1 1>&2 2> osinfo.ini
  RET=$?
  case $RET in
    $DIALOG_OK)
      read -d "\n" ECOMM_ADMIN_EMAIL ERP_SITE_URL NGINX_ECOM_DOMAIN ROOT_PASSED ROOT_CERT_PASSWD DEPLOY_CERT_PASSWD <<<$(cat osinfo.ini)
      export       ECOMM_ADMIN_EMAIL ERP_SITE_URL NGINX_ECOM_DOMAIN ROOT_PASSED ROOT_CERT_PASSWD DEPLOY_CERT_PASSWD
      ;;
    *) return 1
       ;;
   esac
}

prepare_os_for_xtc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  if [ "$RUNTIMEENV" = 'server' -a -n "$ROOT_PASSWD" ] ; then
    echo "root:${ROOT_PASSWD}" | sudo chpasswd
  fi

  log_exec sudo apt-get --quiet update
  log_exec sudo apt-get --quiet --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --fix-missing upgrade
  log_exec sudo apt-get --quiet --yes -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --fix-missing dist-upgrade

  if [ ${RUNTIMEENV} = 'server' ]; then
    safecp ${WORKDIR}/templates/ssh/sshd_config.conf /etc/ssh/sshd_config
    service_restart ssh
  elif [ ${RUNTIMEENV} = 'vagrant' ] ; then
    eval $(stat --printf 'NFS_UID=%u
                          NFS_GROUP=%G' /var/www)
    sudo adduser --system --no-create-home --uid ${NFS_UID} --ingroup ${NFS_GROUP} ${HOST_USERNAME}
  fi

  generate_p12
  generate_xdruple_keypairs ${ECOMM_ADMIN_EMAIL} ${ERP_SITE_URL} ${NGINX_ECOM_DOMAIN} ${ROOT_CERT_PASSWD} ${DEPLOY_CERT_PASSWD}
  if $XTC_HOST_IS_REMOTE ; then
    ssh root@${ERP_SITE_URL} mkdir --parents /var/xtuple/keys
    scp ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN_P12} ${ERP_SITE_URL}:/var/xtuple/keys/

     local IP=$(nslookup $URL | awk '/Server:/ { print $2 }')
     back_up_file /etc/hosts
     cat <<-EOF | sudo tee -a /etc/hosts
           $URL            $IP
           dev.$URL        $IP
           stage.$URL      $IP
           live.$URL       $IP
EOF
  elif [ "$RUNTIMEENV" = 'server' ] ; then
    sudo mkdir --parents /var/xtuple/keys
    safecp ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} /var/xtuple/keys
  elif [ "$RUNTIMEENV" = 'vagrant' ] ; then
    sudo mkdir --parents /var/xtuple
    sudo ln --symbolic --force /vagrant/xtuple/keys /var/xtuple/keys
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

  psql -At -U postgres -l | grep -q ${XTC_DATABASE_NAME} 2>/dev/null
  RET=$?
  if [[ $RET == 0 ]]; then
    echo "Database ${XTC_DATABASE_NAME} already exists"
  else
    echo "Creating ${XTC_DATABASE_NAME}!"
    createdb -U postgres -O xtuplecommerce -p ${PGPORT} ${XTC_DATABASE_NAME}

    if [[ ! -f ${WORKDIR}/db/${XTC_DATABASE_BACKUP} ]]; then
      echo "Could not find ${WORKDIR}/db/${XTC_DATABASE_BACKUP}"
      echo "Don't know what you want me to restore!"
    else
      pg_restore -U xtuplecommerce -d ${XTC_DATABASE_NAME} ${WORKDIR}/db/${XTC_DATABASE_BACKUP} 2>/dev/null
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
  local DATABASE="${3:-${ERP_DATABASE_NAME}}"
  local KEYDIR="${CONFIGDIR}/private"

  if [ ! -d "${BUILD_XT}" ] ; then
    BUILD_XT="${BUILD_WORKING}/${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}"
  fi
  [ -d "${BUILD_XT}" ] || die "Cannot figure out where to stash the encryption keys"

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
         -e "/port: 8443/c\      port: $NGINX_PORT,"              \
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

  if [[ -z "$NGINX_PORT" ]]; then
    export NGINX_PORT=8443
    echo "Using port 8443 for Node.js https requests"
  fi

  if [[ -z "$PGPORT" ]]; then
    export PGPORT=5432
    echo "Using port 5432 for PostgreSQL"
  fi

  if [ ! -f /opt/xtuple/$BUILD_XT_TAG/"$ERP_DATABASE_NAME"/xtuple/node-datasource/sample_config.js ]; then
    die "Cannot find sample_config.js. Check the output or log and try again"
  fi

  export XTDIR=/opt/xtuple/$BUILD_XT_TAG/"$ERP_DATABASE_NAME"/xtuple

  log_exec sudo rm -rf /etc/xtuple/$BUILD_XT_TAG/"$ERP_DATABASE_NAME"
  encryption_setup /etc/xtuple/$BUILD_XT_TAG/"$ERP_DATABASE_NAME" $XTDIR

  log_exec sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /etc/xtuple

  if [ $DISTRO = "ubuntu" ]; then
    case "$CODENAME" in
      "trusty") ;&
      "utopic")
        log "Creating upstart script using filename /etc/init/xtuple-$ERP_DATABASE_NAME.conf"
        # create the upstart script
        sudo cp $WORKDIR/templates/ubuntu-upstart /etc/init/xtuple-"$ERP_DATABASE_NAME".conf
        log_exec sudo bash -c "echo \"chdir /opt/xtuple/$BUILD_XT_TAG/\"$ERP_DATABASE_NAME\"/xtuple/node-datasource\" >> /etc/init/xtuple-\"$ERP_DATABASE_NAME\".conf"
        log_exec sudo bash -c "echo \"exec ./main.js -c /etc/xtuple/$BUILD_XT_TAG/\"$ERP_DATABASE_NAME\"/config.js > /var/log/node-datasource-$BUILD_XT_TAG-\"$ERP_DATABASE_NAME\".log 2>&1\" >> /etc/init/xtuple-\"$ERP_DATABASE_NAME\".conf"
        ;;
      "vivid") ;&
      "xenial")
        log "Creating systemd service unit using filename /etc/systemd/system/xtuple-$ERP_DATABASE_NAME.service"
        safecp $WORKDIR/templates/xtuple-systemd.service /etc/systemd/system/xtuple-${ERP_DATABASE_NAME}.service
        log_exec sudo sed -i -e "s/{DEPLOYER_NAME}/$DEPLOYER_NAME/"       \
                             -e "s/{SYSLOGID}/xtuple-$ERP_DATABASE_NAME/" \
                             -e "s,{XTDIR},/opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME," \
                             -e "s,{CONFIGDIR},/etc/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME," /etc/systemd/system/xtuple-${ERP_DATABASE_NAME}.service
        ;;
    esac
  else
    die "Do not know how to configure_web_client_scripts on $DISTRO $CODENAME"
  fi
}

get_environment() {
  upgrade_database

  DEPLOYER_NAME=${DEPLOYER_NAME}

  ERP_DATABASE_NAME=${DATABASE}
  ERP_ISS="xTupleCommerceID"

  SITE_TEMPLATE="flywheel"
  ERP_APPLICATION="xTupleCommerce"
  ERP_DEBUG="true"
  WENVIRONMENT="stage"

  DOMAIN=${SITE_TEMPLATE}.xd
  DOMAIN_ALIAS=${SITE_TEMPLATE}.xtuple.net
  HTTP_AUTH_NAME="Developer"
  HTTP_AUTH_PASS="ChangeMe"
  ERP_HOST=https://${DOMAIN}:8443

  # TODO: some of this may be specific to xTupleCommerce
  dialog --ok-label  "Submit"                           \
         --backtitle "xTuple Web Client Setup"          \
         --title     "Configuration"                    \
         --form      "Configure Web Client Environment" \
         0 0 0 \
           "ERP Host:"  1 1          "${ERP_HOST}"   1 20 50 0 \
       "ERP Database:"  2 1 "${ERP_DATABASE_NAME}"   2 20 50 0 \
     "OAuth Token Id:"  3 1           "${ERP_ISS}"   3 20 50 0 \
        "Application:"  4 1   "${ERP_APPLICATION}"   4 20 50 0 \
           "Web Repo:"  5 1     "${SITE_TEMPLATE}"   5 20 50 0 \
          "ERP Debug:"  6 1         "${ERP_DEBUG}"   6 20 50 0 \
        "Environment:"  7 1      "${WENVIRONMENT}"   7 20 50 0 \
             "Domain:"  8 1            "${DOMAIN}"   8 20 50 0 \
       "Domain Alias:"  9 1      "${DOMAIN_ALIAS}"   9 20 50 0 \
     "HTTP Auth User:" 10 1    "${HTTP_AUTH_NAME}"  10 20 50 0 \
     "HTTP Auth Pass:" 11 1    "${HTTP_AUTH_PASS}"  11 20 50 0 \
      "Deployer Name:" 12 0     "${DEPLOYER_NAME}"  12 20 50 0 \
       "Github Token:" 13 0      "${GITHUB_TOKEN}"  13 20 50 0 \
  3>&1 1>&2 2>&3 2> xtuple_webclient.ini
  return_value=$?

  case $return_value in
    $DIALOG_OK)

      read -d "\n" ERP_HOST ERP_DATABASE_NAME ERP_ISS ERP_APPLICATION SITE_TEMPLATE ERP_DEBUG WENVIRONMENT DOMAIN DOMAIN_ALIAS HTTP_AUTH_NAME HTTP_AUTH_PASS DEPLOYER_NAME GITHUB_TOKEN <<<$(cat xtuple_webclient.ini);

      export DEPLOYER_NAME    DOMAIN            DOMAIN_ALIAS
      export ERP_APPLICATION  ERP_DATABASE_NAME ERP_DEBUG ERP_HOST ERP_ISS ERP_SITE_URL
      export GITHUB_TOKEN
      export HTTP_AUTH_NAME    HTTP_AUTH_PASS
      export NGINX_ECOM_DOMAIN SITE_TEMPLATE WENVIRONMENT
      export ECOMM_ADMIN_EMAIL=admin@${DOMAIN}
      ;;

    $DIALOG_CANCEL)
       main_menu                        ;;
    $DIALOG_HELP)
      echo "Help pressed."              ;;
    $DIALOG_EXTRA)
      echo "Extra button pressed."      ;;
    $DIALOG_ITEM_HELP)
      echo "Item-help button pressed."  ;;
    $DIALOG_ESC)
     main_menu                          ;;
  esac

}

get_xtc_environment() {
  local ECOMM_EMAIL=admin@${DOMAIN}
  local ECOMM_SITE_NAME='xTupleCommerceSite'
  local ECOMM_DB_NAME=${ERP_DATABASE_NAME}_xtc
  local ECOMM_DB_USERNAME="${ERP_DATABASE_NAME}_admin"
  local ECOMM_DB_USERPASS="ChangeMe"

  dialog --ok-label  "Submit"                               \
         --backtitle "xTupleCommerce Setup"                 \
         --title     "Configuration"                        \
         --form      "Configure xTupleCommerce Environment" \
         0 0 0 \
             "Site Email:" 1 1       "${ECOMM_EMAIL}" 1 20 50 0 \
              "Site Name:" 2 1   "${ECOMM_SITE_NAME}" 2 20 50 0 \
    "Ecomm Database Name:" 3 1     "${ECOMM_DB_NAME}" 3 20 50 0 \
        "Site DB Pg User:" 4 1 "${ECOMM_DB_USERNAME}" 4 20 50 0 \
        "Site DB Pg Pass:" 5 1 "${ECOMM_DB_USERPASS}" 5 20 50 0 \
  3>&1 1>&2 2>&3 2> xtuple_commerce.ini
  return_value=$?

  case $return_value in
    $DIALOG_OK)
      read -d "\n" ECOMM_EMAIL ECOMM_SITE_NAME ECOMM_DB_NAME ECOMM_DB_USERNAME ECOMM_DB_USERPASS <<<$(cat xtuple_commerce.ini);

      export ECOMM_EMAIL=${ECOMM_EMAIL}
      export ECOMM_SITE_NAME=${ECOMM_SITE_NAME}
      export ECOMM_DB_NAME=${ECOMM_DB_NAME}
      export ECOMM_DB_USERNAME=${ECOMM_DB_USERNAME}
      export ECOMM_DB_USERPASS=${ECOMM_DB_USERPASS}
      export ECOMM_ADMIN_EMAIL=${ECOM_EMAIL}
      ;;
    $DIALOG_CANCEL)     main_menu                       ;;
    $DIALOG_HELP)       echo "Help pressed."            ;;
    $DIALOG_EXTRA)      echo "Extra button pressed."    ;;
    $DIALOG_ITEM_HELP)  echo "Item-help button pressed.";;
    $DIALOG_ESC)        main_menu                       ;;
  esac
}

# TODO: why do we have install_webclient in mobileclient.sh and this?
# TODO: remove partial duplication from mwc_build_static_mwc?
webclient_setup() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local APPLY_FOUNDATION=

  if [[ $ISXTAU ]]; then
    get_environment
    psql -At -U postgres -l | grep -q ${ERP_DATABASE_NAME} 2>/dev/null
    RET=$?

    if [[ $RET == 0 ]]; then
      echo "Database ${ERP_DATABASE_NAME} already exists, good!"
      export ERP_DATABASE=${ERP_DATABASE_NAME}
    else
      echo "Creating ${ERP_DATABASE_NAME}!"
      createdb -U admin -p ${PGPORT} ${ERP_DATABASE_NAME}
      psql -U admin -p ${PGPORT} ${ERP_DATABASE_NAME} -c "CREATE EXTENSION plv8;"
    fi
  fi

  cd $WORKDIR

  if [[ ! -f ${WORKDIR}/${ERP_MWC_TARBALL} ]]; then
    echo "Could not find ${WORKDIR}/${ERP_MWC_TARBALL}! This is kinda important..."
    exit 2
  fi

  ERPTARDIR=$(tar -tzf ${ERP_MWC_TARBALL} | head -1 | cut -f1 -d"/")

  if [ -z "$(ls -A ${ERPTARDIR})" ]; then
    echo "${ERPTARDIR} is empty or does not exist\nExtracting ${ERP_MWC_TARBALL}"
    tar xf ${ERP_MWC_TARBALL}
  else
    echo "${ERPTARDIR} exists and is not empty"
  fi
  BUILD_XT_TAG=$(cd ${ERPTARDIR}/xtuple && git describe --abbrev=0 --tags)

  local XT_ROOT=/opt/xtuple/${BUILD_XT_TAG}/${ERP_DATABASE_NAME}
  if [[ -d "${XT_ROOT}" ]]; then
    back_up_file $XT_ROOT
    rm -rf $XT_ROOT
  fi
  log_exec sudo mkdir --parents $(dirname $XT_ROOT)
  log_exec sudo mkdir --parents /etc/xtuple/${BUILD_XT_TAG}

  echo "Copying ${WORKDIR}/${ERPTARDIR} to /opt/xtuple/${BUILD_XT_TAG}/${ERP_DATABASE_NAME}"
  sudo cp -R ${WORKDIR}/${ERPTARDIR} ${XT_ROOT}
  echo "Setting owner to ${DEPLOYER_NAME} on $(dirname $XT_ROOT)"
  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} $(dirname $XT_ROOT)
  turn_on_plv8
  config_webclient_scripts

  local XTAPP=$(psql -At -U admin -p ${PGPORT} ${ERP_DATABASE_NAME} -c "SELECT getEdition();")
  if [[ ${XTAPP} == "PostBooks" ]]; then
    APPLY_FOUNDATION='-f'
  fi

  HAS_XTEXT=$(psql -At -U admin ${ERP_DATABASE_NAME} <<EOF
    SELECT 1
      FROM pg_catalog.pg_class JOIN pg_namespace n ON n.oid = relnamespace
     WHERE nspname = 'xt' AND relname = 'ext';
EOF
)
  cd ${XT_ROOT}/xtuple
  if [[ $HAS_XTEXT == 1 ]]; then
    echo "${ERP_DATABASE_NAME} has xt.ext so we can preload things that may not exist.  There may be exceptions to doing this."
    psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/preload.sql
  fi

  cd $XT_ROOT
  for REPO in * ; do
    [ -d $XT_ROOT/$REPO ] && cd $XT_ROOT/$REPO && repo_setup $REPO
  done
  cd $XT_ROOT/xtuple

  scripts/build_app.js -c /etc/xtuple/${BUILD_XT_TAG}/${ERP_DATABASE_NAME}/config.js ${APPLY_FOUNDATION} 2>&1 | tee buildapp_output.log
  RET=$?
  msgbox "$(cat buildapp_output.log)"
  if [[ $RET -ne 0 ]]; then
    main_menu
  fi

  #TODO: why run this twice?
  scripts/build_app.js -c /etc/xtuple/${BUILD_XT_TAG}/${ERP_DATABASE_NAME}/config.js ${APPLY_FOUNDATION} 2>&1 | tee buildapp_output.log
  RET=$?
  msgbox "$(cat buildapp_output.log)"
  if [[ $RET -ne 0 ]]; then
    main_menu
  fi

  if [[ $HAS_XTEXT != 1 ]]; then
    echo "${ERP_DATABASE_NAME} does not have xt.ext"
    # We can check for the private extensions dir...
    if [[ -d "${XT_ROOT}/private-extensions" ]] ; then
      scripts/build_app.js -c /etc/xtuple/$BUILD_XT_TAG/${ERP_DATABASE_NAME}/config.js -e ../private-extensions/source/inventory ${APPLY_FOUNDATION} 2>&1 | tee buildapp_output.log
      RET=$?
      msgbox "$(cat buildapp_output.log)"
      if [[ $RET -ne 0 ]]; then
        main_menu
      fi
    else
      msgbox "private-extensions does not exist. Contact xTuple for access on github."
      main_menu
    fi

    psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/preload.sql
    echo "Running build_app for the extensions we preloaded into xt.ext"
    scripts/build_app.js -c /etc/xtuple/${BUILD_XT_TAG}/${ERP_DATABASE_NAME}/config.js 2>&1 | tee buildapp_output.log
    RET=$?
    msgbox "$(cat buildapp_output.log)"
    if [[ $RET -ne 0 ]]; then
      main_menu
    fi
  fi
}

load_oauth_site() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  generate_p12  || die
  generateoasql || die

  psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/oa2client.sql || die
  psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/xd_site.sql || die
}

# TODO: either remove or make this ask for gateway info and do the full config
gateway_setup() {
  psql -U admin -p 5432 ${ERP_DATABASE_NAME} <<EOF
    INSERT INTO paymentgateways.gateway (
      gateway_name,  gateway_hostname,  gateway_base_path,  gateway_node_lib_name
    ) SELECT ${GATEWAY_NAME}, ${GATEWAY_HOSTNAME}, ${GATEWAY_BASE_PATH}, ${GATEWAY_NODE_LIB_NAME}
      WHERE NOT EXISTS (SELECT 1 FROM paymentgateways.gateway WHERE gateway_name = ${GATEWAY_NAME});
EOF
}

ruby_setup() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  sudo apt-get --quiet --yes install rubygems rubygems-integration ruby-dev

  # required for theme CSS generation
  sudo gem install compass

  if $ISDEVELOPMENTENV ; then
    # ASCIIDoc, required for documentation generation
    sudo gem install asciidoctor coderay --quiet
  fi
}

setup_flywheel() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  get_environment
  get_xtc_environment

  service_restart xtuple-${ERP_DATABASE_NAME}

  local SITE_ENV_TMP_WORK=${WORKING}/xdruple-sites/${ERP_DATABASE_NAME}
  local SITE_ENV_TMP=${SITE_ENV_TMP_WORK}/${WENVIRONMENT}
  local SITE_ROOT=/var/www
  local SITE_WEBROOT=${SITE_ROOT}/${WENVIRONMENT}
  local KEY_PATH=/var/xtuple/keys
  local ERP_KEY_FILE_PATH=${KEY_PATH}/${NGINX_ECOM_DOMAIN_P12}

  # The site template developer
  local SITE_DEV=xtuple

  mkdir --parents ${SITE_ENV_TMP_WORK}

  if [ -n ${NGINX_ECOM_DOMAIN_P12} ]; then
    load_oauth_site
  else
    die "DOMAIN NOT SET - EXITING!"
  fi

  sudo mkdir --parents ${KEY_PATH}
  if $ISDEVELOPMENTENV ; then
    ln -s /vagrant/xtuple/keys ${KEY_PATH}
  fi

  log_exec sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} ${SITE_ROOT}

  {
    echo -e "XXX\n0\nCloning ${SITE_TEMPLATE} to ${SITE_ENV_TMP}\nXXX"
    log_exec "git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${SITE_DEV}/${SITE_TEMPLATE} ${SITE_ENV_TMP}" 2>/dev/null

    echo -e "XXX\n10\nRunning submodule update\nXXX"
    log_exec "cd ${SITE_ENV_TMP} && git submodule update --init --recursive" 2>/dev/null

    echo -e "XXX\n20\nRunning composer install\nXXX"
    # Check for composer token
    GITHUB_TOKEN=$(git config --get github.token)
    cat <<-EOF > /home/${DEPLOYER_NAME}/.composer/config.json
	{
	  "config": {
	    "github-oauth": {
	    "github.com": "$GITHUB_TOKEN" },
	    "process-timeout": 600,
	    "preferred-install": "source",
	    "github-protocols": ["ssh", "https", "git"],
	    "secure-http": false
	  }
	}
EOF

    log_exec "cd ${SITE_ENV_TMP} && composer install" 2>/dev/null

    echo -e "XXX\n30\nWriting out environment.xml\nXXX"
    ERP_DATABASE=${ERP_DATABASE_NAME}
    tee ${SITE_ENV_TMP}/application/config/environment.xml <<EOF
	<?xml version="1.0" encoding="UTF-8" ?>
        <environment type="${WENVIRONMENT}"
                     xmlns="https://xdruple.xtuple.com/schema/environment"
                     xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                     xsi:schemaLocation="https://xdruple.xtuple.com/schema/environment schema/environment.xsd">
	  <xtuple host="${ERP_HOST}"
                  database="${ERP_DATABASE}"
                  iss="${ERP_ISS}"
                  key="${ERP_KEY_FILE_PATH}"
                  application="${ERP_APPLICATION}"
                  debug="${ERP_DEBUG}"/>
	</environment>
EOF
    sleep 1

    echo -e "XXX\n35\nCopying ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} to ${ERP_KEY_FILE_PATH}"
    cp ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} ${ERP_KEY_FILE_PATH} 2>/dev/null
    sleep 1

    echo -e "XXX\n40\nSetting /etc/hosts\nXXX"
    (echo '127.0.0.1' ${DOMAIN} ${DOMAIN_ALIAS} dev.${DOMAIN_ALIAS} stage.${DOMAIN_ALIAS} live.${DOMAIN_ALIAS}) | sudo tee -a /etc/hosts >/dev/null
    sleep 1

    echo -e "XXX\n45\nMoving WENVIRONMENT=${WENVIRONMENT}\nXXX"
    log_exec "mv ${SITE_ROOT}/${WENVIRONMENT} ${SITE_ROOT}/${WENVIRONMENT}_${WORKDATE}"
    log_exec "mv ${SITE_ENV_TMP} ${SITE_WEBROOT}"

    echo -e "XXX\n50\nRunning console.php install:drupal\nXXX"

    local CMD="./console.php install:drupal --db-name=${ECOMM_DB_NAME}     \
                                            --db-pass=${ECOMM_DB_USERPASS} \
                                            --db-user=${ECOMM_DB_USERNAME} \
                                            --user-pass=${ECOMM_DB_USERPASS} \
                                            --site-mail=${ECOMM_EMAIL}     \
                                            --site-name=${ECOMM_SITE_NAME}"
    echo $CMD >> ${SITE_WEBROOT}/console_cmd.sh

    cd ${SITE_WEBROOT}
    eval $CMD
    RET=$?
    [ $? -eq 0 ] || die "console.php install:drupal returned $RET in $(pwd)"

    echo -e "XXX\n80\nSetting permissions on ${SITE_WEBROOT}/web\nXXX"
    log_exec sudo chown -R www-data:www-data ${SITE_WEBROOT}/web
    sleep 1
    echo -e "XXX\n85\nSetting permissions on ${SITE_WEBROOT}/web/files\nXXX"
    log_exec sudo chmod -R 775 ${SITE_WEBROOT}/web/files
    sleep 1
    echo -e "XXX\n90\nSetting permissions on ${SITE_WEBROOT}/drupal\nXXX"
    log_exec sudo chown -R www-data:www-data ${SITE_WEBROOT}/drupal
    sleep 1
    echo -e "XXX\n95\nSetting permissions on ${NGINX_ECOM_DOMAIN_P12}\nXXX"
    log_exec sudo chown www-data:www-data ${SITE_WEBROOT}/${NGINX_ECOM_DOMAIN_P12}

    echo -e "XXX\n100\nInstallation Complete!\nXXX"

  } | whiptail --title "${SITE_TEMPLATE} - Installing web stuff" --gauge "Please wait while installing" 10 140 8

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
  if [[ -d "/var/www/xTupleCommerce" ]]; then
    echo "Moving old /var/www/xTupleCommerce directory to /var/www/xTupleCommerce-${WORKDATE}"
    back_up_file /var/www/xTupleCommerce
  fi

  sudo mv $WORKDIR/${XTCTARDIR} /var/www/xTupleCommerce
  sudo chown -R www-data:www-data /var/www/xTupleCommerce
}

webnotes() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if type -p "ec2metadata" > /dev/null; then
    #prefer this if we have it and we're on EC2...
    IP=$(ec2metadata --public-ipv4)
  else
    IP=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)
  fi

  if [[ -z ${IP} ]]; then
    IP="The IP address of this machine"
  fi

  back_up_file xtuplecommerce_connection.log
  cat << EOF | tee xtuplecommerce_connection.log
     ************************************"
     ***** IMPORTANT!!! PLEASE READ *****"
     ************************************"

     Here is the information to get logged in!

     First, Add the following to your system's hosts file
     Windows: %SystemRoot%\System32\drivers\etc\hosts
     OSX/Linux: /etc/hosts

     ${IP} ${ERP_SITE_URL}

     Here is where you can login:
     xTuple Desktop Client v${BUILD_XT_TAG}:
     Server: ${IP}
     Port: ${PGPORT}
     Database: ${ERP_DATABASE_NAME}
     User: admin
     Pass: admin


     Web Client/REST:
     Login at: http://xtuple.xd:8888
     Login at: https:/${DOMAIN_ALIAS}:8443
     User: admin
     Pass: admin

     Ecommerce Site Login:
     Login at http://${DOMAIN_ALIAS}/login
     User: Developer
     Pass: admin

     Nginx Config:
     Webroot: /var/www/xTupleCommerce/drupal/core

  Please set your nginx config for the xTupleCommerce webroot to:
    root /var/www/xTupleCommerce/drupal/core;
EOF
}

destroy_env() {
  echo "About to delete the following"
}

xtau_deploy_mwc() {
  read_configs ${WORKDIR}/xtau_mwc-${WORKDATE}.config
}

php_setup() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  mkdir --parents $HOME/.composer

  export RUNTIMEENV=${1:-${RUNTIMEENV:-vagrant}}
  export TZ=${2:-${TZ:-$(tzselect)}}
  export DEPLOYER_NAME=${3:-${DEPLOYER_NAME:-$(whoami)}}
  export GITHUB_TOKEN=${4:-${GITHUB_TOKEN:-$(git config --get github.token)}}

  export MAX_EXECUTION_TIME=60
  if [ ${RUNTIMEENV} = 'vagrant' ]; then
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
                          php7.1-mcrypt  php7.1-mbstring php7.1-soap || die

  if [ ${RUNTIMEENV} = 'vagrant' ]; then
    sudo apt-get --quiet -y install php-xdebug || die
    safecp ${WORKDIR}/templates/php/mods/xdebug.ini /etc/php/7.1/mods-available || die
  fi

  safecp ${WORKDIR}/templates/php/fpm/php-fpm.conf.ini /etc/php/7.1/fpm
  safecp ${WORKDIR}/templates/php/fpm/www.conf.ini /etc/php/7.1/fpm/pool.d

  ESCAPED_TIMEZONE=$(echo ${TZ} | sed -e 's/[]\/$*.^|[]/\\&/g')
  safecp ${WORKDIR}/templates/php/fpm/php.ini /etc/php/7.1/fpm
  sudo sed -i -e "s/{TZ}/${ESCAPED_TIMEZONE}/g" \
              -e "s/{MAX_EXECUTION_TIME}/${MAX_EXECUTION_TIME}/g" /etc/php/7.1/fpm/php.ini

  safecp ${WORKDIR}/templates/php/cli/php.ini /etc/php/7.1/cli
  sudo sed -i "s/{TZ}/${ESCAPED_TIMEZONE}/g" /etc/php/7.1/cli/php.ini

  # Composer
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" || die
  php composer-setup.php                                || die
  php -r "unlink('composer-setup.php');"                || die
  sudo mv composer.phar /usr/local/bin/composer         || die
  sudo mkdir -p /home/${DEPLOYER_NAME}/.composer        || die
  safecp ${WORKDIR}/templates/php/composer/config-${RUNTIMEENV}.json /home/${DEPLOYER_NAME}/.composer/config.json
  sudo sed -i "s/{GITHUB_TOKEN}/${GITHUB_TOKEN}/g" /home/${DEPLOYER_NAME}/.composer/config.json
  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /home/${DEPLOYER_NAME}/.composer

  # TODO: some(?) of these should be moved to devenv.sh
  if [ "$MODE" = manual ] ; then
    GET=dlf_fast
  else
    GET=dlf_fast_console
  fi
  # PHPUnit (v6.x)
  $GET https://phar.phpunit.de/phpunit.phar /usr/local/bin/phpunit +x

  # PHP CodeSniffer
  $GET https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar /usr/local/bin/phpcs +x

  # PHP Code Beautifier
  $GET https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar /usr/local/bin/phpcbf +x

  # PHP Mess Detector
  $GET http://static.phpmd.org/php/latest/phpmd.phar /usr/local/bin/phpmd +x

  # Couscous (User documentation generation)
  $GET http://couscous.io/couscous.phar /usr/local/bin/couscous +x

  # Restart PHP and Nginx
  sudo service php7.1-fpm restart
  sudo service nginx restart
}

fi # }
