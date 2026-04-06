#!/bin/bash
# Claude Code PreToolUse hook: Validates Cadence (.cdc) files on commit
# Exit 0 = allow, Exit 2 = block

INPUT=$(cat)

if command -v jq >/dev/null 2>&1; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
else
    COMMAND=$(echo "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"command"[[:space:]]*:[[:space:]]*"//;s/"$//')
fi

if ! echo "$COMMAND" | grep -qE '^git[[:space:]]+commit'; then
    exit 0
fi

STAGED_CDC=$(git diff --cached --name-only 2>/dev/null | grep -E '\.cdc$')
if [ -z "$STAGED_CDC" ]; then
    exit 0
fi

ERRORS=""

for file in $STAGED_CDC; do
    if [ ! -f "$file" ]; then continue; fi

    # Check for Cadence 0.x forbidden patterns
    if grep -nE '\bpub\b' "$file" | grep -v '//'; then
        ERRORS="$ERRORS\nERROR: $file uses 'pub' (Cadence 0.x). Use 'access(all)' instead."
    fi
    if grep -nE '\bpriv\b' "$file" | grep -v '//'; then
        ERRORS="$ERRORS\nERROR: $file uses 'priv' (Cadence 0.x). Use 'access(self)' instead."
    fi
    if grep -nqE 'auth[[:space:]]*&[A-Z]' "$file"; then
        ERRORS="$ERRORS\nWARN: $file may use unentitled auth ref (Cadence 0.x pattern). Use auth(Entitlement) &T."
    fi

    # Check for hardcoded addresses (0x followed by hex, not in comments)
    if grep -nE '^\s*[^/].*0x[0-9a-fA-F]{8,}' "$file" | grep -v 'import'; then
        ERRORS="$ERRORS\nWARN: $file may contain hardcoded addresses. Use flow.json named accounts."
    fi

    # Check for force-unwrap on capabilities
    if grep -nE 'getCapability.*\)!' "$file"; then
        ERRORS="$ERRORS\nWARN: $file uses force-unwrap on capability. Use ?? panic(...) instead."
    fi
done

# Run flow cadence lint if available
if command -v flow >/dev/null 2>&1 && [ -n "$STAGED_CDC" ]; then
    for file in $STAGED_CDC; do
        if [ -f "$file" ]; then
            LINT_OUT=$(flow cadence lint "$file" 2>&1)
            if [ $? -ne 0 ]; then
                ERRORS="$ERRORS\nLINT ERROR in $file:\n$LINT_OUT"
            fi
        fi
    done
fi

if echo "$ERRORS" | grep -q "^ERROR:"; then
    echo -e "=== Cadence Validation BLOCKED ===$ERRORS\n=================================" >&2
    exit 2
fi

if [ -n "$ERRORS" ]; then
    echo -e "=== Cadence Validation Warnings ===$ERRORS\n===================================" >&2
fi

exit 0
