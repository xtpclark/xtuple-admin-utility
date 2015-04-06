#!/bin/bash
provision_menu() {
    ACTIONS=$(whiptail --separate-output --title "Select Components" --checklist --cancel-button "Exit" \
    "Please choose the actions you would like to take" 15 60 7 \
    "installpg93" "Install PostgreSQL 9.3" OFF \
    "provisioncluster" "Provision PostgreSQL Cluster" OFF \
    "initdb" "Add xTuple admin user and role" OFF \
    "nginx" "Nginx" OFF \
    "nodejs" "NodeJS" OFF \
    "qtclient" "xTuple ERP Client" OFF \
    "demodb" "Load xTuple Database" OFF \
    3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET = 0 ]; then
        for i in $ACTIONS; do   
            case "$i" in
            "installpg93") install_postgresql 9.3
                          drop_cluster 9.3 main auto
                          ;;
            "provisioncluster") provision_cluster 9.3
                                ;;
            "initdb") prepare_database auto
                      #reset_sudo admin
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
