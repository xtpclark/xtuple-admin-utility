#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$TOKENMANAGEMENT_H" ] ; then # {
TOKENMANAGEMENT_H=true

ssh_setup() {
  log "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  # This is added so composer doesn't ask for auth during the process.
  if [[ -e ~/.ssh/config ]]; then
    log "Found SSH config"
    SSHFILE=~/.ssh/config
    declare regex="\s+
#Added by xTau
Host github.com
HostName github.com
StrictHostKeyChecking no\s+"

    declare file_content=$( cat "${SSHFILE}" )
    if [[ " $file_content " =~ $regex ]] ; then
      log "SSH Config looks good"
    else
      cat <<-EOF >> $HOME/.ssh/config

	#Added by xTau
	Host github.com
	HostName github.com
	StrictHostKeyChecking no
EOF
    fi

  else
    log "Creating ~/.ssh/config"
    if [ ! -d $HOME/.ssh  ]; then
      log_exec mkdir --parents $HOME/.ssh
    else
      cat <<-EOF >> ~/.ssh/config
	#Added by xTau
	Host github.com
	HostName github.com
	StrictHostKeyChecking no
EOF
    fi
  fi
}

get_github_token() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  loadadmin_gitconfig

  if [ -z "${GITHUB_TOKEN}" ] ; then
    GITHUB_TOKEN=$(git config --get github.token)
  fi
  if [ -z "${GITHUB_TOKEN}" -a -f .githubtoken ] ; then
    source .githubtoken
    export GITHUBNAME GITHUB_TOKEN
  fi
  if [ -z "${GITHUB_TOKEN}" -a "${MODE}" = 'auto' ] ; then
    msgbox "Cannot find your github personal access token.
Either set GITHUB_TOKEN in your environment,
write a .githubtoken file in the xtuple-admin-utility directory,
or run $PROG interactively."
    return 1
  fi

  if [ -z "${GITHUB_TOKEN}" ] ; then
    generate_github_token
  fi
}

generate_github_token() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local OAMSG RET
  local OUTPUT=GITHUB_TOKEN_${WORKDATE}.log

  if [ -z "${GITHUBNAME}" -o -z "${GITHUBPASS}" ] ; then
    dialog --ok-label  "Submit"                                 \
           --backtitle "$(window_title)"                        \
           --title     "Generate GitHub Personal Access Token"  \
           --form      "GitHub Credentials" 0 0 3               \
           "GitHub Username:" 1 1 "" 1 20 50 0                  \
           "GitHub Password:" 2 1 "" 2 20 50 0                  \
           3>&1 1>&2 2> github.ini
    RET=$?
    if [ $RET -ne $DIALOG_OK ] ; then
      return 1
    fi
    read -d "\n" GITHUBNAME GITHUBPASS <<<$(cat github.ini)
    export       GITHUBNAME GITHUBPASS
    rm -f github.ini
  fi

  log "Generating your Github token."
  curl https://api.github.com/authorizations --user ${GITHUBNAME}:${GITHUBPASS} \
       --data '{"scopes":["user","read:org","repo","public_repo"],"note":"Added Via xTau '${WORKDATE}'"}' \
       -o $OUTPUT
  GITHUB_TOKEN=$(jq --raw-output '.token | select(length > 0)' $OUTPUT)
  if grep -q errors $OUTPUT ; then
    OAMSG=$(jq --compact-output --raw-output '{ (.message): .errors[0].code }' $OUTPUT)
  fi

  if [ -n "${OAMSG}" -o -z "${GITHUB_TOKEN}" ] ; then
    msgbox "Error creating your token:\n${OAMSG}"
    return 1
  fi

  git config --global github.token ${GITHUB_TOKEN}
  echo "GITHUBNAME=$GITHUBNAME\nGITHUB_TOKEN=${GITHUB_TOKEN}" >> .githubtoken

  msgbox "Your GitHub Personal Access token is: ${GITHUB_TOKEN}.
Maintain your tokens at https://github.com/settings/tokens

Token written to ${HOME}/.gitconfig"
  log "Your GitHub Personal Access token is: ${GITHUB_TOKEN}"
}

ssh_setup

fi # }
