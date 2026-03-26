# Contract Upgrade Guide

## Before You Upgrade

1. Run `/flow-migrate [contract] [version]` — checks compatibility
2. Run `/flow-audit [contract]` — security review of new version
3. Run `/flow-review [contract]` — code review
4. Deploy to testnet first — always

## The Golden Rule

**Cadence contracts are permanent. Bad upgrades cannot be fully undone.**
Player assets stored in their accounts cannot be seized or altered by the contract owner.
A bad upgrade can brick the contract but cannot steal player funds.

## Migration Transaction Pattern

When adding new required fields to a player-stored resource:

```cadence
// cadence/transactions/migrations/migrate_[contract]_v2.cdc
// Players run this ONCE to upgrade their stored resource.
import "[Contract]"

transaction {
    prepare(player: auth(Storage) &Account) {
        let resource = player.storage.borrow<&[Contract].Resource>(from: [Contract].StoragePath)
            ?? panic("Resource not found")
        // Trigger the migration function added in v2
        resource.migrateToV2()
    }
}
```

## Version Numbering

Use semantic versioning: `MAJOR.MINOR.PATCH`
- MAJOR: breaking change (requires new contract name)
- MINOR: new fields/functions (backwards compatible upgrade)
- PATCH: logic-only fixes (no interface changes)
