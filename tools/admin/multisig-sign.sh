#!/usr/bin/env bash
# multisig-sign.sh
# Helper to collect multiple signatures on a Flow transaction before submission.
# Usage: ./multisig-sign.sh <tx.cdc> <args...>
set -euo pipefail

TX_FILE="${1:?Usage: $0 <transaction.cdc> [args...]}"
shift
SIGNER_COUNT="${SIGNER_COUNT:-2}"  # Number of required signatures
NETWORK="${NETWORK:-testnet}"

echo "=== Flow Multisig Transaction Signing ==="
echo "Transaction: $TX_FILE"
echo "Required signers: $SIGNER_COUNT"
echo "Network: $NETWORK"
echo ""

UNSIGNED="tx-unsigned.rlp"
SIGNED="tx-signed"

# Build unsigned transaction
CMD="flow transactions build $TX_FILE"
for arg in "$@"; do
    CMD="$CMD --arg $arg"
done
CMD="$CMD --proposer admin --payer admin --authorizer admin --filter payload --save $UNSIGNED --network $NETWORK"

echo "Building unsigned transaction..."
eval "$CMD"
echo "Unsigned transaction saved to: $UNSIGNED"
echo ""

echo "=== Signing Instructions ==="
echo "Each signer should run:"
echo ""
echo "  Signer 1:"
echo "  flow transactions sign $UNSIGNED --signer admin-key-1 --filter payload --save ${SIGNED}-1.rlp --network $NETWORK"
echo ""
for i in $(seq 2 $SIGNER_COUNT); do
    prev=$((i-1))
    echo "  Signer $i:"
    echo "  flow transactions sign ${SIGNED}-${prev}.rlp --signer admin-key-${i} --filter payload --save ${SIGNED}-${i}.rlp --network $NETWORK"
    echo ""
done

echo "  After all signatures collected:"
echo "  flow transactions send-signed ${SIGNED}-${SIGNER_COUNT}.rlp --network $NETWORK"
