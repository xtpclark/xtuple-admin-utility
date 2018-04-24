#!/bin/bash

postgresql_menu() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    log "Opened PostgreSQL menu"

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title PostgreSQL\ Menu )" 0 0 10 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Install PostgreSQL $PGVER" \
            "2" "List provisioned clusters" \
            "3" "Select Cluster" \
            "4" "Create new cluster" \
            "5" "Backup Globals" \
            "6" "Restore Globals" \
            "7" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?
        if [ $RET -ne 0 ]; then
            # instead of exiting, bring us back to the previous menu. Will capture escape and other cancels. 
            break
        elif [ $RET -eq 0 ]; then
            case "$PGM" in
            "1") log_exec install_postgresql $PGVER ;;
            "2") log_exec list_clusters ;;
            "3") log_exec select_cluster ;;
            "4") log_exec provision_cluster ;;
            "5") log_exec backup_globals ;;
            "6") log_exec restore_globals ;;
            "7") break ;;
            *) msgbox "Error. How did you get here?" && break ;;
            esac
        fi
    done

}

password_menu() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    log "Opened password menu"

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Reset\ Password\ Menu )" 0 0 10 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Reset postgres via sudo postgres" \
            "2" "Reset postgres via psql" \
            "3" "Reset admin via sudo postgres" \
            "4" "Reset admin via psql" \
            "5" "Return to previous menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -ne 0 ]; then
            break
        elif [ $RET -eq 0 ]; then
            case "$PGM" in
            "1") reset_sudo postgres ;;
            "2") reset_psql postgres ;;
            "3") reset_sudo admin ;;
            "4") reset_psql admin ;;
            "5") break ;;
            *) msgbox "How did you get here?" && exit 0 ;;
            esac
        fi
    done

}

# $1 is pg version (9.3, 9.4, etc)
install_postgresql() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  PGVER="${1:-$PGVER}"

  sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  sudo apt-get --quiet -y update
  log_exec sudo apt-get --quiet -y install postgresql-common

  # Let's not install the main cluster by default just to drop it...
  sudo sed -i -e s/'#create_main_cluster = true'/'create_main_cluster = false'/g /etc/postgresql-common/createcluster.conf

  log_exec sudo apt-get --quiet -y install postgresql-$PGVER postgresql-client-$PGVER postgresql-contrib-$PGVER postgresql-server-dev-$PGVER
  RET=$?
  if [ $RET -eq 0 ]; then
    export PGUSER=postgres
    export PGHOST=localhost
    export PGPORT=5432
  fi

  install_plv8
}

install_plv8() {
  local STARTDIR=$(pwd)
  cd "${WORKDIR}"
  wget http://updates.xtuple.com/updates/plv8/linux64/xtuple_plv8.tgz
  tar xf xtuple_plv8.tgz
  cd xtuple_plv8
  log_exec echo '' | sudo ./install_plv8.sh || die
  cd "${WORKDIR}"
  rm -f xtuple_plv8.tgz
  cd "${STARTDIR}"
}

# $1 is pg version (9.3, 9.4, etc)
# we don't remove -client because we still need it for managment tasks
remove_postgresql() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    PGVER="${1:-$PGVER}"
    if (whiptail --title "Are you sure?" --yesno "Uninstall PostgreSQL $PGVER? Cluster data will be left behind." --yes-button "Yes" --no-button "No" 10 60) then
        log "Uninstalling PostgreSQL "$PGVER"..."
        log_exec sudo apt-get --quiet -y remove postgresql-$PGVER postgresql-contrib-$PGVER postgresql-$PGVER-plv8 postgresql-server-dev-$PGVER
        RET=$?
        return $RET
    else
        return 0
    fi

}

# $1 is pg version (9.3, 9.4, etc)
# we don't remove -client because we still need it for managment tasks
purge_postgresql() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    PGVER="${1:-$PGVER}"
    if (whiptail --title "Are you sure?" --yesno "Completely remove PostgreSQL $PGVER and all of the cluster data?" --yes-button "Yes" --no-button "No" 10 60) then
        log "Purging PostgreSQL "$PGVER"..."
        log_exec sudo apt-get --quiet -y purge postgresql-$PGVER postgresql-contrib-$PGVER postgresql-$PGVER-plv8
        RET=$?
        return $RET
    else
        return 0
    fi

}

get_cluster_list() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    CLUSTERS=()
    
    while read -r line; do 
        CLUSTERS+=("$line" "$line")
    done < <( sudo pg_lsclusters | tail -n +2 )

}

list_clusters() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    get_cluster_list

    if [ -z "$CLUSTERS" ]; then
        msgbox "No database clusters detected on this system"
        return 0
    fi

    msgbox "`sudo pg_lsclusters`"

}

# $1 is postgresql version
# $2 is cluster name
# $3 is port
# $4 is locale
# $5 if exists, start at boot
provision_cluster() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]} $@"
  install_plv8

  PGVER="${1:-$PGVER}"
  local POSTNAME="$2"
  PGPORT="$3"
  local POSTLOCALE="${4:-$POSTLOCALE}"
  local POSTSTART="${5:-$POSTSTART}"

  if [ -z "$PGVER" ] && [ "$MODE" = "manual" ]; then
    PGVER=$(whiptail --backtitle "$( window_title )" --inputbox "Enter PostgreSQL Version (make sure it is installed!)" 8 60 "$PGVER" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return 0
    fi
  fi

  local CLUSTERS="$(sudo pg_lsclusters -h | \
                    awk '{ print "Existing Clusters:" $2 }
                     END { if (!NR) print "No Existing Clusters" }')"
  local ERRMSG=
  while [ -z "$POSTNAME" ] && [ "$MODE" = "manual" ] ; do
    POSTNAME=$(whiptail --backtitle "$( window_title )" \
                       --inputbox "${ERRMSG}Enter Cluster Name\n\n$CLUSTERS" 15 60 "xtuple" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return 0
    fi

    sudo pg_lsclusters -h | awk '{print $2}' | grep $POSTNAME 2>&1 > /dev/null
    if [ "$?" -ne 0 ]; then
      break
    fi
    ERRMSG="$POSTNAME already exists.\n"
    log $ERRMSG
    POSTNAME=
  done

  ERRMSG=
  while [ -z "$PGPORT" ] && [ "$MODE" = "manual" ] ; do
    new_postgres_port
    PGPORT=$(whiptail --backtitle "$( window_title )" --inputbox "${ERRMSG}Enter Database Port" 8 60 "$PGPORT" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return 0
    fi

    sudo pg_lsclusters -h | awk '{print $3}' | grep $PGPORT 2>&1 > /dev/null
    if [ "$?" -ne 0 ]; then
      break;
    fi
    ERRMSG="$PGPORT is already in use\n"
    log $ERRMSG
    PGPORT=
  done

  if [ -z "$POSTLOCALE" ] && [ "$MODE" = "manual" ]; then
    POSTLOCALE=$(whiptail --backtitle "$( window_title )" --inputbox "Enter Locale" 8 60 "$LANG" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return 0
    fi
  fi

  if [ -z "$POSTSTART" ] && [ "$MODE" = "manual" ]; then
    if (whiptail --title "Autostart" --yes-button "Yes" --no-button "No"  --yesno "Would you like the cluster to start at boot?" 10 60) then
      POSTSTART="--start-conf=auto"
    else
      POSTSTART=""
    fi
  fi

  setup_postgresql_cluster "$PGVER" "$POSTNAME" "$PGPORT" "$POSTLOCALE" "$POSTSTART"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Creation of PostgreSQL cluster failed. Please check the output and correct any issues."
    do_exit
  fi
}

select_cluster() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  set_database_info_select
}

# $1 is version
# $2 is name
# $3 is mode (auto/manual)
# prompt if not provided
drop_cluster() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    PGVER="${1:-$PGVER}"
    POSTAME="${2:-$POSTNAME}"
    MODE="${3:-$MODE}"
    MODE="${MODE:-manual}"

    if [ $MODE = "manual" ]; then
        if [ -z "$PGVER" ]; then
            PGVER=$(whiptail --backtitle "$( window_title )" --inputbox "Enter version of cluster to remove" 8 60 "" 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -ne 0 ]; then
                return 0
            fi
        fi

        if [ -z "$POSTNAME" ]; then
            POSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter name of cluster to remove" 8 60 "" 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -ne 0 ]; then
                return 0
            fi
        fi

        if (whiptail --title "Are you sure?" --yesno "Completely remove cluster $POSTNAME - $PGVER?" --yes-button "No" --no-button "Yes" 10 60) then
            return 0
        fi
    fi

    log "Dropping PostgreSQL cluster $POSTNAME version $PGVER"

   # We do not want to drop ANY CLUSTERS.  Either modify what is there for plv8/pg_hba.conf or CREATE new.
  # log_exec sudo su - postgres -c "pg_dropcluster --stop $PGVER $POSTNAME"
true
    RET=$?
    if [ $MODE = "manual" ]; then
        if [ $RET -ne 0 ]; then
            msgbox "Dropping PostgreSQL cluster failed. Please check the output and correct any issues."
            do_exit
        else
            msgbox "Dropping PostgreSQL cluster $POSTNAME version $PGVER completed successfully."
        fi
    fi
    return $RET
}

drop_cluster_menu() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    CLUSTERS=()

    while read -r line; do 
        CLUSTERS+=("$line" "$line")
    done < <( sudo pg_lsclusters | tail -n +2 )

     if [ -z "$CLUSTERS" ]; then
        msgbox "No database clusters detected on this system"
        return 0
    fi

    CLUSTER=$(whiptail --title "PostgreSQL Clusters" --menu "Select cluster to drop" 16 120 10 "${CLUSTERS[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
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

    log_exec drop_cluster "$VER" "$NAME"

}

# $1 is user to reset
reset_sudo() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    NEWPASS=$(whiptail --backtitle "$( window_title )" --passwordbox "New $1 password" 8 60  3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    fi

    log "Resetting PostgreSQL password for user $1 using psql via su - postgres"

    log_exec psql -qAt -U $PGUSER -h $PGHOST -p $PGPORT -d postgres -c "ALTER USER $1 WITH PASSWORD '$NEWPASS';"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Looks like something went wrong resetting the password via sudo. Try using psql, or opening up pg_hba.conf"
        return 0
    else
        export PGUSER=$1
        msgbox "Password for user $1 successfully reset"
        return 0
    fi

}

# $1 is user to reset
reset_psql() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    NEWPASS=$(whiptail --backtitle "$( window_title )" --passwordbox "New $1 password" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    fi
    
    log "Resetting PostgreSQL password for user $1 using psql directly"
    
    log_exec psql -q -h $PGHOST -U postgres -d postgres -p $PGPORT -c "ALTER USER $1 WITH PASSWORD '$NEWPASS';"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Looks like something went wrong resetting the password via psql. Try using sudo psql, or opening up pg_hba.conf"
        return 0
    else
        export PGUSER=$1
        msgbox "Password for user $1 successfully reset"
        return 0
    fi
    
}

#  $1 is globals file to backup to
backup_globals() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    if [ -z "$1" ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Full file name to save globals to" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    else
        DEST=$1
    fi
    
    log "Backing up globals to file "$DEST"."

    log_exec pg_dumpall --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --database "postgres" --no-password --file "$DEST" --globals-only
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    else
        msgbox "Globals successfully backed up to $DEST"
        return 0
    fi
}

#  $1 is globals file to restore
restore_globals() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    fi

    if [ -z "$1" ]; then
        SOURCE=$(whiptail --backtitle "$( window_title )" --inputbox "Full file name to globals file" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    else
        SOURCE=$1
    fi

    log "Restoring globals from file $SOURCE"

    log_exec psql -h $PGHOST -p $PGPORT -U $PGUSER -d postgres -q -f "$SOURCE"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    else
        msgbox "Globals successfully restored."
        return 0
    fi
}
