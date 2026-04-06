#!/usr/bin/env bash
# setup-multisig-account.sh
# Generates and configures a 2-of-3 multisig admin account on Flow.
# Run once on account setup. Requires flow CLI and hardware wallet support.
set -euo pipefail

NETWORK="${1:-testnet}"
ACCOUNT="${2:-default}"

echo "=== Flow 2-of-3 Multisig Account Setup ==="
echo "Network: $NETWORK"
echo "Account: $ACCOUNT"
echo ""
echo "Step 1: Generate 3 key pairs (run on separate hardware wallets)"
echo ""
echo "  flow keys generate --sig-algo ECDSA_P256 > key1.txt"
echo "  flow keys generate --sig-algo ECDSA_P256 > key2.txt"
echo "  flow keys generate --sig-algo ECDSA_P256 > key3.txt"
echo ""
echo "Step 2: Add each key to the admin account with weight 500"
echo "  (Each signer runs this from their own machine with the public key)"
echo ""
echo "  flow transactions send cadence/transactions/admin/add_key.cdc \\"
echo "    --arg String:<PUBLIC_KEY_HEX> \\"
echo "    --arg UInt8:1 \\"
echo "    --arg UInt8:3 \\"
echo "    --arg UFix64:500.0 \\"
echo "    --network $NETWORK --signer $ACCOUNT"
echo ""
echo "Step 3: After adding all 3 keys, revoke the original key:"
echo "  flow transactions send cadence/transactions/admin/revoke_key.cdc \\"
echo "    --arg Int:0 --network $NETWORK --signer $ACCOUNT"
echo ""
echo "Step 4: Verify the account has 3 keys with weight 500 each:"
echo "  flow accounts get <ADMIN_ADDRESS> --network $NETWORK"
echo ""
echo "IMPORTANT: Store each private key securely. Loss of 2 keys = permanent lockout."
