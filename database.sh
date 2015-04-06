#!/bin/bash
XTMP="/tmp/xtdb"

rm -rf $XTMP
mkdir -p $XTMP

database_menu() {
    while true; do
        DBM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Database\ Menu )" 15 60 8 --cancel-button "Exit" --ok-button "Select" \
            "1" "Set database info" \
            "2" "Clear database info" \
            "3" "Backup Database" \
            "4" "List Databases" \
            "5" "Rename Database" \
            "6" "Drop Database" \
            "7" "Carve Pilot From Existing Database" \
            "8" "Create Database From File" \
            "9" "Download Latest Demo Database" \
            "10" "Download Specific Database" \
            "11" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            do_exit
        elif [ $RET -eq 0 ]; then
            case "$DBM" in
            "1") set_database_info ;;
            "2") clear_database_info ;;
            "3") backup_database ;;
            "4") list_databases ;;
            "5") rename_database_menu ;;
            "6") drop_database_menu ;;
            "7") carve_pilot ;;
            "8") create_database_from_file ;;
            "9") download_latest_demo ;;
            "10") download_demo ;;
            "11") main_menu ;;
            *) msgbox "How did you get here?" && exit 0 ;;
            esac || database_menu
        fi
    done
}

# $1 is mode, auto (no prompt for demo location, delete when done) 
# manual, prompt for location, don't delete
download_demo() {
    
    if [ -z $1 ]; then
        MODE="manual"
    else
        MODE="auto"
    fi
         
    MENUVER=$(whiptail --backtitle "$( window_title )" --menu "Choose Version" 15 60 7 --cancel-button "Exit" --ok-button "Select" \
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
            *) msgbox "How did you get here?" && exit 0 ;;
            esac || database_menu
        fi
    
    if [ $MODE = "manual" ]; then
        DEMODEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter the filename where you would like to save the database" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        fi
    elif [ $MODE = "auto" ]; then
        DEMODEST=$XTMP/$VERSION-$DBTYPE.backup
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
        if [ $MODE = "manual" ]; then
            if (whiptail --title "Download Successful" --yesno "Download complete. Would you like to deploy this database now?." 10 60) then
                DEST=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
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
        elif [ $MODE = "auto" ]; then
            restore_database $DEMODEST $DEST
            RET=$?
            if [ $RET -eq 1 ]; then
                msgbox "Something has gone wrong. Check output and correct any issues."
                rm $DEMODEST
                do_exit
            else
                return 0
            fi
        fi
	fi
}

download_latest_demo() {
    
    VERSION=$(latest_version db)
    
    if [ -z $VERSION ]; then
        msgbox "Could not determine latest database version"
        do_exit
    fi
    
    if [ -z $DEMODEST ]; then
        DEMODEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter the filename where you would like to save the database" 8 60 3>&1 1>&2 2>&3)
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
            DEST=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -eq 1 ]; then
                return 0
            fi
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
backup_database() {

    check_database_info
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    if [ -z $1 ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Full file name to save backup to" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        fi
    else
        DEST=$1
    fi
    
    if [ -z $2 ]; then
        SOURCE=$(whiptail --backtitle "$( window_title )" --inputbox "Database name to back up" 8 60 3>&1 1>&2 2>&3)
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
restore_database() {

    check_database_info
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    fi
    
    if [ -z $2 ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        fi
    else
        DEST=$2
    fi
    echo "Creating database $DEST."
    psql postgres -q -c "CREATE DATABASE "$DEST" OWNER admin"
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    else
        echo "Restoring database $DEST from file $1 on server $PGHOST:$PGPORT"
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

# $1 is source
# $2 is new pilot
# prompt if not provided
carve_pilot() {

    check_database_info
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    if [ -z "$1" ]; then
        DATABASES=()

        while read -r line; do
            DATABASES+=("$line" "$line")
         done < <( su - postgres -c "psql --tuples-only -P format=unaligned -c \"SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');\"" )
         if [ -z "$DATABASES" ]; then
            msgbox "No databases detected on this system"
            return 0
        fi
        
        SOURCE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to use as source for pilot" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        SOURCE="$1"
    fi

    if [ -z "$2" ]; then
        PILOT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new name of database" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        PILOT="$2"
    fi

    echo "Creating pilot database $PILOT from database $SOURCE"
    su - postgres -c "psql postgres -q -p $PGPORT -c \"CREATE DATABASE \"$PILOT\" TEMPLATE \"$SOURCE\" OWNER admin;\""
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    else
        msgbox "Database "$PILOT" has been created"
    fi
}

create_database_from_file() {

    check_database_info
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    SOURCE=$(whiptail --backtitle "$( window_title )" --inputbox "Enter source backup filename" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    if [ ! -f $SOURCE ]; then
        msgbox "File "$SOURCE" not found!"
        return 1
    fi
    
    PILOT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?
        
    if [ $RET -eq 1 ]; then
        return $RET
    elif [ $RET -eq 0 ]; then
        echo "Creating database $PILOT from file $SOURCE"
        restore_database $SOURCE $PILOT
        RET=$?
        if [ $RET -eq 1 ]; then
            msgbox "Something has gone wrong. Check output and correct any issues."
            do_exit
        else
            msgbox "Database "$PILOT" has been created"
        fi
    fi
    
}

list_databases() {

    check_database_info

    DATABASES=()

    while read -r line; do
        DATABASES+=("$line" "$line")
    #done < <( su - postgres -c "psql -l -t | cut -d'|' -f1 | sed -e 's/ //g' -e '/^$/d'" )
     done < <( su - postgres -c "psql --tuples-only -P format=unaligned -c \"SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');\"" )
     if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    #msgbox "`su - postgres -c "psql -l -t | cut -d'|' -f1 | sed -e 's/ //g' -e '/^$/d'"`"

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "List of databases on this cluster" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
}

drop_database_menu() {

    check_database_info

    DATABASES=()

    while read -r line; do
        DATABASES+=("$line" "$line")
    #done < <( su - postgres -c "psql -l -t | cut -d'|' -f1 | sed -e 's/ //g' -e '/^$/d'" )
     done < <( su - postgres -c "psql --tuples-only -P format=unaligned -c \"SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');\"" )
     if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi
    
    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to drop" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    fi
    
    drop_database "$DATABASE"
    
}

# $1 is name
# prompt if not provided
drop_database() {

    check_database_info
    
    if [ -z "$1" ]; then
        POSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter name of database to drop" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        POSTNAME="$1"
    fi
	
    if (whiptail --title "Are you sure?" --yesno "Completely remove database $POSTNAME?" --yes-button "No" --no-button "Yes" 10 60) then
        return 0
    fi

    su - postgres -c "psql -q -c \"DROP DATABASE $POSTNAME;\""
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Dropping database $POSTNAME failed. Please check the output and correct any issues."
        do_exit
    else
        msgbox "Dropping database $POSTNAME successful"
    fi
    
}

rename_database_menu() {

    check_database_info

    DATABASES=()

    while read -r line; do
        DATABASES+=("$line" "$line")
     done < <( su - postgres -c "psql --tuples-only -P format=unaligned -c \"SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');\"" )
     if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi
    
    SOURCE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to rename" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    fi
    
    DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new database name" 8 60 "" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return 0
    fi
    
    rename_database "$SOURCE" "$DEST"
    
}

# $1 is source
# $2 is new name
# prompt if not provided
rename_database() {

    if [ -z "$1" ]; then
        SOURCE=$(whiptail --backtitle "$( window_title )" --inputbox "Enter name of database to rename" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        SOURCE="$1"
    fi

    if [ -z "$2" ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new name of database" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi
    else
        DEST="$2"
    fi

    su - postgres -c "psql -q -c \"ALTER DATABASE $SOURCE RENAME TO $DEST;\""
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Renaming database $SOURCE failed. Please check the output and correct any issues."
        do_exit
    else
        msgbox "Successfully renamed database $SOURCE to $DEST"
    fi
    
}

set_database_info() {

    if (whiptail --title "xTuple Utility v$_REV" --yes-button "Select Cluster" --no-button "Manually Enter"  --yesno "Would you like to choose from installed clusters, or manually enter server information?" 10 60) then
        CLUSTERS=()
        
        while read -r line; do 
            CLUSTERS+=("$line" "$line")
        done < <( pg_lsclusters | tail -n +2 )

         if [ -z "$CLUSTERS" ]; then
            msgbox "No database clusters detected on this system"
            return 0
        fi
        
        CLUSTER=$(whiptail --title "xTuple Utility v$_REV" --menu "Select cluster to use" 16 120 5 "${CLUSTERS[@]}" --notags 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return 0
        fi

        if [ -z "$CLUSTER" ]; then
            msgbox "No database clusters detected on this system"
            return 0
        fi
        
        export PGVER=`awk  '{print $1}' <<< "$CLUSTER"`
        export PGNAME=`awk  '{print $2}' <<< "$CLUSTER"`
        export PGPORT=`awk  '{print $3}' <<< "$CLUSTER"`
        export PGHOST=localhost
        export PGUSER=postgres
        
        PGPASSWORD=$(whiptail --backtitle "$( window_title )" --passwordbox "Enter postgres user password" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -eq 1 ]; then
            return $RET
        else
            export PGPASSWORD
        fi
        
        if [ -z "$PGVER" ] || [ -z "$PGNAME" ] || [ -z "$PGPORT" ]; then
            msgbox "Could not determine database version or name"
            return 0
        fi
    else
        if [ -z $PGHOST ]; then
            PGHOST=$(whiptail --backtitle "$( window_title )" --inputbox "Hostname" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -eq 1 ]; then
                return $RET
            else
                export PGHOST
            fi
        fi
        if [ -z $PGPORT ] ; then
            PGPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Port" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -eq 1 ]; then
                return $RET
            else
                export PGPORT
            fi
        fi
        if [ -z $PGUSER ] ; then
            PGUSER=$(whiptail --backtitle "$( window_title )" --inputbox "Username" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -eq 1 ]; then
                return $RET
            else
                export PGUSER
            fi
        fi
        if [ -z $PGPASSWORD ] ; then
            PGPASSWORD=$(whiptail --backtitle "$( window_title )" --passwordbox "Password" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -eq 1 ]; then
                return $RET
            else
                export PGPASSWORD
            fi
        fi
    fi
}

clear_database_info() {
    unset PGHOST
    unset PGPASSWORD
    unset PGPORT
    unset PGUSER
}

check_database_info() {
    if [ -z $PGHOST ] || [ -z $PGPORT ] || [ -z $PGUSER ] || [ -z $PGPASSWORD ]; then
        set_database_info
        RET=$?
        return $RET
    else
		return 0
	fi
}
