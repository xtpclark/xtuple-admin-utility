#!/bin/bash

provision_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  log "Opened provisioning menu"

  ACTION=$(whiptail --backtitle "$( window_title )" --menu "Select Action" 0 0 10 \
                    --ok-button "Select" --cancel-button "Cancel" \
                    "1" "Install base xTuple system" \
                    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return 0
  elif [ $ACTION = "1" ]; then
    log_exec install_postgresql $PGVER
    get_cluster_list
    if [ -n "$CLUSTERS" ]; then
      set_database_info_select
    else
      log_exec provision_cluster $PGVER
    fi
    log_exec create_database

  else
    msgbox "Return to main menu and select another option"
    main_menu
  fi

  return 0
}
