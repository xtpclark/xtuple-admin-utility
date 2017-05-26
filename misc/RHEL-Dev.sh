#!/bin/bash
WORKDIR=`pwd`

# What version do you want to build?
# Check: https://github.com/xtuple/qt-client/tags
GITTAG=v4.10.0

installEnv() {
yum install -y  			\
        deltarpm					\
        wget						\
        git 						\
        gcc-c++						\
        nano						\
        perl 						\
        python 						\
        flex 						\
        bison 						\
        ruby 						\
        axel						\
        curl						\
        gperf 						

yum install -y  			 \
        postgresql-devel  			\
        postgresql-libs  			\
        readline  					\
        krb5-devel 					\
        mariadb-devel  				\
        pam-devel  					\
        perl-devel 					\
        readline-devel  			\
        readline  					\
        sqlite-devel 				\
        openssl-devel 	 			\
        openldap-devel 				\
        libxml2-devel  				\
        libxslt-devel  				\
        libevdev-devel              \
        zlib-devel  				\
        unixODBC-devel 				\
        libxcb						\
        libxcb-devel  				\
        icu                         \
        libicu                      \
        xkeyboard-config		    \
        gtk2-devel                  \
        xcb-util					\
        fontconfig-devel 			\
        xorg-x11-server-devel 		\
        libXcursor-devel 			\
        libXcomposite-devel 		\
        libXdamage-devel 			\
        libXrandr-devel 			\
        libXtst-devel 				\
        libXrender-devel 			\
        libXcomposite-devel 		\
        libdrm-devel 				\
        alsa-lib 					\
        alsa-lib-devel				\
        cups-libs 					\
        cups-devel					\
        pulseaudio-libs-devel 		\
        systemd-libs 				\
        systemd-devel               \
        gstreamer-devel 			\
        gstreamer-plugins-base      \
        gstreamer-plugins-base-devel \
        libXdmcp                 \        
        libXfont                 \
        libepoxy                 \
        libfontenc               \
        libxkbfile               \
        mtdev                    \
        xkeyboard-config         \
        xorg-x11-server-Xorg     \
        xorg-x11-server-common   \
        xorg-x11-xkb-utils       \
        libevdev-utils           \
        xorg-x11-drv-evdev       \
        xorg-x11-drv-evdev-devel 

}

build_QT() {
SRCDIR=/usr/local/src

cd $SRCDIR

wget https://download.qt.io/archive/qt/5.5/5.5.1/single/qt-everywhere-opensource-src-5.5.1.tar.gz
tar zxvf qt-everywhere-opensource-src-5.5.1.tar.gz

QTSRCDIR=${SRCDIR}/qt-everywhere-opensource-src-5.5.1

# Need to remove leveldb dir inorder to build qt-web etc...
# See: https://github.com/xtuple/qt-client/wiki/Desktop-Development-Environment-Setup#get-qt
# https://bugreports.qt.io/browse/QTBUG-15344

cd ${QTSRCDIR}/qtwebkit/Tools/qmake/config.tests
rm -r leveldb

cd ${QTSRCDIR}

./configure -qt-sql-psql -qt-sql-sqlite -qt-zlib -qt-libpng -qt-libjpeg -qt-xcb -nomake examples -skip qtwebengine -opensource -confirm-license
make -j`nproc`

make install

# Maybe this should be in the global profile?  
# ubuntu uses .profile, rhel uses .bash_profile by default.

bash -c "echo export PATH=/usr/local/Qt-5.5.1/bin:$PATH >> ~/.bash_profile"
bash -c "echo export LD_LIBRARY_PATH=/usr/local/Qt-5.5.1/lib:$LD_LIBRARY_PATH >> ~/.bash_profile"

}

build_xtuple() {

    XTWORKDIR=${WORKDIR}/xtuple

    mkdir -p ${XTWORKDIR}

    cd ${XTWORKDIR}
    
    
    git clone https://github.com/xtuple/qt-client
    cd ${XTWORKDIR}/qt-client
    
    if [ -z "$GITTAG" ] ; then
    
     GITTAG=$(curl https://api.github.com/repos/xtuple/qt-client | \
             awk -v FS='"' '/default_branch/ { print $4 }')
             
      if [ -z "$GITTAG" ] ; then
        GITTAG=master
       fi
    fi
    git checkout $GITTAG
    git submodule update --init --recursive
    cd openrpt
    qmake
    make -j`nproc`
    cd ../csvimp
    qmake
    make -j`nproc`
    cd ..
    qmake
    make -j`nproc`

}


installEnv

build_QT

build_xtuple
