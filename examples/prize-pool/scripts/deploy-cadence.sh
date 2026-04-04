#!/usr/bin/env bash
# deploy-cadence.sh — Deploy Cadence contracts for the Prize Pool example.
#
# Prerequisites:
#   - Flow emulator running: flow emulator
#   - From examples/prize-pool/ directory
#
# Usage:
#   cd examples/prize-pool
#   bash scripts/deploy-cadence.sh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "=== Prize Pool — Cadence Deploy ==="
echo ""

# Step 1: Deploy all contracts via flow project deploy
echo "[1/3] Deploying contracts..."
flow project deploy --network emulator --update
echo ""

# Step 2: Run setup_coa.cdc to create the COA
echo "[2/3] Setting up COA..."
flow transactions send cadence/transactions/setup_coa.cdc \
  --signer emulator-account \
  --network emulator
echo ""

# Step 3: Get the COA EVM address
echo "[3/3] COA EVM address:"
flow scripts execute cadence/scripts/get_coa_address.cdc \
  --arg Address:0xf8d6e0586b0a20c7 \
  --network emulator

echo ""
echo "=== Cadence deploy complete! ==="
echo ""
echo "Next steps:"
echo "  1. Run the EVM deploy: npm run deploy-evm"
echo "  2. Call PrizePool.transferOwnership(<COA_EVM_ADDRESS>) on EVM"
echo "  3. Set the EVM address in PrizePoolOrchestrator via Admin resource"
echo "  4. cd client && npm install && npm run dev"
