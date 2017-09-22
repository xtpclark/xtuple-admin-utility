#!/bin/bash

getSelfCert() {

if [[ -z ${SELF_CERT_FQDN} ]]; then

read -p "ENTER FQDN FOR SSL (i.e. erp.prodiem.xd)" SELF_CERT_FQDN

createSelfCert

fi

}


createSelfCert() {
if [[ ${SELF_CERT_FQDN} ]]; then

sudo openssl req -x509 -newkey rsa:2048 -subj /CN=${SELF_CERT_FQDN} -days 365 -nodes -keyout ${SELF_CERT_FQDN}_server.key -out ${SELF_CERT_FQDN}_server.crt

else

getSelfCert

fi
}

createSelfCert
