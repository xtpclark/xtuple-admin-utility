#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$DEVENV_SH" ] ; then # {
DEVENV_SH=true

dev_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Opened development menu"

  while true; do
      CC=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Development\ Menu )" 0 0 10 --cancel-button "Cancel" --ok-button "Select" \
          "1" "Install Development Pre-reqs"            \
          "2" "Build & Install Qt 5.5.1"                \
          "3" "Build xTuple"                            \
          "4" "Set up xTupleCommerce Dev Environment"   \
          "5" "Generate xTupleCommerce API Docs"        \
          "6" "Generate xTupleCommerce Developer Docs"  \
          3>&1 1>&2 2>&3)
      RET=$?

      if [ $RET -ne 0 ]; then
          break
      else
        case "$CC" in
          "1") install_dev_prereqs ;;
          "2") build_qt5           ;;
          "3") build_xtuple        ;;
          "4") build_xtc_dev_env   ;;
          "5") build_xtc_apidocs   ;;
          "6") build_xtc_devdocs   ;;
          *) msgbox "Don't know how you got here! Please report on GitHub >> dev_menu $CC" && break ;;
        esac
      fi
  done
}

install_dev_prereqs() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  log "Installing Development Environment pre-requisites..."

  log_exec sudo apt-get -y --quiet install                                       \
                                   bison flex gperf libasound2-dev libbz2-dev    \
                                   libcap-dev libcups2-dev libdrm-dev            \
                                   libfontconfig1-dev libgcrypt11-dev            \
                                   libglu1-mesa-dev                              \
                                   libgstreamer-plugins-base0.10-dev             \
                                   libgstreamer0.10-dev libicu-dev libkrb5-dev   \
                                   libldap2-dev libmysqlclient-dev libnss3-dev   \
                                   libpam0g-dev libpci-dev libperl-dev libpq-dev \
                                   libpulse-dev libreadline6-dev libsqlite0-dev  \
                                   libssl-dev libudev-dev libx11-xcb-dev         \
                                   "^libxcb.*" libxcomposite-dev libxcursor-dev  \
                                   libxdamage-dev libxi-dev libxml2-dev          \
                                   libxrandr-dev libxrender-dev libxslt1-dev     \
                                   libxtst-dev readline-common ruby unixodbc-dev \
                                   xorg zlib1g-dev
    RET=$?
    if [ $RET -ne 0 ]; then
      msgbox "There was an error installing pre-requisites. Check the log and correct any issues before trying again."
    fi
    return $RET

}

build_qt5() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Building Qt5 from source"

  cd $WORKDIR

  # This moved: http://download.qt.io/official_releases/qt/5.5/5.5.1/single/qt-everywhere-opensource-src-5.5.1.tar.gz
  wget https://download.qt.io/archive/qt/5.5/5.5.1/single/qt-everywhere-opensource-src-5.5.1.tar.gz

  tar zxvf qt-everywhere-opensource-src-5.5.1.tar.gz
  cd qt-everywhere-opensource-src-5.5.1
  # we will likely want to embrace qtwebengine but for now it doubles the build time...
  log_exec ./configure -qt-sql-psql -qt-sql-sqlite -qt-zlib -qt-libpng -qt-libjpeg -nomake examples -skip qtwebengine -opensource -confirm-license
  RET=$?
  if [ $RET -ne 0 ]; then
    log "There was an error running configure. Check the log and correct any issues before trying again."
    return $RET
  fi

  log_exec make -j$(nproc)
  RET=$?
  if [ $RET -ne 0 ]; then
    log "There was an error building Qt. Check the log and correct any issues before trying again."
    return $RET
  fi

  log_exec sudo make install
  RET=$?
  if [ $RET -ne 0 ]; then
    log "There was an error installing Qt. Check the log and correct any issues before trying again."
    return $RET
  fi

  log "Adding Qt installation directory (/usr/local/Qt-5.5.1/) to PATH and LD_LIBRARY_PATH"
  sudo bash -c "echo export PATH=/usr/local/Qt-5.5.1/bin:$PATH >> ~/.profile"
  sudo bash -c "echo export LD_LIBRARY_PATH=/usr/local/Qt-5.5.1/lib:$LD_LIBRARY_PATH >> ~/.profile"

}

build_xtuple() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  cd $WORKDIR
  mkdir xtuple
  cd xtuple
  git clone https://github.com/xtuple/qt-client
  cd qt-client
  GITTAG=$(curl https://api.github.com/repos/xtuple/qt-client | \
           awk -v FS='"' '/default_branch/ { print $4 }')
  if [ -z "$GITTAG" ] ; then
    GITTAG=master
  fi
  git checkout $GITTAG
  git submodule update --init --recursive
  cd openrpt
  qmake
  make -j$(nproc)
  cd ../csvimp
  qmake
  make -j$(nproc)
  cd ..
  qmake
  make -j$(nproc)
}

build_xtc_dev_env() {
  if [ ${RUNTIMEENV} = 'vagrant' ] ; then

    dialog --ok-label "Submit"                           \
           --backtitle "PostgreSQL User Passwords"       \
           --title "PostgreSQL Passwords"                \
           --form "Set PostgreSQL Development Passwords" \
           0 0 0 \
          "Development:"  1 1 ""   1 20 50 0 \
                "Stage:"  2 1 ""   2 20 50 0 \
           "Production:"  3 1 ""   3 20 50 0 \
    3>&1 1>&2 2>&3 2> postgresql.ini
    RET=$?
    case $RET in
      $DIALOG_OK)
        read -d "\n" DEVELOPMENT_DB_PASS STAGE_DB_PASS PRODUCTION_DB_PASS <<<$(cat postgresql.ini)
        export DEVELOPMENT_DB_PASS STAGE_DB_PASS PRODUCTION_DB_PASS
        ;;
      *)
        return 1
        ;;
    esac

  fi
}

build_xtc_apidocs () {
  export PATH="/home/deployer/.composer/vendor/bin":$PATH
  local STARTDIR=$(pwd)
  date -R
  cd /home/deployer/source/xdruple
  git fetch origin
  git reset --hard origin/master
  apigen generate --source /home/deployer/source/xdruple/xdruple \
                  --destination /var/www/xdruple/api \
                  --config /home/deployer/source/xdruple/apigen.neon \
                  --quiet
  RET=$?
  cd $STARTDIR
  if [ $RET -ne 0 ] ; then
    echo "API documentation generation failed"
    return 1
  fi
  echo "API documentation generated"
}

build_xtc_devdocs() {
  export PATH="/home/deployer/.composer/vendor/bin":$PATH
  local STARTDIR=$(pwd)
  date -R
  cd /home/deployer/source/xdruple
  git fetch origin
  git reset --hard origin/master
  couscous generate --target=/var/www/xdruple/docs /home/deployer/source/xdruple
  RET=$?
  cd $STARTDIR
  if [ $RET -ne 0 ] ; then
    echo "Developer documentation generation failed"
    return 1
  fi
  echo "Developer documentation generated"
}

fi # }
