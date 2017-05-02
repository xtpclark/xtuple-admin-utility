#!/bin/bash

provision_menu() {

    log "Opened provisioning menu"

    ACTION=$(whiptail --backtitle "$( window_title )" --menu "Select Action" 0 0 7 --ok-button "Select" --cancel-button "Cancel" \
    "1" "Install non-web-enabled xTuple" \
    "2" "Install web-enabled xTuple" \
    3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    elif [ $ACTION = "1" ]; then
        log_choice install_postgresql $POSTVER
        log_choice provision_cluster $POSTVER
        log_choice create_database
    else
        log_choice install_postgresql $POSTVER
        log_choice provision_cluster $POSTVER
        configure_nginx
        log_choice create_database
        log_choice install_mwc_menu
    fi
    msgbox "Install Complete"

    return 0
}
