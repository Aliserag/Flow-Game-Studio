# /flow-game-state

Snapshot the current on-chain game state for a player or the entire game.
Useful for debugging, customer support, and analytics.

## Usage

- `/flow-game-state player 0xabc123` — full snapshot of one player's assets
- `/flow-game-state global` — contract-level state (supply, active season, prices)
- `/flow-game-state tournament 42` — tournament bracket and participant status

## Player Snapshot

Generates and runs these scripts:
1. `get_nft_collection.cdc` — all NFT IDs and metadata
2. `get_token_balance.cdc` — GameToken balance
3. `get_season_progress.cdc` — current tier, XP, claimed rewards
4. `get_tournament_status.cdc` — active tournaments the player entered

Output: formatted table of all player assets with Flow block number and timestamp.

## Global Snapshot

1. `get_token_supply.cdc` — total minted, total burned, circulating supply
2. `get_active_season.cdc` — season config, end epoch
3. `get_price_table.cdc` — all items in DynamicPricing with current effective price
4. `get_active_listings.cdc` — top 20 Marketplace listings by price

## Debugging Mode

Add `--debug` flag to also print:
- Raw Cadence JSON payloads (before decoding)
- Last 10 events for each watched contract
- Current block height and epoch number
