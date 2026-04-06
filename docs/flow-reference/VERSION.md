# Flow Blockchain — Version Reference

| Field | Value |
|-------|-------|
| **Cadence Version** | 1.0 |
| **Flow CLI Version** | 2.x |
| **FCL Version** | 1.x |
| **Project Pinned** | 2026-03-23 |
| **Last Docs Verified** | 2026-03-23 |
| **LLM Knowledge Cutoff** | Aug 2025 |

## Knowledge Gap Warning

Cadence 1.0 is a **breaking change** from Cadence 0.x. The LLM's training data
may include Cadence 0.x patterns that are now **invalid**. Always cross-reference
this directory before suggesting Cadence code.

## Critical Cadence 1.0 Breaking Changes

| Area | Old (0.x) | New (1.0) |
|------|-----------|-----------|
| Access control | `pub`, `priv`, `access(self)` | `access(all)`, `access(self)`, `access(contract)`, `access(account)` |
| Entitlements | `auth &T` (all-or-nothing) | `entitlement E` + `access(E) fun` + `auth(E) &T` |
| Capabilities | `getCapability<&T>` | `getCapability<auth(E) &T>` |
| Force cast | `as!` on auth refs | Typed entitlement refs |
| Contract access | `pub contract Foo` | `access(all) contract Foo` |
| Resource fields | `pub let` | `access(all) let` |

## Verified Sources

- Cadence 1.0 docs: https://cadence-lang.org/docs
- Migration guide: https://cadence-lang.org/docs/cadence-migration-guide
- Flow CLI docs: https://developers.flow.com/tools/flow-cli
- FCL docs: https://developers.flow.com/tools/clients/fcl-js
- Standard contracts: https://github.com/onflow/flow-nft
- RandomBeaconHistory: https://github.com/onflow/flow-core-contracts
