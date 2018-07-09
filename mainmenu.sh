#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

main_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  log "Opened main menu"

  while true; do

    CC=$(whiptail --backtitle "$(window_title)"               \
                  --menu "$(menu_title Main Menu)" 0 0 10     \
                  --cancel-button "Exit" --ok-button "Select" \
                  "1" "Install Base xTuple system"      \
                  "2" "PostgreSQL Maintenance"          \
                  "3" "Database Maintenance"            \
                  "4" "SSH Connection Manager"          \
                  "5" "Generate Github Token"           \
                  "6" "Web Enable a Database"           \
                  "7" "xTupleCommerce Maintenance"      \
                  "8" "Developer Zone"                  \
                  3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET -ne 0 ]; then
      do_exit
    else
      case "$CC" in
        "1") install_postgresql $PGVER
             get_cluster_list
             if [ -n "$CLUSTERS" ]; then
               set_database_info_select
             else
               provision_cluster $PGVER
             fi
             create_database
             ;;
        "2") postgresql_menu ;;
        "3") database_menu   ;;
        "4") conman_menu     ;;
        "5") get_github_token
             generate_github_token
             ;;
        "6") source ${WORKDIR:-.}/CreatePackages.sh try_deploy_xtau;;
        "7") drupal_menu     ;;
        "8") dev_menu        ;;
        *) msgbox "Don't know how you got here! Please report on GitHub >> mainmenu" && do_exit ;;
      esac
    fi
    done
}

main_menu
