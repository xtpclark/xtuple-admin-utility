#!/bin/bash
XTMP="/tmp/xtdb"

rm -rf $XTMP
mkdir -p $XTMP
cd $XTMP

database_menu() {
    while true; do
        DBM=$(whiptail --backtitle "xTuple Server v$_REV" --menu "Database Menu" 15 60 6 --cancel-button "Return" --ok-button "Select" \
            "1" "Set database info" \
            "2" "Backup Database" \
            "3" "Create Pilot Database" \
            "4" "Download Latest Demo Database" \
            "5" "Exit" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            break
        elif [ $RET -eq 0 ]; then
            case "$DBM" in
            "1") database_info ;;
            "2") backup_database ;;
            "3") carve_pilot ;;
            "4") download_demo ;;
            "5") do_exit ;;
            *) msgbox "Error 002. Please report on GitHub" && exit 0 ;;
            esac || msgbox "I don't know how you got here! >> $DBM <<  Report on GitHub"
        fi
    done
}

download_demo() {
    
    VERSION=$(latest_version db)
    
    if [ -z $VERSION ]; then
        msgbox "Could not determine latest database version"
        exit
    fi
    
    DB_URL="http://files.xtuple.org/$VERSION/demo.backup"
    MD5_URL="http://files.xtuple.org/$VERSION/demo.backup.md5sum"
    
    dlf_fast $DB_URL "Downloading Demo Database. Please Wait." $XTMP/demo.backup
	dlf_fast $MD5_URL "Downloading MD5SUM. Please Wait." $XTMP/demo.backup.md5sum
    
	VALID=`cat $XTMP/demo.backup.md5sum | awk '{printf $1}'`
	CURRENT=`md5sum $XTMP/demo.backup | awk '{printf $1}'`
	if [ "$VALID" != "$CURRENT" ]; then
		msgbox "There was an verifying the downloaded database. Utility will now exit."
		exit
    else
        if (whiptail --title "Download Successful" --yesno "Download complete. Would you like to deploy this database now?." 10 60) then
            restore_database $XTMP/demo.backup
        else
            echo "You chose No. Exit status was $?."
        fi
	fi
}
#  $1 is database file to restore
restore_database() {

    check_database_info
    
    DEST=$(whiptail --backtitle "xTuple Server v$_REV" --inputbox "New database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
    
    if [ $RET -eq 1 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    elif [ $RET -eq 0 ]; then
        echo "Creating new database $DEST from database file "$1""
        psql postgres -c "CREATE DATABASE "$DEST" OWNER admin"
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
                msgbox "Database file "$1" successfully restored to database "$DEST"."
            fi
        fi
    fi
}

database_info() {
    if [ -z $PGHOST ]; then
        export PGHOST=$(whiptail --backtitle "xTuple Server v$_REV" --inputbox "Hostname" 8 60 "$CH" 3>&1 1>&2 2>&3)
    elif [ -z $PGPORT ] ; then
        export PGPORT=$(whiptail --backtitle "xTuple Server v$_REV" --inputbox "Port" 8 60 "$CH" 3>&1 1>&2 2>&3)
    elif [ -z $PGUSER ] ; then
        export PGUSER=$(whiptail --backtitle "xTuple Server v$_REV" --inputbox "Username" 8 60 "$CH" 3>&1 1>&2 2>&3)
    elif [ -z $PGPASSWORD ] ; then
        export PGPASSWORD=$(whiptail --backtitle "xTuple Server v$_REV" --passwordbox "Password" 8 60 3>&1 1>&2 2>&3)
    fi
}

carve_pilot() {

    check_database_info
    
    SOURCE=$(whiptail --backtitle "xTuple Server v$_REV" --inputbox "Source database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
    PILOT=$(whiptail --backtitle "xTuple Server v$_REV" --inputbox "Pilot database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
    
    RET=$?
        
    if [ $RET -eq 1 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    elif [ $RET -eq 0 ]; then
        echo "Creating pilot database $PILOT from database $SOURCE"
        psql postgres -c "CREATE DATABASE "$PILOT" TEMPLATE "$SOURCE" OWNER admin"
        RET=$?
        if [ $RET -eq 1 ]; then
            msgbox "Something has gone wrong. Check output and correct any issues."
            do_exit
        else
            msgbox "Database "$PILOT" has been created"
        fi
    fi
    
}

check_database_info() {
    if [ -z $PGHOST ] || [ -z $PGPORT ] || [ -z $PGUSER ] || [ -z $PGPASSWORD ]; then
		msgbox "Database information incomplete. Please set database information before continuing. "
        #database_menu
        database_info
        return 0
    else
		return 0
	fi
}


