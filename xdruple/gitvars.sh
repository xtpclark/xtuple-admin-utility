#!/bin/bash
source functions/gitvars.fun
CRMACCT=$1

if [[ -z ${CRMACCT} ]]; then
echo "Need to set a CRMACCT"
exit 0
else
loadcrm_gitconfig
checkcrm_gitconfig
fi

