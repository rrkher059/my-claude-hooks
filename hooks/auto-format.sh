#!/usr/bin/env bash
# PostToolUse hook (Edit|Write): format the file that was just written.
# Never blocks the tool-use loop - always exits 0, even on formatter failure.

PAYLOAD=$(cat)
FILE_PATH=$(echo "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [ -n "$FILE_PATH" ] && [ -f "$FILE_PATH" ]; then
    case "$FILE_PATH" in
        *.py)
            if command -v ruff &> /dev/null; then
                ruff format "$FILE_PATH" &> /dev/null
            fi
            ;;
        *)
            if command -v prettier &> /dev/null; then
                prettier --write "$FILE_PATH" &> /dev/null
            fi
            ;;
    esac
fi

exit 0
