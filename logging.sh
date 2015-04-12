#!/bin/bash

LOG_FILE=$(pwd)/install-$DATE.log

log_exec() {
   "$@" | tee -a $LOG_FILE 2>&1
   RET=$?
   return $RET
}

log() {
    echo "$( timestamp ) xtuple >> $@"
    echo "$( timestamp ) xtuple >> $@" >> $LOG_FILE
}

timestamp() {
  date +"%T"
}

datetime() {
  date +"%D %T"
}

log "Logging initialized. Current session will be logged to $LOG_FILE"