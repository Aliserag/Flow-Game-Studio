---
name: flow-contract
description: "Deploy or upgrade a Cadence contract to emulator, testnet, or mainnet. Handles pre-deployment validation, test run, staged deployment, and post-deployment verification."
argument-hint: "[contract-name] [network: emulator|testnet|mainnet]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

# /flow-contract

Safely deploys or upgrades a Cadence contract.

## Pre-deployment Checklist (always run)

- [ ] `flow cadence lint cadence/contracts/[name].cdc` — no errors
- [ ] `flow test cadence/tests/[Name]_test.cdc` — all pass
- [ ] No hardcoded addresses in contract
- [ ] No `pub`/`priv` keywords (Cadence 0.x patterns)
- [ ] Admin resources secured (not on public paths)
- [ ] Contract reviewed by `/flow-audit` (for testnet/mainnet)

## Deploy to Emulator

```bash
flow emulator start --log-format=text &
sleep 2
flow project deploy --network emulator --update
```

## Deploy to Testnet

CONFIRM with user before running:
```bash
flow project deploy --network testnet
```

## Deploy to Mainnet

CONFIRM TWICE with user. Show exact contract name and account address.
```bash
flow project deploy --network mainnet
```

## Contract Upgrade Safety

Cadence contracts are upgradeable but with restrictions:
- Cannot remove fields from resources/structs
- Cannot change field types
- Cannot remove entitlements
- CAN add new fields (optional/with default), new functions, new events

If the upgrade breaks these rules: STOP and tell the user.

## Post-deployment Verification

Run verification script:
```bash
flow scripts execute cadence/scripts/verify_{contract}.cdc --network [network]
```

Report: contract address, total supply (if NFT), deployment block.
