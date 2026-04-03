#!/usr/bin/env bash
# Create two test player accounts on the local Flow emulator.
# Run AFTER deploy.sh. Prints addresses and public keys for reference.
# Use the flow dev-wallet (http://localhost:8701) to connect as each account.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHESS_DIR="$(dirname "$SCRIPT_DIR")"

cd "$CHESS_DIR"

echo "=== Creating test player accounts ==="
echo ""

echo "--- Player 1 ---"
KEYS1=$(flow keys generate --format json)
PUBKEY1=$(echo "$KEYS1" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['public'])")
flow accounts create \
  --key "$PUBKEY1" \
  --network emulator \
  --signer emulator-account \
  --yes

echo ""
echo "--- Player 2 ---"
KEYS2=$(flow keys generate --format json)
PUBKEY2=$(echo "$KEYS2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['public'])")
flow accounts create \
  --key "$PUBKEY2" \
  --network emulator \
  --signer emulator-account \
  --yes

echo ""
echo "=== Accounts created ==="
echo "Note: The dev wallet at http://localhost:8701 provides access to all emulator"
echo "accounts. Use it to connect as each player in separate browser tabs."
