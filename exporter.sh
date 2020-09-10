#!/usr/bin/env bash
. "$(dirname "$0")/config.sh"

fetch_fields() {
    curl -sSL -f -k -H "Authorization: Bearer ${1}" "${HOST}/api/${2}" | jq -r "if type==\"array\" then .[] else . end| .${3}"
}

for row in "${ORGS[@]}" ; do
    ORG=${row%%:*}
    KEY=${row#*:}
    DIR="$FILE_DIR/$ORG"

    echo DashBoards
    mkdir -p "$DIR/dashboards"
    for dash in $(fetch_fields $KEY 'search?query=&' 'uri'); do
        DB=$(echo ${dash}|sed 's,db/,,g').json
        echo DashBoard $DB
        curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/dashboards/${dash}" | jq 'del(.overwrite,.dashboard.version,.meta.created,.meta.createdBy,.meta.updated,.meta.updatedBy,.meta.expires,.meta.version)' > "$DIR/dashboards/$DB"
    done

    echo DataSources
    mkdir -p "$DIR/datasources"
    for id in $(fetch_fields $KEY 'datasources' 'id'); do
        DS=$(echo $(fetch_fields $KEY "datasources/${id}" 'name')|sed 's/ /-/g').json
        echo DataSource $DS
        curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/datasources/${id}" | jq '' > "$DIR/datasources/${id}.json"
    done

    echo Alert-Notifications
    mkdir -p "$DIR/alert-notifications"
    for id in $(fetch_fields $KEY 'alert-notifications' 'id'); do
        FILENAME=${id}.json
        echo alert-notification $FILENAME
        curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/alert-notifications/${id}" | jq 'del(.created,.updated)' > "$DIR/alert-notifications/$FILENAME"
    done

    BackupDir=$(dirname "$DIR")
    cd "$BackupDir"
    Backup_File=$(basename "$DIR")
    Backup_Name="${Backup_File}_$(date '+%Y%m%d_%H%M%S').tgz"
    tar -czf "$Backup_Name" "$Backup_File"
    ls -lh "$BackupDir/$Backup_Name"
    tar -tvf "$BackupDir/$Backup_Name"
done
