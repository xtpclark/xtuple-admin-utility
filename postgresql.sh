#!/bin/bash

XTPG="/tmp/xtpg"
rm -rf $XTPG
mkdir -p $XTPG

postgresql_menu() {

    while true; do
        PGM=$(whiptail --backtitle "xTuple Utility v$_REV" --menu "PostgreSQL Menu" 15 60 7 --cancel-button "Exit" --ok-button "Select" \
            "1" "Install 9.3" \
            "2" "Remove 9.3" \
            "3" "Install 9.4" \
            "4" "Remove 9.4" \
            "5" "Prepare database for xTuple" \
            "6" "Reset passwords" \
            "7" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -eq 1 ]; then
            do_exit
        elif [ $RET -eq 0 ]; then
            case "$PGM" in
            "1") apt-get -y install postgresql-9.3 postgresql-client-9.3 postgresql-contrib-9.3;;
            "2") apt-get -y remove postgresql-9.3 postgresql-contrib-9.3 ;;
            "3") apt-get -y install postgresql-9.4 postgresql-client-9.4 postgresql-contrib-9.4;;
            "4") apt-get -y remove postgresql-9.4 postgresql-contrib-9.4 ;;
            "5") prepare_database ;;
            "6") password_menu ;;
            "7")  break ;;
            *) msgbox "Error 004. How did you get here?" && exit 0 ;;
            esac || postgresql_menu
        fi
    done

}

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
        return $RET
    fi
    
    echo "Deploying init.sql, creating admin user and xtrole group"
    psql -q -U postgres -d postgres -f $XTPG/init.sql
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Error deplying init.sql. Check for errors and try again"
        return $RET
    fi
    
    echo "Deploying extras.sql, creating extensions adminpack, pgcrypto, cube, earthdistance"
    psql -q -U postgres -d postgres -f $XTPG/extras.sql
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Error deplying extras.sql. Check for errors and try again"
        return $RET
    fi
    
    msgbox "Operations completed successfully"
    return 0;
}

password_menu() {

    while true; do
        PGM=$(whiptail --backtitle "xTuple Utility v$_REV" --menu "Reset Password Menu" 15 60 7 --cancel-button "Exit" --ok-button "Select" \
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
            "3") reset_sudo admin;;
            "4") reset_psql admin ;;
            "5") postgresql_menu ;;
            "6")  break ;;
            *) msgbox "Error 005. How did you get here?" && exit 0 ;;
            esac || postgresql_menu
        fi
    done

}

# $1 is user to reset
reset_sudo() {

    NEWPASS=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "New $1 password" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    echo "Resetting PostgreSQL password for user $1 using psql via su - postgres"
    
    su - postgres -c "psql -q -U postgres -d postgres -c \"alter user $1 with password '$NEWPASS';\""
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Looks like something went wrong resetting the password via sudo. Try using psql, or opening up pg_hba.conf"
        return $RET
    else
        msgbox "Password for user $1 successfully reset"
        return 0
    fi
    
}

# $1 is user to reset
reset_psql() {

    NEWPASS=$(whiptail --backtitle "xTuple Utility v$_REV" --inputbox "New $1 password" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -eq 1 ]; then
        return $RET
    fi
    
    echo "Resetting PostgreSQL password for user $1 using psql directly"
    
    psql -q -U postgres -d postgres -c \"alter user $1 with password '$NEWPASS';\"
    RET=$?
    if [ $RET -eq 1 ]; then
        msgbox "Looks like something went wrong resetting the password via psql. Try using sudo psql, or opening up pg_hba.conf"
        return $RET
    else
        msgbox "Password for user $1 successfully reset"
        return 0
    fi
    
}