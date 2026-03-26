---
name: flow-migrate
description: "Safe contract upgrade workflow. Checks upgrade compatibility (no removed fields, no type changes), generates migration transactions for existing player data if needed, registers the new version in VersionRegistry, and deploys with rollback plan."
argument-hint: "[contract-name] [new-version]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, WebSearch
---

# /flow-migrate

Safe contract upgrade and migration workflow.

**Read first:** `docs/flow/upgrade-guide.md`, `docs/flow-reference/VERSION.md`

## Cadence Upgrade Rules (Hard Constraints)

These CANNOT be done in an upgrade — they break existing deployed state:

| Forbidden | Why |
|-----------|-----|
| Remove a field from a resource/struct | Breaks existing stored values |
| Change a field's type | Same |
| Remove an entitlement | Breaks existing capability holders |
| Remove a public function | Breaks downstream callers |
| Change function signatures | Same |

These CAN be done safely:

| Allowed | Notes |
|---------|-------|
| Add new optional fields (with default) | Safe |
| Add new functions | Safe |
| Add new events | Safe |
| Add new entitlements | Safe (additive) |
| Change function bodies (logic only) | Safe if signature unchanged |

## Steps

### 1. Read the current deployed contract

Read `cadence/contracts/[name].cdc`. Note every field, function, event, entitlement.

### 2. Read the proposed new version

Ask the user to describe or show the proposed changes.

### 3. Compatibility check

For every change, classify as SAFE or FORBIDDEN.
If any FORBIDDEN changes exist:
- STOP
- Explain that a new contract (different name) must be deployed alongside the old one
- Offer to help design a migration path with a proxy/router contract

### 4. Generate diff summary

Show a clear before/after table of every changed field/function/event.

### 5. Check if player data migration is needed

If new fields are added: do existing stored resources need to be updated?
If yes: generate a migration transaction players must run to upgrade their stored resources.
Show the migration transaction draft, get approval.

### 6. Pre-upgrade tests

```bash
flow test cadence/tests/[Name]_test.cdc   # ensure old tests still pass
```

Also write a new test for the new behavior.

### 7. Deploy upgrade

```bash
flow project deploy --update --network testnet
```

### 8. Register in VersionRegistry

```bash
flow transactions send cadence/transactions/registry/register_version.cdc \
  --args-json '[{"type": "String", "value": "[name]"}, ...]' \
  --network testnet
```

### 9. Verify post-upgrade

Run all tests. Run scripts to verify existing player data is readable.
Report: upgrade successful / data integrity confirmed.

### 10. Rollback plan

If upgrade causes failures:
1. The old contract code is in git — rollback by redeploying previous version
2. Player data in storage is immutable — you cannot corrupt it with a bad upgrade
3. Document the rollback steps in `docs/flow/deployment-guide.md`
