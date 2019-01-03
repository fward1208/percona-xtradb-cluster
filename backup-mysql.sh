#!/bin/bash

export LC_ALL=C

days_of_backups=14
parent_dir="${PWD}/backups"
todays_dir="${parent_dir}/$(date +%F)"
log_file="${todays_dir}/backup-progress.log"
touch $log_file
now="$(date +%m-%d-%Y_%H-%M-%S)"
processors="$(nproc --all)"

# Use this to echo to standard error
error () {
    printf "%s: %s\n" "$(basename "${BASH_SOURCE}")" "${1}" >&2
    exit 1
}

trap 'error "An unexpected error occurred."' ERR

set_options () {
    # List the xtrabackup arguments
    xtrabackup_args=(
        "--host=${HOST}"
        "--user=${MYSQL_USER}"
        "--password=${MYSQL_ROOT_PASSWORD}"
        "--backup"
        "--extra-lsndir=${todays_dir}"
        "--compress"
        "--stream=xbstream"
        "--parallel=${processors}"
        "--compress-threads=${processors}"
        "--slave-info"
    )

    backup_type="full"

    # Add option to read LSN (log sequence number) if a full backup has been
    # taken today.
    if grep -q -s "to_lsn" "${todays_dir}/xtrabackup_checkpoints"; then
        backup_type="incremental"
        lsn=$(awk '/to_lsn/ {print $3;}' "${todays_dir}/xtrabackup_checkpoints")
        xtrabackup_args+=( "--incremental-lsn=${lsn}" )
    fi
}

rotate_old () {
    # Remove the oldest backup in rotation
    day_dir_to_remove="${parent_dir}/$(date --date="${days_of_backups} days ago" +%F)"

    if [ -d "${day_dir_to_remove}" ]; then
        rm -rf "${day_dir_to_remove}"
    fi
}

take_backup () {
    # Make sure today's backup directory is available and take the actual backup
    mkdir -p "${todays_dir}"
    find "${todays_dir}" -type f -name "*.incomplete" -delete
    xtrabackup "${xtrabackup_args[@]}" --target-dir="${todays_dir}" > "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" 2> "${log_file}"

    mv "${todays_dir}/${backup_type}-${now}.xbstream.incomplete" "${todays_dir}/${backup_type}-${now}.xbstream"
}

sync_backup () {
    if [ -e ~/.mc/config.json ]; then
        mc mirror --remove --overwrite "${parent_dir}"/ "${MINIO_BUCKET}"
    fi

set_options && rotate_old && take_backup && sync_backup

# Check success and print message
if tail -1 "${log_file}" | grep -q "completed OK"; then
    printf "Backup successful!\n"
    printf "Backup created at %s/%s-%s.xbstream\n" "${todays_dir}" "${backup_type}" "${now}"
else
    error "Backup failure! Check ${log_file} for more information"
fi
