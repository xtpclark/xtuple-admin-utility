#!/bin/bash

export CONFIG_DIR=${CONFIG_DIR:-${BUILD_WORKING}/xdruple-server/config}
export GITHUB_TOKEN=${GITHUB_TOKEN:-$(git config --get github.token)}
export KEYTMP=${KEYTMP:-${KEY_P12_PATH}/tmp}
export KEY_P12_PATH=${KEY_P12_PATH:-${WORKDIR}/private}
export SCRIPTS_DIR=${SCRIPTS_DIR:-${BUILD_WORKING}/xdruple-server/scripts}
export TIMEZONE=${TIMEZONE:-America/New_York}
export TYPE=${TYPE:-'server'}
export WORKDATE=${WORKDATE:-$(date "+%m%d%y")}

source ${WORKDIR:-.}/functions/oatoken.fun

read_configs() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  local CONFIGFILE="${1:-${WORKDIR}/CreatePackages-${WORKDATE}.config}"
  local CONFIGVAR

  if [[ -f "$CONFIGFILE" ]]; then
    source "$CONFIGFILE"
  fi

  rm -f ${WORKDIR}/setup.bak

  for CONFIGVAR in NODE_ENV PGVER MWC_VERSION ERP_MWC_TARBALL XTC_WWW_TARBALL ; do
    if [[ ${!CONFIGVAR} ]]; then
     echo "${CONFIGVAR}=${!CONFIGVAR}" | tee -a ${WORKDIR}/setup.bak
    fi
  done

  if [[ -f ${WORKDIR}/setup.ini ]]; then
    source ${WORKDIR}/setup.ini
  else
    echo "Missing setup.ini file."
    echo "We'll create a sample for you. Please review."

    cat >> ${WORKDIR}/setup.ini <<EOSETUP
      export TIMEZONE=${TIMEZONE}
      PGVER=${PGVER}
      MWC_VERSION=v${MWC_VERSION}
      ERP_DATABASE_NAME=xtupleerp
      ERP_DATABASE_BACKUP=manufacturing_demo-${MWC_VERSION}.backup
      ERP_MWC_TARBALL=${BUILD_XT_TARGET_NAME}-v${MWC_VERSION}.tar.gz
      XTC_DATABASE_NAME=xtuplecommerce
      XTC_DATABASE_BACKUP=xTupleCommerce-v${MWC_VERSION}.backup
      XTC_WWW_TARBALL=xTupleCommerce-v${MWC_VERSION}.tar.gz
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

  sudo apt-get update
  RET=$?
  if [[ $RET != 0 ]]; then
    echo "apt-get returned $RET trying to update"
    echo "Log out and back in and try again"
    exit 2
  fi
}

add_mwc_user() {
  sudo useradd xtuple -m -s /bin/bash
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
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

cd $WORKDIR
# sudo apt-get -y install npm

wget https://raw.githubusercontent.com/visionmedia/n/master/bin/n -qO n
chmod +x n
sudo mv n /usr/bin/n
sudo n 0.10.40
sudo npm install -g npm@2.x.x
sudo npm install -g browserify

}


install_postgresql() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

if [[ -z "${PGVER}" ]]; then
echo "Need to set PGVER before running"
echo "i.e.: export PGVER=9.6"
exit 0
fi

# check to make sure the PostgreSQL repo is already added on the system
   if [ ! -f /etc/apt/sources.list.d/pgdg.list ] || ! grep -q "apt.postgresql.org" /etc/apt/sources.list.d/pgdg.list; then
      sudo bash -c "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -"
      sudo bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
   fi

# We handle this package separately - if create_main_cluster is true, then it can cause issues for our purposes.
    sudo apt-get -y install postgresql-common
    sudo sed -i -e s/'#create_main_cluster = true'/'create_main_cluster = false'/g /etc/postgresql-common/createcluster.conf

POSTGRESQL_PACKAGES="postgresql-${PGVER} postgresql-client-${PGVER} postgresql-contrib-${PGVER} postgresql-server-dev-${PGVER} postgresql-client-${PGVER} postgresql-${PGVER}-plv8"

for POSTGRESQL_PACKAGE in $POSTGRESQL_PACKAGES; do
dpkg-query -Wf'${Status}' $POSTGRESQL_PACKAGE 2>/dev/null | grep -q "install ok installed";
RET=$?
if [[ $RET == 0 ]]; then
echo "$POSTGRESQL_PACKAGE Is Installed"
else
   echo "Installing ${POSTGRESQL_PACKAGE}"
    sudo apt-get -y install $POSTGRESQL_PACKAGE
    RET=$?
   if [[ $RET != 0 ]]; then
   echo "apt-get returned $RET trying to install $POSTGRESQL_PACKAGE"
   exit 2
   fi
fi

done
}

setup_postgresql_cluster() {
CLUSTERINFO=$(pg_lsclusters -h)

echo "$CLUSTERINFO" | grep -q "5432"
RET=$?

if [[ $RET == 0 ]]; then
echo "Already have a cluster on 5432"
echo "$CLUSTERINFO"

else
echo "Creating PostgreSQL Cluster on 5432"

sudo bash -c "su - root -c \"pg_createcluster --locale en_US.UTF8 -p 5432 ${PGVER} xtuple -o listen_addresses='*' -o log_line_prefix='%t %d %u ' -- --auth=trust --auth-host=trust --auth-local=trust\""
sudo bash -c "echo  \"hostnossl    all           all             0.0.0.0/0                 reject\" >> /etc/postgresql/${PGVER}/xtuple/pg_hba.conf"
sudo bash -c "echo  \"hostssl    all             postgres             0.0.0.0/0                 reject\" >> /etc/postgresql/${PGVER}/xtuple/pg_hba.conf"
sudo bash -c "echo  \"hostssl    all             +xtrole             0.0.0.0/0                 md5\" >> /etc/postgresql/${PGVER}/xtuple/pg_hba.conf"

# We keep plv8 turned off until we restore the database.  This is becuase of a current issue with plv8.
sudo bash -c "echo  \"#plv8.start_proc='xt.js_init'\" >> /etc/postgresql/${PGVER}/xtuple/postgresql.conf"


sudo pg_ctlcluster ${PGVER} xtuple stop --force
sudo pg_ctlcluster ${PGVER} xtuple start

ALLCLUSTERS=$(pg_lsclusters)
echo "Completed - these are your PostgreSQL clusters:"
echo "${ALLCLUSTERS}"


fi

}

#Turn on plv8 and restart postgresql.
turn_on_plv8() {
POSTGRESQL_CONF=/etc/postgresql/${PGVER}/xtuple/postgresql.conf
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

sudo sed -i '/^#plv8.start_proc/c\plv8.start_proc='\'xt.js_init\''' ${POSTGRESQL_CONF}
sudo pg_ctlcluster ${PGVER} xtuple stop --force
sudo pg_ctlcluster ${PGVER} xtuple start
}

#Turn off plv8 and restart postgresql.
turn_off_plv8() {
POSTGRESQL_CONF=/etc/postgresql/${PGVER}/xtuple/postgresql.conf

echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

sudo sed -i '/^plv8.start_proc/c\#plv8.start_proc='\'xt.js_init\''' ${POSTGRESQL_CONF}
sudo pg_ctlcluster ${PGVER} xtuple stop --force
sudo pg_ctlcluster ${PGVER} xtuple start
}


setup_erp_db() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

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
   createdb -U admin -p 5432 ${ERP_DATABASE_NAME}
   psql -U admin ${ERP_DATABASE_NAME} -c "CREATE EXTENSION plv8;"

if [[ ! -f ${WORKDIR}/db/${ERP_DATABASE_BACKUP} ]]; then
    echo "File not found! ${WORKDIR}/db/${ERP_DATABASE_BACKUP}"
    echo "Don't know what you want me to restore!"
else
turn_off_plv8

# Let's stop this service if running.
echo "Stopping any node.js for this instance"
sudo service xtuple-${ERP_DATABASE_NAME} stop
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
   createdb -U postgres -O xtuplecommerce -p 5432 ${XTC_DATABASE_NAME}

if [[ ! -f ${WORKDIR}/db/${XTC_DATABASE_BACKUP} ]]; then
    echo "File not found! ${WORKDIR}/db/${XTC_DATABASE_BACKUP}"
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

config_mwc_scripts() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if [[ -z $NGINX_PORT ]]; then
    export NGINX_PORT=8443
    echo "Using port 8443 for Node.js https requests"
  fi

  if [[ -z $PGPORT ]]; then
    export PGPORT=5432
    echo "Using port 5432 for PostgreSQL"
  fi

  if [ ! -f /opt/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/xtuple/node-datasource/sample_config.js ]; then
    log "Hrm, sample_config.js doesn't exist.. something went wrong. check the output/log and try again"
    do_exit
  fi

  export XTDIR=/opt/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/xtuple

  sudo rm -rf /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"
  log_exec sudo mkdir -p /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private

  # setup encryption details
  log_exec sudo touch /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt
  log_exec sudo touch /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt
  log_exec sudo chown -R ${DEPLOYER_NAME}.${DEPLOYER_NAME} /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"
  # temporarily so we can cat to them since bash is being a bitch about quoting the trim string below
  log_exec sudo chmod 777 /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt
  log_exec sudo chmod 777 /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt

  cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt
  cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt

  log_exec sudo chmod 660 /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt
  log_exec sudo chmod 660 /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt

  log_exec sudo openssl genrsa -des3 -out /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.key -passout pass:xtuple 4096
  log_exec sudo openssl rsa -in /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.key -passin pass:xtuple -out /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/key.pem -passout pass:xtuple
  log_exec sudo openssl req -batch -new -key /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/key.pem -out /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.csr -subj '/CN='$(hostname)
  log_exec sudo openssl x509 -req -days 365 -in /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.csr -signkey /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/key.pem -out /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.crt

  log_exec sudo cp /opt/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/xtuple/node-datasource/sample_config.js /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js

  log_exec sudo sed -i  "/encryptionKeyFile/c\      encryptionKeyFile: \"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt\"," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js
  log_exec sudo sed -i  "/keyFile/c\      keyFile: \"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/key.pem\"," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js
  log_exec sudo sed -i  "/certFile/c\      certFile: \"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.crt\"," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js
  log_exec sudo sed -i  "/saltFile/c\      saltFile: \"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt\"," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js

  log "Using database $ERP_DATABASE_NAME"
  log_exec sudo sed -i  "/databases:/c\      databases: [\"$ERP_DATABASE_NAME\"]," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js
  log_exec sudo sed -i  "/port: 5432/c\      port: $PGPORT," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js

  log_exec sudo sed -i  "/port: 8443/c\      port: $NGINX_PORT," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js

  log_exec sudo chown -R ${DEPLOYER_NAME}.${DEPLOYER_NAME} /etc/xtuple

  if [ $DISTRO = "ubuntu" ]; then
    case "$CODENAME" in
      "trusty") ;&
      "utopic")
        log "Creating upstart script using filename /etc/init/xtuple-$ERP_DATABASE_NAME.conf"
        # create the upstart script
        sudo cp $WORKDIR/templates/ubuntu-upstart /etc/init/xtuple-"$ERP_DATABASE_NAME".conf
        log_exec sudo bash -c "echo \"chdir /opt/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/xtuple/node-datasource\" >> /etc/init/xtuple-\"$ERP_DATABASE_NAME\".conf"
        log_exec sudo bash -c "echo \"exec ./main.js -c /etc/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/config.js > /var/log/node-datasource-$MWC_VERSION-\"$ERP_DATABASE_NAME\".log 2>&1\" >> /etc/init/xtuple-\"$ERP_DATABASE_NAME\".conf"
        ;;
      "vivid") ;&
      "xenial")
        log "Creating systemd service unit using filename /etc/systemd/system/xtuple-$ERP_DATABASE_NAME.service"
        sudo cp $WORKDIR/templates/xtuple-systemd.service /etc/systemd/system/xtuple-"$ERP_DATABASE_NAME".service
        log_exec sudo bash -c "echo \"User=${DEPLOYER_NAME}\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
        log_exec sudo bash -c "echo \"Group=${DEPLOYER_NAME}\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
        log_exec sudo bash -c "echo \"SyslogIdentifier=xtuple-$ERP_DATABASE_NAME\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
        log_exec sudo bash -c "echo \"ExecStart=/usr/local/bin/node /opt/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/xtuple/node-datasource/main.js -c /etc/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/config.js\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
        ;;
    esac
  elif [ $DISTRO = "debian" ]; then
    case "$CODENAME" in
      "wheezy")
        log "Creating debian init script using filename /etc/init.d/xtuple-$ERP_DATABASE_NAME"
        # create the weird debian sysvinit style script
        sudo cp $WORKDIR/templates/debian-init /etc/init.d/xtuple-"$ERP_DATABASE_NAME"
        log_exec sudo sed -i  "/APP_DIR=/c\APP_DIR=\"/opt/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/xtuple/node-datasource\"" /etc/init.d/xtuple-"$ERP_DATABASE_NAME"
        log_exec sudo sed -i  "/CONFIG_FILE=/c\CONFIG_FILE=\"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js\"" /etc/init.d/xtuple-"$ERP_DATABASE_NAME"
        # should be +x from git but just in case...
        sudo chmod +x /etc/init.d/xtuple-"$ERP_DATABASE_NAME"
        ;;
      "jessie")
        log "Creating systemd service unit using filename /etc/systemd/system/xtuple-$ERP_DATABASE_NAME.service"
        sudo cp $WORKDIR/templates/xtuple-systemd.service /etc/systemd/system/xtuple-"$ERP_DATABASE_NAME".service
        log_exec sudo bash -c "echo \"SyslogIdentifier=xtuple-$ERP_DATABASE_NAME\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
        log_exec sudo bash -c "echo \"ExecStart=/usr/local/bin/node /opt/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/xtuple/node-datasource/main.js -c /etc/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/config.js\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
        ;;
    esac
  else
    log "Seriously? We made it all the way to where I need to write out the init script and suddenly I can't detect your distro -> $DISTRO codename -> $CODENAME"
    do_exit
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

  : ${DIALOG_OK=0}
  : ${DIALOG_CANCEL=1}
  : ${DIALOG_HELP=2}
  : ${DIALOG_EXTRA=3}
  : ${DIALOG_ITEM_HELP=4}
  : ${DIALOG_ESC=255}

  dialog --ok-label "Submit" \
            --backtitle "xTuple Web Client Setup" \
            --title "Configuration" \
            --form "Configure Web Client Environment" \
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

      export ERP_HOST=${ERP_HOST}
      export ERP_DATABASE_NAME=${ERP_DATABASE_NAME}
      export ERP_ISS=${ERP_ISS}
      export ERP_APPLICATION=${ERP_APPLICATION}
      export SITE_TEMPLATE=${SITE_TEMPLATE}
      export ERP_DEBUG=${ERP_DEBUG}
      export WENVIRONMENT=${WENVIRONMENT}
      export DOMAIN=${DOMAIN}
      export DOMAIN_ALIAS=${DOMAIN_ALIAS}
      export HTTP_AUTH_NAME=${HTTP_AUTH_NAME}
      export HTTP_AUTH_PASS=${HTTP_AUTH_PASS}
      export DEPLOYER_NAME=${DEPLOYER_NAME}
      export GITHUB_TOKEN=${GITHUB_TOKEN}
      export ERP_SITE_URL=${DOMAIN}
      export NGINX_ECOM_DOMAIN=${DOMAIN}
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
#get_environment

ECOMM_EMAIL=admin@${DOMAIN}
ECOMM_SITE_NAME='xTupleCommerceSite'
ECOMM_DB_NAME=${ERP_DATABASE_NAME}_xtc
ECOMM_DB_USERNAME="${ERP_DATABASE_NAME}_admin"
ECOMM_DB_USERPASS="ChangeMe"

: ${DIALOG_OK=0}
: ${DIALOG_CANCEL=1}
: ${DIALOG_HELP=2}
: ${DIALOG_EXTRA=3}
: ${DIALOG_ITEM_HELP=4}
: ${DIALOG_ESC=255}

dialog --ok-label "Submit" \
          --backtitle "xTupleCommerce Setup" \
          --title "Configuration" \
          --form "Configure xTupleCommerce Environment" \
0 0 0 \
         "Site Email:"    1 1              "${ECOMM_EMAIL}"   1 20 50 0 \
     "Site Name:"         2 1          "${ECOMM_SITE_NAME}"   2 20 50 0 \
 "Ecomm Database Name:"   3 1            "${ECOMM_DB_NAME}"   3 20 50 0 \
      "Site DB Pg User:"  4 1        "${ECOMM_DB_USERNAME}"   4 20 50 0 \
      "Site DB Pg Pass:"  5 1        "${ECOMM_DB_USERPASS}"   5 20 50 0 \
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
  $DIALOG_CANCEL)
  main_menu
;;
  $DIALOG_HELP)
    echo "Help pressed.";;
  $DIALOG_EXTRA)
    echo "Extra button pressed.";;
  $DIALOG_ITEM_HELP)
    echo "Item-help button pressed.";;
  $DIALOG_ESC)
  main_menu
    ;;
esac
}

install_mwc() {
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

  sudo mkdir -p /opt/xtuple/${MWC_VERSION}

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
  MWC_VERSION=$(cd ${ERPTARDIR}/xtuple && git describe --abbrev=0 --tags)

  sudo mkdir -p /etc/xtuple/${MWC_VERSION}

  if [[ -d "/opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}" ]]; then
    echo "Moving existing ${ERP_DATABASE_NAME} directory to /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}-${WORKDATE}"
    sudo mv /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME} /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}-${WORKDATE}
  else
    echo "Creating /opt/xtuple/${MWC_VERSION}"
    sudo mkdir -p /opt/xtuple/${MWC_VERSION}
  fi

  echo "Copying ${WORKDIR}/${ERPTARDIR} to /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}"
  sudo cp -R ${WORKDIR}/${ERPTARDIR} /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}
  echo "Setting owner to ${DEPLOYER_NAME} on /opt/xtuple/${MWC_VERSION}"
  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /opt/xtuple/${MWC_VERSION}

  config_mwc_scripts

  local XTAPP=$(psql -At -U admin -p ${PGPORT} ${ERP_DATABASE_NAME} -c "SELECT getEdition();")
  if [[ ${XTAPP} == "PostBooks" ]]; then
    APPLY_FOUNDATION='-f'
  fi

  HAS_XTEXT=$(psql -At -U admin ${ERP_DATABASE_NAME} -c "SELECT 1 FROM pg_catalog.pg_class JOIN pg_namespace n ON n.oid = relnamespace WHERE nspname = 'xt' AND relname = 'ext';")
  cd /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/xtuple
  if [[ $HAS_XTEXT == 1 ]]; then
    echo "${ERP_DATABASE_NAME} has xt.ext so we can preload things that may not exist.  There may be exceptions to doing this."
    psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/preload.sql
  fi

  scripts/build_app.js -c /etc/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/config.js ${APPLY_FOUNDATION} 2>&1 | tee buildapp_output.log
  RET=$?
  msgbox "$(cat buildapp_output.log)"
  if [[ $RET -ne 0 ]]; then
    main_menu
  fi

  scripts/build_app.js -c /etc/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/config.js ${APPLY_FOUNDATION} 2>&1 | tee buildapp_output.log
  RET=$?
  msgbox "$(cat buildapp_output.log)"
  if [[ $RET -ne 0 ]]; then
    main_menu
  fi

  if [[ $HAS_XTEXT != 1 ]]; then
    echo "${ERP_DATABASE_NAME} does not have xt.ext"
    # We can check for the private extensions dir...
    if [[ -d "/opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/private-extensions" ]] ; then
      scripts/build_app.js -c /etc/xtuple/$MWC_VERSION/${ERP_DATABASE_NAME}/config.js -e ../private-extensions/source/inventory ${APPLY_FOUNDATION} 2>&1 | tee buildapp_output.log
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
    scripts/build_app.js -c /etc/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/config.js 2>&1 | tee buildapp_output.log
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

stop_mwc() {
  echo "Stopping any node.js for this instance"
  sudo service xtuple-${ERP_DATABASE_NAME} stop
}

start_mwc() {
  echo "Lets try starting this..."
  sudo service xtuple-${ERP_DATABASE_NAME} stop
  sudo service xtuple-${ERP_DATABASE_NAME} start
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Something went wrong trying to run"
    echo "sudo service xtuple-${ERP_DATABASE_NAME} start"
  else
    msgbox "service xtuple-${ERP_DATABASE_NAME} started successfully"
  fi
}

config_xtc() {
echo "Updating the xTupleCommerce Login/Password"
psql -U xtuplecommerce -d xtuplecommerce -f ${WORKDIR}/sql/setadmin.sql


# (echo '127.0.0.1 ${NGINX_ECOM_DOMAIN} ${NGINX_SITE} ) | sudo tee -a /etc/hosts >/dev/null
echo "Setting the local /etc/hosts file for 127.0.0.1 xtuple.xd"
(echo '127.0.0.1 xtuple.xd') | sudo tee -a /etc/hosts >/dev/null


}

install_example_gateway() {
psql -U admin -p 5432 ${ERP_DATABASE_NAME} -c "INSERT INTO paymentgateways.gateway (  gateway_name,  gateway_hostname,  gateway_base_path,  gateway_node_lib_name ) \
SELECT  ${GATEWAY_NAME},  ${GATEWAY_HOSTNAME},  ${GATEWAY_BASE_PATH},  ${GATEWAY_NODE_LIB_NAME} \
WHERE NOT EXISTS ( SELECT 1 FROM paymentgateways.gateway WHERE gateway_name = ${GATEWAY_NAME} );"
}


setup_compass()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  source ${WORKDIR}/ruby.sh
}

setup_phpunit() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  # PHPUnit
  if type -p  "phpunit" > /dev/null; then
    echo "phpunit found"
  else
    echo "Installing phpunit and dependencies"

    wget https://phar.phpunit.de/phpunit-old.phar && \
    chmod +x phpunit-old.phar && \
    sudo mv phpunit-old.phar /usr/local/bin/phpunit
  fi
}

setup_flywheel() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  get_environment
  get_xtc_environment
  setup_xdruple_nginx
  setup_compass

  start_mwc

  local SITE_ENV_TMP_WORK=${WORKING}/xdruple-sites/${ERP_DATABASE_NAME}
  local SITE_ENV_TMP=${SITE_ENV_TMP_WORK}/${WENVIRONMENT}
  local SITE_ROOT=/var/www
  local SITE_WEBROOT=${SITE_ROOT}/${WENVIRONMENT}
  local KEY_PATH=/var/xtuple/keys
  local ERP_KEY_FILE_PATH=${KEY_PATH}/${NGINX_ECOM_DOMAIN_P12}

  # The site template developer
  local SITE_DEV=xtuple

  mkdir -p ${SITE_ENV_TMP_WORK}

  if [ -n ${NGINX_ECOM_DOMAIN_P12} ]; then
    load_oauth_site
  else
    die "DOMAIN NOT SET - EXITING!"
  fi

  sudo mkdir -p ${KEY_PATH}

  log_exec sudo chown -R ${DEPLOYER_NAME}.${DEPLOYER_NAME} ${SITE_ROOT}

  {
    echo -e "XXX\n0\nCloning ${SITE_TEMPLATE} to ${SITE_ENV_TMP}\nXXX"
    log_exec "git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${SITE_DEV}/${SITE_TEMPLATE} ${SITE_ENV_TMP}" 2>/dev/null

    echo -e "XXX\n10\nRunning submodule update\nXXX"
    log_exec "cd ${SITE_ENV_TMP} && git submodule update --init --recursive" 2>/dev/null

    echo -e "XXX\n20\nRunning composer install\nXXX"
    # Check for composer token
    GITHUB_TOKEN=$(git config --get github.token)
    cat << EOF > /home/${DEPLOYER_NAME}/.composer/config.json
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

setup_xtuplecommerce() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

if [[ ! -f ${WORKDIR}/${XTC_WWW_TARBALL} ]]; then
    echo "Looking for: ${XTC_WWW_TARBALL}"
    echo "Can't find it... This is important"
    exit 2
fi

sudo mkdir -p /var/www
echo "Directory /var/www created."

cd $WORKDIR
XTCTARDIR=$(tar -tzf ${XTC_WWW_TARBALL} | head -1 | cut -f1 -d"/")

echo "Extracting ${XTC_WWW_TARBALL}"
tar xf ${XTC_WWW_TARBALL}
if [[ -d "/var/www/xTupleCommerce" ]]; then
echo "Moving old /var/www/xTupleCommerce directory to /var/www/xTupleCommerce-${WORKDATE}"
sudo mv /var/www/xTupleCommerce /var/www/xTupleCommerce-${WORKDATE}
fi

sudo mv $WORKDIR/${XTCTARDIR} /var/www/xTupleCommerce
sudo chown -R www-data:www-data /var/www/xTupleCommerce

}

setup_xdruple_nginx() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  install_nginx
  configure_nginx || die
  drupal_crontab  || die
}


webnotes() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

if type -p "ec2metadata" > /dev/null; then

#prefer this if we have it and we're on EC2...

IP=$(ec2metadata --public-ipv4)

else

IP=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)

fi

if [[ -z ${IP} ]]; then
IP="The IP of This Machine"
fi

cat << EOF > xtuplecommerce_connection.log
     ************************************"
     ***** IMPORTANT!!! PLEASE READ *****"
     ************************************"

     Here is the information to get logged in!

     First, Add the following to your system's hosts file
     Windows: %SystemRoot%\System32\drivers\etc\hosts
     OSX/Linux: /etc/hosts

     ${IP} xtuple.xd

     Here is where you can login:
     xTuple Desktop Client v${MWC_VERSION}:
     Server: ${IP}
     Port: 5432
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
cat xtuplecommerce_connection.log
}

destroy_env() {
  echo "About to delete the following"
}

xtau_deploy_mwc() {
  read_configs ${WORKDIR}/xtau_mwc-${WORKDATE}.config
}

install_composer() {
  mkdir -p ~/.composer

# git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/xtuple/xdruple-server
  local TYPE=${RUNTIMEENV}      # vagrant | ???

  sudo timedatectl set-timezone ${TIMEZONE}
  source ${WORKING}/php.sh ${TYPE} ${TIMEZONE} ${DEPLOYER_NAME} ${GITHUB_TOKEN}
}

