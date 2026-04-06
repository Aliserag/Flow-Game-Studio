# /flow-storage

Audit and manage Flow account storage capacity for game contracts.

## Usage

- `/flow-storage check --address 0xabc` — check available storage for a player account
- `/flow-storage estimate --contract GameNFT` — estimate storage cost per mint
- `/flow-storage audit` — scan all active player accounts in the indexer for low capacity
- `/flow-storage top-up --address 0xabc --amount 0.01` — generate storage top-up transaction

## Storage Cost Model

```
capacity_bytes = flowBalance * 10,000,000   (10MB per FLOW, approximately)
cost_per_NFT ~= 2KB storage = 0.0002 FLOW minimum balance required
```

For a game expecting 10,000 players, each with 10 NFTs:
- 200KB storage per player
- ~0.002 FLOW minimum per player (at current rates — verify from Flow docs)
- Budget: 0.002 x 10,000 = 20 FLOW for storage deposits

## Prevention Patterns

1. **Sponsor storage top-up**: Before minting, check capacity; if < 2x mint_size, top up from sponsor account
2. **Lazy collection setup**: Require players to set up their own collection (they pay storage) before minting to them
3. **Storage deposit in mint price**: Include a FLOW storage deposit in the NFT mint price that gets forwarded to the player account
4. **Batch check**: Run nightly via indexer to find players approaching capacity before they hit errors

## CI Check

In `tools/ci/check-storage-impact.sh`, estimate the storage delta of any new struct/resource added to contracts:
- Each field in a struct adds ~50-100 bytes
- Resources have overhead ~200 bytes
- Arrays grow dynamically — document max size assumptions
