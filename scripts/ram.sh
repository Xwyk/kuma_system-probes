#!/bin/bash

# Parse options
while getopts ":d" opt; do
    case $opt in
        d) dry_run=1 ;;
        \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
    esac
done

# Check required environment variables
if [[ -z "$KUMA_URL" ]] || [[ -z "$KUMA_TOKEN" ]] || [[ -z "$CRITICAL_LIMIT" ]]; then
    echo "Error: Missing required environment variables (KUMA_URL, KUMA_TOKEN, CRITICAL_LIMIT)"
    exit 1
fi

RAM_USAGE=$(free | awk '/Mem:/ {printf "%.1f", 100-($7/$2*100)}')

STATUS="up"
MSG="ram usage: ${RAM_USAGE}%"

if awk "BEGIN {exit !($RAM_USAGE >= $CRITICAL_LIMIT)}"; then
  STATUS="down"
  MSG="CRITICAL - $MSG"
fi

MSG_ENC=$(echo "$MSG" | sed 's/%/%25/g;s/ /%20/g')

if [ "${dry_run:-0}" -eq 1 ]; then
  echo "RAM : ${KUMA_URL}/api/push/${KUMA_TOKEN}?status=${STATUS}&msg=${MSG_ENC}&ping=${RAM_USAGE}"
else
  curl -s "${KUMA_URL}/api/push/${KUMA_TOKEN}?status=${STATUS}&msg=${MSG_ENC}&ping=${RAM_USAGE}" > /dev/null
fi
