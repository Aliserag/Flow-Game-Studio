---
name: flow-testnet
description: "Full testnet deployment and verification workflow. Deploys all contracts, runs testnet smoke tests, verifies contract addresses, and confirms all game features work end-to-end on testnet."
argument-hint: "no args — deploys all contracts in flow.json"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

# /flow-testnet

Full testnet deployment workflow.

**Prerequisites:**
- Testnet account funded via https://testnet-faucet.onflow.org
- Account address in `.env` as `FLOW_TESTNET_ADDRESS`
- Key file at `.flow-testnet.pkey` (gitignored)

## Steps

### 1. Pre-deployment checklist

```bash
flow cadence lint cadence/contracts/core/GameNFT.cdc
flow cadence lint cadence/contracts/systems/RandomVRF.cdc
flow cadence lint cadence/contracts/systems/Scheduler.cdc
flow test cadence/tests/
```

All must pass. Also run: `/flow-audit all` — no BLOCK findings allowed.

### 2. Check account balance

```bash
flow accounts get $FLOW_TESTNET_ADDRESS --network testnet
```

Must have >= 0.001 FLOW for storage fees per contract.

### 3. Deploy contracts

```bash
flow project deploy --network testnet
```

If any fail: check error, do NOT retry until cause is understood.

### 4. Verify deployment

```bash
flow scripts execute cadence/scripts/get_random_state.cdc --network testnet
flow scripts execute cadence/scripts/get_epoch.cdc --network testnet
```

### 5. Test VRF commit/reveal cycle

```bash
flow transactions send cadence/transactions/vrf/commit_move.cdc \
  --args-json '[{"type": "UInt256", "value": "99999"}, {"type": "UInt64", "value": "1"}]' \
  --network testnet --signer testnet-account
```

### 6. Record contract addresses

After successful deployment, record addresses in `docs/flow/deployment-guide.md`.
