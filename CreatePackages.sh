#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

shopt extdebug

export WORKDATE=${WORKDATE:-$(date "+%m%d%y")}
export WORKDIR=${WORKDIR:-$(pwd)}
export BUILD_XT_TARGET_NAME=${BUILD_XT_TARGET_NAME:-xTupleREST}
export P12_KEY_FILE=${P12_KEY_FILE:-xTupleCommerce.p12}

source ${WORKDIR}/functions/gitvars.fun
source ${WORKDIR}/functions/setup.fun
source ${WORKDIR}/functions/oatoken.fun

export NODE_ENV=${NODE_ENV:-production}

# Create Packages for bundling xTuple REST-API and xTupleCommerce

mwc_createdirs_static_mwc()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  # From functions/setup.fun
  install_npm_node
  check_pgdep

  echo "Creating Directories in ${BUILD_XT_TARGET_NAME}-${WORKDATE}"

  BUILD_XT_ROOT=${WORKDIR}/${BUILD_XT_TARGET_NAME}-${WORKDATE}
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

  mkdir --parents ${BUILD_XT_ROOT}
  mkdir --parents ${BUILD_CONFIG_ETC}
  mkdir --parents ${BUILD_CONFIG_XTUPLE}/private
  mkdir --parents ${BUILD_CONFIG_INIT}
  mkdir --parents ${BUILD_CONFIG_SYSTEMD}
}

mwc_build_static_mwc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  local BUILDTAG REPOS
  local STARTDIR=$(pwd)

  [ -n "$GITHUB_TOKEN" ] || get_github_token

  REPOS="xtuple nodejsshim"
  if $PRIVATEEXT ; then
    REPOS="$REPOS private-extensions xtdash"
  fi

  for REPO in $REPOS ; do
    # TODO: read the BUILDTAG from an external source
    if [ "$REPO" = "xtuple" ] ; then
      BUILDTAG=${MWCREFSPEC:-TAG}
    else
      BUILDTAG="TAG"
    fi
    gitco $REPO ${BUILD_XT_ROOT} ${BUILDTAG} || die
  done
}

mwc_createinit_static_mwc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  # create the upstart scripts
  cat <<-EOF > ${BUILD_CONFIG_INIT}/xtuple-${ERP_DATABASE_NAME}.conf
	description "xTuple Node Server"
	start on filesystem or runlevel [2345]
	stop on runlevel [!2345]
	console output
	respawn
	#setuid xtuple
	#setgid xtuple
	chdir /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME/xtuple/node-datasource
	exec ./main.js -c $CONFIGDIR/config.js > /var/log/node-datasource-$BUILD_XT_TAG-$MWCNAME.log 2>&1
EOF
}

mwc_createsystemd_static_mwc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cat <<-EOF > ${BUILD_CONFIG_SYSTEMD}/xtuple-${ERP_DATABASE_NAME}.service

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
	SyslogIdentifier=xtuple-${ERP_DATABASE_NAME}
	ExecStart=/usr/local/bin/node /opt/xtuple/$BUILD_XT_TAG/$ERP_DATABASE_NAME/xtuple/node-datasource/main.js -c $CONFIGDIR/config.js

EOF

}

remove_git_dirs()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  echo "Removing Git Directories"
  [ -n "$BUILD_XT_ROOT" ] && rm -rf ${BUILD_XT_ROOT}/*/.git
}

mwc_bundle_mwc()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  echo "Bundling MWC"

  cd ${WORKDIR}

  cat << EOF >  ${BUILD_XT_ROOT}/xtau_config
  export NODE_ENV=production
  export PGVER=${PGVER}
  export BUILD_XT_TAG=${BUILD_XT_TAG}
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
  BUILD_XTC_ROOT=${WORKDIR}/${BUILD_XTC_TARGET_NAME}-${WORKDATE}
  BUILD_XTC_CONF_DIR=${BUILD_XTC_ROOT}/config

  CDDREPOURL=http://satis.codedrivendrupal.com
  GITXDDIR=xtuple/xdruple-drupal
  local PROJ_STABILITY

  if $IS_DEV_ENV ; then
    PROJ_STABILITY=dev
  else
    PROJ_STABILITY=stable
  fi

  log_exec composer create-project --stability ${PROJ_STABILITY} --no-interaction --repository-url=${CDDREPOURL} ${GITXDDIR} ${BUILD_XTC_ROOT}
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

  echo "Bundling xTupleCommerce"

  cd ${WORKDIR}
  generate_p12
  generateoasql

  echo "Copy a p12 key file that matches the sql in oa2client.sql"
  cp ${WORKDIR}/private/${P12_KEY_FILE} ${BUILD_XTC_ROOT}
  RET=$?
  if [[ $RET -ne 0 ]]; then
   echo "There was a problem copying the P12 Key. Continuing..."
  else
   echo "Copied ${WORKDIR}/private/${P12_KEY_FILE} to ${BUILD_XTC_ROOT}"
  fi

  echo "Copy a settings.php file that tells the xTupleCommerce site which database to connect to."
  cp ${WORKDIR}/private/settings.php ${BUILD_XTC_ROOT}/drupal/core/sites/default/
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "There was a problem copying the settings.php file. Continuing..."
  else
    echo "Copied ${WORKDIR}/private/settings.php to ${BUILD_XTC_ROOT}/drupal/core/sites/default/"
  fi

  echo "Building ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz"
  cp -R ${BUILD_XTC_ROOT} ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}
  RET=$?
  if [[ $RET -ne 0 ]]; then
    die "Could not copy ${BUILD_XTC_ROOT} to ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}"
  fi
  echo "Copied ${BUILD_XTC_ROOT} to ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}"
  tar czf ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}
RET=$?
  if [[ $RET -ne 0 ]]; then
    die "Bundling xTupleCommerce Failed"
  fi

  echo "xTupleCommerce bundling was a success!"
  echo "Created: ${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz "
}

xtc_build_xtuplecommerce_envphp() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  cd ${WORKDIR}
  CRMACCT=${CRMACCT:-xTupleBuild}

  loadcrm_gitconfig
  checkcrm_gitconfig

  log "Populating environment.xml file with settings for ${CRMACCT}"
  log "See loadcrm_gitconfig() and checkcrm_gitconfig()"

  echo "Writing out environment.xml"
  mkdir --parents ${SITE_WEBROOT}/application/config
  safecp ${SITE_WEBROOT}drupal/xdruple/dist/environment.xml.dist ${SITE_WEBROOT}/application/config/environment.xml
  replace_params --no-backup ${SITE_WEBROOT}/application/config/environment.xml
}

writeout_config() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cat << EOF > ${WORKDIR}/CreatePackages-${WORKDATE}.config
    NODE_ENV=production
    PGVER=${PGVER}
    BUILD_XT_TAG=${BUILD_XT_TAG}
    ERP_MWC_TARBALL=${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz
    XTC_WWW_TARBALL=${BUILD_XTC_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz
EOF
}

writeout_xtau_config() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cat << EOF > ${WORKDIR}/xtau_mwc-${WORKDATE}.config
    export NODE_ENV=production
    export PGVER=${PGVER}
    export BUILD_XT_TAG=${BUILD_XT_TAG}
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
    install_webclient
    sudo systemctl daemon-reload
    service_restart xtuple-${ERP_DATABASE_NAME}

    msgbox "Web Client Setup Complete!
Here is where you can login:

xTuple Desktop Client: ${BUILD_XT_TAG}

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
    # we're using a yesno box for a multiple choice question - Yes/No/Cancel.
    # whiptail returns 255 on ESC => Cancel
    return 255
  else
    install_webclient
    RET=$?
    return $RET
  fi
}

# TODO: make each step handle remote hosts
xtau_deploy_ecommerce() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  prepare_os_for_xtc    # xdruple-server/scripts/common.sh
  deployer_setup        # xdruple-server/scripts/depoyler.sh
  install_nginx         # xdruple-server/scripts/nginx-server.sh
  configure_nginx
  php_setup             # xdruple-server/scripts/php.sh
  xtc_pg_setup          # xdruple-server/scripts/postgresql.sh
  postfix_setup         # xdruple-server/scripts/postfix.sh
  ruby_setup            # xdruple-server/scripts/ruby.sh
  # xdruple-server/scripts/zsh.sh - see get_deployer_info and deployer_setup
  druple_crontab        # xdruple-server/scripts/cron.sh

  xtc_code_setup || die
  setup_flywheel || die
  webnotes

  main_menu      || die
}

mwc_only() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  mwc_createdirs_static_mwc
  mwc_build_static_mwc
  encryption_setup ${BUILD_CONFIG_XTUPLE} ${BUILD_XT}
  mwc_createinit_static_mwc
  mwc_createsystemd_static_mwc
  remove_git_dirs
  mwc_bundle_mwc
}

xtc_only() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  # TODO: this doesn't look right {
  xtc_build_static_xtuplecommerce
  xtc_build_xtuplecommerce_envphp
  xtc_bundle_xtuplecommerce
  # }

  # TODO: does this go before or after ^^^?
  xtau_deploy_ecommerce
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

  if [ -z "${ERP_DATABASE_NAME}" ] ; then
    if [ -z "${PGPORT}" ] ; then
      set_database_info_select
    fi
    select_database
    RET=$?
    if [ "$RET" -ne 0 ] ; then
      return 1
    fi
    ERP_DATABASE_NAME=${DATABASE}
  fi

  if [[ -f ${MWC_CONFIG} ]]; then
    echo "sourcing ${MWC_CONFIG}"
    source ${MWC_CONFIG}
  fi
  if [[ -e ${ERP_MWC_TARBALL}  ]]; then
    echo "Looks like we have a package already. Skipping any hard work."
    echo "Tarball: ${BUILD_XT_TARGET_NAME}-${BUILD_XT_TAG}.tar.gz "
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
  ./CreatePackages.sh xtau_deploy_ecommerce
  ./CreatePackages.sh build_all"
else
  ${1}
fi

exit
