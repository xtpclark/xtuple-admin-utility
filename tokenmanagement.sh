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
      cat <<-EOF >> ~/.ssh/config

	#Added by xTau
	Host github.com
	HostName github.com
	StrictHostKeyChecking no
EOF
    fi

  else
    log "Creating ~/.ssh/config"
    if [ ! -d ~/.ssh  ]; then
      log_exec mkdir -p ~/.ssh
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

# TODO: rewrite using dialog
generate_github_token() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  local OAMSG RET
  local OUTPUT=GITHUB_TOKEN_${WORKDATE}.log

  loadadmin_gitconfig

  export GITHUB_TOKEN=$(git config --get github.token)
  if [[ -z ${GITHUB_TOKEN} ]]; then
    if ! whiptail --title "GitHub Personal Access Token" \
                 --yesno "Would you like to set up your GitHub Personal Access Token?" 10 60 ; then
      return;
    fi

    log "Creating GitHub Personal Access Token"
    GITHUBNAME=$(whiptail --backtitle "$( window_title )" \
                          --inputbox "Enter your GitHub username" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi

    GITHUBPASS=$(whiptail --backtitle "$( window_title )" \
                          --passwordbox "Enter your GitHub password" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi

    log "Generating your Github token."
    curl https://api.github.com/authorizations --user ${GITHUBNAME}:${GITHUBPASS} \
         --data '{"scopes":["user","read:org","repo","public_repo"],"note":"Added Via xTau '${WORKDATE}'"}' \
         -o $OUTPUT
    GITHUB_TOKEN=$(jq --raw-output '.token | select(length > 0)' $OUTPUT)
    if grep -q errors $OUTPUT ; then
      OAMSG=$(jq --compact-output --raw-output '{ (.message): .errors[0].code }' $OUTPUT)
    fi

    if [[ -n "${GITHUB_TOKEN}" ]]; then
      git config --global github.token ${GITHUB_TOKEN}
    else
      whiptail --backtitle "$( window_title )" --msgbox "Error creating your token. ${OAMSG}" 8 60 3>&1 1>&2 2>&3
      return
    fi
  fi

  if [[ -z "${GITHUB_TOKEN}" ]]; then
    whiptail --backtitle "$( window_title )" --msgbox "Not sure what happened, but we don't know about a token..." 8 60 3>&1 1>&2 2>&3
    return
  fi

  whiptail --backtitle "$( window_title )" \
           --msgbox "Your GitHub Personal Access token is: ${GITHUB_TOKEN}.
Maintain your tokens at https://github.com/settings/tokens

Token written to ${HOME}/.gitconfig" 16 60 3>&1 1>&2 2>&3
  log "Your GitHub Personal Access token is: ${GITHUB_TOKEN}"
}

ssh_setup

fi # }
