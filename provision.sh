#!/bin/bash
provision_menu() {

    log "Opened provisioning menu"

<<<<<<< dc8a8446b9efd45697bdc8e001b7832cebdd4580
    ACTIONS=$(whiptail --separate-output --title "Select Components" --checklist --cancel-button "Cancel" \
    "Please choose the actions you would like to take" 15 60 7 \
    "installpg" "Install PostgreSQL $POSTVER" ON \
    "provisioncluster" "Provision PostgreSQL Cluster" ON \
    "initdb" "Add xTuple admin user and role" ON \
    "demodb" "Load xTuple Database" OFF \
    "webclient" "Load xTuple Web Client" OFF \
    "nginx" "Nginx" OFF \
=======
    ACTION=$(whiptail --backtitle "$( window_title )" --menu "Select Action" --ok-button "Select" --cancel-button "Cancel" \
    "Please choose the action you would like to take" 15 60 7 \
    "1" "Install PostBooks Database Only" ON \
    "2" "Install PostBooks Database With Web Components" OFF \
>>>>>>> Merge provisioning options into two main choices.
    3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET = 0 ]; then
        fi
<<<<<<< dc8a8446b9efd45697bdc8e001b7832cebdd4580
        for i in $ACTIONS; do   
            case "$i" in
            "installpg") log_choice install_postgresql $POSTVER
                           log_choice drop_cluster $POSTVER main auto
                           ;;
            "provisioncluster") log_choice provision_cluster $POSTVER
                                ;;
            "initdb") log_choice prepare_database auto
                      ;;
            "nginx") configure_nginx
                     ;;
            "demodb") log_choice download_demo manual $WORKDIR/tmp.backup
                      ;;
            "webclient") log_choice install_mwc_menu
                      ;;
             *) ;;
            esac || main_menu
        done
    fi
    
    if [ -n "$ACTIONS" ]; then
        msgbox "The following actions were completed: \n$ACTIONS" 
    elif [ -z "$ACTIONS" ]; then
        msgbox "No actions were taken."
=======
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
>>>>>>> Merge provisioning options into two main choices.
    fi

    msgbox "Install Complete"

    return 0;
}
