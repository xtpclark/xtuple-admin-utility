#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

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

