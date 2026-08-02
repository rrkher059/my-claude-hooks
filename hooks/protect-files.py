#!/usr/bin/env python3
import sys
import json
import os
import fnmatch

BLOCKED_PATTERNS = [
    ".env*",
    "*.pem",
    "package-lock.json",
    "pnpm-lock.yaml",
    "yarn.lock",
    ".git/*"
]

def main():
    try:
        raw_input = sys.stdin.read()
        if not raw_input:
            sys.exit(0)
        data = json.loads(raw_input)
    except Exception:
        sys.exit(0)

    target_path = data.get("tool_input", {}).get("file_path", "")
    if not target_path:
        sys.exit(0)

    basename = os.path.basename(target_path).lower()
    full_path_lower = target_path.lower()

    if ".git/" in full_path_lower or full_path_lower.startswith(".git" + os.sep):
        sys.stderr.write(f"BLOCKED: Protected file target '{target_path}' matches rule '.git/*'.\n")
        sys.exit(2)

    for pattern in BLOCKED_PATTERNS:
        if pattern == ".git/*":
            continue
        pattern_lower = pattern.lower()
        if fnmatch.fnmatch(basename, pattern_lower) or fnmatch.fnmatch(full_path_lower, pattern_lower):
            sys.stderr.write(f"BLOCKED: Protected file target '{target_path}' matches rule '{pattern}'.\n")
            sys.exit(2)

    sys.exit(0)

if __name__ == "__main__":
    main()
