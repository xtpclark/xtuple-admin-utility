#!/bin/bash

nginx_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

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
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Installing nginx"

  log_exec sudo apt-get -y install nginx
  RET=$?
  if [ $RET -ne 0 ] ; then
    msgbox "Nginx failed to install."
  fi
  return $RET
}

# Confirm or set all nginx related variables interactively
# Run this before configure_nginx if interactive
# Set all variables if headless/automatic
nginx_prompt() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  type nginx >/dev/null 2>&1 || { echo >&2 "nginx not installed, installing"; install_nginx; }

  if [ "$MODE" = "auto" ]; then
    return 127
  fi

  NGINX_HOSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "nginx host name (the domain comes next)" 8 60 "$NGINX_HOSTNAME" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  NGINX_DOMAIN=$(whiptail --backtitle "$( window_title )" --inputbox "nginx domain name (example.com)" 8 60 "$NGINX_DOMAIN" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  NGINX_SITE=$(whiptail --backtitle "$( window_title )" --inputbox "nginx site name. This will be the name of the config file." 8 60 "$NGINX_SITE" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  if (whiptail --title "Generate SSL key" --yesno "Would you like to generate a self signed SSL certificate and key?" 10 60) then
    GEN_SSL=true
  else
    GEN_SSL=false
  fi

  NGINX_CERT=$(whiptail --backtitle "$( window_title )" --inputbox "nginx SSL Certificate file path" 8 60 "/etc/xtuple/ssl/$NGINX_SITE.crt" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  NGINX_KEY=$(whiptail --backtitle "$( window_title )" --inputbox "nginx SSL Key file path" 8 60 "/etc/xtuple/ssl/$NGINX_SITE.key" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  new_nginx_port
  local USEDPORTS=$(sudo head --lines 2 /etc/nginx/sites-available/* | grep --only-matching '8[0-9]{3}')
  [ -z "$USEDPORTS" ] || USEDPORTS="\nUsed Ports:\n$USEDPORTS"
  NGINX_PORT=$(whiptail --backtitle "$( window_title )" --inputbox "nginx port number.\n$USEDPORTS\n" 18 60 "$NGINX_PORT" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi
}

# run nginx_prompt first if interactive
#  the return value should be 0 before continuing
# set variables first if headless/automatic
# variables:
#   NGINX_HOSTNAME  - subdomain that points to the specific web client
#   NGINX_DOMAIN    - domain name of the server
#   NGINX_SITE      - nginx site name which is also the web client instance name
#   NGINX_CERT      - website certificate which should be per site and a separate file in /etc/xtuple/ssl
#   NGINX_KEY       - website key with the same requirements
#   NGINX_PORT      - nginx port to listen to
configure_nginx() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  NGINX_HOSTNAME="${1:-$NGINX_HOSTNAME}"
  NGINX_DOMAIN="${2:-$NGINX_DOMAIN}"
  NGINX_SITE="${3:-$NGINX_SITE}"
  NGINX_CERT="${4:-$NGINX_CERT}"
  NGINX_KEY="${5:-$NGINX_KEY}"
  NGINX_PORT="${6:-$NGINX_PORT}"
  WEBROOT="${WEBROOT:-/var/www}"
  NGINX_LOG="${NGINX_LOG:-/var/log/nginx}"

  if [ -z "$NGINX_HOSTNAME" -o -z "$NGINX_DOMAIN" -o -z "$NGINX_SITE" \
    -o -z "$NGINX_CERT"     -o -z "$NGINX_KEY"    -o -z "$NGINX_PORT" \
    -o -z "$WEBROOT" ] ; then
    nginx_prompt
    RET=$?
    if [ $RET -ne 0 ] ; then
      msgbox "Insufficient information to configure nginx"
      return $RET
    fi
  fi

  local CURRENTDIR=$(pwd)

  log "Removing nginx site default"
  sudo rm -f /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

  log "Creating nginx site file"
  safecp ${WORKDIR}/templates/nginx/nginx-site /etc/nginx/sites-available/$NGINX_SITE

  safecp ${WORKDIR}/templates/nginx/mime.types     /etc/nginx
  safecp ${WORKDIR}/templates/nginx/fastcgi_params /etc/nginx
  safecp ${WORKDIR}/templates/nginx/sites-available/default.conf /etc/nginx/sites-available/default.http.conf

  sudo cp -R ${WORKDIR}/templates/nginx/apps /etc/nginx/
  sudo cp -R ${WORKDIR}/templates/nginx/conf.d/* /etc/nginx/conf.d/

  log "Enabling nginx site"
  sudo ln --symbolic --force /etc/nginx/sites-available/$NGINX_SITE \
                             /etc/nginx/sites-available/default.http.conf \
                             /etc/nginx/sites-enabled

  export SSL=""
  if [ -f ~/${NGINX_DOMAIN}.crt ] && [ -f ~/${NGINX_DOMAIN}.key ] ; then
    export SSL="ssl"
    sudo mkdir -p /etc/nginx/private /etc/nginx/certs
    sudo mv ~/${NGINX_DOMAIN}.key /etc/nginx/private/ || die
    sudo mv ~/${NGINX_DOMAIN}.crt /etc/nginx/certs/   || die

  else
    sudo mkdir -p /etc/xtuple/ssl

    # LetsEncrypt will go around here
    log "Generating certificate"
    sudo openssl req -x509 -newkey rsa:4096 \
                     -subj /CN=${NGINX_HOSTNAME}.${NGINX_DOMAIN} \
                     -days 365 -nodes -keyout $NGINX_KEY -out $NGINX_CERT
    RET=$?
    if [ $RET -ne 0 ]; then
      msgbox "SSL Certificate creation failed."
      return $RET
    fi
  fi

  sudo sed -i -e "s#DOMAINNAME#$NGINX_DOMAIN#" \
              -e "s#HOSTNAME#$NGINX_HOSTNAME#" \
              -e "s#SERVER_CRT#$NGINX_CERT#g"  \
              -e "s#SERVER_KEY#$NGINX_KEY#g"   \
              -e "s#MWCPORT#$NGINX_PORT#g" /etc/nginx/sites-available/${NGINX_SITE}
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Error configuring nginx. Check ${NGINX_SITE} in /etc/nginx/sites-available"
    return $RET
  fi

  for ENVIRONMENT in dev stage live ; do
    safecp ${WORKDIR}/templates/nginx/sites-available/stage.conf \
              /etc/nginx/sites-available/${ENVIRONMENT}.http.conf
    sudo sed -i -e "s/{DOMAIN_ALIAS}/${DOMAIN_ALIAS}/g" \
                -e "s/{ENVIRONMENT}/${ENVIRONMENT}/g"   \
                /etc/nginx/sites-available/${ENVIRONMENT}.http.conf
    if [ $RET -ne 0 ]; then
      msgbox "Error configuring nginx. Check ${ENVIRNOMENT}.http.conf in /etc/nginx/sites-available"
      return $RET
    fi
    sudo ln --symbolic --force /etc/nginx/sites-available/${ENVIRONMENT}.http.conf \
                               /etc/nginx/sites-enabled

    sudo mkdir -p ${NGINX_LOG}/${ENVIRONMENT} ${WEBROOT}/${ENVIRONMENT}

    # TODO: why is it important to make this live/other distinction here?
    if [ ${ENVIRONMENT} = "live" ] ; then
      if [ "${SSL}" = "ssl" ] ; then
        sudo sed -i "s/{DOMAIN}/${DOMAIN}/g" /etc/nginx/conf.d/ssl.conf
        S=s
      else
        S=
      fi
      safecp ${WORKDIR}/templates/nginx/sites-available/http${S}.conf \
             /etc/nginx/sites-available
      sudo sed -i -e "s/{DOMAIN}/${DOMAIN}/g" \
                  -e "s/{ENVIRONMENT}/${ENVIRONMENT}/g" \
                  /etc/nginx/sites-available/http${S}.conf
      if [ $RET -ne 0 ]; then
        msgbox "Error configuring nginx. Check /etc/nginx/sites-available/http${S}.conf"
        return $RET
      fi
      sudo ln --symbolic --force /etc/nginx/sites-available/http${S}.conf \
                                 /etc/nginx/sites-enabled
    fi
  done
  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} ${WEBROOT}

  sudo apt-get -q -y install apache2-utils

  if [ -z "${HTTP_AUTH_NAME}" -o -z "${HTTP_AUTH_PASS}" ] ; then
    get_environment
  fi
  sudo htpasswd -b -c /var/www/.htpasswd ${HTTP_AUTH_NAME} ${HTTP_AUTH_PASS}

  # TODO: pick one?
  log "Reloading nginx configuration"
  local OUTPUT=$(log_exec sudo bash -c "service nginx restart || nginx -s reload")
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Reloading nginx configuration failed:\n$OUTPUT"
    return $RET
  fi
  msgbox "nginx installed and configured successfully."
}

remove_nginx() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if (whiptail --title "Are you sure?" --yesno "Uninstall nginx?" --yes-button "Yes" --no-button "No" 10 60) then
    log "Uninstalling nginx..."
    log_exec sudo apt-get -y remove nginx
    RET=$?
    return $RET
  fi
  return 0
}

