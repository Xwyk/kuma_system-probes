#!/bin/bash

# Parse options
while getopts ":d" opt; do
    case $opt in
        d) dry_run=1 ;;
        \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
    esac
done

# Check required environment variables
if [[ -z "$KUMA_URL" ]] || [[ -z "$KUMA_TOKEN" ]] || [[ -z "$CRITICAL_LIMIT" ]] || [[ -z "$MOUNT_POINT" ]]; then
    echo "Error: Missing required environment variables (KUMA_URL, KUMA_TOKEN, CRITICAL_LIMIT, MOUNT_POINT)"
    exit 1
fi

# récupération info stockage
DISK_USAGE=$(df -h "$MOUNT_POINT" | awk 'NR==2 {gsub("%",""); print $5}')
MSG="disk usage: ${DISK_USAGE}%"
STATUS="up"

# vérification seuils
if [ "$DISK_USAGE" -ge "$CRITICAL_LIMIT" ]; then
    STATUS="down"
    MSG="CRITICAL - $MSG"
fi

# encodage URL
MSG_ENC=$(echo "$MSG" | sed 's/%/%25/g;s/ /%20/g')

# push
if [ "${dry_run:-0}" -eq 1 ]; then
    echo "DISK : ${KUMA_URL}/api/push/${KUMA_TOKEN}?status=${STATUS}&msg=${MSG_ENC}&ping=${DISK_USAGE}"
else
    curl -s "${KUMA_URL}/api/push/${KUMA_TOKEN}?status=${STATUS}&msg=${MSG_ENC}&ping=${DISK_USAGE}" > /dev/null
fi
