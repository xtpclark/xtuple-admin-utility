#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$OATOKEN_FUN" ] ; then # {
OATOKEN_FUN=true

# TODO: find commonalities with encryption_setup()
# TODO: how much of this is important?
# generate_p12 [ -f ]
generate_p12() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local FORCE=false
  if [ "$1" = "-f" ] ; then
    FORCE=true
  fi

  ECOMM_ADMIN_EMAIL=${ECOMM_ADMIN_EMAIL:-"admin@xtuple.xd"}
  ERP_SITE_URL=${ERP_SITE_URL:-'xtuple.xd'}
  NGINX_ECOM_DOMAIN=${NGINX_ECOM_DOMAIN:-xTupleCommerce}
  KEY_P12_PATH=${KEY_P12_PATH:-${WORKDIR}/private}

  ROOT_CERT_PASSWD=${ROOT_CERT_PASSWD:-"pass:notasecret"}

  if $FORCE || [ ! -e  ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.p12 ] ; then
    mkdir --parents ${KEY_P12_PATH}

    for suffix in key csr p12 pem crt ; do
      back_up_file ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.$suffix
    done

    ssh-keygen     -t rsa -b 2048 -C "${ECOMM_ADMIN_EMAIL}"            \
                   -f ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.key -P ''
    openssl req    -batch -new -key ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.key \
                   -out ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.csr
    openssl x509   -req -in ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.csr         \
                   -signkey ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.key         \
                   -out ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.crt
    openssl pkcs12 -export -in ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.crt      \
                   -inkey ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.key           \
                   -out ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.p12 -password "$ROOT_CERT_PASSWD"
    openssl pkcs12 -in ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.p12 -passin "$ROOT_CERT_PASSWD" \
                   -nocerts -nodes |
      openssl rsa > ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}_private.pem
    openssl rsa -in ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}_private.pem -passin "${ROOT_CERT_PASSWD}" \
                -pubout -passout "${ROOT_CERT_PASSWD}" > ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}_public.pem

    sudo mkdir --parents ${ERP_KEY_FILE_PATH}
    safecp ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.key ${ERP_KEY_FILE_PATH}
    safecp ${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}.p12 ${ERP_KEY_FILE_PATH}

    export OAPUBKEY=$(<${KEY_P12_PATH}/${NGINX_ECOM_DOMAIN}_public.pem)
    echo "Created OAPUBKEY"
  fi
}

generateoasql() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  cat << EOF > ${WORKDIR}/sql/oa2client.sql
    DELETE FROM xt.oa2client
     WHERE oa2client_client_x509_pub_cert = '${OAPUBKEY}'
        OR oa2client_client_id = '${ERP_ISS}';
    INSERT INTO xt.oa2client (
      oa2client_client_id, oa2client_client_secret, oa2client_client_name,
      oa2client_client_email, oa2client_client_web_site, oa2client_client_type,
      oa2client_active, oa2client_issued, oa2client_delegated_access,
      oa2client_client_x509_pub_cert, oa2client_org
    ) SELECT '${ERP_ISS}', xt.uuid_generate_v4(), '${NGINX_ECOM_DOMAIN}',
           '${ECOMM_ADMIN_EMAIL}', '${ERP_SITE_URL}', 'jwt bearer',
           TRUE, now(), TRUE,
           '${OAPUBKEY}', current_database();
EOF

  cat << EOF > ${WORKDIR}/sql/xd_site.sql
    DELETE FROM xdruple.xd_site;
    INSERT INTO xdruple.xd_site (
      xd_site_name,         xd_site_url,        xd_site_notes
    ) VALUES (
      '${ERP_APPLICATION}', 'http://${DOMAIN}', 'ecomm site'
    );
EOF
}

fi # }
