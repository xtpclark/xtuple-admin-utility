#!/bin/bash

postgresql_menu() {

    while true; do
        PGM=$(whiptail --backtitle "xTuple Server v$_REV" --menu "PostgreSQL Menu" 15 60 7 --cancel-button "Exit" --ok-button "Select" \
            "1" "Install 9.3" \
            "2" "Remove 9.3" \
            "3" "Install 9.4" \
            "4" "Remove 9.4" \
            "5" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            do_exit
        elif [ $RET -eq 0 ]; then
            case "$PGM" in
            "1") apt-get -y install postgresql-9.3 postgresql-client-9.3 postgresql-contrib-9.3;;
            "2") apt-get -y remove postgresql-9.3 postgresql-contrib-9.3 ;;
            "3") apt-get -y install postgresql-9.4 postgresql-client-9.4 postgresql-contrib-9.4;;
            "4") apt-get -y remove postgresql-9.4 postgresql-contrib-9.4 ;;
            "5")  break ;;
            *) msgbox "Error 004. How did you get here?" && exit 0 ;;
            esac || postgresql_menu
        fi
    done

}