#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$NGINX_SH" ] ; then # {
NGINX_SH=true

nginx_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  log "Opened nginx menu"

  while true; do
    NGM=$(whiptail --backtitle "$(window_title)" --title "xTuple Utility v$_REV" \
                   --menu "$(menu_title nginx Menu)" 0 0 10 --cancel-button "Cancel" --ok-button "Select" \
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
        "1") install_nginx
             ;;
        "2") nginx_prompt
             configure_nginx
             ;;
        "3") remove_nginx
             ;;
        "4") break ;;
        *) msgbox "How did you get here? nginx_menu $NGM" && break ;;
      esac
    fi
  done
}

install_nginx() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Installing nginx"

  local OUTPUT="$(log_exec sudo apt-get --quiet --yes install nginx)"
  RET=$?
  if [ $RET -ne 0 ] ; then
    msgbox "Nginx failed to install:\n$OUTPUT"
    return $RET
  fi
  sudo rm -rf /var/www/html
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

  dialog --ok-label   "Submit"                            \
         --backtitle  "$(window_title)"                   \
         --form       "nginx configuration details" 0 0 7 \
         "Host name:"                 1 1 "$NGINX_HOSTNAME" 1 25 50 0 \
         "Domain name (example.com):" 2 1 "$NGINX_DOMAIN"   2 25 50 0 \
         "Site name:"                 3 1 "$NGINX_SITE"     3 25 50 0 \
         3>&1 1>&2 2> nginx.ini
  RET=$?
  case $RET in
    $DIALOG_OK)
      read -d "\n" NGINX_HOSTNAME NGINX_DOMAIN NGINX_SITE <<<$(cat nginx.ini)
      export       NGINX_HOSTNAME NGINX_DOMAIN NGINX_SITE
      ;;
    *)
      return 1
      ;;
  esac

  if (whiptail --title "Generate SSL key" --yesno "Would you like to generate a self signed SSL certificate and key?" 10 60) then
    GEN_SSL=true
  else
    GEN_SSL=false
  fi

  dialog --ok-label    "Submit"                 \
         --backtitle  "$(window_title)"         \
         --form       "nginx SSL details" 0 0 7 \
         "Certificate file path" 1 1 "/etc/nginx/certs/$NGINX_SITE.crt"   1 25 50 0    \
         "Key file path"         2 1 "/etc/nginx/private/$NGINX_SITE.key" 2 25 50 0    \
           3>&1 1>&2 2> nginxssl.ini
  RET=$?
  case $RET in
    $DIALOG_OK)
      read -d "\n" NGINX_CERT NGINX_KEY <<<$(cat nginxssl.ini)
      export       NGINX_CERT NGINX_KEY
      ;;
    *)
      return 1
      ;;
  esac

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
  NGINX_PORT="${6:-${NGINX_PORT:-8443}}"
  WEBROOT="${WEBROOT:-/var/www}"
  NGINX_LOG="${NGINX_LOG:-/var/log/nginx}"

  if [ -z "$NGINX_HOSTNAME" -o -z "$NGINX_DOMAIN" -o -z "$NGINX_SITE" \
    -o -z "$NGINX_CERT"     -o -z "$NGINX_KEY"    -o -z "$NGINX_PORT" \
    -o -z "$WEBROOT" ] ; then
      die "Insufficient information to configure nginx"
  fi

  local CURRENTDIR=$(pwd)
  local S

  log "Removing nginx site default"
  sudo rm -f /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

  log "Creating nginx site file"

  safecp ${WORKDIR}/templates/nginx/nginx-site /etc/nginx/nginx.conf

  safecp ${WORKDIR}/templates/nginx/mime.types     /etc/nginx
  safecp ${WORKDIR}/templates/nginx/fastcgi_params /etc/nginx
  safecp ${WORKDIR}/templates/nginx/sites-available/default.conf /etc/nginx/sites-available/default.http.conf

  sudo cp --recursive ${WORKDIR}/templates/nginx/apps     /etc/nginx/
  sudo cp --recursive ${WORKDIR}/templates/nginx/conf.d/* /etc/nginx/conf.d/

  if egrep --quiet --no-messages "^[[:blank:]]*keepalive_timeout" /etc/nginx/nginx.conf ; then
    back_up_file /etc/nginx/nginx.conf
    sudo sed -i -e "s/^[[:blank:]]*keepalive_timeout/#&/" /etc/nginx/nginx.conf
  fi

  log "Enabling nginx site"
  sudo ln --symbolic --force /etc/nginx/sites-available/default.http.conf \
                             /etc/nginx/sites-enabled
  if $IS_DEV_ENV ; then
    safecp ${WORKDIR}/templates/nginx/sites-available/xdruple.conf /etc/nginx/sites-available/$NGINX_SITE
    sudo ln --symbolic --force /etc/nginx/sites-available/xdruple.conf \
                               /etc/nginx/sites-enabled
  fi

  sudo mkdir --parents /etc/nginx/private /etc/nginx/certs
  export SSL=""
  if [ -f $HOME/${NGINX_DOMAIN}.crt ] && [ -f $HOME/${NGINX_DOMAIN}.key ] ; then
    export SSL="ssl"
    sudo mv $HOME/${NGINX_DOMAIN}.key /etc/nginx/private/ || die
    sudo mv $HOME/${NGINX_DOMAIN}.crt /etc/nginx/certs/   || die

  else
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

  for ENVIRONMENT in dev stage live ; do
    CONFFILE=/etc/nginx/sites-available/${ENVIRONMENT}.http.conf
    safecp ${WORKDIR}/templates/nginx/sites-available/stage.conf $CONFFILE && \
      replace_params --no-backup $CONFFILE
    if [ $RET -ne 0 ]; then
      msgbox "Error configuring nginx. Check $CONFFILE."
      return $RET
    fi
    sudo ln --symbolic --force $CONFFILE /etc/nginx/sites-enabled
    sudo mkdir --parents ${NGINX_LOG}/${ENVIRONMENT} ${WEBROOT}/${ENVIRONMENT}

    # TODO: why is it important to make this live/other distinction here?
    if [ ${ENVIRONMENT} = "live" ] ; then
      if [ "${SSL}" = "ssl" ] ; then
        S=s
      else
        S=
      fi
      safecp ${WORKDIR}/templates/nginx/sites-available/http${S}.conf \
             /etc/nginx/sites-available &&
        replace_params --no-backup /etc/nginx/sites-available/http${S}.conf
      if [ $RET -ne 0 ]; then
        msgbox "Error configuring nginx. Check /etc/nginx/sites-available/http${S}.conf"
        return $RET
      fi
      sudo ln --symbolic --force /etc/nginx/sites-available/http${S}.conf \
                                 /etc/nginx/sites-enabled
    fi
  done

  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} ${WEBROOT}

  sudo apt-get --quiet -y install apache2-utils

  if [ -z "${HTTP_AUTH_NAME}" -o -z "${HTTP_AUTH_PASS}" ] ; then
    get_xtc_environment
  fi
  sudo htpasswd -b -c /var/www/.htpasswd ${HTTP_AUTH_NAME} ${HTTP_AUTH_PASS}

  log "Reloading nginx configuration"
  service_reload nginx
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Reloading nginx configuration failed"
    return $RET
  fi
  msgbox "nginx installed and configured successfully."
}

remove_nginx() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  if (whiptail --title "Are you sure?" --yesno "Uninstall nginx?" --yes-button "Yes" --no-button "No" 10 60) then
    log "Uninstalling nginx..."
    log_exec sudo apt-get --quiet -y remove nginx
    RET=$?
    return $RET
  fi
  return 0
}

fi # }
