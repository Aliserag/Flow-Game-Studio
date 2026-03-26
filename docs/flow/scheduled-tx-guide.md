# Scheduled Transactions Guide — Epoch-Based Game Mechanics

## Flow's Approach to Scheduling

Flow does not have native scheduled transactions (like Ethereum's `block.timestamp` triggers).
Instead, we use the **Epoch Pattern**: a contract tracks game epochs, and anyone can advance
the epoch by calling `Scheduler.processEpoch()` when enough blocks have passed.

## When to Use Epochs

| Mechanic | Epoch Approach |
|----------|---------------|
| Daily rewards | Epoch = 1 day in blocks (~8640 blocks) |
| Tournament resolution | Epoch = tournament duration |
| Cooldown timers | Action checks "target epoch <= current epoch" |
| Auction endings | Epoch = auction duration |
| Seasonal events | Epoch = season length |

## Block Time Reference

- 1 hour ≈ 360 blocks (Flow ~10s block time)
- 24 hours ≈ 8640 blocks
- 1 week ≈ 60480 blocks

## Epoch Bot

The epoch bot (`tools/epoch-bot.ts`) is a simple off-chain script that:
1. Runs on a cron schedule (every 5 minutes)
2. Calls `Scheduler.blocksUntilNextEpoch()` to check if epoch is ready
3. Submits `processEpoch.cdc` if ready

**The game must be resilient to bot downtime.** Design your game contract to handle multi-epoch gaps.

## On-chain Resilience Pattern

```cadence
// In your game contract
access(all) fun claimDailyReward(player: Address) {
    let currentEpoch = Scheduler.currentEpoch
    let lastClaim = self.lastClaimEpoch[player] ?? 0
    assert(currentEpoch > lastClaim, message: "Already claimed this epoch")
    self.lastClaimEpoch[player] = currentEpoch
    // ... reward logic
}
```

## Queueing vs. Polling

**Queue pattern** (use for actions that must happen at a specific time):
```cadence
Scheduler.scheduleAction(epochsFromNow: 5, description: "resolve-tournament-42", ...)
```

**Poll pattern** (use for actions any player can trigger when their time comes):
```cadence
let action = self.pendingActions[playerId]!
assert(action.targetEpoch <= Scheduler.currentEpoch, message: "Cooldown active")
```

Use **poll** when the player drives the action. Use **queue** when the game server drives it.
