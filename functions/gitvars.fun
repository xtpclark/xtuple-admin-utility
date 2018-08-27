# #!/bin/bash
# # Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# # See www.xtuple.com/CPAL for the full text of the software license.

# if [ -z "$GITVARS_FUN" ] ; then # {
# GITVARS_FUN=true

loadadmin_gitconfig() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  [ -e $HOME/.gitconfig ] || touch $HOME/.gitconfig
  ADMINVARSLIST=$(git config --global -l | grep -E '(github|xdruple)' | cut -d . -f 2-)

  if [[ -z ${ADMINVARSLIST} ]]; then
    echo "${DEPLOYER_NAME} does not have any git config variables set"
  else
    for ADMINVAR in ${ADMINVARSLIST}; do
      export ${ADMINVAR}
    done
  fi
}

# # TODO: alter to work in AUTO mode and use whiptail/dialog
# loadcrm_gitconfig() {
#   echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

#   if [[ -z ${CRMACCT} ]]; then
#     read -p "CRMACCT Needed: " CRMACCT
#   fi

#   PHPVARSLIST=$(git config --global -l | grep ${CRMACCT,,}env | cut -d . -f 2-)

#   if [[ -z ${PHPVARSLIST} ]]; then
#     echo "No gitconfig vars for ${CRMACCT}"

#   else
#     for PHPVAR in ${PHPVARSLIST}; do
#       export ${PHPVAR}
#       echo "export ${PHPVAR}"
#     done
#     echo "Found and exported vars for ${CRMACCT}"
#   fi
# }

# # TODO: alter to work in AUTO mode and use whiptail/dialog
# checkcrm_gitconfig() {
#   echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

#   USEXDRUPLEAPIKEYS=0
#   WHICHSHIP="${CRMACCT,,}env"

#   git config --global -l | grep -E '(xdrupleshipping)' > /dev/null
#   RET=$?
#   if [[ ${RET} > 0 ]]; then
#     echo "You do not have xdrupleshipping keys"
#   elif [[ ${CRMACCT} = "xTupleBuild" ]]; then
#       unset USEXDRUPLEAPIKEYS
#       USEXDRUPLEAPIKEYS=1
#       WHICHSHIP="xdrupleshipping"

#   else
#     echo "I found xTuple Shipping API Keys "
#     read -r -p "Do you want to them? [y,N] " response
#     response=${response,,}

#     if [[ "$response" =~ ^(yes|y)$ ]]; then
#       unset USEXDRUPLEAPIKEYS
#       USEXDRUPLEAPIKEYS=1
#       WHICHSHIP="xdrupleshipping"
#     fi
#   fi
# }

# fi # }
