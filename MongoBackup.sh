#!/bin/bash
#
# MongoDB Backup Tool
# Copyright (c) 2017 Alexey Baikov <sysboss[@]mail.ru>
#
# Description: Backing up MongoDB to S3 Bucket
# GitHub: https://github.com/sysboss/mongodb_backup

##########################
# Required Configuration #
##########################
# General
  WORKDIR="/home/ubuntu"
  BACKUP_DIR="${WORKDIR}/backups"
# MongoDB Connector
  MONGO_HOST="localhost"
  MONGO_PORT=27017
  MONGO_DATABASE=
  MONGO_USERNAME=
  MONGO_PASSWORD=
# Backup behavior
  STORE_LOCAL_COPIES=0
  S3_BUCKET_NAME=
  S3_BUCKET_PATH=
  UPLOAD_RETRIES=3

# Other defaults
  FILE_NAME_FORMAT="mongodump_"`date '+%F-%H%M'`".dump"
  LOCKFILE="${BACKUP_DIR}/.mongobackup.lock"
  LOGFILE="${BACKUP_DIR}/mongobackup.log"
  REQUIRED_TOOLS="mongodump aws tar"


##########################
# Functions              #
##########################
function usage {
cat << EOF
MongoDB Backup Tool
Copyright (c) 2017 Alexey Baikov <sysboss[@]mail.ru>

usage: $0 options

OPTIONS:
    -b    AWS S3 Bucket Name
    -k    Keep local copies (default: 0)
    -r    AWS S3 Region (optional)
    -p    Path / Folder inside the bucket (optional)

EOF
}

while getopts “ht:k:b:p:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    k)
      STORE_LOCAL_COPIES=$OPTARG
      ;;
    r)
      S3_REGION=$OPTARG
      ;;
    b)
      S3_BUCKET_NAME=$OPTARG
      ;;
    p)
      S3_BUCKET_PATH=$OPTARG
      ;;
    ?)
      usage
      exit
    ;;
  esac
done

# options
if [ -z ${S3_REGION} ] || [ -z ${S3_BUCKET_NAME} ] || [ -z ${S3_BUCKET_PATH} ]; then
  usage
  exit 1
fi

function die {
    echo $@
    exit 126
}

function lock {
    LOCK_FD=2
    local fd=${200:-$LOCK_FD}

    # create lock file
    eval "exec $fd>$LOCKFILE"

    # acquier the lock
    flock -n $fd \
        && return 0 \
        || return 1
}

function unlock {
    rm -f $LOCKFILE
}

function getDateTime {
    echo $(date '+%F-%H%M')
}

function logToFile {
    exec > $LOGFILE
    exec 2>&1
}

function log {
    local msg=$1
    local lvl=${2:-"INFO"}

    if ! which printf > /dev/null; then
        echo "$(getDateTime)   $lvl  $msg" #| tee -a ${LOGFILE}
    else
        printf "%15s  %5s  %s\n" "$(getDateTime)" "$lvl" "$msg"
    fi
}

function cleanup {
    local lvl=$1

    # release lock
    unlock

    if [ "${BACKUP_DIR}/${FILE_NAME_FORMAT}" != "" ]; then
        rm -fr "${BACKUP_DIR}/${FILE_NAME_FORMAT}"
    fi

    # unlock database writes
    runCommand mongo admin --eval "printjson(db.fsyncUnlock())"
    log "Database is unlocked"

    if [ "$lvl" != "" ]; then
        log "Aborting backup" "$lvl"
        exit 2
    fi
}

function runCommand {
    "$@"
    exitCode=$?

    if [ $exitCode -ne 0 ]; then
        log "Failed to execute: $1 command ($exitCode)" "ERROR"
        cleanup "ERROR"
        exit 2
    fi
}

# setup trap function
function sigHandler {
    if type cleanup | grep -i function > /dev/null; then
        trap "cleanup KILL" HUP TERM INT
    else
        echo "ERROR: cleanup function is not defined"
        exit 127
    fi
}

# Create directories and files
mkdir -p "${BACKUP_DIR}"
touch ${LOGFILE}

# verify no other backup is running
lock || die "Only one backup instance can run at a time"

# interrupts handler
sigHandler

# log to file
#[ -f "${LOGFILE}" ] && logToFile

# verify all tools installed
for i in ${REQUIRED_TOOLS}; do
    if ! which $i > /dev/null; then
        die "ERROR: $i is required."
    fi
done

# log start time
log "Starting MongoDB Backup"

# force file sync to disk and lock writes
log "Lock database writes"
runCommand mongo admin --eval "printjson(db.fsyncLock())"

log "Taking database dump into backup directory"

if [ "${MONGO_DATABASE}" != "" ]; then
    mongodump -h $MONGO_HOST:$MONGO_PORT -d $MONGO_DATABASE -o ${BACKUP_DIR}/${FILE_NAME_FORMAT}
else
    mongodump -h $MONGO_HOST:$MONGO_PORT -o ${BACKUP_DIR}/${FILE_NAME_FORMAT}
fi

log "Creating compressed archive of backup directory"
tar -zcvf "${BACKUP_DIR}/${FILE_NAME_FORMAT}.tar.gz" -C "${BACKUP_DIR}/" .

# do some cleanup
# and release locks
cleanup

log "Backup complete"

