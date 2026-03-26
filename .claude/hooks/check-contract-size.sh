#!/bin/bash
# Claude Code PreToolUse hook: Checks Cadence contract file sizes before commit.
# Exit 0 = allow, Exit 2 = block.

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

if ! echo "$COMMAND" | grep -qE '^git[[:space:]]+commit'; then
    exit 0
fi

STAGED_CDC=$(git diff --cached --name-only 2>/dev/null | grep -E '^cadence/contracts/.*\.cdc$')
if [ -z "$STAGED_CDC" ]; then
    exit 0
fi

MAX_BYTES=102400
ERRORS=""

for file in $STAGED_CDC; do
    if [ ! -f "$file" ]; then continue; fi
    SIZE=$(wc -c < "$file")
    if [ "$SIZE" -gt "$MAX_BYTES" ]; then
        ERRORS="$ERRORS\nBLOCK: $file is ${SIZE} bytes (max ${MAX_BYTES}). Split into multiple contracts."
    elif [ "$SIZE" -gt 51200 ]; then
        ERRORS="$ERRORS\nWARN: $file is ${SIZE} bytes — approaching 100KB limit. Consider splitting."
    fi
done

if echo "$ERRORS" | grep -q "^BLOCK:"; then
    echo -e "=== Contract Size Check FAILED ===$ERRORS\n================================" >&2
    exit 2
fi

if [ -n "$ERRORS" ]; then
    echo -e "=== Contract Size Warnings ===$ERRORS\n=============================" >&2
fi

exit 0
