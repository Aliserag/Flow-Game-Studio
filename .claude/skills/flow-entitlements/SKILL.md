---
name: flow-entitlements
description: "Design and implement Cadence 1.0 entitlement structures for a contract. Analyzes the access control requirements, proposes entitlements, and generates correct auth(E) reference patterns."
argument-hint: "[contract-name or describe the resource]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit
---

# /flow-entitlements

Designs entitlement structures for a Cadence 1.0 contract.

**Read first:** `docs/flow-reference/entitlements-reference.md`

## Steps

### 1. Understand the resource and its operations

Ask:
1. What resource(s) need access control? (e.g., NFT, Collection, AdminPanel)
2. List all operations the resource can perform
3. For each operation: who should be able to call it?
   - The owner only?
   - Specific roles (Minter, Admin, Moderator)?
   - Anyone publicly?
4. Are there hierarchical permissions? (e.g., Admin can do everything Minter can)

### 2. Propose entitlement design

Present a table:

| Entitlement | Holders | Operations it grants |
|-------------|---------|---------------------|
| `Minter`    | Deployer account | `mintNFT()` |
| `Updater`   | Game server account | `updateMetadata()`, `setLevel()` |
| `Admin`     | DAO multisig | `setMinter()`, `pause()`, `Admin \| Minter` |

Ask: "Does this match your intentions?"

### 3. Generate entitlement definitions

```cadence
access(all) contract YourContract {
    // Entitlements — define before any types
    access(all) entitlement Minter
    access(all) entitlement Updater
    access(all) entitlement Admin

    // Entitlement mappings (optional — inherit permissions)
    access(all) entitlement mapping AdminMap {
        Admin -> Minter
        Admin -> Updater
    }
```

### 4. Generate entitled resource methods

For each privileged operation:

```cadence
access(all) resource NFT {
    // Public (no entitlement)
    access(all) let id: UInt64
    access(all) let name: String

    // Restricted (requires Updater or Admin)
    access(Updater | Admin) fun setLevel(_ newLevel: UInt32) {
        self.level = newLevel
    }

    // Highly restricted (requires Admin only)
    access(Admin) fun revokeOwnership() {
        // ...
    }
}
```

### 5. Generate capability issuance patterns

Show how to issue and use capabilities with entitlements:

```cadence
// Issuing an entitled capability to a game server
let updaterCap = account.capabilities.storage.issue<auth(Updater) &YourContract.NFT>(
    /storage/yourNFT
)
account.capabilities.publish(updaterCap, at: /public/yourNFTUpdater)

// Using it
let ref = account.capabilities.get<auth(Updater) &YourContract.NFT>(/public/yourNFTUpdater)
    .borrow() ?? panic("Updater capability missing")
ref.setLevel(5)  // works because ref is auth(Updater)
```

### 6. Show to user, get approval, write to contract file

Ask: "May I update `cadence/contracts/[name].cdc` with these entitlement definitions?"

### 7. Verify with lint

```bash
flow cadence lint cadence/contracts/[name].cdc
```

Fix any issues before finishing.
