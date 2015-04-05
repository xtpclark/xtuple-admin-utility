#!/bin/bash

extras_menu() {
while true; do

	CC=$(whiptail --backtitle "$( window_title )" --menu "Extras Menu" 0 0 1 --cancel-button "Exit" --ok-button "Select" \
        "1" "Install Prerequesites" \
        "2" "Return to main menu" \
        3>&1 1>&2 2>&3)
	
	RET=$?
	
	if [ $RET -eq 1 ]; then
        do_exit
	elif [ $RET -eq 0 ]; then
        case "$CC" in
        "1") install_prereqs ;;
        "2") break ;;
        *) msgbox "Error 001. Please report on GitHub" && exit 0 ;;
		esac || msgbox "I don't know how you got here!!! >> $CC <<  Report on GitHub"
	fi
done
}

main_menu() {
while true; do

	CC=$(whiptail --backtitle "$( window_title )" --menu "Main Menu" 0 0 1 --cancel-button "Exit" --ok-button "Select" \
        "1" "Provisioning Menu" \
        "2" "PostgreSQL Maintainence" \
        "3" "Database Maintainence" \
        "4" "nginx Maintainence" \
        "5" "Extras Menu" \
        3>&1 1>&2 2>&3)
	
	RET=$?
	
	if [ $RET -eq 1 ]; then
        do_exit
	elif [ $RET -eq 0 ]; then
        case "$CC" in
        "1") provision_menu ;;
        "2") postgresql_menu ;;
        "3") database_menu ;;
        "4") nginx_menu ;;
        "5") extras_menu ;;
        *) msgbox "Error 001. Please report on GitHub" && exit 0 ;;
		esac || msgbox "I don't know how you got here!!! >> $CC <<  Report on GitHub"
	fi
done
}

main_menu
