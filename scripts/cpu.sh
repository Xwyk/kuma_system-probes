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
CPU_LINE1=($(head -n1 /proc/stat))
IDLE1=${CPU_LINE1[4]}
TOTAL1=0
for V in "${CPU_LINE1[@]:1}"; do TOTAL1=$((TOTAL1 + V)); done

sleep 1

CPU_LINE2=($(head -n1 /proc/stat))
IDLE2=${CPU_LINE2[4]}
TOTAL2=0
for V in "${CPU_LINE2[@]:1}"; do TOTAL2=$((TOTAL2 + V)); done

DIFF_IDLE=$((IDLE2 - IDLE1))
DIFF_TOTAL=$((TOTAL2 - TOTAL1))

CPU_USAGE=$(awk "BEGIN{printf \"%.1f\", ($DIFF_TOTAL - $DIFF_IDLE)/$DIFF_TOTAL*100}")
MSG="cpu usage: $CPU_USAGE%"
STATUS="up"

if awk "BEGIN {exit !($CPU_USAGE >= $CRITICAL_LIMIT)}"; then
  STATUS="down"
  MSG="CRITICAL - $MSG"
fi

MSG_ENC=$(echo "$MSG" | sed 's/%/%25/g;s/ /%20/g')

if [ "${dry_run:-0}" -eq 1 ]; then
  echo "CPU : ${KUMA_URL}/${KUMA_TOKEN}?status=${STATUS}&msg=${MSG_ENC}&ping=${CPU_USAGE}"
else
  curl -s "${KUMA_URL}/${KUMA_TOKEN}?status=${STATUS}&msg=${MSG_ENC}&ping=${CPU_USAGE}" > /dev/null
fi
