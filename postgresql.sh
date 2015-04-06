#!/bin/bash

XTPG="/tmp/xtpg"
rm -rf $XTPG
mkdir -p $XTPG

postgresql_menu() {

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --menu "PostgreSQL Menu" 15 60 9 --cancel-button "Exit" --ok-button "Select" \
            "1" "Install PostgreSQL 9.3" \
            "2" "Remove PostgreSQL 9.3" \
            "3" "Purge PostgreSQL 9.3" \
            "4" "List provisioned clusters" \
            "5" "Provision database cluster" \
            "6" "Drop database cluster" \
            "7" "Prepare cluster for xTuple" \
            "8" "Reset passwords" \
            "9" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            do_exit
        elif [ $RET -eq 0 ]; then
            case "$PGM" in
            "1") install_postgresql 9.3 ;;
            "2") remove_postgresql 9.3 ;;
            "3") purge_postgresql 9.3 ;;
            "4") list_clusters ;;
            "5") provision_cluster ;;
            "6") drop_cluster_menu ;;
            "7") prepare_database ;;
            "8") password_menu ;;
            "9") break ;;
            *) msgbox "Error. How did you get here?" && exit 0 ;;
            esac || postgresql_menu
        fi
    done

}

# $1 is mode (auto/manual)
prepare_database() {

    INIT_URL="http://files.xtuple.org/common/init.sql"
    EXTRAS_URL="http://files.xtuple.org/common/extras.sql"
    
    dlf_fast $INIT_URL "Downloading init.sql. Please Wait." $XTPG/init.sql
    dlf_fast $INIT_URL.md5sum "Downloading init.sql.md5sum. Please Wait." $XTPG/init.sql.md5sum
    
	VALID=`cat $XTPG/init.sql.md5sum | awk '{printf $1}'`
	CURRENT=`md5sum $XTPG/init.sql | awk '{printf $1}'`
	if [ "$VALID" != "$CURRENT" ]; then
		msgbox "There was an error verifying the init.sql that was downloaded. Utility will now exit."
		do_exit
	fi
    
    dlf_fast $EXTRAS_URL "Downloading init.sql. Please Wait." $XTPG/extras.sql
    dlf_fast $EXTRAS_URL.md5sum "Downloading init.sql.md5sum. Please Wait." $XTPG/extras.sql.md5sum
    
	VALID=`cat $XTPG/extras.sql.md5sum | awk '{printf $1}'`
	CURRENT=`md5sum $XTPG/extras.sql | awk '{printf $1}'`
	if [ "$VALID" != "$CURRENT" ]; then
		msgbox "There was an error verifying the extras.sql that was downloaded. Utility will now exit."
		do_exit
	fi
    
    check_database_info
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    fi
    
    echo "Deploying init.sql, creating admin user and xtrole group"
    psql -q -U postgres -d postgres -p $PGPORT -f $XTPG/init.sql
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Error deplying init.sql. Check for errors and try again"
        return 0
    fi
    
    echo "Deploying extras.sql, creating extensions adminpack, pgcrypto, cube, earthdistance. Extension exists errors can be safely ignored."
    psql -q -U postgres -d postgres -p $PGPORT -f $XTPG/extras.sql
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Error deplying extras.sql. Check for errors and try again"
        return 0
    fi
    
    reset_sudo admin
    if [ $RET -eq 1 ]; then
        msgbox "Error setting the admin password. Check for errors and try again"
        return 0
    fi
    
    if [ -z $1 ] || [ $1 = "manual" ]; then
        msgbox "Operations completed successfully"
    else
        return 0
    fi

}

password_menu() {

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --menu "Reset Password Menu" 15 60 7 --cancel-button "Exit" --ok-button "Select" \
            "1" "Reset postgres via sudo postgres" \
            "2" "Reset postgres via psql" \
            "3" "Reset admin via sudo postgres" \
            "4" "Reset admin via psql" \
            "5" "Return to previous menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            do_exit
        elif [ $RET -eq 0 ]; then
            case "$PGM" in
            "1") reset_sudo postgres ;;
            "2") reset_psql postgres ;;
            "3") reset_sudo admin ;;
            "4") reset_psql admin ;;
            "5") break ;;
            *) msgbox "How did you get here?" && exit 0 ;;
            esac || postgresql_menu
        fi
    done

}

# $1 is pg version (9.3, 9.4, etc)
install_postgresql() {

    apt-get -y install postgresql-$1 postgresql-client-$1 postgresql-contrib-$1
    RET=$?
    if [ $RET -eq 1 ]; then
    do_exit
    elif [ $RET -eq 0 ]; then
        export PGUSER=postgres
        export PGPASSWORD=postgres
        export PGHOST=localhost
        export PGPORT=5432
    fi
    return $RET

}

# $1 is pg version (9.3, 9.4, etc)
# we don't remove -client because we still need it for managment tasks
remove_postgresql() {

    if (whiptail --title "Are you sure?" --yesno "Uninstall PostgreSQL $1? Cluster data will be left behind." --yes-button "No" --no-button "Yes" 10 60) then
	return 0
    else
        echo "Uninstalling PostgreSQL "$1"..."
    fi

    apt-get -y remove postgresql-$1 postgresql-contrib-$1
    RET=$?
    return $RET

}

# $1 is pg version (9.3, 9.4, etc)
# we don't remove -client because we still need it for managment tasks
purge_postgresql() {

    if (whiptail --title "Are you sure?" --yesno "Completely remove PostgreSQL $1 and all of the cluster data?" --yes-button "No" --no-button "Yes" 10 60) then
        return 0
    else
        echo "Purging PostgreSQL "$1"..."
    fi 
    apt-get -y purge postgresql-$1 postgresql-contrib-$1
    RET=$?
    return $RET

}

list_clusters() {

    CLUSTERS=()
    
    while read -r line; do 
        CLUSTERS+=("$line" "$line")
    done < <( pg_lsclusters | tail -n +2 )

     if [ -z "$CLUSTERS" ]; then
        msgbox "No database clusters detected on this system"
        return 0
    fi

    msgbox "`pg_lsclusters`"

}

# $1 is postgresql version
# $2 is cluster name
# $3 is port
# $4 is locale
provision_cluster() {

    if [ -z $1 ]; then
        POSTVER=$(whiptail --backtitle "$( window_title )" --inputbox "Enter PostgreSQL Version (make sure it is installed!)" 8 60 "9.3" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        POSTVER=$1
    fi

    if [ -z $2 ]; then   
        POSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter Cluster Name (make sure it isn't already in use!)" 8 60 "xtuple" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        POSTNAME=$2
    fi
    
    if [ -z $3 ]; then
        POSTPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter Database Port (make sure it isn't already in use!)" 8 60 "5432" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        POSTPORT=$3
    fi
    
    if [ -z $4 ]; then  
        POSTLOCALE=$(whiptail --backtitle "$( window_title )" --inputbox "Enter Locale" 8 60 "en_US.UTF-8" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        POSTLOCALE=$4
    fi
    
    if (whiptail --title "Autostart" --yes-button "Yes" --no-button "No"  --yesno "Would you like the cluster to start at boot?" 10 60) then
        POSTSTART="--start-conf=auto"
    else
        POSTSTART=""
    fi
    echo "Creating database cluster $POSTNAME using version $POSTVER"
    su - postgres -c "pg_createcluster --locale $POSTLOCALE -p $POSTPORT --start $POSTSTART $POSTVER $POSTNAME"
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Creation of PostgreSQL cluster failed. Please check the output and correct any issues."
        do_exit
    else
        msgbox "Creation of database cluster $POSTNAME using version $POSTVER created successfully."
        export PGHOST=localhost
        export PGUSER=postgres
        export PGPASSWORD=postgres
        export PGPORT=$POSTPORT
        reset_sudo postgres
        if [ $RET -eq 1 ]; then
            msgbox "Error setting the postgres password. Correct any errors on the console. \nYou can try setting the password via another method using the Password Reset menu."
            do_exit
        fi
    fi
    
}

# $1 is version
# $2 is name
# $3 is mode (auto/manual)
# prompt if not provided
drop_cluster() {

    if [ -z "$1" ]; then
        POSTVER=$(whiptail --backtitle "$( window_title )" --inputbox "Enter version of cluster to remove" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        POSTVER=$1
    fi

    if [ -z "$2" ]; then
        POSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter name of cluster to remove" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        POSTNAME=$2
    fi
	
    if [ -z $3 ]; then
        MODE="manual"
    else
        MODE="auto"
    fi
    
    if [ $MODE = "manual" ]; then
        if (whiptail --title "Are you sure?" --yesno "Completely remove cluster $2 - $1?" --yes-button "No" --no-button "Yes" 10 60) then
            return 0
        else
            echo "Dropping PostgreSQL cluster $POSTNAME version $POSTVER completed successfully."
        fi
    fi

    su - postgres -c "pg_dropcluster --stop $POSTVER $POSTNAME"
    RET=$?
    if [ $MODE = "manual" ]; then
        if [ $RET -eq 1 ]; then
            msgbox "Dropping PostgreSQL cluster failed. Please check the output and correct any issues."
            do_exit
        else
            msgbox "Dropping PostgreSQL cluster $POSTNAME version $POSTVER completed successfully."
        fi
    fi
    return $RET
}

drop_cluster_menu() {

    CLUSTERS=()
    
    while read -r line; do 
        CLUSTERS+=("$line" "$line")
    done < <( pg_lsclusters | tail -n +2 )

     if [ -z "$CLUSTERS" ]; then
        msgbox "No database clusters detected on this system"
        return 0
    fi
    
    CLUSTER=$(whiptail --title "PostgreSQL Clusters" --menu "Select cluster to drop" 16 120 5 "${CLUSTERS[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    fi

    if [ -z "$CLUSTER" ]; then
        msgbox "No database clusters detected on this system"
        return 0
    fi

    VER=`awk  '{print $1}' <<< "$CLUSTER"`
    NAME=`awk  '{print $2}' <<< "$CLUSTER"`
    
    if [ -z "$VER" ] || [ -z "$NAME" ]; then
        msgbox "Could not determine database version or name"
        return 0
    fi
    
    drop_cluster "$VER" "$NAME"
    
}

# $1 is user to reset
reset_sudo() {

    check_database_info

    NEWPASS=$(whiptail --backtitle "$( window_title )" --passwordbox "New $1 password" 8 60  3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    fi
    
    echo "Resetting PostgreSQL password for user $1 using psql via su - postgres"
    
    su - postgres -c "psql -q -U postgres -d postgres -p $PGPORT -c \"alter user $1 with password '$NEWPASS';\""
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Looks like something went wrong resetting the password via sudo. Try using psql, or opening up pg_hba.conf"
        return 0
    else
        export PGUSER=$1
        export PGPASSWORD=$NEWPASS
        msgbox "Password for user $1 successfully reset"
        return 0
    fi
    
}

# $1 is user to reset
reset_psql() {

    check_database_info

    NEWPASS=$(whiptail --backtitle "$( window_title )" --passwordbox "New $1 password" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    fi
    
    echo "Resetting PostgreSQL password for user $1 using psql directly"
    
    psql -q -U postgres -d postgres  -p $PGPORT -c \"alter user $1 with password '$NEWPASS';\"
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Looks like something went wrong resetting the password via psql. Try using sudo psql, or opening up pg_hba.conf"
        return 0
    else
        export PGUSER=$1
        export PGPASSWORD=$NEWPASS
        msgbox "Password for user $1 successfully reset"
        return 0
    fi
    
}
