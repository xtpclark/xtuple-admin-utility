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
            "1") install_mwc ;;
            "2") remove_mwc ;;
            "3") break ;;
            *) msgbox "Error. How did you get here? >> mwc_menu / $PGM" && do_exit ;;
            esac || postgresql_menu
        fi
    done

}


# $1 is xtuple version
# $2 is the instance name
install_mwc() {

    log "installing web client"

    if [ -z $1 ]; then
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
    else 
        MWCVERSION=$1
    fi

    export MWCVERSION

    if [ -z "$2" ]; then
        MWCNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter a name for this xTuple instance" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        fi
    else 
        MWCNAME="$2"
    fi

    export MWCNAME

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

    # cleanup existing folder
    # does this need to happen? (I don't think so...-DB)
    #sudo rm -rf /opt/xtuple/$MWCVERSION

    log "Cloning xTuple Web Client Source Code to /opt/xtuple/$MWCVERSION/xtuple"
    log "Using version $MWCVERSION with the given name $MWCNAME"
    log_exec sudo mkdir -p /opt/xtuple/$MWCVERSION/"$MWCNAME"
    log_exec sudo chown -R xtuple.xtuple /opt/xtuple

    # main code
    log_exec sudo su - xtuple -c "cd /opt/xtuple/$MWCVERSION/"$MWCNAME" && git clone https://github.com/xtuple/xtuple.git && cd  /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple && git checkout v$MWCVERSION && git submodule update --init --recursive && npm install bower && npm install"
    # main extensions
    log_exec sudo su - xtuple -c "cd /opt/xtuple/$MWCVERSION/"$MWCNAME" && git clone https://github.com/xtuple/xtuple-extensions.git && cd /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple-extensions && git checkout v$MWCVERSION && git submodule update --init --recursive && npm install"
    # private extensions
    if (whiptail --title "Private Extensions" --yesno "Would you like to install the commercial extensions? The \"xtuple\" user will need to have a SSH key setup for github, and be deploying the web client against a commercial database or this step will fail." 10 60) then
        log "Installing the commercial extensions"
        log_exec sudo su xtuple -c "cd /opt/xtuple/$MWCVERSION/"$MWCNAME" && git clone git@github.com:/xtuple/private-extensions.git && cd /opt/xtuple/$MWCVERSION/"$MWCNAME"/private-extensions && git checkout v$MWCVERSION && git submodule update --init --recursive && npm install"
    else
        log "Not installing the commercial extensions"
    fi

    if [ ! -f /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource/sample_config.js ]; then
        msgbox "Hrm, sample_config.js doesn't exist.. something went wrong. check the output/log and try again"
        do_exit
    fi

    export XTDIR=/opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple

    # why was I doing this twice?
    # sudo rm -rf /etc/xtuple/$MWCVERSION
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

    # prompt user to choose database
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
        msgbox "Installing the mobile client was interrupted. Please make sure you have an xTuple database already deployed before trying again."
        main_menu
    fi
    log "Chose database $DATABASE"
    log_exec sudo sed -i  "/databases:/c\      databases: [\"$DATABASE\"]," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js

    log_exec sudo chown -R xtuple.xtuple /etc/xtuple

    log_exec sudo su - xtuple -c "cd $XTDIR && ./scripts/build_app.js -c /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "buildapp failed to run. Check output and try again"
        do_exit
    fi

    log "Creating upstart script using filename /etc/init/xtuple-"$MWCNAME".conf"
    # create the upstart script
    sudo bash -c "echo $'description     \"xTuple Node Server\"' > /etc/init/xtuple-"$MWCNAME".conf"
    sudo bash -c "sudo echo \"start on filesystem or runlevel [2345]\" >> /etc/init/xtuple-"$MWCNAME".conf"
    sudo bash -c "sudo echo \"stop on runlevel [!2345]\" >> /etc/init/xtuple-"$MWCNAME".conf"
    sudo bash -c "sudo echo \"console output\" >> /etc/init/xtuple-"$MWCNAME".conf"
    sudo bash -c "sudo echo \"respawn\" >> /etc/init/xtuple-"$MWCNAME".conf"
    #sudo bash -c "sudo echo \"setuid xtuple\" >> /etc/init/xtuple-"$MWCNAME".conf"
    #sudo bash -c "sudo echo \"setgid xtuple\" >> /etc/init/xtuple-"$MWCNAME".conf"
    sudo bash -c "sudo echo \"chdir /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource\" >> /etc/init/xtuple-"$MWCNAME".conf"
    sudo bash -c "sudo echo \"exec n use 0.10\" >> /etc/init/xtuple-"$MWCNAME".conf"
    sudo bash -c "sudo echo \"exec ./main.js -c /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js > /var/log/node-datasource-$MWCVERSION-"$MWCNAME".log 2>&1\" >> /etc/init/xtuple-"$MWCNAME".conf"

    # now that we have the script, start the server!
    log_exec sudo service xtuple-"$MWCNAME" start

    # assuming etho for now... hostname -I will give any non-local address if we wanted
    IP=`ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`
    msgbox "All set! You should now be able to log on to this server at https://$IP:8443"

}
