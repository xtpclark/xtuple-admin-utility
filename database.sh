#!/bin/bash
# Copyright (c) 2014-2018 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

if [ -z "$DATABASE_SH" ] ; then # {
DATABASE_SH=true

database_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  log "Opened database menu"
  while true; do
    DBM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Database\ Menu )" 15 60  7 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Select a Database to work with" \
            "2" "Inspect Database"  \
            "3" "Rename Database"   \
            "4" "Copy database"     \
            "5" "Backup Database"   \
            "6" "Create Database"   \
            "7" "Drop Database"     \
            "8" "Setup Automated Backup" \
            "9" "Return to main menu" \
            3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET -ne 0 ]; then
      break
    else
      case "$DBM" in
          "1") select_database ;;
          "2") inspect_database_menu ;;
          "3") rename_database ;;
          "4") copy_database ;;
          "5") log_exec backup_database ;;
          "6") create_database ;;
          "7") drop_database ;;
          "8") source xtnbackup2/xtnbackup.sh ;;
          "9") main_menu ;;
            *) msgbox "How did you get here?" && break ;;
        esac
    fi
  done
}

# auto, (no prompt for demo location, delete when done)
# manual, prompt for location, don't delete
# $1 where to save database to
# $2 is version to grab
# $3 is type of database: empty, demo, manufacturing, distribution, masterref, ...
download_database() {
    echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

    local DESTFILE="$1"
    local DBVERSION="$2"
    local DBTYPE="${3:-$DBTYPE}"

    if [ -z "$DBVERSION" ]; then
        msgbox "Database version not specified."
        return 1
    fi

    DBTYPE="${DBTYPE:-demo}"

    if [ -z "$DESTFILE" ] && [ "$MODE" = "manual" ]; then
        DESTFILE=$(whiptail --backtitle "$( window_title )" --inputbox "Enter the filename where you would like to save the database" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    elif [ -z "$DESTFILE" ]; then
        return 127
    fi

    local DB_URL="http://files.xtuple.org/$DBVERSION/$DBTYPE.backup"
    local MD5_URL="http://files.xtuple.org/$DBVERSION/$DBTYPE.backup.md5sum"

    log "Saving $DB_URL as $DESTFILE."
    mkdir -p $(dirname $DESTFILE)
    if [ $MODE = "auto" ]; then
        dlf_fast_console $DB_URL "$DESTFILE"
        dlf_fast_console $MD5_URL "$DESTFILE".md5sum
    else
        dlf_fast $DB_URL  "Downloading $DBTYPE Database. Please Wait." "$DESTFILE"
        dlf_fast $MD5_URL "Downloading MD5SUM. Please Wait." "$DESTFILE".md5sum
    fi

    local VALID=$(cat "$DESTFILE".md5sum | awk '{printf $1}')
    local CURRENT=$(md5sum "$DESTFILE" | awk '{printf $1}')
    if [ "$VALID" != "$CURRENT" ]; then
        msgbox "There was an error verifying the downloaded database."
        return 1
    fi
}

# Copies database $1 to $2 by backing up $1 and restoring to $2
#  $1 is database to be copied
#  $2 is name of the new database
copy_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

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

  OLDDATABASE="$1"
  if [ -z "$OLDDATABASE" ] && [ "$MODE" = "manual" ]; then
    select_database
    if [ $RET -ne 0 ]; then
      return $RET
    fi

    OLDDATABASE="${DATABASE}"
  elif [ -z "$OLDDATABASE" ]; then
    return 127
  fi

  NEWDATABASE="$2"
  if [ -z "$NEWDATABASE" ] && [ "$MODE" = "manual" ]; then
    NEWDATABASE=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$NEWDATABASE" ]; then
    return 127
  fi

  log "Copying database "$OLDDATABASE" to "$NEWDATABASE"."

  backup_database "$OLDDATABASE-copy.backup" "$OLDDATABASE"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Backup of $OLDDATABASE failed."
    return $RET
  fi

  restore_database "$BACKUPDIR/$OLDDATABASE-copy.backup" "$NEWDATABASE"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Restore of $NEWDATABASE failed."
    return $RET
  else
    msgbox "Database $OLDDATABASE successfully copied up to $NEWDATABASE"
    return 0
  fi
}

#  $1 is database file to backup to
#  $2 is name of database (if not provided, prompt)
backup_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  DATABASE="$2"
  if [ -z "$DATABASE" ]; then
    select_database "Select database to back up"
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  fi

  DEST="$1"
  if [ -z "$DEST" ] && [ "$MODE" = "manual" ]; then
    DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Full file name to save backup to" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$DEST" ]; then
    return 127
  fi

  log "Backing up database "$DATABASE" to file "$DEST"."

  pg_dump --username "$PGUSER" --port "$PGPORT" --host "$PGHOST" --format custom  --file "$BACKUPDIR/$DEST" "$DATABASE"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Something has gone wrong. Check log and correct any issues."
    return $RET
  fi
  msgbox "Database $DATABASE successfully backed up to $DEST"
  return 0
}

# Either download and restore a new database
# or restore a local file
# This can not be run in automatic mode
create_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  [ "$MODE" = "auto" ] && return 127
  local BACKUPFILE=

  local DOWNLOADABLEDBS=()
  while read -r line ; do
    DOWNLOADABLEDBS+=("$line" "$line")
  done < <( curl http://files.xtuple.org/ | grep -oP '/\d\.\d\d?\.\d/' | sed 's#/\(.*\)/#Download \1#g' |  sort --version-sort -r | tr ' ' '_' )

  local EXISTINGDBS=()
  while read -r line ; do
    EXISTINGDBS+=("$line" "$line")
  done < <( ls -t "${DATABASEDIR}/*.backup" 2>/dev/null | tr ' ' '_' )

  local BACKUPDBS=()
  while read -r line ; do
    BACKUPDBS+=("$line" "$line")
  done < <( ls -t $BACKUPDIR 2>/dev/null | awk '{printf("Restore %s\n", $0)}' | tr ' ' '_' )
  CUSTOMDB=("EnterFileName..." "EnterFileName...")

  CHOICE=$(whiptail --backtitle "$(window_title)" --menu "Choose Database" 15 60 7 \
                    --cancel-button "Cancel" --ok-button "Select" --notags \
                    ${EXISTINGDBS[@]} \
                    ${BACKUPDBS[@]} \
                    ${CUSTOMDB[@]} \
                    ${DOWNLOADABLEDBS[@]} \
                    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  if echo $CHOICE | grep '^Download' ; then
    local DBVERSION=$(echo $CHOICE | grep -oP '\d\.\d\d?\.\d')
    local EDITIONS=()
    while read line ; do
      EDITIONS+=("$line" "$line")
    done < <( curl http://files.xtuple.org/$DBVERSION/ | grep -oP '>\K\S+.backup' | uniq )
    CHOICE=$(whiptail --backtitle "$( window_title )" --menu "Choose Starting Database" 15 60  7 \
                      --cancel-button "Cancel" --ok-button "Select" --notags \
                      ${EDITIONS[@]} \
                      3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi

    EDITION=$(echo $CHOICE | cut -f1 -d'.')
    BACKUPFILE="$DATABASEDIR/$DBVERSION/$EDITION.backup"
    download_database "$BACKUPFILE" "$DBVERSION" "$EDITION"

  elif echo $CHOICE | grep '^Backup db' ; then
    DATABASE=$(echo $CHOICE | sed 's/Backup db //')
    BACKUPFILE="$BACKUPDIR/$DATABASE"

  elif [ "$CHOICE" = "EnterFileName..." ]; then
    DATABASE=$(whiptail --backtitle "$( window_title )" --inputbox "Full Database Pathname" 8 60 $(pwd) 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
    BACKUPFILE="$DATABASE"

  else
    BACKUPFILE="$DATABASEDIR/$CHOICE"
  fi

  restore_database "$BACKUPFILE"
}

#  $1 is database file to restore
#  $2 is name of new database (if not provided, prompt)
restore_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

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
  if [ -z "$DATABASE" ] && [ "$MODE" = "manual" ]; then
    DATABASE=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$DATABASE" ]; then
      return 127
  fi

  service_start postgresql # just in case
  log "Creating database $DATABASE."
  log_exec createdb -h $PGHOST -p $PGPORT -U $PGUSER -O "admin" "$DATABASE"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Something has gone wrong. Check log and correct any issues."
    return $RET
  fi
  # XTDIR/lib/orm/source/create_{xt_schema,plv8}.sql but XTDIR isn't installed yet
  log_exec psql -qAt -U $PGUSER -h $PGHOST -p $PGPORT -d $DATABASE <<EOSCRIPT
    CREATE SCHEMA IF NOT EXISTS xt;
    GRANT ALL ON SCHEMA xt TO GROUP xtrole;
    CREATE OR REPLACE FUNCTION xt.js_init(debug BOOLEAN DEFAULT false, initialize BOOLEAN DEFAULT false)
    RETURNS VOID AS 'BEGIN RETURN; END;' LANGUAGE plpgsql;
    CREATE EXTENSION IF NOT EXISTS plv8;
EOSCRIPT
  log "Restoring database $DATABASE from file $1 on server $PGHOST:$PGPORT"
  pg_restore --username "$PGUSER" --port "$PGPORT" --host "$PGHOST" --dbname "$DATABASE" "$1" 2>restore_output.log
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "$(cat restore_output.log)"
    return $RET
  fi

  return 0
}

# select a database from the list on the currently selected cluster
# this can not be run in automatic mode
# the db name is in DATABASE
select_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local MSG="${1:-List of databases on this cluster}"

  [ "$MODE" = "auto" ] && return 127

  get_database_list

  if [ -z "$DATABASES" ]; then
    msgbox "No databases detected on this system"
    return 1
  fi

  DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "$MSG" 16 60  7 \
                      --notags "${DATABASES[@]}" 3>&1 1>&2 2>&3)
}

# $1 is name
# prompt if not provided
drop_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

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

  DATABASE="$1"
  if [ -z "$DATABASE" ] && [ "$MODE" = "manual" ]; then
    select_database "Select database to drop"
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi

    if (whiptail --title "Are you sure?" --yesno "Completely remove database $DATABASE?" 10 60) then
      backup_database "$BACKUPDIR/$DATABASE.$(date +%Y.%m.%d-%H:%M).backup" "$DATABASE"
      log_exec dropdb -U $PGUSER -h $PGHOST -p $PGPORT "$DATABASE"
      RET=$?
      if [ $RET -ne 0 ]; then
        msgbox "Dropping database $DATABASE failed. Please check the output and correct any issues."
        return $RET
      fi
      msgbox "Dropping database $DATABASE successful"
    else
      return 0
    fi
  elif [ -z "$DATABASE" ]; then
    return 127
  fi
}

# $1 is source
# $2 is new name
# prompt if not provided
rename_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  SOURCE="$1"
  if [ -z "$SOURCE" ] && [ "$MODE" = "manual" ]; then
    select_database "Select database to rename"
    if [ $RET -ne 0 ]; then
      return $RET
    fi
    SOURCE=$DATABASE
  elif [ -z "$SOURCE" ]; then
    return 127
  fi

  DEST="$2"
  if [ -z "$DEST" ] && [ "$MODE" = "manual" ]; then
    DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new name of database" 8 60 "" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$DEST" ]; then
    return 127
  fi

  log_exec psql -qAt -U $PGUSER -h $PGHOST -p $PGPORT -d postgres -c "ALTER DATABASE $SOURCE RENAME TO $DEST;"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Renaming database $SOURCE failed. Please check the output and correct any issues."
    return $RET
  fi
  msgbox "Successfully renamed database $SOURCE to $DEST"
}

# display a menu of databases on the currently configured cluster
# can not be run in automatic mode
inspect_database_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  [ "MODE" = "auto"] && return 127

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
      return $RET
  fi

  select_database
  RET=$?
  if [ $RET -ne 0 ]; then
    return 0
  fi

  inspect_database "$DATABASE"
}

# Get a list of databases on the currently configured cluster
# into the DATABASES array
get_database_list() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  check_database_info

  DATABASES=()
  while read -r line; do
    DATABASES+=("$line" "$line")
  done < <( psql -At -U $PGUSER -h $PGHOST -p $PGPORT -d postgres -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');" )
}

## remove, kill, and restore are used to stop new connections
##   to a database in order to allow dropping

# $1 is database name
remove_connect_priv() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    log_exec psql -At -U postgres -h $PGHOST -p $PGPORT -d postgres -c "REVOKE CONNECT ON DATABASE "$1" FROM public, admin, xtrole;"
}

# $1 is database name
kill_database_connections() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    log_exec psql -At -U postgres -h $PGHOST -p $PGPORT -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"$1"';"
}

# $1 is database name
restore_connect_priv() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    log_exec psql -At -U postgres -h $PGHOST -p $PGPORT -d postgres -c "GRANT CONNECT ON DATABASE "$1" TO public, admin, xtrole;"
}

# Display important metrics of an xTuple database in the current configured cluster
# $1 is database name to inspect
inspect_database() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    VAL=$(psql -At -U $PGUSER -h $PGHOST -p $PGPORT -d $1 -c "SELECT data FROM ( \
        SELECT 1,'Co: '||fetchmetrictext('remitto_name') AS data \
        UNION \
        SELECT 2,'Ap: '||fetchmetrictext('Application')||' v'||fetchmetrictext('ServerVersion') \
        UNION \
        SELECT 3,'Pk: '||pkghead_name||' v'||pkghead_version \
        FROM pkghead) as dummy ORDER BY 1;")

    msgbox "${VAL}"

}

# select a cluster that the functions in this file will use
# this can not be run in automatic mode, set the variables in script
set_database_info_select() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  [ "$MODE" = "auto" ] && return 127

  CLUSTERS=()

  while read -r line; do
    CLUSTERS+=("$line" "$line")
  done < <( sudo pg_lsclusters | tail -n +2 )

  if [ -z "$CLUSTERS" ]; then
    msgbox "No database clusters detected on this system."
    return
  fi

  while true; do
    CLUSTER=$(whiptail --title "xTuple Utility v$_REV" --menu "Select cluster to use" \
                       16 120  7 "${CLUSTERS[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
    break
  done

  eval $(awk '{ print "PGVER="    $1 ;
                print "POSTNAME=" $2 ;
                print "PGPORT="   $3 }' <<< "$CLUSTER")
  export PGVER POSTNAME PGPORT
  export PGHOST=localhost
  export PGUSER=postgres

  if [ -z "$PGVER" ] || [ -z "$POSTNAME" ] || [ -z "$PGPORT" ]; then
    msgbox "Could not determine database version or name"
    return 1
  fi
}


# set the current cluster by entering the parameters manually
# this can not be run in automatic mode
# TODO: dialog
set_database_info_manual() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  [ "$MODE" = "auto" ] && return 127

    if [ -z "$PGHOST" ]; then
        PGHOST=$(whiptail --backtitle "$( window_title )" --inputbox "Hostname" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            unset PGHOST && unset PGPORT && unset PGUSER
            return $RET
        else
            export PGHOST
        fi
    fi
    if [ -z "$PGPORT" ] ; then
        PGPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Port" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            unset PGHOST && unset PGPORT && unset PGUSER
            return $RET
        else
            export PGPORT
        fi
    fi
    if [ -z "$PGUSER" ] ; then
        PGUSER=$(whiptail --backtitle "$( window_title )" --inputbox "Username" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            unset PGHOST && unset PGPORT && unset PGUSER
            return $RET
        else
            export PGUSER
        fi
    fi


}

clear_database_info() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    unset PGHOST
    unset PGPORT
    unset PGUSER
}

# Check that there is a currently selected cluster
check_database_info() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  RET=0

  if [ -z "$PGHOST" ] || [ -z "$PGPORT" ] || [ -z "$PGUSER" ]; then
    whiptail --yes-button "Select Cluster" --no-button "Manually Enter"  \
             --yesno "Would you like to choose from installed clusters, or manually enter server information?" 10 60
    RET=$?
    if [ "$RET" -eq 0 ] ; then
      set_database_info_select
      RET=$?
    elif [ "$RET" -eq 255 ] ; then
      # we're using a yesno box as a multiple choice question - Yes/No/Cancel.
      # whiptail returns 255 on ESC => Cancel.
      return 255
    else
      set_database_info_manual
      RET=$?
    fi
  fi
  return $RET
}

# Upgrade an existing database to a Web-Enabled
# $1 is database
upgrade_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  DATABASE="$1"
  if [ -z "$DATABASE" ] && [ "$MODE" = "manual" ]; then
    select_database "Select database to upgrade"
    RET=$?
    if [ $RET -ne 0 ]; then
      return 0
    fi
  elif [ -z "$DATABASE" ]; then
    return 127
  fi

  psql -At -U $PGUSER -h $PGHOST -p $PGPORT -d $DATABASE -c "SELECT 1 FROM pkghead WHERE pkghead_name='xt';"
  if [ $? -ne 0 ]; then
    whiptail --title "Database not Web-Enabled" --yesno "The selected database is not currently web-enabled. If you continue, this process will update AND web-enable the database. If you prefer to not web-enable the database, exit xTuple Admin Utility and use the xTuple Updater app to apply the desired update package. Continue?" 10 60
    RET=$?
    if [ ${RET} -ne 0 ] ; then
      return 0
    fi
  else
    return 127
  fi

  # make sure plv8 is in
  log_exec psql -At -U ${PGUSER} -p ${PGPORT} -d $DATABASE -c "create EXTENSION IF NOT EXISTS plv8;"

  # find the instance name and version
  CONFIG_JS=$(find /etc/xtuple -name 'config.js' -exec grep -Pl "(?<=databases: \[\")$DATABASE" {} \; -exec grep -P "(?<=port: \[\")$PGPORT" {} \;)
  if [ -z "$CONFIG_JS" ]; then
    log "config.js not found. Skipping cleanup of old datasource."
    configure_nginx
  else
    MWCNAME=$(echo $CONFIG_JS | cut -d'/' -f5)
    BUILD_XT_TAG=$(echo $CONFIG_JS | cut -d'/' -f4)

    # shutdown node datasource
    service_stop xtuple-"$MWCNAME"

    # get the listening port for the node datasource
    MWCPORT=$(grep -Po '(?<= port: )8[0-9]{3}' /etc/xtuple/$BUILD_XT_TAG/$MWCNAME/config.js)
    if [ -z "$MWCPORT" ] && [ "$MODE" = "manual" ]; then
        MWCPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Web Client Port Number" 8 60 3>&1 1>&2 2>&3)
    elif [ -z "$MWCPORT" ]; then
        return 127
    fi
    NGINX_PORT=$MWCPORT

    log "Removing files in /etc/xtuple"
    log_exec sudo rm -rf /etc/xtuple/$BUILD_XT_TAG/$MWCNAME

    log "Removing files in /opt/xtuple"
    log_exec sudo rm -rf /opt/xtuple/$BUILD_XT_TAG/$MWCNAME

    log "Deleting systemd service file"
    log_exec sudo rm /etc/systemd/system/xtuple-$MWCNAME.service

    log "Completely removed previous mobile client installation"
  fi

  # install or update the mobile client
  ERP_DATABASE_NAME=$DATABASE
  install_mwc_menu

  # display results
  NEWVER=$(psql -At -U ${PGUSER} -p ${PGPORT} -d $DATABASE -c "SELECT fetchmetrictext('ServerVersion') AS application;")
  msgbox "Database $DATABASE\nVersion $NEWVER"
}

fi # }
