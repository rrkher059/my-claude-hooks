#!/usr/bin/env bash
PAYLOAD=$(cat)
FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.path // empty')

if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
    if command -v prettier &> /dev/null; then
        prettier --write "$FILE_PATH" &> /dev/null
    fi
fi

exit 0
