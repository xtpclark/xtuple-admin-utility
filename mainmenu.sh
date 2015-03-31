#!/bin/bash

main_menu() {
while true; do

	CC=$(whiptail --backtitle "xTuple Server v$_REV" --menu "Main Menu" 0 0 1 --cancel-button "Exit" --ok-button "Select" \
        "1" "Install prerequisite packages" \
        "2" "Database Menu" \
        "3" "Other Stuff" \
        3>&1 1>&2 2>&3)
	
	RET=$?
	
	if [ $RET -eq 1 ]; then
        do_exit
	elif [ $RET -eq 0 ]; then
        case "$CC" in
        "1") install_prereqs ;;
        "2") database_menu ;;
        "3") other_stuff ;;
        *) msgbox "Error 001. Please report on GitHub" && exit 0 ;;
		esac || msgbox "I don't know how you got here!!! >> $CC <<  Report on GitHub"
	fi
done
}
main_menu