
generate_p12() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
# THE P12 KEY OUT NEEDS TO GO IN /var/xtuple/keys/
  NGINX_ECOM_DOMAIN=${NGINX_ECOM_DOMAIN:-'xTupleCommerce'}
  ECOMM_ADMIN_EMAIL=${ECOM_ADMIN_EMAIL:-"admin@xtuple.xd"}
  ERP_SITE_URL=${ERP_SITE_URL:-'xtuple.xd'}
  KEY_P12_PATH=${KEY_P12_PATH:-${BUILD_WORKING}/private}
  KEYTMP=${KEYTMP:-${KEY_P12_PATH}/tmp_${WORKDATE}}

  mkdir -p ${KEY_P12_PATH} ${KEYTMP}

  rm -rf ${KEYTMP}/*.key
  rm -rf ${KEYTMP}/*.csr
  rm -rf ${KEYTMP}/*.p12
  rm -rf ${KEYTMP}/*.pem
  rm -rf ${KEYTMP}/*.crt

  export NGINX_ECOM_DOMAIN_P12=${NGINX_ECOM_DOMAIN}.p12

  ssh-keygen -t rsa -b 2048 -C "${ECOMM_ADMIN_EMAIL}" \
             -f ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key -P ''
  openssl req -batch -new -key ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key \
              -out ${KEYTMP}/${NGINX_ECOM_DOMAIN}.csr
  openssl x509 -req -in ${KEYTMP}/${NGINX_ECOM_DOMAIN}.csr \
               -signkey ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key \
               -out ${KEYTMP}/${NGINX_ECOM_DOMAIN}.crt

  openssl pkcs12 -export -in ${KEYTMP}/${NGINX_ECOM_DOMAIN}.crt \
                 -inkey ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key \
                 -out ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -password pass:notasecret
  openssl pkcs12 -in ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -passin pass:notasecret -nocerts -nodes | \
    openssl rsa > ${KEYTMP}/${NGINX_ECOM_DOMAIN}_private.pem
  openssl rsa -in ${KEYTMP}/${NGINX_ECOM_DOMAIN}_private.pem -passin pass:notasecret \
              -pubout -passout pass:notasecret > ${KEYTMP}/${NGINX_ECOM_DOMAIN}_public.pem
  cp ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} ${KEY_P12_PATH}

  export OAPUBKEY=$(<${KEYTMP}/${NGINX_ECOM_DOMAIN}_public.pem)
  echo "Created OAPUBKEY"

  if $ISDEVELOPMENTENV ; then
    local SSHSUBDIR="$HOME/.ssh/${NGINX_ECOM_DOMAIN}"
    mkdir -p $SSHSUBDIR
    ssh-keygen -q -t rsa -b 4096 -C ${ECOM_ADMIN_EMAIL} \
               -f ${SSHSUBDIR}/${NGINX_ECOM_DOMAIN}_root_rsa     -N "${ROOTPASS}"      || die
    ssh-keygen -q -t rsa -b 4096 -C ${ECOM_ADMIN_EMAIL} \
               -f ${SSHSUBDIR}/${NGINX_ECOM_DOMAIN}_deployer_rsa -N "${DEPLOYER_PASS}" || die
  fi
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

