#!/usr/bin/env bash
# Deploy all Chess on Flow contracts to the local Flow emulator.
# Idempotent: safe to re-run at any time (--update handles already-deployed contracts).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHESS_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Chess on Flow — Deploying contracts ==="
cd "$CHESS_DIR"

flow project deploy --update --network emulator

echo ""
echo "=== Contracts deployed ==="
echo "Emulator service account: 0xf8d6e0586b0a20c7"
