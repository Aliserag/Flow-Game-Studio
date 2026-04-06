# /flow-identity

Design soul-bound tokens and cross-game player identity for Flow games.

## Usage

- `/flow-identity setup` — generate profile creation transaction for new players
- `/flow-identity record-session --game dungeon-crawler --won true` — record game outcome
- `/flow-identity leaderboard --game dungeon-crawler --top 10` — generate leaderboard script
- `/flow-identity export --address 0xabc` — export player's full cross-game history

## Soul-bound in Cadence = No Withdraw Entitlement

The simplest, most idiomatic approach:

```cadence
// BAD: Implement Withdraw -> transferable NFT
access(NonFungibleToken.Withdraw) fun withdraw(withdrawID: UInt64): @{NonFungibleToken.NFT} { ... }

// GOOD: Omit Withdraw entirely -> soul-bound
// Collection has no withdraw function.
// Without auth(Withdraw) &Collection, nobody can remove the resource.
```

No external lock contract, no transfer guard — the capability system enforces it.

## Cross-game Portability

PlayerProfile works across all games in the studio because:
1. `gameHistory` is a dictionary keyed by `gameId` string
2. Any game in the studio can call `profile.recordGameSession(gameId: "my-game", won: true)`
3. Reputation accumulates from ALL games
4. Other studios can use the same contract if they import from the same address

## Reputation Score

`reputationScore = sum(winRate x gamesPlayed) + achievements x 10`

This rewards:
- Consistency over luck (win rate matters more than single wins)
- Engagement (more games = higher potential)
- Achievement hunting (each achievement = 10 reputation)

Games can gate content on `reputationScore` thresholds — "players with >100 rep can enter elite dungeons."
