# Contract Upgrade Guide

## Cadence 1.0 Upgrade Constraints

Cadence contracts can be upgraded with `flow project deploy --update`, but with restrictions:

**Cannot change:**
- Remove a field from a struct or resource
- Change the type of an existing field
- Remove an entitlement
- Remove a public function (breaks callers)
- Change a function's parameter types

**Can change:**
- Add new fields with default values
- Add new functions
- Add new entitlements
- Add new events
- Change function bodies (logic changes)

## Canary Deploy Workflow

1. Deploy canary to a separate account on testnet/mainnet
2. Start canary routing: `flow transactions send start_canary.cdc <contractName> <canaryAddr> <prodAddr> 5`
3. Monitor for 24 hours — check event indexer for errors
4. Increase to 25%: `flow transactions send ...start_canary.cdc... 25`
5. After 48h with no errors, complete: `flow transactions send complete_upgrade.cdc <contractName>`
6. Deploy the upgraded contract: `flow project deploy --update --network mainnet`

## Rollback

If errors are detected during canary:
```bash
flow transactions send rollback_canary.cdc <contractName>
```

This immediately routes all traffic back to production.
