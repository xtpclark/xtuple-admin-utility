#! /bin/bash

wget https://dl.eff.org/certbot-auto
chmod a+x certbot-auto
sudo chown root:root certbot-auto
sudo mv certbot-auto /usr/sbin

ERP_HOSTNAME=dhlive
ERP_DOMAIN=xtuplecloud.com
ERP_FQDN=${ERP_HOSTNAME}.${ERP_DOMAIN}
ERP_WEBROOT=/usr/share/nginx/${ERP_FQDN}
ERP_DEFAULT=${ERP_DOMAIN}-defaults.conf
NGINX_AVAIL=/etc/nginx/sites-available
NGINX_ENABLE=/etc/nginx/sites-enabled

sudo mkdir -p /usr/share/nginx/${ERP_FQDN}

sudo certbot-auto certonly --webroot -w ${ERP_WEBROOT} -d ${ERP_FQDN}


#  ssl_certificate /etc/xtuple/ssl/server.crt;
#  ssl_certificate_key /etc/xtuple/ssl/server.key;

#  /etc/nginx/sites-enabled/default.conf

#  cat << EOF > ${ERP_DEFAULT}

#  location ~ /.well-known {
#        allow all;
#  }

#  EOF

# sudo cp ${ERP_DEFAULT} ${NGINX_AVAIL}
# sudo ln -s ${NGINX_AVAIL}/${ERP_DEFAULT} ${NGINX_ENABLE}/
