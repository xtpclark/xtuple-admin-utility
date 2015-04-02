#!/bin/bash
XTMP="/tmp/xtdb"

rm -rf $XTMP
mkdir -p $XTMP

provision_menu() {
    #while true; do
        SELECTIONS=$(whiptail --separate-output --title "Select Software to Install" --checklist \
        "Choose individual pieces to install" 15 60 6 \
        "postgresql" "PostgreSQL 9.3" OFF \
        "preparext" "Add xTuple admin user and role" OFF \
        "nginx" "Nginx" OFF \
        "nodejs" "NodeJS" OFF \
        "qtclient" "xTuple ERP Client" OFF \
        "demodb" "Load xTuple Database" OFF \
        3>&1 1>&2 2>&3)

        RET=$?
        if [ $RET = 0 ]; then
            for i in $SELECTIONS; do   
                case "$i" in
                "postgresql") install_postgresql 9.3
                                   reset_sudo postgres
                                   ;;
                "preparext") prepare_database auto
                                   reset_sudo admin
                                   ;;
                "nginx") install_nginx
                            ;;
                "nodejs") 
                              ;;
                "qt-client") 
                                ;;
                "demodb") download_demo auto
                                ;;
                 *) ;;
             esac || main_menu
            done
        fi
    #done
}

provision_demo() {
    
    MENUVER=$(whiptail --backtitle "xTuple Utility v$_REV" --menu "Choose Version" 15 60 7 --cancel-button "Exit" --ok-button "Select" \
            "1" "PostBooks 4.7.0 Demo" \
            "2" "PostBooks 4.7.0 Empty" \
            "3" "PostBooks 4.8.1 Demo" \
            "4" "PostBooks 4.8.1 Empty" \
            "5" "Return to database menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            return 0
        elif [ $RET -eq 0 ]; then
            case "$MENUVER" in
            "1") VERSION=4.7.0 
                   DBTYPE="demo"
                   ;;
            "2") VERSION=4.7.0 
                   DBTYPE="empty"
                   ;;
            "3") VERSION=4.8.1 
                   DBTYPE="demo"
                   ;;
            "4") VERSION=4.8.1 
                   DBTYPE="empty"
                   ;;
            "5") return 0 ;;
            *) msgbox "Error 005. How did you get here?" && exit 0 ;;
            esac || database_menu
        fi
    
    DEMODEST=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "Enter the filename where you would like to save the database" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
        
    DB_URL="http://files.xtuple.org/$VERSION/$DBTYPE.backup"
    MD5_URL="http://files.xtuple.org/$VERSION/$DBTYPE.backup.md5sum"
    
    dlf_fast $DB_URL "Downloading Demo Database. Please Wait." "$DEMODEST"
	dlf_fast $MD5_URL "Downloading MD5SUM. Please Wait." "$DEMODEST".md5sum
    
    echo "Saving "$DB_URL" as "$DEMODEST"."
    
	VALID=`cat "$DEMODEST".md5sum | awk '{printf $1}'`
	CURRENT=`md5sum "$DEMODEST" | awk '{printf $1}'`
	if [ "$VALID" != "$CURRENT" ]; then
		msgbox "There was an error verifying the downloaded database. Utility will now exit."
		do_exit
    else
        if (whiptail --title "Download Successful" --yesno "Download complete. Would you like to deploy this database now?." 10 60) then
            DEST=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -eq 1 ]; then
                return $RET
            fi
            echo "Creating database $DEST from file $DEMODEST"
            restore_database $DEMODEST $DEST
            RET=$?
            if [ $RET -eq 1 ]; then
                msgbox "Something has gone wrong. Check output and correct any issues."
                do_exit
            else
                msgbox "Database $DEST successfully restored from file $DEMODEST"
                return 0
            fi
        else
            echo "Exiting without restoring database."
        fi
	fi
}

provision_latest_demo() {
    
    VERSION=$(latest_version db)
    
    if [ -z $VERSION ]; then
        msgbox "Could not determine latest database version"
        do_exit
    fi
    
    if [ -z $DEMODEST ]; then
        DEMODEST=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "Enter the filename where you would like to save the database" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        else
            export DEMODEST
        fi
    fi
        
    DB_URL="http://files.xtuple.org/$VERSION/demo.backup"
    MD5_URL="http://files.xtuple.org/$VERSION/demo.backup.md5sum"
    
    dlf_fast $DB_URL "Downloading Demo Database. Please Wait." "$DEMODEST"
	dlf_fast $MD5_URL "Downloading MD5SUM. Please Wait." "$DEMODEST".md5sum
    
	VALID=`cat "$DEMODEST".md5sum | awk '{printf $1}'`
	CURRENT=`md5sum "$DEMODEST" | awk '{printf $1}'`
	if [ "$VALID" != "$CURRENT" ]; then
		msgbox "There was an verifying the downloaded database. Utility will now exit."
		exit
    else
        if (whiptail --title "Download Successful" --yesno "Download complete. Would you like to deploy this database now?." 10 60) then
            DEST=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -eq 1 ]; then
                return 0
            fi
            echo "Creating database $DEST from file $DEMODEST"
            restore_database $DEMODEST $DEST
            RET=$?
            if [ $RET -eq 1 ]; then
                msgbox "Something has gone wrong. Check output and correct any issues."
                do_exit
            else
                msgbox "Database $DEST successfully restored from file $DEMODEST"
                return 0
            fi
        else
            echo "Exiting without restoring database."
        fi
	fi
}

#  $1 is database file to backup to
#  $2 is name of new database (if not provided, prompt)
provision_database() {

    check_database_info
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    if [ -z $1 ]; then
        DEST=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "Full file name to save backup to" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        fi
    else
        DEST=$1
    fi
    
    if [ -z $2 ]; then
        SOURCE=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "Database name to back up" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        fi
    else
        SOURCE=$2
    fi
    
    echo "Backing up database "$SOURCE" to file "$DEST"."
    
    pg_dump --username "$PGUSER" --port "$PGPORT" --host "$PGHOST" --format custom  --file "$DEST" "$SOURCE"
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    else
        msgbox "Database $SOURCE successfully backed up to $DEST"
        return 0
    fi
}

#  $1 is database file to restore
#  $2 is name of new database (if not provided, prompt)
provision_restore() {

    check_database_info
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    if [ -z $2 ]; then
        DEST=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "New database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        fi
    else
        DEST=$2
    fi

    psql postgres -q -c "CREATE DATABASE "$DEST" OWNER admin"
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    else
        pg_restore --username "$PGUSER" --port "$PGPORT" --host "$PGHOST" --dbname "$DEST" "$1"
        RET=$?
        if [ $RET -eq 1 ]; then
            msgbox "Something has gone wrong. Check output and correct any issues."
            do_exit
        else
            return 0
        fi
    fi
}

pro_pilot() {

    check_database_info
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    SOURCE=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "Source database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    PILOT=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "Pilot database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?

    if [ $RET -eq 1 ]; then
        return $RET
    elif [ $RET -eq 0 ]; then
        echo "Creating pilot database $PILOT from database $SOURCE"
        psql postgres -q -c "CREATE DATABASE "$PILOT" TEMPLATE "$SOURCE" OWNER admin"
        RET=$?
        if [ $RET -eq 1 ]; then
            msgbox "Something has gone wrong. Check output and correct any issues."
            do_exit
        else
            msgbox "Database "$PILOT" has been created"
        fi
    fi
}

set_provision_info() {
    if [ -z $PGHOST ]; then
        PGHOST=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "Hostname" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        else
            export PGHOST
        fi
    fi
    if [ -z $PGPORT ] ; then
        PGPORT=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "Port" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        else
            export PGPORT
        fi
    fi
    if [ -z $PGUSER ] ; then
        PGUSER=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "Username" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        else
            export PGUSER
        fi
    fi
    if [ -z $PGPASSWORD ] ; then
        PGPASSWORD=$(whiptail --backtitle "xTuple Utility v$_REV" --passwordbox "Password" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        else
            export PGPASSWORD
        fi
    fi
}

check_provision_info() {
    if [ -z $PGHOST ] || [ -z $PGPORT ] || [ -z $PGUSER ] || [ -z $PGPASSWORD ]; then
		msgbox "Database information incomplete. You will be prompted for missing information now. You can skip this dialog in the future by setting the PGHOST, PGPORT, PGUSER, PGPASSWORD environment variables"
        set_database_info
        RET=$?
        return $RET
    else
		return 0
	fi
}


