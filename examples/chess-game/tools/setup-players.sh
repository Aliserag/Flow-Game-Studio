#!/usr/bin/env bash
# Chess on Flow — Test account setup
#
# No manual setup needed! The Flow dev-wallet (localhost:8701) automatically
# provides access to all emulator accounts.
#
# To get a second test account:
#   1. Run: flow accounts create --network emulator --signer emulator-account --yes
#   2. Add the printed address to flow.json under "accounts"
#   3. Restart flow dev-wallet
#
# Most developers can just use the emulator-account for both players by
# opening two browser tabs and connecting different "profiles" in the dev wallet.

echo "See the README for dev-wallet setup instructions."
echo "Run 'flow dev-wallet' to start the wallet UI at http://localhost:8701"
