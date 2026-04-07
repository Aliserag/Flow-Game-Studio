# Dungeon Crawler Arena — Cadence Pattern Reference

> **⚠️ This is a Cadence reference, not a runnable example.**
> The contracts and transactions here demonstrate advanced Flow patterns.
> There is no complete client app or test suite yet.
> See the four runnable examples: `coin-flip`, `nft-battler`, `chess-game`, `prize-pool`.

This reference shows how to combine every Flow pattern from the game studio plan:

| Feature | Contract / Pattern Used |
|---------|------------------------|
| Commit/reveal combat | RandomVRF.commit() + reveal() |
| NFT equipment checks | GameNFT collection borrowing |
| Token rewards | GameToken.Minter capability |
| Seasonal dungeons | SeasonPass + Scheduler epochs |
| Emergency pause | EmergencyPause.assertNotPaused() |
| Player governance | Governance vote to change rewards |

## Files

| File | Description |
|------|-------------|
| `cadence/contracts/DungeonCrawler.cdc` | Main contract combining VRF, NFT checks, token rewards |
| `cadence/transactions/enter_dungeon.cdc` | Commit phase — player submits secret + dungeon level |
| `cadence/transactions/reveal_combat_result.cdc` | Reveal phase — VRF resolves combat outcome |
| `cadence/scripts/get_dungeon_state.cdc` | Read dungeon state for a player |

## Intended Game Loop

1. Player calls `enter_dungeon.cdc` with a secret and dungeon level (1-3)
2. Client waits 1 block (minimum)
3. Player calls `reveal_combat_result.cdc` — VRF resolves combat
4. Victory: GameTokens minted to player vault
5. Defeat: No reward, try again next dungeon reset
