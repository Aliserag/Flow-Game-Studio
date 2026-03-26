# Cadence 1.0 — Breaking Changes from 0.x

## Access Modifiers (BREAKING)

| 0.x | 1.0 | Notes |
|-----|-----|-------|
| `pub` | `access(all)` | Required for all public members |
| `priv` | `access(self)` | Private to the enclosing declaration |
| `pub(set)` | `access(all) var` or entitlement | Removed |

## Auth References and Entitlements (BREAKING)

Old: `auth &T` — grants all access at once.
New: `auth(E) &T` — grants only entitlement `E`.

Old code:
```cadence
let ref: auth &NFT = ...
ref.dangerousAdmin()  // works if the function is pub
```

New code:
```cadence
entitlement Admin
let ref: auth(Admin) &NFT = ...
ref.dangerousAdmin()  // only works if function is access(Admin)
```

## Capability API (BREAKING)

| 0.x | 1.0 |
|-----|-----|
| `account.link<&T>(publicPath, target:)` | `account.capabilities.storage.issue<&T>(storagePath)` + `account.capabilities.publish(cap, at: publicPath)` |
| `account.getCapability<&T>(path)` | `account.capabilities.get<&T>(path)` |
| `account.borrow<&T>(from:)` | `account.storage.borrow<&T>(from:)` |

## Contract Deployment (BREAKING)

Old: `AuthAccount(payer: signer)` to create accounts.
New: `Account(payer: signer)` — `AuthAccount` removed.

## Import Syntax (Recommended Change)

Old: `import Foo from 0x01`
New: `import "Foo"` — resolves via `flow.json` aliases. Use this form.

## Resource Destruction

All resource destruction must be explicit via `destroy`.

## Restricted Types Removed

Old: `{FungibleToken.Receiver}` restricted type syntax.
New: Use interface-typed references: `&{FungibleToken.Receiver}`.
