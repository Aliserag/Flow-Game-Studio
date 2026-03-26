---
name: flow-nft
description: "Create a game NFT contract from the GameNFT base. Guides through metadata design, entitlement structure, minting logic, and royalties. Produces a ready-to-deploy Cadence 1.0 contract."
argument-hint: "[nft-name] e.g. 'DragonNFT', 'WeaponNFT', 'CharacterNFT'"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

# /flow-nft

Creates a game NFT contract extending GameNFT.

**Read first:** `docs/flow-reference/standard-contracts.md`, `cadence/contracts/core/GameNFT.cdc`

## Steps

### 1. Gather requirements

Ask:
1. What is this NFT called? (e.g., DragonNFT)
2. What metadata fields does it have? (name, type, level, rarity, stats...)
3. Who can mint? (deployer only, game server, players?)
4. Is there a max supply?
5. Should it support upgradeable metadata (evolving NFTs)?
6. Does it need royalties? If yes, what percentage and to whom?
7. Will it be listed on Flow marketplaces? (affects MetadataViews completeness)

### 2. Show the generated contract

Present the full contract draft before writing. Highlight:
- Which fields are immutable (set at mint) vs. mutable (require Updater entitlement)
- How royalties are implemented via MetadataViews.Royalties
- The Minter resource and how it's secured

### 3. Generate the contract

Extend GameNFT with game-specific fields and logic.
Include: entitlements, events, complete MetadataViews implementation.

### 4. Generate setup and mint transactions

### 5. Generate Cadence test file

Minimum tests: deploy, setup collection, mint, verify metadata, transfer.

### 6. Add to flow.json

Add the new contract to `flow.json` under `contracts` and `deployments`.

### 7. Deploy to emulator and run tests

```bash
flow project deploy --network emulator
flow test cadence/tests/{Name}_test.cdc
```
