#!/usr/bin/env bash
# Deploy all chess contracts to the Flow emulator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHESS_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Chess on Flow — Deploying contracts ==="
cd "$CHESS_DIR"

echo "Deploying ChessPiece..."
flow accounts add-contract ChessPiece ./cadence/contracts/ChessPiece.cdc --network emulator --signer emulator-account

echo "Deploying ChessStatsAttachment..."
flow accounts add-contract ChessStatsAttachment ./cadence/contracts/ChessStatsAttachment.cdc --network emulator --signer emulator-account

echo "Deploying ChessGame..."
flow accounts add-contract ChessGame ./cadence/contracts/ChessGame.cdc --network emulator --signer emulator-account

echo "=== All contracts deployed ==="
