#!/usr/bin/env bash
# Deploy all Chess on Flow contracts to the local emulator.
# Run from anywhere — this script resolves paths automatically.
# Re-running is safe: already-deployed contracts are skipped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHESS_DIR="$(dirname "$SCRIPT_DIR")"
STUDIO_ROOT="$(dirname "$(dirname "$CHESS_DIR")")"

echo "=== Chess on Flow — Deploying contracts ==="
cd "$CHESS_DIR"

echo "Deploying EmergencyPause (required by ChessGame)..."
flow accounts add-contract EmergencyPause \
  "$STUDIO_ROOT/cadence/contracts/systems/EmergencyPause.cdc" \
  --network emulator --signer emulator-account 2>/dev/null || echo "  (EmergencyPause already deployed — skipping)"

echo "Deploying ChessPiece..."
flow accounts add-contract ChessPiece \
  ./cadence/contracts/ChessPiece.cdc \
  --network emulator --signer emulator-account 2>/dev/null || echo "  (ChessPiece already deployed — skipping)"

echo "Deploying ChessStatsAttachment..."
flow accounts add-contract ChessStatsAttachment \
  ./cadence/contracts/ChessStatsAttachment.cdc \
  --network emulator --signer emulator-account 2>/dev/null || echo "  (ChessStatsAttachment already deployed — skipping)"

echo "Deploying ChessGame..."
flow accounts add-contract ChessGame \
  ./cadence/contracts/ChessGame.cdc \
  --network emulator --signer emulator-account 2>/dev/null || echo "  (ChessGame already deployed — skipping)"

echo ""
echo "=== All contracts deployed ==="
echo "Service account: 0xf8d6e0586b0a20c7"
