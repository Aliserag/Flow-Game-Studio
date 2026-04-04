#!/usr/bin/env bash
# deploy.sh — Full deploy orchestration for the Prize Pool example.
#
# Assumes Flow emulator is already running.
# Run from the repository root or examples/prize-pool/.

set -euo pipefail

EXAMPLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$EXAMPLE_DIR"

echo "======================================"
echo " Prize Pool — Full Deploy"
echo "======================================"
echo ""

# ── 1. EVM: install deps + compile ────────────────────────────────────────────
echo "[1/5] Installing EVM deps..."
npm install --silent

echo "[2/5] Compiling Solidity contracts..."
npm run compile

# ── 2. Cadence: deploy contracts ──────────────────────────────────────────────
echo "[3/5] Deploying Cadence contracts..."
flow project deploy --network emulator --update

# ── 3. EVM: deploy PrizePool + MockToken ─────────────────────────────────────
echo "[4/5] Deploying EVM contracts to Flow emulator..."
npm run deploy-evm 2>&1 | tee /tmp/evm-deploy-output.txt

# ── 4. COA setup ─────────────────────────────────────────────────────────────
echo "[5/5] Setting up COA..."
flow transactions send cadence/transactions/setup_coa.cdc \
  --signer emulator-account \
  --network emulator

echo ""
echo "======================================"
echo " Deploy complete!"
echo "======================================"
echo ""
echo "EVM deploy output:"
cat /tmp/evm-deploy-output.txt
echo ""
echo "COA EVM address:"
flow scripts execute cadence/scripts/get_coa_address.cdc \
  --arg Address:0xf8d6e0586b0a20c7 \
  --network emulator
echo ""
echo "Manual step required:"
echo "  Transfer PrizePool ownership to the COA address shown above."
echo "  Then start the client: cd client && npm install && npm run dev"
