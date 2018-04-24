#!/bin/bash

main_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  log "Opened main menu"

  while true; do

    CC=$(whiptail --backtitle "$( window_title )" \
                  --menu "$( menu_title Main\ Menu)" 0 0 10 \
                  --cancel-button "Exit" --ok-button "Select" \
                  "1" "Quick Install"          \
                  "2" "PostgreSQL Maintenance" \
                  "3" "Database Maintenance"   \
                  "4" "SSH Connection Manager" \
                  "5" "Generate Github Token"  \
                  "6" "Web Enable a Database"  \
                  "7" "Install xTupleCommerce" \
                  "8" "Developer Zone"         \
                  3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET -ne 0 ]; then
      do_exit
    else
      case "$CC" in
        "1") provision_menu  ;;
        "2") postgresql_menu ;;
        "3") database_menu   ;;
        "4") selectServer    ;;
        "5") generate_github_token;;
        "6") source ${WORKDIR:-.}/CreatePackages.sh try_deploy_xtau;;
        "7") source ${WORKDIR:-.}/CreatePackages.sh xtau_deploy_ecommerce;;
        "8") dev_menu        ;;
        *) msgbox "Don't know how you got here! Please report on GitHub >> mainmenu" && do_exit ;;
      esac
    fi
    done
}

main_menu
