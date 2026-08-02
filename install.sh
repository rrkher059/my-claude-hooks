#!/usr/bin/env bash
set -e

HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing hooks to $HOOKS_DIR..."
cp -f "$SCRIPT_DIR/hooks/"* "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/"*

echo ""
echo "Successfully copied hook scripts!"
echo ""
echo "To activate globally, add the following to your ~/.claude/settings.json:"
echo '------------------------------------------------------------------'
cat << 'JSON'
{
  "hooks": {
    "UserPromptSubmit": [{ "command": "~/.claude/hooks/concise-prompt.sh" }],
    "PreToolUse": [{ "matcher": "Edit|Write", "command": "~/.claude/hooks/protect-files.py" }],
    "PostToolUse": [{ "matcher": "Edit|Write", "command": "~/.claude/hooks/auto-format.sh" }]
  }
}
JSON
echo '------------------------------------------------------------------'
