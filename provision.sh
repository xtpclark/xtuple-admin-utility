#!/bin/bash
provision_menu() {

    log "Opened provisioning menu"

    ACTIONS=$(whiptail --separate-output --title "Select Components" --checklist --cancel-button "Return" \
    "Please choose the actions you would like to take" 15 60 7 \
    "installpg93" "Install PostgreSQL 9.3" ON \
    "provisioncluster" "Provision PostgreSQL Cluster" ON \
    "initdb" "Add xTuple admin user and role" ON \
    "nginx" "Nginx" OFF \
    "nodejs" "NodeJS" OFF \
    "qtclient" "xTuple ERP Client" OFF \
    "demodb" "Load xTuple Database" OFF \
    3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET = 0 ]; then
    if [[ $ACTIONS == *"installpg93"* ]] && [[ $ACTIONS != *"provisioncluster"* ]]
    then
        msgbox "You are about to install PostgreSQL but not provision to any clusters. \nYou will need to create a cluster manually before you can initialize \nit for xTuple. If you have chosen to initialize the database or install a demo \nthose actions will be skipped."
        SKIP=1
        ACTIONS=`sed "/initdb/d" <<< "$ACTIONS"`
        log "Skipping initdb because provisioncluster was not chosen."
        ACTIONS=`sed "/demodb/d" <<< "$ACTIONS"`
        log "Skipping demodb because provisioncluster was not chosen."
    fi
        for i in $ACTIONS; do   
            case "$i" in
            "installpg93") install_postgresql 9.3
                           drop_cluster 9.3 main auto
                           ;;
            "provisioncluster") provision_cluster 9.3
                                ;;
            "initdb") prepare_database auto
                      ;;
            "nginx") install_nginx
                     ;;
            "nodejs") apt-get -y install nodejs
                      ;;
            "qt-client") msgbox "Qt Client not implemented yet"
                         ;;
            "demodb") download_demo auto
                      ;;
             *) ;;
         esac || main_menu
        done
    fi
    
    if [ -n "$ACTIONS" ]; then
        msgbox "The following actions were completed: \n$ACTIONS" 
    fi
    return 0;
}
