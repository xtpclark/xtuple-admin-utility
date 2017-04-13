#!/bin/bash
provision_menu() {

    log "Opened provisioning menu"

    ACTION=$(whiptail --backtitle "$( window_title )" --menu "Select Action" --ok-button "Select" --cancel-button "Cancel" \
    "Please choose the action you would like to take" 15 60 7 \
    "1" "Install PostBooks Database Only" ON \
    "2" "Install PostBooks Database With Web Components" OFF \
    3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET = 0 ]; then
        fi
        if [ $ACTION = "1" ]; then
            log_choice install_postgresql $POSTVER
		    log_choice drop_cluster $POSTVER main auto
			log_choice provision_cluster $POSTVER
			configure_nginx
			log_choice download_demo manual $WORKDIR/tmp.backup
		else
            log_choice install_postgresql $POSTVER
			log_choice drop_cluster $POSTVER main auto
			log_choice provision_cluster $POSTVER
			configure_nginx
			log_choice download_demo manual $WORKDIR/tmp.backup
			log_choice install_mwc_menu
		fi
    fi

    msgbox "Install Complete"

    return 0;
}
