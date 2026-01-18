#!/bin/bash

# Parse options
while getopts ":d" opt; do
    case $opt in
        d) dry_run=1 ;;
        \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
    esac
done

# Check required environment variables
if [[ -z "$KUMA_URL" ]] || [[ -z "$KUMA_TOKEN" ]] || [[ -z "$COMMAND" ]] || [[ -z "$EXPECTED_VALUE" ]]; then
    echo "Error: Missing required environment variables (KUMA_URL, KUMA_TOKEN, COMMAND, EXPECTED_VALUE)"
    exit 1
fi

# Execute command and extract result
if [[ -n "$GREP_PATTERN" ]]; then
    # Use grep pattern if provided
    RESULT=$(eval "$COMMAND" 2>/dev/null | grep -i "$GREP_PATTERN" | awk '{print $2}')
else
    # Execute command directly
    RESULT=$(eval "$COMMAND" 2>/dev/null)
fi

# Remove whitespace
RESULT=$(echo "$RESULT" | xargs)

MSG="command result: $RESULT"
STATUS="up"

# Check if result matches expected value
if [[ "$RESULT" != "$EXPECTED_VALUE" ]]; then
    STATUS="down"
    MSG="CRITICAL - expected '$EXPECTED_VALUE', got '$RESULT'"
fi

# URL encode message
MSG_ENC=$(echo "$MSG" | sed 's/%/%25/g;s/ /%20/g;s/:/%3A/g;s/,/%2C/g')

# Push to Kuma
if [ "${dry_run:-0}" -eq 1 ]; then
    echo "CMD : ${KUMA_URL}/api/push/${KUMA_TOKEN}?status=${STATUS}&msg=${MSG_ENC}&ping="
else
    curl -s "${KUMA_URL}/api/push/${KUMA_TOKEN}?status=${STATUS}&msg=${MSG_ENC}&ping=" > /dev/null
fi
