#!/usr/bin/env bash

# Usage:
# cd /opt/prometheus/grafana-exporter
# ./importer.sh                                         #will import all stored in ${FILE_DIR}
# ./importer.sh Organization/dashboards/hpe-msa.json    #will import hpe-msa.json from ${FILE_DIR}/Organization/dashboards

MyDir=$(dirname "$0")
. "${MyDir}/config.sh"


declare -aa ORGMAP
for row in "${ORGS[@]}"; do
    IFS=':' read -r -a values <<< "$row"
    ORGMAP[${values[0]}]=${values[1]}
done

curl_wrap() {
    FILE=$1
    KEY=$2
    URL=$3
    HTTP_VERB=$4
    [[ -z "$HTTP_VERB" ]] && HTTP_VERB=POST

    curl --fail -k -X$HTTP_VERB \
         -H "Content-Type: application/json" \
         -H "Accept: application/json" \
         -H "Authorization: Bearer $KEY" \
         --data-binary @$FILE \
         $URL
}

import_file() {
    FILE="$1"
    KEY="$2"
    TYPE="$3"

    if ! [ -f "$FILE" ]; then
        echo "$FILE not found." >>/dev/stderr
        return
    fi

    echo "Processing $FILE file..."
    curl_wrap "$FILE" "$KEY" "${HOST}/api/$TYPE"
    CURL_EXIT=$?
    echo

    if [[ ${CURL_EXIT} = 22 && $TYPE = "datasources" ]]; then
        echo "409 conflict error is normal. Retrying as update."
        id=$(basename $file .json)
        curl_wrap "$FILE" "$KEY" "${HOST}/api/$TYPE/$id" PUT
    elif [[ ${CURL_EXIT} = 22 && $TYPE = "alert-notifications" ]]; then
        echo "500 server error is normal. Retrying as update."
        id=$(basename $file .json)
        curl_wrap "$FILE" "$KEY" "${HOST}/api/$TYPE/$id" PUT
    fi
}


cd "${FILE_DIR}"
if [[ $# -eq 0 ]]; then
    ARGS=(*/*/*.json)
else
    ARGS=("$@")
fi

for FILE in "${ARGS[@]}"; do

    IFS='/' read -r -a args <<< "$FILE"
    if [ ${#args[@]} -ne 3 ]; then
        echo "Wrong param \"${FILE}\". Must be data/{organization}/{type}/{file}"
    fi

    KEY=${ORGMAP[${args[0]}]}
    TYPE=${args[1]}
    # FILE=${args[2]}

    echo $TYPE

    case $TYPE in
    alert-notifications)
        import_file $FILE "$KEY" 'alert-notifications'
        ;;
    dashboards)
        import_file $FILE "$KEY" 'dashboards/db'
        ;;
    datasources)
        import_file $FILE "$KEY" 'datasources'
        ;;
    *)
        echo "Unknown type $TYPE"
        ;;
    esac
done