#!/bin/bash

nginx_menu() {

    while true; do
        NGM=$(whiptail --backtitle "xTuple Utility v$_REV" --menu "nginx Menu" 15 60 7 --cancel-button "Exit" --ok-button "Select" \
            "1" "Install nginx" \
            "2" "Remove nginx" \
            "3" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            do_exit
        elif [ $RET -eq 0 ]; then
            case "$NGM" in
            "1") install_nginx ;;
            "2") remove_nginx ;;
            "3") break ;;
            *) msgbox "Error 004. How did you get here?" && exit 0 ;;
            esac || nginx_menu
        fi
    done

}

install_nginx() {
    apt-get -y install nginx
    RET=$?
    return $RET
}

remove_nginx() {
    apt-get -y remove nginx
    RET=$?
    return $RET
}
