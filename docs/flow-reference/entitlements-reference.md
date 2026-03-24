# Cadence 1.0 Entitlements Reference

## Defining Entitlements

```cadence
access(all) contract MyContract {
    // Define entitlements at contract scope
    access(all) entitlement Minter
    access(all) entitlement Burner
    access(all) entitlement Admin

    // Entitlement mapping (maps one entitlement to another)
    access(all) entitlement mapping NFTCollectionMap {
        Minter -> Insert
        Burner -> Remove
    }
}
```

## Granting Access with Entitlements

```cadence
access(all) resource NFT {
    // Public read — no entitlement required
    access(all) let id: UInt64

    // Requires Minter entitlement on the reference
    access(Minter) fun setMetadata(_ key: String, _ val: String) { ... }

    // Requires EITHER entitlement
    access(Minter | Admin) fun update() { ... }

    // Requires BOTH entitlements
    access(Minter, Admin) fun dangerousReset() { ... }
}
```

## Creating Entitled References

```cadence
// Entitled reference type
let ref: auth(Minter) &MyContract.NFT = ...

// Getting a capability with entitlements
let cap = account.capabilities.storage.issue<auth(Minter) &MyContract.NFT>(
    /storage/myNFT
)

// Borrowing with entitlements
let entitled = cap.borrow()  // returns auth(Minter) &NFT?
```

## Storing and Retrieving Capabilities

```cadence
// Store capability
account.capabilities.publish(cap, at: /public/myNFTMinter)

// Retrieve and use
let cap = account.capabilities.get<auth(Minter) &MyContract.NFT>(/public/myNFTMinter)
let ref = cap.borrow() ?? panic("capability missing")
ref.setMetadata("name", "Dragon Shield")  // works because auth(Minter)
```

## Common Patterns

### Restricting who can mint

```cadence
access(all) contract GameNFT {
    access(all) entitlement Minter

    access(all) resource Minter {
        access(all) fun mintNFT(name: String): @NFT {
            return <- create NFT(name: name)
        }
    }

    // Only contract deployer gets the Minter resource
    init() {
        self.account.storage.save(<- create Minter(), to: /storage/GameNFTMinter)
    }
}
```
