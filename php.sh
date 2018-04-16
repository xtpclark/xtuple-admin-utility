#!/bin/bash
shopt extdebug
set -o errexit

export TYPE=${1:-${RUNTIMEENV:-vagrant}}
export TIMEZONE=${2:-${TIMEZONE:-$(get local timezone)}}
export DEPLOYER_NAME=${3:-${DEPLOYER_NAME:-$(whoami)}}
export GITHUB_TOKEN=${4:-${GITHUB_TOKEN:-$(git config --get github.token)}}

export MAX_EXECUTION_TIME=60
if [ ${TYPE} = 'vagrant' ]; then
    export MAX_EXECUTION_TIME=600
fi

sudo add-apt-repository -y ppa:ondrej/php && \
sudo apt-get -q -y update       || die
sudo apt-get -q -y upgrade      || die
sudo apt-get -q -y install \
  php-common \
  php7.1-common \
  php7.1-json \
  php7.1-opcache \
  php7.1-readline \
  php7.1-fpm \
  php7.1 \
  php7.1-cli \
  php7.1-xml \
  php-pear \
  php7.1-dev \
  php7.1-gd \
  php7.1-pgsql \
  php7.1-curl \
  php7.1-intl \
  php7.1-mcrypt \
  php7.1-mbstring \
  php7.1-soap                   || die

if [ ${TYPE} = 'vagrant' ]; then
  sudo apt-get -q -y install php-xdebug || die
  safecp ${WORKDIR}/templates/php/mods/xdebug.ini /etc/php/7.1/mods-available || die
fi

safecp ${WORKDIR}/templates/php/fpm/php-fpm.conf.ini /etc/php/7.1/fpm
safecp ${WORKDIR}/templates/php/fpm/www.conf.ini /etc/php/7.1/fpm/pool.d

ESCAPED_TIMEZONE=$(echo ${TIMEZONE} | sed -e 's/[]\/$*.^|[]/\\&/g')
safecp ${WORKDIR}/templates/php/fpm/php.ini /etc/php/7.1/fpm
sudo sed -i -e "s/{TIMEZONE}/${ESCAPED_TIMEZONE}/g" \
            -e "s/{MAX_EXECUTION_TIME}/${MAX_EXECUTION_TIME}/g" /etc/php/7.1/fpm/php.ini

safecp ${WORKDIR}/templates/php/cli/php.ini /etc/php/7.1/cli
sudo sed -i "s/{TIMEZONE}/${ESCAPED_TIMEZONE}/g" /etc/php/7.1/cli/php.ini

# Composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('SHA384', 'composer-setup.php') === '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;" && \
php composer-setup.php && \
php -r "unlink('composer-setup.php');" && \
sudo mv composer.phar /usr/local/bin/composer && \
sudo mkdir -p /home/${DEPLOYER_NAME}/.composer && \
safecp ${WORKDIR}/templates/php/composer/config-${TYPE}.json /home/${DEPLOYER_NAME}/.composer/config.json
sudo sed -i "s/{GITHUB_TOKEN}/${GITHUB_TOKEN}/g" /home/${DEPLOYER_NAME}/.composer/config.json
sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /home/${DEPLOYER_NAME}/.composer

# PHPUnit (v6.x)
wget https://phar.phpunit.de/phpunit.phar && \
chmod +x phpunit.phar && \
sudo mv phpunit.phar /usr/local/bin/phpunit

# PHP CodeSniffer
dlf_fast_console https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar /usr/local/bin/phpcs "+x"

# PHP Code Beautifier
dlf_fast_console https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar /usr/local/bin/phpcbf "+x"

# PHP Mess Detector
dlf_fast_console http://static.phpmd.org/php/latest/phpmd.phar /usr/local/bin/phpmd "+x"

# Couscous (User documentation generation)
dlf_fast_console http://couscous.io/couscous.phar /usr/local/bin/couscous "+x"

# Restart PHP and Nginx
sudo service php7.1-fpm restart
sudo service nginx restart
