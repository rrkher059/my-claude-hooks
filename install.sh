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
echo "IMPORTANT: this script does NOT modify ~/.claude/settings.json for you."
echo "Merge the JSON below into your global settings.json by hand (do not"
echo "overwrite the file directly - other settings may already live there)."
echo ""
echo "WARNING: PreToolUse hooks apply to EVERY project you use Claude Code in,"
echo "not just this repo. Before merging the PreToolUse block below, pipe-test"
echo "protect-files.py standalone against a few payloads to make sure it"
echo "behaves as expected, e.g.:"
echo "    cat some_payload.json | python3 ~/.claude/hooks/protect-files.py"
echo "A bad global PreToolUse hook can block edits across all your projects,"
echo "so verify it before wiring it in."
echo ""
echo "To activate globally, add the following to your ~/.claude/settings.json:"
echo '------------------------------------------------------------------'
cat << 'JSON'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/concise-prompt.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/protect-files.py" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/auto-format.sh" }
        ]
      }
    ]
  }
}
JSON
echo '------------------------------------------------------------------'
