# Dungeon Crawler Arena — Reference Implementation

This mini-game demonstrates every Flow pattern from the game studio plan:

| Feature | Contract / Pattern Used |
|---------|------------------------|
| Commit/reveal combat | RandomVRF.commit() + reveal() |
| NFT equipment checks | GameNFT collection borrowing |
| Token rewards | GameToken.Minter capability |
| Seasonal dungeons | SeasonPass + Scheduler epochs |
| Emergency pause | EmergencyPause.assertNotPaused() |
| Player governance | Governance vote to change rewards |

## How to Run

1. Start emulator: `flow emulator`
2. Deploy all contracts: `flow project deploy --network emulator`
3. Run tests: `flow test examples/dungeon-crawler/cadence/tests/`
4. Run client: `cd examples/dungeon-crawler/client && npm start`

## Game Loop

1. Player calls `enter_dungeon.cdc` with a secret and dungeon level (1-3)
2. Client waits 1 block (minimum)
3. Player calls `reveal_combat_result.cdc` — VRF resolves combat
4. Victory: GameTokens minted to player vault
5. Defeat: No reward, try again next dungeon reset
