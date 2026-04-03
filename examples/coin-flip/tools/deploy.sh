#!/usr/bin/env bash
# deploy.sh — Deploy CoinFlip contracts to the Flow emulator.
set -euo pipefail

COIN_FLIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== Coin Flip on Flow — Deploying contracts ==="
echo "Working dir: ${COIN_FLIP_DIR}"

cd "${COIN_FLIP_DIR}"

flow project deploy --update --network emulator

echo ""
echo "=== Done. ==="
echo "Emulator account: 0xf8d6e0586b0a20c7"
echo "Contracts deployed: RandomBeaconHistory, CoinFlip"
