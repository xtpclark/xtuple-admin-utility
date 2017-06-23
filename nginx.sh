#!/bin/bash

nginx_menu() {

    log "Opened nginx menu"

    while true; do
        NGM=$(whiptail --backtitle "xTuple Utility v$_REV" --menu "$( menu_title nginx\ Menu )" 0 0 4 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Install nginx" \
            "2" "Configure nginx" \
            "3" "Remove nginx" \
            "4" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -ne 0 ]; then
            break
        else
            case "$NGM" in
            "1") log_exec install_nginx ;;
            "2") log_exec configure_nginx ;;
            "3") log_exec remove_nginx ;;
            "4") break ;;
            *) msgbox "How did you get here? nginx_menu $NGM" && break ;;
            esac
        fi
    done

}

install_nginx() {

    log "Installing nginx"

    log_exec sudo apt-get -y install nginx
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Nginx failed to install."
        return $RET
    fi
}

clear_nginx_settings() {
    unset NGINX_HOSTNAME
    unset NGINX_DOMAIN
    unset NGINX_SITE
    unset NGINX_CERT
    unset NGINX_KEY
    unset NGINX_PORT
}

nginx_prompt() {

type nginx >/dev/null 2>&1 || { echo >&2 "Installing nginx."; install_nginx; }


    if [ -z "$NGINX_HOSTNAME" ]; then
        NGINX_HOSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Host name (the domain comes next)" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            clear_nginx_settings
            return $RET
        else
            export NGINX_HOSTNAME
        fi
    fi

    if [ -z "$NGINX_DOMAIN" ]; then
        NGINX_DOMAIN=$(whiptail --backtitle "$( window_title )" --inputbox "Domain name (example.com)" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            clear_nginx_settings
            return $RET
        else
            export NGINX_DOMAIN
        fi
    fi

    if [ -z "$NGINX_SITE" ]; then
        NGINX_SITE=$(whiptail --backtitle "$( window_title )" --inputbox "Site name. This will be the name of the config file." 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            clear_nginx_settings
            return $RET
        else
            export NGINX_SITE
        fi
    fi

    if [ -z "$GEN_SSL" ]; then
        if (whiptail --title "Generate SSL key" --yesno "Would you like to generate a self signed SSL certificate and key?" 10 60) then
            GEN_SSL=true
	   else
	       GEN_SSL=false
	   fi
	   export GEN_SSL
    fi

    if [ -z "$NGINX_CERT" ]; then
        NGINX_CERT=$(whiptail --backtitle "$( window_title )" --inputbox "SSL Certificate file path" 8 60 "/etc/xtuple/ssl/server.crt" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            clear_nginx_settings
            return $RET
        else
            export NGINX_CERT
        fi
    fi

    if [ -z "$NGINX_KEY" ]; then
        NGINX_KEY=$(whiptail --backtitle "$( window_title )" --inputbox "SSL Key file path" 8 60 "/etc/xtuple/ssl/server.key" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            clear_nginx_settings
            return $RET
        else
            export NGINX_KEY
        fi
    fi

    if [ -z "$NGINX_PORT" ]; then
        new_nginx_port
        NGINX_PORT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter port number.\n\nUsed Ports:\n$(head -2 /etc/nginx/sites-available/* | grep -Po '8[0-9]{3}')" 18 60 "$NGINX_PORT" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            clear_nginx_settings
            return $RET
        else
            export NGINX_PORT
        fi
    fi
}

# $1 is hostname for nginx
# $2 is domain name
# $3 is the site name to use
# $4 is to generate an ssl key
# $5 specifies a cert file
# $6 specifies a key file
# $7 is the port to use
configure_nginx()
{
    log "Configuring nginx"

    NGINX_HOSTNAME="${1:-$NGINX_HOSTNAME}"
    NGINX_DOMAIN="${2:-$NGINX_DOMAIN}"
    NGINX_SITE="${3:-$NGINX_SITE}"
    NGINX_CERT="${5:-$NGINX_CERT}"
    NGINX_KEY="${6:-$NGINX_KEY}"
    NGINX_PORT="${7:-$NGINX_PORT}"

    nginx_prompt
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    [[ -e /etc/nginx/sites-available/default ]] && sudo rm /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>&1 >/dev/null
    sudo cp templates/nginx-site /etc/nginx/sites-available/$NGINX_SITE
    sudo sed -i -e "s#DOMAINNAME#$NGINX_DOMAIN#" -e "s#HOSTNAME#$NGINX_HOSTNAME#" /etc/nginx/sites-available/$NGINX_SITE
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Error configuring nginx.  Check site file in /etc/nginx/sites-available"
        return $RET
    fi

    sudo ln -s /etc/nginx/sites-available/$NGINX_SITE /etc/nginx/sites-enabled/$NGINX_SITE

    NGINX_CERT="${4:-$NGINX_CERT}"
    NGINX_CERT="${NGINX_CERT:-true}"

#    if [[ -z ${NGINX_CERT} ]]; then
        # sudo mkdir -p $(dirname $NGINX_CERT $NGINX_KEY)
        sudo mkdir -p /etc/xtuple/ssl
        RET=$?
        if [ $RET -ne 0 ]; then
            msgbox "SSL DIR creation failed."
        fi


        sudo openssl req -x509 -newkey rsa:2048 -subj /CN=${NGINX_HOSTNAME}.${NGINX_DOMAIN} -days 365 -nodes -keyout $NGINX_KEY -out $NGINX_CERT
        RET=$?
        if [ $RET -ne 0 ]; then
            msgbox "SSL Certificate creation failed."
            return $RET
        fi
#    fi

    sudo sed -i -e 's#SERVER_CRT#'$NGINX_CERT'#g' -e 's#SERVER_KEY#'$NGINX_KEY'#g' /etc/nginx/sites-available/$NGINX_SITE
    sudo sed -i 's#MWCPORT#'$NGINX_PORT'#g' /etc/nginx/sites-available/${NGINX_SITE}

#   -s signal     : send signal to a master process: stop, quit, reopen, reload
#    sudo nginx -s start

#Add check for systemd

    sudo service nginx stop
    sudo service nginx start
#sudo systemctl stop nginx.service
#sudo systemctl start nginx.service

    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Reloading nginx configuration failed. Check the log file for errors."
        return $RET
    else
        msgbox "nginx installed and configured successfully."
    fi
}

remove_nginx() {

    if (whiptail --title "Are you sure?" --yesno "Uninstall nginx?" --yes-button "Yes" --no-button "No" 10 60) then
        log "Uninstalling nginx..."
        log_exec sudo apt-get -y remove nginx
        RET=$?
        return $RET
    else
        return 0
    fi

}
