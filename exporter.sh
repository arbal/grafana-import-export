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
    echo "search for dashboards..."

    #debug
    #echo "$(fetch_fields $KEY 'search?query=&' 'url')"
    #echo "$(curl -sSL -f -k -H "Authorization: Bearer $KEY" "${HOST}/api/search?query=&" | jq -r "if type==\"array\" then .[] else . end" | jq '.uid,.uri' | paste -d" " - - )"
    #echo "$(curl -sSL -f -k -H "Authorization: Bearer $KEY" "${HOST}/api/search?query=&" | jq -r "if type==\"array\" then .[] else . end" )"

    readarray dashboards_info < <( fetch_fields $KEY 'search?query=&' 'uid,.uri' | paste -d" " - - )

    #echo "${dashboards_info[@]}"
    #exit 0

    #for dash in $(fetch_fields $KEY 'search?query=&' 'uri'); do
    for dashboard_info in "${dashboards_info[@]}"; do
        echo "$dashboard_info"
        db_uid=$(echo "$dashboard_info" | cut -d" " -f 1)
        db_file=${db_uid}_"$(echo "$dashboard_info" | cut -d" " -f 2 | sed 's|db/||g').json"
        echo "DashBoard ${db_file} (${db_uid})"
        #curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/dashboards/${dash}" | jq 'del(.overwrite,.dashboard.version,.meta.created,.meta.createdBy,.meta.updated,.meta.updatedBy,.meta.expires,.meta.version)' > "$DIR/dashboards/$DB"
        #added setting .dashboard.uid and .dashboard.id to NULL to allow Grafana to create new dashboard
        #curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/dashboards/${dash}" | jq '.dashboard.uid |= null | .dashboard.id |= null | del(.overwrite,.dashboard.version,.meta.created,.meta.createdBy ,.meta.updated,.meta.updatedBy,.meta.expires,.meta.version)' > "$DIR/dashboards/$DB"

        #added setting .dashboard.uid and .dashboard.id to NULL to allow Grafana to create new dashboard
        #changed to uid download
        curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/dashboards/uid/${db_uid}" | \
         jq '.dashboard.uid |= null | .dashboard.id |= null |
             del(.overwrite,.dashboard.version,.meta.created,.meta.createdBy ,.meta.updated,.meta.updatedBy,.meta.expires,.meta.version)' \
         > "$DIR/dashboards/${db_file}"
        ls -l "$DIR/dashboards/${db_file}"

    done

    #echo DataSources
    #mkdir -p "$DIR/datasources"
    #for id in $(fetch_fields $KEY 'datasources' 'id'); do
    #    DS=$(echo $(fetch_fields $KEY "datasources/${id}" 'name')|sed 's/ /-/g').json
    #    echo DataSource $DS
    #    curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/datasources/${id}" | jq '' > "$DIR/datasources/${id}.json"
    #done

    #echo Alert-Notifications
    #mkdir -p "$DIR/alert-notifications"
    #for id in $(fetch_fields $KEY 'alert-notifications' 'id'); do
    #    FILENAME=${id}.json
    #    echo alert-notification $FILENAME
    #    curl -f -k -H "Authorization: Bearer ${KEY}" "${HOST}/api/alert-notifications/${id}" | jq 'del(.created,.updated)' > "$DIR/alert-notifications/$FILENAME"
    #done

    BackupDir=$(dirname "$DIR")
    #echo BackupDir ${BackupDir}
    cd "$BackupDir"
    Backup_File=$(basename "$DIR")
    Backup_Name="${Backup_File}_$(date '+%Y%m%d_%H%M%S').tgz"
    #echo Backup_Name "${Backup_Name}"
    tar -czf "$Backup_Name" "$Backup_File"
    ls -lh "$BackupDir/$Backup_Name"
    tar -tvf "$BackupDir/$Backup_Name"
done