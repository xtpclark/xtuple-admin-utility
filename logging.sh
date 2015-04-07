#!/bin/bash

LOG_FILE=$(pwd)/install-$DATE.log

log_exec() {
   "$@" | tee -a $LOG_FILE 2>&1
   RET=$?
   return $RET
}

log() {
    echo "xtuple >> $@"
    echo "xtuple >> $@" >> $LOG_FILE
}

log "Logging initialized. Current session will be logged to $LOG_FILE"