#!/usr/bin/env bash
TYPE="${1:-vagrant}"
TIMEZONE="${2}"
GITHUB_TOKEN="${3}"
HOST_USERNAME="${4}"
DEPLOYER_NAME="${5:-vagrant}"
DEPLOYER_PASS="${6:-vagrant}"
SOURCE_DIR="${7:-/vagrant}"

echo "Vagrant shell provisioning..."

export DEBIAN_FRONTEND=noninteractive \
&& apt-get update  \
    --quiet --assume-yes --fix-missing \
&& apt-get upgrade \
    --quiet --assume-yes --fix-missing \
    --option Dpkg::Options::="--force-confdef" \
    --option Dpkg::Options::="--force-confold" \
&& apt-get dist-upgrade \
    --quiet --assume-yes --fix-missing \
    --option Dpkg::Options::="--force-confdef" \
    --option Dpkg::Options::="--force-confold"

if [[ ! -e /var/xtuple/keys && -d "${SOURCE_DIR}"/var/keys ]]; then
  mkdir --parents /var/xtuple \
  && ln --symbolic "${SOURCE_DIR}"/var/keys /var/xtuple/keys
fi

if [[ ! -e /var/log/xtuple && -d "${SOURCE_DIR}"/var/log ]]; then
  mkdir --parents /var/log \
  && ln --symbolic "${SOURCE_DIR}"/var/log /var/log/xtuple
fi

# Fix /vagrant directory user/group
adduser --system --no-create-home \
  --uid "$(stat -c '%u' /vagrant)" \
  --ingroup "$(stat -c '%G' /vagrant)" \
  "${HOST_USERNAME}"

apt-get autoremove \
  --quiet --assume-yes
