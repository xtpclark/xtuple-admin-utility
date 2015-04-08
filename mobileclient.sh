#!/bin/bash

NODE_VERSION=0.10.31

XTMWC="/tmp/xtmwc"
rm -rf $XTMWC
mkdir -p $XTMWC

mwc_menu() {

    log "Opened Web Client menu"

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Web\ Client\ Menu )" 0 0 9 --cancel-button "Exit" --ok-button "Select" \
            "1" "Install xTuple Web Client" \
            "2" "Remove xTuple Web Client" \
            "3" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            do_exit
        elif [ $RET -eq 0 ]; then
            case "$PGM" in
            "1") install_mwc_prereqs ;;
            "2") remove_mwc ;;
            "3") break ;;
            *) msgbox "Error. How did you get here? >> postgresql_menu" && do_exit ;;
            esac || postgresql_menu
        fi
    done

}

# $1 is xTuple version (4.8.0, 4.9.0, etc)
install_mwc() {

    log_exec apt-get -y install postgresql-$1 postgresql-client-$1 postgresql-contrib-$1 postgresql-$1-plv8
    RET=$?
    if [ $RET -eq 1 ]; then
    do_exit
    elif [ $RET -eq 0 ]; then
        export PGUSER=postgres
        export PGPASSWORD=postgres
        export PGHOST=localhost
        export PGPORT=5432
    fi
    return $RET

}

install_mwc_prereqs() {
    log "installing web client prerequisite packages..."

    if [ "$DISTRO" = "debian" ];
    then
    # for Debian wheezy (7.x) we need some things from the wheezy-backports
    sudo add-apt-repository -y "deb http://ftp.debian.org/debian wheezy-backports main"
    fi

    #sudo add-apt-repository -y "deb http://apt.postgresql.org/pub/repos/apt/ ${DEBDIST}-pgdg main"
    #sudo wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    log_exec sudo apt-get -qq update
    log_exec sudo apt-get -q -y install build-essential libssl-dev

    log "Cloning xTuple Web Client Source Code to ~/xtuple"
    rm -rf ~/xtuple
    mkdir ~/xtuple && cd ~/xtuple
    
	git clone git://github.com/xtuple/xtuple.git
    
    # this has always looked odd to me
    cd ~/xtuple/xtuple
    export XT_DIR=~/xtuple/xtuple
    
    if [ ! -d "/usr/local/nvm" ]; then
        log_exec sudo rm -f /usr/local/bin/nvm
        log_exec sudo mkdir /usr/local/nvm
        log_exec sudo git clone https://github.com/xtuple/nvm.git /usr/local/nvm
        log_exec sudo ln -s /usr/local/nvm/nvm_bin.sh /usr/local/bin/nvm
        log_exec sudo chmod +x /usr/local/bin/nvm
    fi
    log_exec sudo nvm install $NODE_VERSION
    log_exec sudo nvm use $NODE_VERSION
    log_exec sudo nvm alias default $NODE_VERSION
    log_exec sudo nvm alias xtuple $NODE_VERSION

    # use latest npm
    log_exec sudo npm install -fg npm@1.4.25
    # npm no longer supports its self-signed certificates
    log "telling npm to use known registrars..."
    log_exec npm config set ca ""

    log_exec log "installing npm modules..."
    log_exec sudo npm install -g bower
    log_exec sudo chown -R $USER $HOME/.npm
    log_exec npm install --unsafe-perm
}

init_everythings() {
	log "Setting properties of admin user"

	cd $XT_DIR/node-datasource

	cat sample_config.js | sed "s/testDatabase: \"\"/testDatabase: '$DATABASE'/" > config.js
	log "Configured node-datasource"
	log "The database is now set up..."

	mkdir -p $XT_DIR/node-datasource/lib/private
	cd $XT_DIR/node-datasource/lib/private
	cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > salt.txt
	log "Created salt"
	cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > encryption_key.txt
	log "Created encryption key"
	openssl genrsa -des3 -out server.key -passout pass:xtuple 1024 2>&1 | tee -a $LOG_FILE
	openssl rsa -in server.key -passin pass:xtuple -out key.pem -passout pass:xtuple 2>&1 | tee -a $LOG_FILE
	openssl req -batch -new -key key.pem -out server.csr -subj '/CN='$(hostname) 2>&1 | tee -a $LOG_FILE
	openssl x509 -req -days 365 -in server.csr -signkey key.pem -out server.crt 2>&1 | tee -a $LOG_FILE
	if [ $? -ne 0 ]
	then
		log "Failed to generate server certificate in $XT_DIR/node-datasource/lib/private"
		return 3
	fi

	cd $XT_DIR/test/lib
  cat sample_login_data.js | sed "s/org: \'dev\'/org: \'$DATABASE\'/" > login_data.js
	log "Created testing login_data.js"

	cdir $XT_DIR
	npm run-script test-build 2>&1 | tee -a $LOG_FILE

	log "You can login to the database and mobile client with:"
	log "  username: admin"
	log "  password: admin"
	log "Installation now finished."
	log "Run the following commands to start the datasource:"
	if [ $USERNAME ]
	then
		log "cd node-datasource"
		log "node main.js"
	else
		log "cd /usr/local/src/xtuple/node-datasource/"
		log "node main.js"
	fi
}