#!/bin/bash
provision_menu() {

    log "Opened provisioning menu"

    ACTIONS=$(whiptail --separate-output --title "Select Components" --checklist --cancel-button "Cancel" \
    "Please choose the actions you would like to take" 15 60 7 \
    "installpg" "Install PostgreSQL $POSTVER" ON \
    "provisioncluster" "Provision PostgreSQL Cluster" ON \
    "initdb" "Add xTuple admin user and role" ON \
    "demodb" "Load xTuple Database" OFF \
    "webclient" "Load xTuple Web Client" OFF \
    "nginx" "Nginx" OFF \
    3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET = 0 ]; then
        if [[ $ACTIONS == *"installpg"* ]] && [[ $ACTIONS != *"provisioncluster"* ]]; then
            msgbox "You are about to install PostgreSQL but not provision to any clusters. \nYou will need to create a cluster manually before you can initialize \nit for xTuple. If you have chosen to initialize the database or install a demo \nthose actions will be skipped."
            SKIP=1
            ACTIONS=`sed "/initdb/d" <<< "$ACTIONS"`
            log "Skipping initdb because provisioncluster was not chosen."
            ACTIONS=`sed "/demodb/d" <<< "$ACTIONS"`
            log "Skipping demodb because provisioncluster was not chosen."
        fi
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
    fi
    return 0;
}
