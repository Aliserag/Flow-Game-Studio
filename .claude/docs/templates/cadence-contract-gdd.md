# Smart Contract Design: [Contract Name]

## Overview
[One paragraph — what this contract does and why it exists]

## Contract Type
- [ ] NFT Collection
- [ ] Fungible Token
- [ ] Game System (VRF / Scheduler / Marketplace)
- [ ] Utility / Library

## Entitlements

| Entitlement | Held By | Operations Granted |
|-------------|---------|-------------------|
| `Minter` | Deployer account | `mintNFT()` |
| `Admin` | DAO multisig | All Minter ops + `pause()`, `setParams()` |

## Resources

| Resource | Purpose | Stored At | Published At |
|----------|---------|-----------|--------------|
| `NFT` | Individual token | Player storage | — |
| `Collection` | Player's NFTs | `/storage/XCollection` | `/public/XCollection` |
| `Minter` | Create new NFTs | `/storage/XMinter` | Not published |

## Events

| Event | When | Fields |
|-------|------|--------|
| `Minted` | NFT created | id, name, recipient |
| `Transferred` | NFT moved | id, from, to |
| `Burned` | NFT destroyed | id |

## Upgrade Plan

- Fields that will never change: [list]
- Fields that may need updates: [list]
- Upgrade constraints: [what can never be removed]

## Dependencies

- `NonFungibleToken` (Flow standard)
- `MetadataViews` (Flow standard)

## Acceptance Criteria

- [ ] `flow test cadence/tests/[Name]_test.cdc` — all pass
- [ ] `/flow-audit` — no BLOCK findings
- [ ] `/flow-review` — approved for testnet
- [ ] Deployed to emulator with correct behavior
