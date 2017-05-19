#!/bin/bash

database_menu() {

    log "Opened database menu"

    while true; do
        DBM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Database\ Menu )" 15 60 8 --cancel-button "Cancel" --ok-button "Select" \
            "1" "List Databases" \
            "2" "Inspect Database" \
            "3" "Rename Database" \
			"4" "Copy database" \
            "5" "Backup Database" \
			"6" "Create Database" \
            "7" "Drop Database" \
            "8" "Upgrade xTuple Database" \
            "9" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?
        if [ $RET -ne 0 ]; then
            break
        else
            case "$DBM" in
            "1") log_exec list_databases ;;
            "2") inspect_database_menu ;;
            "3") rename_database ;;
			"4") copy_database ;;
            "5") log_exec backup_database ;;
			"6") create_database ;;
            "7") drop_database ;;
            "8") log_exec upgrade_database ;;
            "9") main_menu ;;
            *) msgbox "How did you get here?" && break ;;
            esac
        fi
    done
}

# $1 is mode, auto (no prompt for demo location, delete when done)
# manual, prompt for location, don't delete
# $2 where to save database to
# $3 is version to grab
# $4 is type of database to grab (empty, demo, manufacturing, distribution, masterref)
download_database() {

    MODE="${1:-$MODE}"
    MODE="${MODE:-manual}"

    DBVERSION="${3:-$DBVERSION}"

    DBTYPE="${4:-$DBTYPE}"
    DBTYPE="${DBTYPE:-demo}"

    if [ -z "$DBVERSION" ]; then
        MENUVER=$(whiptail --backtitle "$( window_title )" --menu "Choose Version" 15 60 7 --cancel-button "Cancel" --ok-button "Select" \
                "1" "PostBooks 4.9.5 Demo" \
                "2" "PostBooks 4.9.5 Empty" \
                "3" "PostBooks 4.9.5 QuickStart" \
                "4" "PostBooks 4.10.0 Demo" \
                "5" "PostBooks 4.10.0 Empty" \
                "6" "PostBooks 4.10.0 QuickStart" \
                "7" "Return to database menu" \
                3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -ne 0 ]; then
            return $RET
        else
            case "$MENUVER" in
            "1") DBVERSION=4.9.5
                   DBTYPE="demo"
                   ;;
            "2") DBVERSION=4.9.5
                   DBTYPE="empty"
                   ;;
            "3") DBVERSION=4.9.5
                   DBTYPE="quickstart"
                   ;;
            "4") DBVERSION=4.10.0
                   DBTYPE="demo"
                   ;;
            "5") DBVERSION=4.10.0
                   DBTYPE="empty"
                   ;;
            "6") DBVERSION=4.10.0
                   DBTYPE="quickstart"
                   ;;
            "7") return 0 ;;
            *) msgbox "How did you get here?" && return 1 ;;
            esac || return 1
        fi
	   DATABASE=${DBTYPE}${DBVERSION//./}
    fi

    if [ -z "$2" ]; then
        DEMODEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter the filename where you would like to save the database" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    else
        DEMODEST=$2
    fi

    DB_URL="http://files.xtuple.org/$DBVERSION/$DBTYPE.backup"
    MD5_URL="http://files.xtuple.org/$DBVERSION/$DBTYPE.backup.md5sum"

    log "Saving "$DB_URL" as "$DEMODEST"."
    if [ $MODE = "auto" ]; then
        dlf_fast_console $DB_URL "$DEMODEST"
        dlf_fast_console $MD5_URL "$DEMODEST".md5sum
    else
        dlf_fast $DB_URL "Downloading Demo Database. Please Wait." "$DEMODEST"
        dlf_fast $MD5_URL "Downloading MD5SUM. Please Wait." "$DEMODEST".md5sum
    fi

    VALID=`cat "$DEMODEST".md5sum | awk '{printf $1}'`
    CURRENT=`md5sum "$DEMODEST" | awk '{printf $1}'`
    if [ "$VALID" != "$CURRENT" ]; then
        msgbox "There was an error verifying the downloaded database."
        return 1
    fi

    # where is the auto option
    if [ $MODE = "manual" ]; then
        if (whiptail --title "Download Successful" --yesno "Download complete. Would you like to deploy this database now?" 10 60) then
            DEST=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -ne 0 ]; then
                return $RET
            fi

            log "Creating database $DEST from file $DEMODEST"
            log_exec restore_database $DEMODEST $DEST
            RET=$?
            if [ $RET -ne 0 ]; then
                msgbox "Something has gone wrong. Check log and correct any issues."
                return 1
            else
                msgbox "Database $DEST successfully restored from file $DEMODEST"
                return 0
            fi
        else
            log "Exiting without restoring database."
            return 0
        fi
    fi

}

#  $1 is database file to backup to
#  $2 is name of database (if not provided, prompt)
copy_database() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    get_database_list

    if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi


    OLDDATABASE="${1:-$OLDDATABASE}"
	if [ -z "$OLDDATABASE" ]; then
        OLDDATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to copy" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
	fi

    NEWDATABASE="${2:-$NEWDATABASE}"
    if [ -z "$NEWDATABASE" ]; then
        NEWDATABASE=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    fi

    log "Copying database "$OLDDATABASE" to "$NEWDATABASE"."

    backup_database "$OLDDATABASE-copy.backup" "$OLDDATABASE"
    restore_database "$BACKUPDIR/$OLDDATABASE-copy.backup" "$NEWDATABASE"
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    else
        msgbox "Database $OLDDATABASE successfully copied up to $NEWDATABASE"
        return 0
    fi
}

#  $1 is database file to backup to
#  $2 is name of database (if not provided, prompt)
backup_database() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    DATABASE="$2"
    if [ -z "$DATABASE" ]; then
        get_database_list

        if [ -z "$DATABASES" ]; then
            msgbox "No databases detected on this system"
            return 0
        fi

        DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to back up" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    fi

    if [ -z "$1" ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Full file name to save backup to" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    else
        DEST=$1
    fi

    log "Backing up database "$DATABASE" to file "$DEST"."

    pg_dump --username "$PGUSER" --port "$POSTPORT" --host "$PGHOST" --format custom  --file "$BACKUPDIR/$DEST" "$DATABASE"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Something has gone wrong. Check log and correct any issues."
        return $RET
    else
        msgbox "Database $DATABASE successfully backed up to $DEST"
        return 0
    fi
}

# Either download and restore a new database
# or restore a local file
create_database() {

    DOWNLOADABLEDBS=()
    while read -r line ; do
        DOWNLOADABLEDBS+=("$line" "$line")
    done < <( curl http://files.xtuple.org/ | grep -oP '/\d\.\d\d?\.\d/' | sed 's#/\(.*\)/#Download \1#g' |  sort --version-sort -r | tr ' ' '_' )
    EXISTINGDBS=()
    while read -r line ; do
        EXISTINGDBS+=("$line" "$line")
    done < <( ls -t "${DATABASEDIR}*.backup" | tr ' ' '_' )
    BACKUPDBS=()
    while read -r line ; do
	    BACKUPDBS+=("$line" "$line")
    done < <( ls -t $BACKUPDIR | awk '{printf("Restore %s\n", $0)}' | tr ' ' '_' )

    CHOICE=$(whiptail --backtitle "$( window_title )" --menu "Choose Database" 15 60 7 --cancel-button "Cancel" --ok-button "Select" --notags \
        ${DOWNLOADABLEDBS[@]} \
        ${EXISTINGDBS[@]} \
        ${BACKUPDBS[@]} \
        3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi
	
	echo $CHOICE | grep '^Download'
	if [ $? -eq 0 ]; then
	    DBVERSION=$(echo $CHOICE | grep -oP '\d\.\d\d?\.\d')
        EDITIONS=()
        while read line ; do
            EDITIONS+=("$line" "$line")
        done < <( curl http://files.xtuple.org/$DBVERSION/ | grep -oP '>\K\S+.backup' | uniq )
        CHOICE=$(whiptail --backtitle "$( window_title )" --menu "Choose Database Edition" 15 60 7 --cancel-button "Cancel" --ok-button "Select" --notags \
            ${EDITIONS[@]} \
            3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi

        EDITION=$(echo $CHOICE | cut -f1 -d'.')
	    download_database "auto" "$DATABASEDIR/$EDITION_$DBVERSION.backup" "$DBVERSION" "$EDITION"
        restore_database "$DATABASEDIR/$EDITION_$DBVERSION.backup"
	    return $?
	fi
	
	echo $CHOICE | grep '^Backup db'
	if [ $? -eq 0 ]; then
	    DATABASE=$(echo $CHOICE | sed 's/Backup db //')
	    restore_database "$BACKUPDIR/$DATABASE"
        return $?
	fi
	
	restore_database "$DATABASEDIR/$CHOICE"
	return $?

}

#  $1 is database file to restore
#  $2 is name of new database (if not provided, prompt)
restore_database() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    if [ -z "$1" ]; then
        msgbox "No filename provided."
        return 1
    fi

    DATABASE="$2"
    if [ -z "$DATABASE" ]; then
        DATABASE=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    fi

    log "Creating database $DATABASE."
    log_exec psql -h $PGHOST -p $POSTPORT -U $PGUSER -d postgres -q -c "CREATE DATABASE "$DATABASE" OWNER admin"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Something has gone wrong. Check log and correct any issues."
        return $RET
    else
        log "Restoring database $DATABASE from file $1 on server $PGHOST:$POSTPORT"
        log_exec pg_restore --username "$PGUSER" --port "$POSTPORT" --host "$PGHOST" --dbname "$DATABASE" "$1"
        RET=$?
        if [ $RET -ne 0 ]; then
            msgbox "Something has gone wrong. Check output and correct any issues."
            return $RET
        else
            return 0
        fi
    fi
}

list_databases() {

    get_database_list

    if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "List of databases on this cluster" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
}

# $1 is name
# prompt if not provided
drop_database() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    get_database_list

    if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to drop" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    if (whiptail --title "Are you sure?" --yesno "Completely remove database $DATABASE?" 10 60) then
        backup_database $DATABASE
        psql -qAt -U $PGUSER -h $PGHOST -p $POSTPORT -d postgres -c "DROP DATABASE $DATABASE;"
        RET=$?
        if [ $RET -ne 0 ]; then
            msgbox "Dropping database $DATABASE failed. Please check the output and correct any issues."
            return $RET
        else
            msgbox "Dropping database $DATABASE successful"
        fi
    else
        return 0
    fi

}

# $1 is source
# $2 is new name
# prompt if not provided
rename_database() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    get_database_list

    if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    SOURCE="${1:-$SOURCE}"
    if [ -z "$SOURCE" ]; then
        SOURCE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to rename" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    fi

    DEST="${2:-$DEST}"
    if [ -z "$DEST" ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new name of database" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    fi

    log_exec psql -qAt -U $PGUSER -h $PGHOST -p $POSTPORT -d postgres -c "ALTER DATABASE $SOURCE RENAME TO $DEST;"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Renaming database $SOURCE failed. Please check the output and correct any issues."
        return $RET
    else
        msgbox "Successfully renamed database $SOURCE to $DEST"
    fi

}

inspect_database_menu() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    get_database_list

    if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to inspect" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    fi

    inspect_database "$DATABASE"

}

get_database_list() {

    check_database_info

    DATABASES=()
    while read -r line; do
        DATABASES+=("$line" "$line")
    done < <( psql -At -U $PGUSER -h $PGHOST -p $POSTPORT -d postgres -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');" )
}

# $1 is database name
remove_connect_priv() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    log_exec psql -At -U postgres -h $PGHOST -p $POSTPORT -d postgres -c "REVOKE CONNECT ON DATABASE "$1" FROM public, admin, xtrole;"
}

# $1 is database name
kill_database_connections() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    log_exec psql -At -U postgres -h $PGHOST -p $POSTPORT -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"$1"';"
}

# $1 is database name
restore_connect_priv() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    log_exec psql -At -U postgres -h $PGHOST -p $POSTPORT -d postgres -c "GRANT CONNECT ON DATABASE "$1" TO public, admin, xtrole;"
}

# $1 is database name to inspect
inspect_database() {

    VAL=`psql -At -U $PGUSER -h $PGHOST -p $POSTPORT -d $1 -c "SELECT data FROM ( \
        SELECT 1,'Co: '||fetchmetrictext('remitto_name') AS data \
        UNION \
        SELECT 2,'Ap: '||fetchmetrictext('Application')||' v'||fetchmetrictext('ServerVersion') \
        UNION \
        SELECT 3,'Pk: '||pkghead_name||' v'||pkghead_version \
        FROM pkghead) as dummy ORDER BY 1;"`

    msgbox "${VAL}"

}

set_database_info_select() {
    CLUSTERS=()

    while read -r line; do 
        CLUSTERS+=("$line" "$line")
    done < <( sudo pg_lsclusters | tail -n +2 )

     if [ -z "$CLUSTERS" ]; then
        msgbox "No database clusters detected on this system"
        return 1
    fi

    CLUSTER=$(whiptail --title "xTuple Utility v$_REV" --menu "Select cluster to use" 16 120 5 "${CLUSTERS[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    if [ -z "$CLUSTER" ]; then
        msgbox "No database clusters detected on this system"
        return 1
    fi

    export POSTVER=`awk  '{print $1}' <<< "$CLUSTER"`
    export POSTNAME=`awk  '{print $2}' <<< "$CLUSTER"`
    export POSTPORT=`awk  '{print $3}' <<< "$CLUSTER"`
    export PGHOST=localhost
    export PGUSER=postgres

    PGPASSWORD=$(whiptail --backtitle "$( window_title )" --passwordbox "Enter postgres user password" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    else
        export PGPASSWORD
    fi

    if [ -z "$POSTVER" ] || [ -z "$POSTNAME" ] || [ -z "$POSTPORT" ]; then
        msgbox "Could not determine database version or name"
        return 0
    fi
}

set_database_info_manual() {

    if [ -z "$PGHOST" ]; then
        PGHOST=$(whiptail --backtitle "$( window_title )" --inputbox "Hostname" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            unset PGHOST && unset POSTPORT && unset PGUSER && unset PGPASSWORD
            return $RET
        else
            export PGHOST
        fi
    fi
    if [ -z "$POSTPORT" ] ; then
        POSTPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Port" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            unset PGHOST && unset POSTPORT && unset PGUSER && unset PGPASSWORD
            return $RET
        else
            export POSTPORT
        fi
    fi
    if [ -z "$PGUSER" ] ; then
        PGUSER=$(whiptail --backtitle "$( window_title )" --inputbox "Username" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            unset PGHOST && unset POSTPORT && unset PGUSER && unset PGPASSWORD
            return $RET
        else
            export PGUSER
        fi
    fi
    if [ -z "$PGPASSWORD" ] ; then
        PGPASSWORD=$(whiptail --backtitle "$( window_title )" --passwordbox "Password" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            unset PGHOST && unset POSTPORT && unset PGUSER && unset PGPASSWORD
            return $RET
        else
            export PGPASSWORD
        fi
    fi

}

clear_database_info() {
    unset PGHOST
    unset PGPASSWORD
    unset POSTPORT
    unset PGUSER
}

check_database_info() {
    if [ -z "$PGHOST" ] || [ -z "$POSTPORT" ] || [ -z "$PGUSER" ]; then
        if (whiptail --yes-button "Select Cluster" --no-button "Manually Enter"  --yesno "Would you like to choose from installed clusters, or manually enter server information?" 10 60) then
            set_database_info_select
            RET=$?
            return $RET
        else
            # I specifically need to check for ESC here as I am using the yesno box as a multiple choice question, 
            # so it chooses no code even during escape which in this case I want to actually escape when someone hits escape. 
            if [ $? -eq 255 ]; then
                return 255
            fi
            set_database_info_manual
            RET=$?
            return $RET
        fi
    else
        return 0
    fi
}

# $1 is database
upgrade_database() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    get_database_list

    if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to upgrade" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    fi

    psql -At -U $PGUSER -h $PGHOST -p $POSTPORT -d $DATABASE -c "SELECT pkghead_name FROM pkghead WHERE pkghead_name='xt';"
	if [ $? -ne 0 ]; then
        if ! (whiptail --title "Database not Web-Enabled" --yesno "Your database is not currently web-enabled. To keep it that way, do not use xTAU to update your database. Instead, get the xTuple Updater app and apply the desired update package. If you continue the update in xTAU, it will update AND web-enable the database. Continue?" 10 60) then
            return 0
        fi
    fi

    # make sure plv8 is in
    log_exec psql -At -U ${PGUSER} -p ${POSTPORT} -d $DATABASE -c "create EXTENSION IF NOT EXISTS plv8;"

    # find the instance name and version
    CONFIG_JS=$(find /etc/xtuple -name 'config.js' -exec grep -Pl '(?<=databases: \[")first_web' {} \;)
    if [ -z "$CONFIG_JS" ]; then
        # no installation exists, just skip to installation
        log "config.js not found. Skipping cleanup of old datasource."
    else
        MWCNAME=$(echo $CONFIG_JS | cut -d'/' -f4)
        MWCVERSION=$(echo $CONFIG_JS | cut -d'/' -f5)
    
        # shutdown node datasource
        if [ $DISTRO = "ubuntu" ]; then
            case "$CODENAME" in
                "trusty") ;&
                "utopic")
                    log_exec sudo service xtuple-"$MWCNAME" stop
                    ;;
                "vivid") ;&
                "xenial")
                    log_exec sudo systemctl stop xtuple-"$MWCNAME".service
                    log_exec sudo systemctl disable xtuple-"$MWCNAME".service
                    ;;
            esac
        elif [ $DISTRO = "debian" ]; then
            case "$CODENAME" in
                "wheezy")
                    log_exec sudo /etc/init.d/xtuple-"$MWCNAME" stop
                    ;;
                "jessie")
                    log_exec sudo systemctl stop xtuple-"$MWCNAME".service
                    log_exec sudo systemctl disable xtuple-"$MWCNAME".service
                    ;;
            esac
        else
            log "Seriously? We made it all the way to where I need to start the server and suddenly I can't detect your distro -> $DISTRO codename -> $CODENAME"
            do_exit
        fi

        # get the listening port for the node datasource
        MWCPORT=$(grep -Po "(?<= port: )[0-9]{4}" /etc/xtuple/4.10.1/first_web/config.js)
        # find nginx site
        NGINX_SITE_FILE=$(grep -Pl "127.0.0.1:$MWCPORT" /etc/nginx/sites-available/*)
        if [ -z "$NGINX_SITE_FILE" ]; then
            log "No nginx site file found. Skipping removal."
        else
            # get the site name
            NGINX_SITE=$(echo "$NGINX_SITE_FILE" | cut -d'/' -f5)
            # delete nginx site
            log_exec sudo rm /etc/nginx/sites-available/$NGINX_SITE
            log_exec sudo rm /etc/nginx/sites-enabled/$NGINX_SITE
            log "Nginx site \"$NGINX_SITE\" removed."
        fi
        
        log "Removing files in /etc/xtuple"
        log_exec sudo rm -rf /etc/xtuple/$MWCVERSION/$MWCNAME

        log "Removing files in /opt/xtuple"
        log_exec sudo rm -rf /opt/xtuple/$MWCVERSION/$MWCNAME

        log "Deleting systemd service file"
        log_exec sudo rm /etc/systemd/system/xtuple-$MWCNAME.service

        log "Completely removed previous mobile client installation"
    fi

    # install or update the mobile client
    PGDATABASE=$DATABASE
    install_mwc_menu

    # display results
    NEWVER=`psql -At -U ${PGUSER} -p ${POSTPORT} -d $DATABASE -c "SELECT fetchmetrictext('ServerVersion') AS application;"`
    msgbox "Database $DATABASE\nVersion $NEWVER"
}
