---
name: flow-scheduled
description: "Add epoch-based scheduled mechanics to a game system. Generates the schedule transaction, epoch processor, and off-chain bot script for automatic epoch advancement."
argument-hint: "[mechanic-name] e.g. 'daily-rewards', 'tournament-resolution', 'cooldown'"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash
---

# /flow-scheduled

Adds epoch-based scheduled mechanics to a game system.

**Read first:** `cadence/contracts/systems/Scheduler.cdc`

## Flow's Scheduling Model

Flow does not have native scheduled transactions. Use epoch-based scheduling:
- Actions queue with a target epoch
- Anyone calls `Scheduler.processEpoch()` after enough blocks
- Contract processes all due actions atomically

## Block Time Reference

- 1 hour ≈ 360 blocks (Flow ~10s block time)
- 24 hours ≈ 8640 blocks
- 1 week ≈ 60480 blocks

## Steps

### 1. Understand the mechanic

Ask:
1. What mechanic needs time-based execution?
2. How long should the delay be?
3. Who queues the action? (player, game server?)
4. What happens when the action resolves?
5. What if no one calls processEpoch?

### 2. Generate schedule transaction

```cadence
// cadence/transactions/scheduler/schedule_{mechanic}.cdc
import "Scheduler"

transaction(epochsFromNow: UInt64, payload: {String: AnyStruct}) {
    let submitterAddress: Address
    prepare(signer: &Account) {
        self.submitterAddress = signer.address
    }
    execute {
        let id = Scheduler.scheduleAction(
            epochsFromNow: epochsFromNow,
            description: "{mechanic}",
            payload: payload,
            submitter: self.submitterAddress
        )
        log("Scheduled {mechanic} action ID: ".concat(id.toString()))
    }
}
```

### 3. Generate off-chain epoch bot

```typescript
// tools/epoch-bot.ts
import * as fcl from "@onflow/fcl"

async function checkAndProcessEpoch() {
  const blocksRemaining = await fcl.query({
    cadence: `import "Scheduler"
      access(all) fun main(): UInt64 { return Scheduler.blocksUntilNextEpoch() }`,
  })
  if (Number(blocksRemaining) === 0) {
    await fcl.mutate({
      cadence: `import "Scheduler"
        transaction { execute { Scheduler.processEpoch() } }`,
      limit: 999,
    })
    console.log("Epoch processed")
  }
}
checkAndProcessEpoch().catch(console.error)
```

### 4. Summary

Show epoch config, how to queue actions, bot setup, and resilience if bot is down.
