#!/bin/bash
export WORKDATE=${WORKDATE:-$(date "+%m%d%y")}
export BUILD_WORKING=${BUILD_WORKING:-$(pwd)}
export BUILD_XT_TARGET_NAME=${BUILD_XT_TARGET_NAME:-xTupleREST}
export P12_KEY_FILE=${P12_KEY_FILE:-xTupleCommerce.p12}

source ${BUILD_WORKING}/functions/gitvars.fun
source ${BUILD_WORKING}/functions/setup.fun

export NODE_ENV=${NODE_ENV:-production}

# Create Packages for bundling xTuple REST-API and xTupleCommerce

mwc_createdirs_static_mwc()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  # From functions/setup.fun
  install_npm_node
  check_pgdep

  echo "Creating Directories in ${BUILD_XT_TARGET_NAME}-${WORKDATE}"

  BUILD_XT_ROOT=${BUILD_WORKING}/${BUILD_XT_TARGET_NAME}-${WORKDATE}
  BUILD_CONFIG_ETC=${BUILD_XT_ROOT}/etc
  BUILD_CONFIG_XTUPLE=${BUILD_CONFIG_ETC}/xtuple
  BUILD_CONFIG_INIT=${BUILD_CONFIG_ETC}/init
  BUILD_CONFIG_SYSTEMD=${BUILD_CONFIG_ETC}/systemd/system
  BUILD_XT=${BUILD_XT_ROOT}/xtuple
  BUILD_PE=${BUILD_XT_ROOT}/private-extensions
  BUILD_XD=${BUILD_XT_ROOT}/xdruple-extension
  BUILD_PG=${BUILD_XT_ROOT}/payment-gateways
  BUILD_NJ=${BUILD_XT_ROOT}/nodejsshim
  BUILD_EP=${BUILD_XT_ROOT}/enhanced-pricing
  BUILD_DA=${BUILD_XT_ROOT}/xtdash

  mkdir -p ${BUILD_XT_ROOT}
  mkdir -p ${BUILD_CONFIG_ETC}
  mkdir -p ${BUILD_CONFIG_XTUPLE}/private
  mkdir -p ${BUILD_CONFIG_INIT}
  mkdir -p ${BUILD_CONFIG_SYSTEMD}
}


mwc_build_static_mwc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  local BUILDTAG REPOS
  local STARTDIR=$(pwd)

  [ -n "$GITHUB_TOKEN" ] || generate_github_token

  # TODO: find a smart way to build this list that's not specific to xTupleCommerce
  REPOS=" xtuple
          private-extensions
          enhanced-pricing
          nodejsshim
          payment-gateways
          xdruple-extension
          xtdash
        "

  for REPO in $REPOS ; do
    if git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/xtuple/$REPO ${BUILD_XT_ROOT}/$REPO ; then
      cd ${BUILD_XT_ROOT}/$REPO
      git fetch --tags
      # TODO: read the BUILDTAG from an external source
      BUILDTAG=$(git describe --tags $(git rev-list --tags --max-count=1))
      git checkout ${BUILDTAG}
      git submodule update --init --recursive

      if [[ -f package.json ]] ; then
        echo "package.json found for ${REPO} => running npm install"
        npm install
        RET=$?
        echo "npm install returned: ${RET}"
        [ "$RET" -eq 0 ] || die
      fi
      cd ${STARTDIR}
    fi
  done

  # some repos require special treatment
  if [ -d xtuple ] ; then
    cd xtuple
    export BUILD_XT_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))
    cd $STARTDIR
  fi

  if [ -d payment-gateways ] ; then
    cd payment-gateways
    make
    cd $STARTDIR
  fi
}

mwc_createconf_static_mwc()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

   # setup encryption details
   touch ${BUILD_CONFIG_XTUPLE}/private/salt.txt
   touch ${BUILD_CONFIG_XTUPLE}/private/encryption_key.txt

   cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > ${BUILD_CONFIG_XTUPLE}/private/salt.txt
   cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > ${BUILD_CONFIG_XTUPLE}/private/encryption_key.txt

   chmod 660 ${BUILD_CONFIG_XTUPLE}/private/encryption_key.txt
   chmod 660 ${BUILD_CONFIG_XTUPLE}/private/salt.txt

   openssl genrsa -des3 -out ${BUILD_CONFIG_XTUPLE}/private/server.key -passout pass:xtuple 1024
   openssl rsa -in ${BUILD_CONFIG_XTUPLE}/private/server.key -passin pass:xtuple -out ${BUILD_CONFIG_XTUPLE}/private/key.pem -passout pass:xtuple
   openssl req -batch -new -key ${BUILD_CONFIG_XTUPLE}/private/key.pem -out ${BUILD_CONFIG_XTUPLE}/private/server.csr -subj '/CN='$(hostname)
   openssl x509 -req -days 365 -in ${BUILD_CONFIG_XTUPLE}/private/server.csr -signkey ${BUILD_CONFIG_XTUPLE}/private/key.pem -out ${BUILD_CONFIG_XTUPLE}/private/server.crt

   sed -s  "/encryptionKeyFile/c\      encryptionKeyFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt\"," \
       -s  "/keyFile/c\      keyFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/key.pem\"," \
       -s  "/certFile/c\      certFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.crt\"," \
       -s  "/saltFile/c\      saltFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt\"," \
       -s  "/databases:/c\      databases: [\"$DATABASE\"]," ${BUILD_XT}/node-datasource/sample_config.js > ${BUILD_CONFIG_XTUPLE}/config.js
   # sed -i  "/port: 5432/c\      port: \"$PGPORT\"," ${BUILD_CONFIG_XTUPLE}/config.js

echo "Wrote out keys for MWC:
 ${BUILD_CONFIG_XTUPLE}/private/salt.txt
 ${BUILD_CONFIG_XTUPLE}/private/encryption_key.txt
 ${BUILD_CONFIG_XTUPLE}/private/server.key
 ${BUILD_CONFIG_XTUPLE}/private/key.pem
 ${BUILD_CONFIG_XTUPLE}/private/server.csr
 ${BUILD_CONFIG_XTUPLE}/private/server.crt

Wrote out config for MWC:
 ${BUILD_CONFIG_XTUPLE}/config.js"

 }

mwc_createinit_static_mwc() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

# create the upstart scripts
cat << EOF > ${BUILD_CONFIG_INIT}/xtuple-${MWCNAME}.conf
description "xTuple Node Server"
start on filesystem or runlevel [2345]
stop on runlevel [!2345]
console output
respawn
#setuid xtuple
#setgid xtuple
chdir /opt/xtuple/$MWCVERSION/$MWCNAME/xtuple/node-datasource
exec ./main.js -c /etc/xtuple/$MWCVERSION/$MWCNAME/config.js > /var/log/node-datasource-$MWCVERSION-$MWCNAME.log 2>&1
EOF

}

mwc_createsystemd_static_mwc() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

cat << EOF > ${BUILD_CONFIG_SYSTEMD}/xtuple-${MWCNAME}.service

[Unit]
Description=xTuple ERP NodeJS Server
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
Restart=always
StandardOutput=syslog
StandardError=syslog
User=xtuple
Group=xtuple
Environment=NODE_ENV=production
ExecStop=/bin/kill -9 \$MAINPID
SyslogIdentifier=xtuple-$MWCNAME
ExecStart=/usr/local/bin/node /opt/xtuple/$MWCVERSION/$MWCNAME/xtuple/node-datasource/main.js -c /etc/xtuple/$MWCVERSION/$MWCNAME/config.js

EOF

}

mwc_remove_git_dirs()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  echo "Removing Git Directories"
  cd ${BUILD_XT} && rm -rf .git
  cd ${BUILD_PE} && rm -rf .git
  cd ${BUILD_XD} && rm -rf .git
  cd ${BUILD_PG} && rm -rf .git
  cd ${BUILD_NJ} && rm -rf .git
  cd ${BUILD_EP} && rm -rf .git
}

mwc_bundle_mwc()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  echo "Bundling MWC"

  cd ${BUILD_WORKING}

  cat << EOF >  ${BUILD_XT_ROOT}/xtau_config
  export NODE_ENV=production
  export PGVER=${PGVER}
  export MWC_VERSION=${BUILD_XT_TAG}
  export ERP_MWC_TARBALL=${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz
  export XTC_WWW_TARBALL=${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz
EOF

  cat << EOF >  ${BUILD_XT_ROOT}/versions
  xtuple@${BUILD_XT_TAG}
  private-extensions@${BUILD_PE_TAG}
  nodejsshim@${BUILD_NJ_TAG}
  xtdash@${BUILD_DA_TAG}
  payment-gateways@${BUILD_PG_TAG}
  enhanced-pricing@${BUILD_EP_TAG}
  xdruple-extension@${BUILD_XD_TAG}
EOF

  mv ${BUILD_XT_ROOT} ${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}
  echo "Cleaning up ${BUILD_XT_ROOT}"
  rm -rf ${BUILD_XT_ROOT}
  tar czf ${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz ${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}
  RET=$?
  if [[ $RET -ne 0 ]]; then
    die "Bundling MWC Failed"
  else
    export ERP_MWC_TARBALL=${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz
    echo "Bundled MWC as ${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz"
  fi
}

xtc_build_static_xtuplecommerce() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  echo "Building Static xTupleCommerce"

  BUILD_XTC_TARGET_NAME=xTupleCommerce
  BUILD_XTC_ROOT=${BUILD_WORKING}/${BUILD_XTC_TARGET_NAME}-${WORKDATE}
  BUILD_XTC_CONF_DIR=${BUILD_XTC_ROOT}/config

  CDDREPOURL=http://satis.codedrivendrupal.com
  GITXDDIR=xtuple/xdruple-drupal
  XDENV=dev

  echo "Running: composer create-project --stability ${XDENV} --no-interaction --repository-url=${CDDREPOURL} ${GITXDDIR} ${BUILD_XTC_ROOT}"

  composer create-project --stability ${XDENV} --no-interaction --repository-url=${CDDREPOURL} ${GITXDDIR} ${BUILD_XTC_ROOT}
  RET=$?
  [ $? -eq 0 ] || die "composer create-project returned $RET"

  echo "Running composer install"
  cd ${BUILD_XTC_ROOT}
  composer install
  RET=$?
  [ $? -eq 0 ] || die "composer install returned $RET"

  echo "Running console.php update:distributions -f (flywheel flag)"
  ./console.php update:distributions -f
  RET=$?
  [ $? -eq 0 ] || die "console.php update:distributions returned $RET"

  echo "Running console.php install:prepare:directories"
  ./console.php install:prepare:directories
  RET=$?
  [ $? -eq 0 ] || die "console.php install:prepare:directories returned $RET"
}

xtc_bundle_xtuplecommerce() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

source functions/oatoken.fun

echo "Bundling xTupleCommerce"

cd ${BUILD_WORKING}

generate_p12
generateoasql

echo "We include a p12 key file.  The content matches the sql in oa2client.sql"

cp ${BUILD_WORKING}/private/${P12_KEY_FILE} ${BUILD_XTC_ROOT}
RET=$?
if [[ $RET -ne 0 ]]; then
 echo "There was a problem copying the P12 Key. Continuing..."
else
 echo "Copied ${BUILD_WORKING}/private/${P12_KEY_FILE} to ${BUILD_XTC_ROOT}"
fi

echo "We include a settings.php file.  This is what tells the xTupleCommerce site to connect to which database"

cp ${BUILD_WORKING}/private/settings.php ${BUILD_XTC_ROOT}/drupal/core/sites/default/
RET=$?
if [[ $RET -ne 0 ]]; then
 echo "There was a problem copying the settings.php file. Continuing..."
else
 echo "Copied ${BUILD_WORKING}/private/settings.php to ${BUILD_XTC_ROOT}/drupal/core/sites/default/"
fi

echo "Attempting to create ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz"
cp -R ${BUILD_XTC_ROOT} ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}
RET=$?
if [[ $RET -ne 0 ]]; then
 echo "There was a problem copying ${BUILD_XTC_ROOT} to ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}"
 exit 2
else
 echo "Copied ${BUILD_XTC_ROOT} to ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}"
fi

tar czf ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}
RET=$?
if [[ $RET -ne 0 ]]; then
 echo "Bundling xTupleCommerce Failed"
 exit 2
else
 echo "xTupleCommerce bundling was a success!"
 echo "Created: ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz "
fi

}


xtc_build_xtuplecommerce_envphp() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  cd ${BUILD_WORKING}
  CRMACCT=xTupleBuild

  loadcrm_gitconfig
  checkcrm_gitconfig

  echo "Populating the environment.php file with settings for ${CRMACCT}"
  echo "See loadcrm_gitconfig() and checkcrm_gitconfig()"
  echo "Values are from ${HOME}/.gitconfig"

  cat << EOF > ${BUILD_XTC_CONF_DIR}/environment.xml || die
<?xml version="1.0" encoding="UTF-8" ?>
<environment type="${ENVIRONMENT}"
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

  cat << EOF > ${BUILD_XTC_CONF_DIR}/environment.php || die
<?php

\$configuration = [
  'environment' => '${ENVIRONMENT}',
  'xtuple_rest_api' => [
    'application' => '${ERP_APPLICATION}',
    'host' => '${ERP_HOST}',
    'database' => '${ERP_DATABASE}',
    'iss' => '${ERP_ISS}',
    'key' => '${ERP_KEY_FILE_PATH}',
    'debug' => ${ERP_DEBUG},
  ],
  'authorize_net' => [
    'login' => '${COMMERCE_AUTHNET_AIM_LOGIN}',
    'tran_key' => '${COMMERCE_AUTHNET_AIM_TRANSACTION_KEY}',
  ],
  'ups' => [
    'accountId' => '${UPS_ACCOUNT_ID}',
    'accessKey' => '${UPS_ACCESS_KEY}',
    'userId' => '${UPS_USER_ID}',
    'password' => '${UPS_PASSWORD}',
    'pickupSchedule' => '${UPS_PICKUP_SCHEDULE}',
  ],
  'fedex' => [
    'beta' => ${FEDEX_BETA},
    'key' => '${FEDEX_KEY}',
    'password' => '${FEDEX_PASSWORD}',
    'accountNumber' => '${FEDEX_ACCOUNT_NUMBER}',
    'meterNumber' => '${FEDEX_METER_NUMBER}',
  ],
  'xdruple_shipping' => [],
];
EOF

}

writeout_config() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cat << EOF > ${BUILD_WORKING}/CreatePackages-${WORKDATE}.config
    NODE_ENV=production
    PGVER=${PGVER}
    MWC_VERSION=${BUILD_XT_TAG}
    ERP_MWC_TARBALL=${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz
    XTC_WWW_TARBALL=${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz
EOF
}

writeout_xtau_config() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cat << EOF > ${BUILD_WORKING}/xtau_mwc-${WORKDATE}.config
    export NODE_ENV=production
    export PGVER=${PGVER}
    export MWC_VERSION=${BUILD_XT_TAG}
    export ERP_MWC_TARBALL=${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz
    export XTC_WWW_TARBALL=${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz
EOF
}

xtau_deploy_mwc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  WAN_IP=$(curl ipv4.icanhazip.com)
  LAN_IP=$(hostname -I)

  whiptail --yes-button "Yes" --no-button "No Thanks"  --yesno "Would you like to deploy ${ERP_MWC_TARBALL}?" 10 60
  RET=$?
  if [ $RET -eq 0 ] ; then
    install_mwc
    config_mwc_scripts
    sudo systemctl daemon-reload
    start_mwc

    msgbox "Web Client Setup Complete!
Here is where you can login:

xTuple Desktop Client: ${MWC_VERSION}

Public IP: ${WAN_IP}
Private IP: ${LAN_IP}
Port: ${PGPORT}
Database: ${ERP_DATABASE_NAME}
User: <Your User>
Pass: <Your Pass>
URL: https://${WAN_IP}:8443
URL: https://${LAN_IP}:8443
URL: https://${DOMAIN}:8443

You may need to configure your firewall or router to forward incoming traffic from
${WAN_IP} to ${LAN_IP}:${PGPORT} if you cannot connect from outside
your network. See your Administrator."

    main_menu

    RET=$?
    return $RET
  elif [ $RET -eq 255 ] ; then
    # specifically check for ESC here as we're using a yesno box for a multiple choice question.
    # it chooses no code even during escape, while in this case we want to actually escape when
    # someone hits escape.
    return 255
  else
    install_mwc
    RET=$?
    return $RET
  fi
}

xtau_deploy_ecommerce() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  setup_xdruple_nginx
  #load_oauth_site
  setup_flywheel || die
  main_menu      || die
}

mwc_only() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  mwc_createdirs_static_mwc
  mwc_build_static_mwc
  mwc_createconf_static_mwc
  mwc_createinit_static_mwc
  mwc_createsystemd_static_mwc
  mwc_remove_git_dirs
  mwc_bundle_mwc
}

xtc_only() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  xtc_build_static_xtuplecommerce
  xtc_build_xtuplecommerce_envphp
  xtc_bundle_xtuplecommerce
  writeout_config
}

build_all() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  mwc_only
  xtc_only
  writeout_config
}


try_deploy_xtau() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  export ISXTAU=1
  # Alternatively, enter the name of the tar.gz package...
  # and read this config from the tar.gz directly.

  local MWC_CONFIG=$(ls -t1 xtau_mwc-*.config 2>/dev/null | head -n 1)
  install_npm_node
  check_pgdep

  if [[ -f ${MWC_CONFIG} ]]; then
    echo "sourcing ${MWC_CONFIG}"
    source ${MWC_CONFIG}
  fi
  if [[ -e ${ERP_MWC_TARBALL}  ]]; then
    echo "Looks like we have a package already. Skipping any hard work."
    echo "Tarball: ${BUILD_XT_TARGET_NAME}-${MWC_VERSION}.tar.gz "
  else
    mwc_createdirs_static_mwc
    mwc_build_static_mwc
    mwc_bundle_mwc
    writeout_xtau_config
  fi
  xtau_deploy_mwc
}

if [[ -z "${1}" ]]; then
echo "Do one of:
./CreatePackages.sh mwc_only
./CreatePackages.sh xtc_only
./CreatePackages.sh try_deploy_xtau
./CreatePackages.sh build_all"
else
${1}
fi

exit
