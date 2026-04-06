# /flow-liveops

Generate live-ops admin transactions for running seasons, flash sales, and price updates without redeploying contracts.

## Usage

- `/flow-liveops season start --name "Season 2" --start-epoch 42 --end-epoch 84 --tiers 100`
- `/flow-liveops price set --item "sword_legendary" --price 500`
- `/flow-liveops discount --item "sword_legendary" --pct 25 --duration-blocks 6000`
- `/flow-liveops xp award --player 0xabc --amount 500`

## Season Start Template

```cadence
import "SeasonPass"

transaction(name: String, startEpoch: UInt64, endEpoch: UInt64, maxTier: UInt8, xpPerTier: UFix64) {
    let adminRef: auth(SeasonPass.SeasonAdmin) &SeasonPass.Admin
    prepare(signer: auth(BorrowValue) &Account) {
        self.adminRef = signer.storage.borrow<auth(SeasonPass.SeasonAdmin) &SeasonPass.Admin>(
            from: SeasonPass.AdminStoragePath) ?? panic("No SeasonPass.Admin")
    }
    execute {
        let config = SeasonPass.SeasonConfig(
            seasonId: 2, name: name, startEpoch: startEpoch, endEpoch: endEpoch,
            maxTier: maxTier, xpPerTier: xpPerTier, freeRewards: {}, premiumRewards: {}
        )
        self.adminRef.startSeason(config: config)
    }
}
```

Fill in reward dictionaries with actual NFT/token reward IDs before running.
