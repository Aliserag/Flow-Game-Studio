#!/usr/bin/env bash
# Setup chess collection for both test players
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHESS_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Setting up chess player accounts ==="
cd "$CHESS_DIR"

echo "Setting up player 1..."
flow transactions send ./cadence/transactions/setup_chess_account.cdc --network emulator --signer chess-player-1

echo "Setting up player 2..."
flow transactions send ./cadence/transactions/setup_chess_account.cdc --network emulator --signer chess-player-2

echo "=== Done. Both players ready. ==="
