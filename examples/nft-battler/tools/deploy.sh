#!/usr/bin/env bash
# deploy.sh — Deploy NFT Battler contracts to the local Flow emulator.
# Usage: ./tools/deploy.sh [--reset]
#   --reset: re-deploy by deleting and re-creating contracts (useful during dev)

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== NFT Battler — Deploying contracts to emulator ==="
cd "$DIR"

if [[ "${1:-}" == "--reset" ]]; then
  echo "--- Resetting deployments (--update flag) ---"
  flow project deploy --update --network emulator
else
  flow project deploy --network emulator
fi

echo ""
echo "=== Deployed contracts: ==="
echo "  ViewResolver     → 0xf8d6e0586b0a20c7"
echo "  NonFungibleToken → 0xf8d6e0586b0a20c7"
echo "  FungibleToken    → 0xf8d6e0586b0a20c7"
echo "  MetadataViews    → 0xf8d6e0586b0a20c7"
echo "  PowerUp          → 0xf8d6e0586b0a20c7"
echo "  Fighter          → 0xf8d6e0586b0a20c7"
echo "  BattleArena      → 0xf8d6e0586b0a20c7"
echo ""
echo "=== Done. Run the client: ==="
echo "  cd client && npm install && npm run dev"
