#!/bin/bash

extras_menu() {
    log "Opened extras menu"

    while true; do

        CC=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Extras\ Menu )" 0 0 1 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Install Prerequisites" \
            "2" "Return to main menu" \
            3>&1 1>&2 2>&3)
        
        RET=$?
        
        if [ $RET -ne 0 ]; then
            break
        else
            case "$CC" in
            "1") install_prereqs ;;
            "2") break ;;
            *) msgbox "Don't know how you got here! Please report on GitHub >> extras_menu $CC" && break ;;
            esac
        fi
    done
}

main_menu() {

    log "Opened main menu"

    while true; do

        CC=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Main\ Menu)" 0 0 1 --cancel-button "Exit" --ok-button "Select" \
            "1" "Provisioning Menu" \
            "2" "PostgreSQL Maintenance" \
            "3" "Database Maintenance" \
            "4" "nginx Maintenance" \
            "5" "Web Client Maintenance" \
            "6" "OpenRPT Menu (web printing)" \
            "7" "Development Menu" \
            "8" "Extras Menu" \
            3>&1 1>&2 2>&3)
        
        RET=$?
        
        if [ $RET -ne 0 ]; then
            do_exit
        else
            case "$CC" in
            "1") provision_menu ;;
            "2") postgresql_menu ;;
            "3") database_menu ;;
            "4") nginx_menu ;;
            "5") mwc_menu ;;
            "6") openrpt_menu ;;
            "7") dev_menu ;;
            "8") extras_menu ;;
            *) msgbox "Don't know how you got here! Please report on GitHub >> mainmenu" && do_exit ;;
            esac
        fi
    done
}

main_menu
