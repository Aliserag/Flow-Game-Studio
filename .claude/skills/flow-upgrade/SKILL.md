# /flow-upgrade

Safe contract upgrade workflow with canary deploys and rollback.

## Usage

- `/flow-upgrade plan <ContractName>` — audit upgrade safety and generate migration plan
- `/flow-upgrade canary <ContractName> --pct 5` — deploy canary to 5% of users
- `/flow-upgrade increase-canary <ContractName> --pct 25` — increase canary traffic
- `/flow-upgrade complete <ContractName>` — complete upgrade (100% rollout)
- `/flow-upgrade rollback <ContractName>` — emergency rollback to previous version

## Cadence 1.0 Upgrade Constraints

You CANNOT in an upgrade:
- Remove a field from a struct or resource
- Change the type of an existing field
- Remove an entitlement
- Remove a public function (breaks callers)
- Change a function's parameter types (breaks callers)

You CAN:
- Add new fields with default values
- Add new functions
- Add new entitlements
- Add new events
- Change function bodies (logic changes)

## Canary Rollout Schedule

| Phase | Canary % | Duration | Pass Criteria |
|-------|----------|----------|---------------|
| 1 | 5% | 24 hours | Zero errors in event indexer for canary users |
| 2 | 25% | 24 hours | Same |
| 3 | 50% | 12 hours | Same |
| 4 | 100% | Complete | Full upgrade via `flow project deploy --update` |

## Before Any Upgrade

1. Run `flow cadence lint` on the new contract
2. Run `flow test` — all existing tests must pass
3. Run `/flow-migrate <ContractName>` — generate migration for existing player data
4. Deploy canary to testnet and run with 100% traffic for 48 hours
5. Get second review from `flow-architect` agent
