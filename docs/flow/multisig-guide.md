# Flow Multisig Guide

## Cadence Side: Protocol-Native Multi-Key

Flow accounts can hold multiple cryptographic keys, each assigned a weight (0–1000).
A transaction is authorized if the sum of signing key weights is ≥ 1000.

### 2-of-3 Setup

Add 3 keys, each with weight 500. Any 2 must sign.

```bash
# Add key 1 (Ledger hardware wallet)
flow keys generate --sig-algo ECDSA_P256

# Add the generated public key to the account with weight 500
flow transactions send cadence/transactions/admin/add_key.cdc \
  --arg String:"PUBLIC_KEY_HEX" \
  --arg UInt8:1  \  # ECDSA_P256
  --arg UInt8:3  \  # SHA3_256
  --arg UFix64:500.0 \
  --network mainnet \
  --signer current-admin

# Repeat for keys 2 and 3
# After adding: reduce the original key weight to 500 or revoke it
```

### Transaction Signing Workflow

```bash
# Signer 1 builds and signs (does not submit)
flow transactions build cadence/transactions/admin/pause_system.cdc \
  --arg String:"Security incident" \
  --proposer 0xADMIN \
  --payer 0xADMIN \
  --authorizer 0xADMIN \
  --filter payload \
  --save pause-unsigned.rlp

flow transactions sign pause-unsigned.rlp \
  --signer admin-key-1 \
  --filter payload \
  --save pause-signed-1.rlp

# Signer 2 adds their signature
flow transactions sign pause-signed-1.rlp \
  --signer admin-key-2 \
  --filter payload \
  --save pause-signed-2.rlp

# Submit after quorum
flow transactions send-signed pause-signed-2.rlp
```

### Key Roles (Recommended)

| Role | Weight | Storage |
|------|--------|---------|
| Deployer | 500 | Hardware wallet (Ledger) |
| Operations | 500 | Hardware wallet (different person) |
| Emergency | 500 | Offline cold storage |

Remove the initial setup key (weight 1000) after adding the 3 multisig keys.

## EVM Side: Solidity Safe Contract

For EVM contracts and COA admin operations, deploy `EVMSafe.sol`.
This is required because Flow's protocol-level multisig only applies to Cadence transactions.
EVM calls from a COA are single-signer — you need a contract-level multisig for EVM-side governance.
