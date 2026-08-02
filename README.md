# my-claude-hooks

Deterministic, local lifecycle hooks for the [Claude Code](https://claude.com/claude-code) CLI.

These are small, dependency-light scripts that Claude Code invokes at specific
points in its tool-use lifecycle (before a prompt is sent, before a tool
runs, after a tool runs). They don't call any LLM themselves — they're plain
shell/Python that inspect the JSON payload Claude Code passes on stdin and
either pass through, modify the environment, or block the action
deterministically via exit codes.

## Hooks

| Hook | Event | Matcher | What it does |
|---|---|---|---|
| `hooks/concise-prompt.sh` | `UserPromptSubmit` | (all) | Prints a directive telling Claude to be concise, direct, and practical. Runs on every prompt submission. |
| `hooks/protect-files.py` | `PreToolUse` | `Edit\|Write` | Reads `tool_input.file_path` from the payload and blocks edits/writes to sensitive files: `.env*`, `*.pem`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, and anything under `.git/`. Matching is case-insensitive against both the basename and the full path. |
| `hooks/auto-format.sh` | `PostToolUse` | `Edit\|Write` | After an edit/write completes, formats the touched file: `ruff format` for `*.py`, `prettier --write` for everything else, if the corresponding formatter is installed. Never fails the hook — always exits `0`. |

## Payload schema note

Claude Code hooks receive a JSON payload on stdin. The important fields used
by these scripts are:

```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "...",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "src/index.js",
    "old_string": "...",
    "new_string": "..."
  }
}
```

The file path field is **`tool_input.file_path`**. There is no
`tool_input.path` fallback for any built-in tool — code that reads a
different key will silently no-op.

## Exit-code contract

- **`PreToolUse`** (`protect-files.py`):
  - `exit 0` = no decision from this hook; Claude Code's normal permission
    flow still applies. This is *not* the same as auto-approving the tool
    call.
  - `exit 2` = block the tool call. The message written to stderr (prefixed
    `BLOCKED:`) is surfaced back to Claude as the reason.
  - Plain stderr + exit 2 is sufficient here; structured JSON hook output is
    optional and not used by this script.
- **`PostToolUse`** (`auto-format.sh`):
  - Always exits `0`, by convention. The hook runs *after* the tool already
    completed, so a nonzero exit can't undo the edit — it would only put the
    session into a spurious error state for no benefit. Formatter failures
    are swallowed (stdout/stderr redirected to `/dev/null`) rather than
    surfaced.

## Running the standalone pipe-tests

Every hook can be exercised directly, outside of Claude Code, by piping a
JSON payload into it on stdin. Fixture payloads live in `tests/`:

```bash
# Should be BLOCKED: exits 2, BLOCKED: message on stderr
cat tests/payload-edit-blocked.json | python3 hooks/protect-files.py

# Should be allowed: exits 0, no output
cat tests/payload-edit-safe.json | python3 hooks/protect-files.py

# Should always exit 0
cat tests/payload-edit-safe.json | bash hooks/auto-format.sh
```

When adding a new hook or fixture, write payloads using the **realistic full
schema** shown above (`session_id`, `transcript_path`, `cwd`,
`hook_event_name`, `tool_name`, `tool_input.file_path`, plus whatever
`tool_input` fields that tool actually sends) rather than a minimal stub —
that way the pipe-test actually reflects what Claude Code sends.

## Install: project-local

This repo's own `.claude/settings.json` already wires up all three hooks
using `$CLAUDE_PROJECT_DIR`, which Claude Code expands to the project root:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/hooks/concise-prompt.sh" }] }
    ],
    "PreToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/hooks/protect-files.py" }] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write", "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/hooks/auto-format.sh" }] }
    ]
  }
}
```

So for project-local use there's nothing to install: just clone this repo
and open it with Claude Code. The hooks activate automatically for that
project only.

## Install: global

To make these hooks available in every project, run:

```bash
./install.sh
```

This copies `hooks/*` into `~/.claude/hooks/` and `chmod +x`s them, then
prints the JSON block to merge into your global `~/.claude/settings.json`.
It deliberately does **not** write to `settings.json` for you — merge the
printed block into your existing file by hand so you don't clobber other
settings that already live there.

**Before merging the `PreToolUse` block**, pipe-test `protect-files.py`
standalone against a few payloads of your own:

```bash
cat some_payload.json | python3 ~/.claude/hooks/protect-files.py
```

This matters more for a global install than a project-local one: a
`PreToolUse` hook wired into your global settings runs for *every* project
you open with Claude Code, not just this one. A bug there can block or
mis-block edits everywhere, so verify it in isolation first.

## Development convention: build → pipe-test → wire

When adding a new hook to this repo:

1. **Build** the script to read the relevant fields from the stdin JSON
   payload (see the payload schema above) and exit with the correct code
   for its event type.
2. **Pipe-test** it standalone with a realistic fixture payload in `tests/`
   before touching any settings file, e.g.
   `cat tests/payload-my-new-case.json | python3 hooks/my-new-hook.py`, and
   confirm both the exit code and stderr/stdout output.
3. **Wire** it into `.claude/settings.json` (project) and/or the
   `install.sh` printed instructions (global) only after step 2 passes,
   using the nested `{ "matcher": ..., "hooks": [{ "type": "command",
   "command": ... }] }` shape.

## Known limitations

- **Formatter coverage is best-effort.** `auto-format.sh` only knows about
  `ruff` (Python) and `prettier` (everything else). If neither is installed,
  or the file type isn't something prettier handles well, nothing happens —
  silently, since the hook always exits 0.
- **`install.sh` targets POSIX shells** (Linux/macOS/WSL). It is a bash
  script and is not intended to run under native Windows (cmd.exe /
  PowerShell without WSL).
- **Symlink bypass.** `protect-files.py` matches on the file path given in
  `tool_input.file_path` (basename and full path). A symlink with an
  innocuous name that points at a protected file (e.g. `notes.txt ->
  .env`) would not match any blocked pattern and could bypass the
  protection.

## License

MIT, see `LICENSE`.
