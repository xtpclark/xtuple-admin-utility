#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$OATOKEN_FUN" ] ; then # {
OATOKEN_FUN=true

# copied from xdruple-server/scripts/host/keygen.sh
# then added edit of .ssh/config
generate_xdruple_keypairs() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  ECOMM_ADMIN_EMAIL=${1:-${ECOMM_ADMIN_EMAIL}}
  ERP_SITE_URL=${2:-${ERP_SITE_URL}}
  local SHORTHAND=${3:-${NGINX_ECOM_DOMAIN}}
  ROOT_CERT_PASSWD=${4:-${ROOT_CERT_PASSWD}}
  DEPLOY_CERT_PASSWD=${5:-${DEPLOY_CERT_PASSWD}}

  local STARTDIR=$(pwd)
  local SSHSUBDIR="$HOME/.ssh/${ERP_SITE_URL}"

  mkdir --parents ${SSHSUBDIR}
  back_up_file "${SSHSUBDIR}/${SHORTHAND}_root_rsa"
  back_up_file "${SSHSUBDIR}/${SHORTHAND}_deployer_rsa"
  rm -f "${SSHSUBDIR}/${SHORTHAND}_root_rsa" "${SSHSUBDIR}/${SHORTHAND}_deployer_rsa"

  log_exec ssh-keygen -q -b 4096 -t rsa -N "${ROOT_CERT_PASSWD}"   -C "${ECOMM_ADMIN_EMAIL}" -f "${SSHSUBDIR}/${SHORTHAND}_root_rsa"
  log_exec ssh-keygen -q -b 4096 -t rsa -N "${DEPLOY_CERT_PASSWD}" -C "${ECOMM_ADMIN_EMAIL}" -f "${SSHSUBDIR}/${SHORTHAND}_deployer_rsa"

  if $XTC_HOST_IS_REMOTE ; then
    back_up_file ${SSHSUBDIR}/../config
    cat >> ${SSHSUBDIR}/../config <<-EOF
          Host $ERP_SITE_URL
            User root
            IdentifyFile ~/.ssh/$ERP_SITE_URL/${SHORTHAND}_root_rsa

          Host $ERP_SITE_URL
            User ${DEPLOYER_NAME:-deployer}
            IdentifyFile ~/.ssh/$ERP_SITE_URL/${SHORTHAND}_deployer_rsa
	EOF
  fi
  echo "Out: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
}

# TODO: find commonalities with encryption_setup()
# TODO: how much of this is important?
generate_p12() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  NGINX_ECOM_DOMAIN=${NGINX_ECOM_DOMAIN:-'xTupleCommerce'}
  ECOMM_ADMIN_EMAIL=${ECOMM_ADMIN_EMAIL:-"admin@xtuple.xd"}
  ERP_SITE_URL=${ERP_SITE_URL:-'xtuple.xd'}
  KEY_P12_PATH=${KEY_P12_PATH:-${WORKDIR}/private}
  KEYTMP=${KEYTMP:-${KEY_P12_PATH}/tmp_${WORKDATE}}

  export NGINX_ECOM_DOMAIN_P12=${NGINX_ECOM_DOMAIN}.p12

  local SSHSUBDIR="$HOME/.ssh/${NGINX_ECOM_DOMAIN}"
  ROOT_CERT_PASSWD=${ROOT_CERT_PASSWD:-"pass:notasecret"}

  mkdir --parents ${KEY_P12_PATH} ${KEYTMP}

  rm -rf ${KEYTMP}/*.key ${KEYTMP}/*.csr
  rm -rf ${KEYTMP}/*.p12 ${KEYTMP}/*.pem ${KEYTMP}/*.crt

  ssh-keygen     -t rsa -b 2048 -C "${ECOMM_ADMIN_EMAIL}"            \
                 -f ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key -P ''
  openssl req    -batch -new -key ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key \
                 -out ${KEYTMP}/${NGINX_ECOM_DOMAIN}.csr
  openssl x509   -req -in ${KEYTMP}/${NGINX_ECOM_DOMAIN}.csr         \
                 -signkey ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key         \
                 -out ${KEYTMP}/${NGINX_ECOM_DOMAIN}.crt
  openssl pkcs12 -export -in ${KEYTMP}/${NGINX_ECOM_DOMAIN}.crt      \
                 -inkey ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key           \
                 -out ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -password "$ROOT_CERT_PASSWD"
  openssl pkcs12 -in ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -passin "$ROOT_CERT_PASSWD" \
                 -nocerts -nodes |
    openssl rsa > ${KEYTMP}/${NGINX_ECOM_DOMAIN}_private.pem
  openssl rsa -in ${KEYTMP}/${NGINX_ECOM_DOMAIN}_private.pem -passin "${ROOT_CERT_PASSWD}" \
              -pubout -passout "${ROOT_CERT_PASSWD}" > ${KEYTMP}/${NGINX_ECOM_DOMAIN}_public.pem

  safecp ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} ${KEY_P12_PATH}

  export OAPUBKEY=$(<${KEYTMP}/${NGINX_ECOM_DOMAIN}_public.pem)
  echo "Created OAPUBKEY"
}

generateoasql() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  cat << EOF > ${WORKDIR}/sql/oa2client.sql
    DELETE FROM xt.oa2client
     WHERE oa2client_client_x509_pub_cert = '${OAPUBKEY}'
        OR oa2client_client_id = 'xTupleCommerceID';
    INSERT INTO xt.oa2client (
      oa2client_client_id, oa2client_client_secret, oa2client_client_name,
      oa2client_client_email, oa2client_client_web_site, oa2client_client_type,
      oa2client_active, oa2client_issued, oa2client_delegated_access,
      oa2client_client_x509_pub_cert, oa2client_org
    ) SELECT 'xTupleCommerceID', xt.uuid_generate_v4(), '${NGINX_ECOM_DOMAIN}',
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
