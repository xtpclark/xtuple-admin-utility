#!/bin/bash

POSSIBLE=$(ls -t1 *.tar.gz |  head -n 1)

FOLDER=$(tar --exclude="*/*" -tf ${POSSIBLE} | cut -d '/' -f 1)

APPARANT_VERSION=$(echo ${FOLDER} | cut -d '-' -f2)

READCONFIG=$(tar xf ${POSSIBLE} ${FOLDER}/xtau_config -O)
if [[ -z "${READCONFIG}" ]]; then
echo "No xtau_config in Archive"
READCONFIG=''
else
echo "We have a valid config"
fi

echo "$POSSIBLE
$APPARANT_VERSION
$FOLDER
$READCONFIG"

