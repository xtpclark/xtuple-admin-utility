#!/bin/bash

main_menu() {

    log "Opened main menu"

    while true; do

        CC=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Main\ Menu)" 0 0 1 --cancel-button "Exit" --ok-button "Select" \
            "1" "Quick Install of PostBooks" \
            "2" "PostgreSQL Maintenance" \
            "3" "Database Maintenance" \
            "4" "Development Environment Setup" \
            3>&1 1>&2 2>&3)
        
        RET=$?
        
        if [ $RET -ne 0 ]; then
            do_exit
        else
            case "$CC" in
            "1") provision_menu ;;
            "2") postgresql_menu ;;
            "3") database_menu ;;
            "4") dev_menu ;;
            *) msgbox "Don't know how you got here! Please report on GitHub >> mainmenu" && do_exit ;;
            esac
        fi
    done
}

main_menu
