# FCL (Flow Client Library) API Reference

## Configuration

```typescript
import * as fcl from "@onflow/fcl"

fcl.config({
  "app.detail.title": "My Game",
  "app.detail.icon": "https://example.com/icon.png",
  "accessNode.api": process.env.NEXT_PUBLIC_ACCESS_NODE_API,
  "discovery.wallet": process.env.NEXT_PUBLIC_WALLET_DISCOVERY,
  "flow.network": process.env.NEXT_PUBLIC_FLOW_NETWORK,
})
```

## Authentication

```typescript
await fcl.authenticate()
const user = await fcl.currentUser.snapshot()
await fcl.unauthenticate()
fcl.currentUser.subscribe((user) => console.log(user))
```

## Transactions (Mutate State)

```typescript
const txId = await fcl.mutate({
  cadence: `
    import "GameNFT"
    transaction { prepare(signer: &Account) { ... } }
  `,
  args: (arg, t) => [
    arg("Dragon Shield", t.String),
    arg("42", t.UInt64),
  ],
  proposer: fcl.authz,
  payer: fcl.authz,
  authorizations: [fcl.authz],
  limit: 999,
})
const result = await fcl.tx(txId).onceSealed()
```

## Scripts (Read State)

```typescript
const result = await fcl.query({
  cadence: `
    import "GameNFT"
    access(all) fun main(address: Address): [UInt64] {
      return getAccount(address)
        .capabilities.get<&GameNFT.Collection>(GameNFT.CollectionPublicPath)
        .borrow()?.getIDs() ?? []
    }
  `,
  args: (arg, t) => [arg(userAddress, t.Address)],
})
```

## Event Subscription

```typescript
const unsub = fcl.events("A.{contractAddress}.GameNFT.Minted").subscribe((event) => {
  console.log("NFT minted:", event.data)
})
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `execution reverted` | Cadence panic in transaction | Check contract logic |
| `invalid argument` | Wrong arg type | Check `t.UInt64` vs `t.UInt32` |
| `account not found` | Address doesn't exist on network | Use faucet to create account |
| `insufficient storage` | Account storage too low | Send FLOW to account |
