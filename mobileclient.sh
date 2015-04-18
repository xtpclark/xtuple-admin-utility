#!/bin/bash

NODE_VERSION=0.10.32

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
            "1") install_mwc_menu ;;
            "2") remove_mwc ;;
            "3") break ;;
            *) msgbox "Error. How did you get here? >> mwc_menu / $PGM" && do_exit ;;
            esac || postgresql_menu
        fi
    done

}

install_mwc_menu() {

    MENUVER=$(whiptail --backtitle "$( window_title )" --menu "Choose Web Client Version" 15 60 7 --cancel-button "Exit" --ok-button "Select" \
        "1" "4.7.0" \
        "2" "4.8.0" \
        "3" "4.8.1" \
        "4" "Return to main menu" \
        3>&1 1>&2 2>&3)

    RET=$?

    if [ $RET -eq 1 ]; then
        return 0
    elif [ $RET -eq 0 ]; then
        case "$MENUVER" in
        "1") MWCVERSION=4.7.0 
               ;;
        "2") MWCVERSION=4.8.0 
               ;;
        "3") MWCVERSION=4.8.1
              ;;
        "4") return 0 ;;
        *) msgbox "How did you get here?" && do_exit ;;
        esac || main_menu
    fi
    
    log "Chose version $MWCVERSION"

    MWCNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter a name for this xTuple instance" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    log "Chose mobile name $MWCNAME"

    check_database_info

    DATABASES=()

    while read -r line; do
        DATABASES+=("$line" "$line")
     done < <( sudo su - postgres -c "psql --tuples-only -P format=unaligned -c \"SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');\"" )
     if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "List of databases on this cluster" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        log "There was an error selecting the database.. exiting"
        do_exit
    fi

    log "Chose database $DATABASE"

    if (whiptail --title "Private Extensions" --yesno "Would you like to install the commercial extensions? The \"xtuple\" user will need to have a SSH key setup for github, and be deploying the web client against a commercial database or this step will fail." 10 60) then
        log "Installing the commercial extensions"
        PRIVATEEXT=true
    else
        log "Not installing the commercial extensions"
        PRIVATEEXT=false
    fi

    install_mwc $MWCVERSION $MWCNAME $PRIVATEEXT $DATABASE
}


# $1 is xtuple version
# $2 is the instance name
# $3 is to install private extensions
# $4 is database name
install_mwc() {

    log "installing web client"

    export MWCVERSION=$1
    export MWCNAME="$2"

    if [ -z "$3" ] || [ "$3" = "false" ]; then
        PRIVATEEXT=false
    else
        PRIVATEEXT=true
    fi
    
    if [ -z "$4" ] && [ -z "$PGDATABASE" ]; then
        log "No database name passed to install_mwc... exiting."
        do_exit
    else
        PGDATABASE=$4
    fi

    log "Creating xtuple user..."
    log_exec sudo useradd xtuple -m -s /bin/bash
    
    log "Installing n..."
    cd $WORKDIR    
    wget https://raw.githubusercontent.com/visionmedia/n/master/bin/n -qO n
    log_exec chmod +x n
    log_exec sudo mv n /usr/bin/n
    # use it to set node to 0.10
    log "Installing node 0.10..."
    log_exec sudo n 0.10

    # need to install npm of course...
    log_exec sudo npm install -g npm@1.4.28

    # cleanup existing folder or git will throw a hissy fit
    sudo rm -rf /opt/xtuple/$MWCVERSION/"$MWCNAME"

    log "Cloning xTuple Web Client Source Code to /opt/xtuple/$MWCVERSION/xtuple"
    log "Using version $MWCVERSION with the given name $MWCNAME"
    log_exec sudo mkdir -p /opt/xtuple/$MWCVERSION/"$MWCNAME"
    log_exec sudo chown -R xtuple.xtuple /opt/xtuple

    # main code
    log_exec sudo su - xtuple -c "cd /opt/xtuple/$MWCVERSION/"$MWCNAME" && git clone https://github.com/xtuple/xtuple.git && cd  /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple && git checkout v$MWCVERSION && git submodule update --init --recursive && npm install bower && npm install"
    # main extensions
    log_exec sudo su - xtuple -c "cd /opt/xtuple/$MWCVERSION/"$MWCNAME" && git clone https://github.com/xtuple/xtuple-extensions.git && cd /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple-extensions && git checkout v$MWCVERSION && git submodule update --init --recursive && npm install"
    # private extensions
    if [ $PRIVATEEXT = "true" ]; then
        log "Installing the commercial extensions"
        log_exec sudo su xtuple -c "cd /opt/xtuple/$MWCVERSION/"$MWCNAME" && git clone git@github.com:/xtuple/private-extensions.git && cd /opt/xtuple/$MWCVERSION/"$MWCNAME"/private-extensions && git checkout v$MWCVERSION && git submodule update --init --recursive && npm install"
    else
        log "Not installing the commercial extensions"
    fi

    if [ ! -f /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource/sample_config.js ]; then
        log "Hrm, sample_config.js doesn't exist.. something went wrong. check the output/log and try again"
        do_exit
    fi

    export XTDIR=/opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple

    sudo rm -rf /etc/xtuple/$MWCVERSION/"$MWCNAME"
    log_exec sudo mkdir -p /etc/xtuple/$MWCVERSION/"$MWCNAME"/private

    # setup encryption details
    log_exec sudo touch /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt
    log_exec sudo touch /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt
    log_exec sudo chown -R xtuple.xtuple /etc/xtuple/$MWCVERSION/"$MWCNAME"
    # temporarily so we can cat to them since bash is being a bitch about quoting the trim string below
    log_exec sudo chmod 777 /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt
    log_exec sudo chmod 777 /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt

    cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt
    cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt

    log_exec sudo chmod 660 /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt
    log_exec sudo chmod 660 /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt

    log_exec sudo openssl genrsa -des3 -out /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.key -passout pass:xtuple 1024
    log_exec sudo openssl rsa -in /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.key -passin pass:xtuple -out /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/key.pem -passout pass:xtuple
    log_exec sudo openssl req -batch -new -key /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/key.pem -out /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.csr -subj '/CN='$(hostname)
    log_exec sudo openssl x509 -req -days 365 -in /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.csr -signkey /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/key.pem -out /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.crt

    log_exec sudo cp /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource/sample_config.js /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js

    log_exec sudo sed -i  "/encryptionKeyFile/c\      encryptionKeyFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt\"," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js
    log_exec sudo sed -i  "/keyFile/c\      keyFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/key.pem\"," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js
    log_exec sudo sed -i  "/certFile/c\      certFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.crt\"," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js
    log_exec sudo sed -i  "/saltFile/c\      saltFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt\"," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js

    log "Using database $PGDATABASE"
    log_exec sudo sed -i  "/databases:/c\      databases: [\"$PGDATABASE\"]," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js

    log_exec sudo chown -R xtuple.xtuple /etc/xtuple

    log_exec sudo su - xtuple -c "cd $XTDIR && ./scripts/build_app.js -c /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js"
    RET=$?
    if [ $RET -ne 0 ]; then
        log "buildapp failed to run. Check output and try again"
        do_exit
    fi

    # bring on systemd please.. but until then
    if [ $DISTRO = "ubuntu" ]; then
        log "Creating upstart script using filename /etc/init/xtuple-"$MWCNAME".conf"
        # create the upstart script
        sudo cp $WORKDIR/templates/ubuntu-upstart /etc/init/xtuple-"$MWCNAME".conf
        log_exec sudo sed -i  "/chdir /opt/xtuple/c\chdir /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource" /etc/init/xtuple-"$MWCNAME".conf
        log_exec sudo sed -i  "/exec/c\exec ./main.js -c /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js > /var/log/node-datasource-$MWCVERSION-"$MWCNAME".log 2>&1" /etc/init/xtuple-"$MWCNAME".conf
    elif [ $DISTRO = "debian" ]; then
        log "Creating debian init script using filename /etc/init.d/xtuple-"$MWCNAME""
        # create the weird debian sysvinit style script
        sudo cp $WORKDIR/templates/debian-init /etc/init.d/xtuple-"$MWCNAME"
        log_exec sudo sed -i  "/APP_DIR=/c\APP_DIR=\"/opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource\"" /etc/init.d/xtuple-"$MWCNAME"
        log_exec sudo sed -i  "/CONFIG_FILE=/c\CONFIG_FILE=\"/etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js\"" /etc/init.d/xtuple-"$MWCNAME"
        # should be +x from git but just in case...
        sudo chmod +x /etc/init.d/xtuple-"$MWCNAME"
    else
        log "Seriously? We made it all the way to where I need to write out the init script and suddenly I can't detect your distro -> $DISTRO codename -> $CODENAME"
        log "well, in the node-datasource dir, type node main.js -c /etc/init/xtuple-\"$MWCNAME\".conf and cross your fingers."
        do_exit
    fi
    
    # now that we have the script, start the server!
    log_exec sudo service xtuple-"$MWCNAME" start

    # assuming etho for now... hostname -I will give any non-local address if we wanted
    IP=`ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`
    log "All set! You should now be able to log on to this server at https://$IP:8443 with username admin and password admin. Make sure you change your password!"

}
