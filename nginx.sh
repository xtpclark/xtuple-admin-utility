#!/bin/bash

nginx_menu() {

    log "Opened nginx menu"

    while true; do
        NGM=$(whiptail --backtitle "xTuple Utility v$_REV" --menu "$( menu_title nginx\ Menu )" 0 0 4 --cancel-button "Exit" --ok-button "Select" \
            "1" "Install nginx" \
            "2" "Remove nginx" \
            "3" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            do_exit
        elif [ $RET -eq 0 ]; then
            case "$NGM" in
            "1") nginx_prompt ;;
            "2") remove_nginx ;;
            "3") break ;;
            *) msgbox "How did you get here?" && exit 0 ;;
            esac || nginx_menu
        fi
    done

}

nginx_prompt() {

    if [ -z $NGINXHOSTNAME ]; then
        NGINXHOSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Hostname" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
	       unset DOMAIN
		  unset NGINXHOSTNAME
            return $RET
        else
            export NGINXHOSTNAME
        fi
    fi
    
    if [ -z $DOMAIN ]; then
        DOMAIN=$(whiptail --backtitle "$( window_title )" --inputbox "Domain Name" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            unset DOMAIN
            return $RET
        else
            export DOMAIN
        fi
    fi
    
    install_nginx $NGINXHOSTNAME $DOMAIN
}

# $1 is hostname for nginx
# $2 is domain name
install_nginx() {

    log "Installing nginx"

    export NGINXHOSTNAME=$1
    export DOMAIN=$2

    log_exec sudo apt-get -y install nginx
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Nginx failed to install."
        return $RET
    fi
    
    sudo rm /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
    sudo cp templates/nginx-site /etc/nginx/sites-available/$NGINXHOSTNAME
    sudo sed -i -e "s/DOMAINNAME/$DOMAIN/" -e "s/HOSTNAME/$NGINXHOSTNAME/" /etc/nginx/sites-available/$NGINXHOSTNAME
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Error configuring nginx.  Check site file in /etc/nginx/sites-available"
	   return $RET
    fi
    
    sudo ln -s /etc/nginx/sites-available/$NGINXHOSTNAME /etc/nginx/sites-enabled/$NGINXHOSTNAME
    
    sudo mkdir -p /etc/xtuple/ssl
    sudo openssl req -x509 -newkey rsa:2048 -subj /CN=$NGINXHOSTNAME.$DOMAIN -days 365 -nodes \
        -keyout /etc/xtuple/ssl/server.key -out /etc/xtuple/ssl/server.crt
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "SSL Certificate creation failed."
	   return $RET
    fi
    
    sudo nginx -s reload
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Reloading nginx configuration failed. Check the log file for errors."
	   return $RET
    else
        msgbox "nginx installed and configured successfully."
    fi
}

remove_nginx() {

    log_exec apt-get -y remove nginx
    RET=$?
    return $RET
}
