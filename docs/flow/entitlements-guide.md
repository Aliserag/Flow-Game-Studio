# Entitlements Guide — Cadence 1.0 Access Control

## Mental Model

Old Cadence (0.x): capabilities were all-or-nothing. If you could borrow a ref, you could call all public functions.

New Cadence (1.0): capabilities carry entitlements. A ref typed `auth(Minter) &NFT` can only call functions marked `access(Minter)`. A plain `&NFT` ref can only call `access(all)` functions.

## The Three Questions

When designing entitlements, answer:
1. **What can the public do?** → `access(all)` — no entitlement needed
2. **What can specific roles do?** → Define `entitlement X`, mark functions `access(X)`
3. **What can only the owner do?** → `access(self)` inside the resource

## Entitlement Naming Convention

Use role-based names, not action-based:
- `entitlement Minter` (who has it) ✅
- `entitlement CanMint` (what it does) ❌
- `entitlement Admin`, `entitlement GameServer`, `entitlement Player` ✅

## Capability Distribution Pattern

```
Deployer Account
  ├── /storage/MyContractMinter    ← Minter resource (never published)
  ├── /storage/MyContractAdmin     ← Admin resource (never published)
  │
  └── Issues capabilities to:
       ├── Game Server Account → auth(GameServer) &GameContract capability
       └── Player Accounts    → auth(Player) &GameContract capability (via their setup tx)
```

## Common Entitlement Patterns for Games

### Pattern 1: Mint-only minter
```cadence
access(all) entitlement Minter
access(all) resource MinterResource {
    access(Minter) fun mint(): @NFT { ... }
}
// Game server gets: auth(Minter) &MinterResource capability
```

### Pattern 2: Evolving NFT (game server can level up)
```cadence
access(all) entitlement Updater
access(all) resource NFT {
    access(all) var level: UInt32           // readable by anyone
    access(Updater) fun levelUp() { ... }   // only game server
}
```

### Pattern 3: Admin supersedes other roles
```cadence
access(all) entitlement mapping AdminMap {
    Admin -> Minter
    Admin -> Updater
    Admin -> Pauser
}
// Admin can do anything Minter, Updater, or Pauser can do
```
