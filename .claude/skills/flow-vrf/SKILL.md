---
name: flow-vrf
description: "Add verifiable randomness (VRF) with commit/reveal to a game system. Generates the commit transaction, reveal transaction, and integration code for any game mechanic that needs fair, unbiasable randomness."
argument-hint: "[mechanic-name] e.g. 'loot-drop', 'card-draw', 'battle-outcome'"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, WebSearch
---

# /flow-vrf

Adds VRF commit/reveal randomness to a named game mechanic.

## Why Commit/Reveal?

`revertibleRandom()` is vulnerable: a player can abort a transaction if the result is bad,
then retry. Commit/reveal prevents this: the player commits *before* seeing the random value.

**Read first:** `docs/flow/vrf-developer-guide.md`, `docs/flow-reference/vrf-api.md`

## Steps

### 1. Understand the mechanic

Ask the user:
1. What game mechanic needs randomness? (e.g., loot drop, battle outcome, card shuffle)
2. Who triggers the randomness — the player, an NPC, or the game server?
3. What's the stakes level? (cosmetic/low, moderate, high/competitive)
4. How many random values are needed per interaction?
5. Is there an existing game contract to integrate with?

### 2. Confirm RandomVRF contract is deployed

```bash
flow scripts execute cadence/scripts/get_random_state.cdc --network emulator
```

If not deployed: `flow project deploy --network emulator`

### 3. Generate mechanic-specific commit transaction

Based on the mechanic name (e.g., "loot-drop"), generate:

```cadence
// cadence/transactions/vrf/commit_{mechanic}.cdc
// IMPORTANT: Capture signer.address in prepare — self.account is not accessible in execute.
import "RandomVRF"

transaction(secret: UInt256, gameSessionId: UInt64) {
    let playerAddress: Address
    prepare(player: &Account) {
        self.playerAddress = player.address
    }
    execute {
        RandomVRF.commit(
            secret: secret,
            gameId: gameSessionId,
            player: self.playerAddress
        )
        log("Committed to {mechanic} randomness for session ".concat(gameSessionId.toString()))
    }
}
```

Ask: "May I write this to `cadence/transactions/vrf/commit_{mechanic}.cdc`?"

### 4. Generate mechanic-specific reveal + resolution transaction

```cadence
// cadence/transactions/vrf/reveal_{mechanic}.cdc
import "RandomVRF"
// import your game contract here

transaction(secret: UInt256, gameSessionId: UInt64) {
    let playerAddress: Address
    prepare(player: &Account) {
        self.playerAddress = player.address
    }
    execute {
        let result = RandomVRF.reveal(
            secret: secret,
            gameId: gameSessionId,
            player: self.playerAddress
        )

        // {mechanic}-specific resolution:
        // Example for loot-drop — determine rarity tier
        let rarity: UInt64
        let roll = RandomVRF.boundedRandom(source: result, max: 100)
        if roll < 60 {
            rarity = 0  // Common
        } else if roll < 85 {
            rarity = 1  // Uncommon
        } else if roll < 97 {
            rarity = 2  // Rare
        } else {
            rarity = 3  // Legendary
        }

        log("Roll: ".concat(roll.toString()).concat(" — Rarity: ".concat(rarity.toString())))
        // TODO: call your game contract with the resolved rarity
    }
}
```

Show to user for approval before writing.

### 5. Generate FCL integration (if client exists)

```typescript
// src/flow/vrf/{mechanic}.ts
import * as fcl from "@onflow/fcl"

// Step 1: Generate a random secret client-side (never server-generated)
export function generateSecret(): bigint {
  const array = new Uint8Array(32)
  crypto.getRandomValues(array)
  return array.reduce((acc, val) => (acc << 8n) | BigInt(val), 0n)
}

// NOTE: Replace MECHANIC_PASCAL with PascalCase (e.g. LootDrop) and
//       {mechanic} filenames with snake_case (e.g. loot_drop) throughout.

// Step 2: Commit phase
export async function commitMECHANIC_PASCAL(secret: bigint, gameSessionId: number) {
  return fcl.mutate({
    cadence: `/* paste commit_{mechanic}.cdc contents here */`,
    args: (arg: any, t: any) => [
      arg(secret.toString(), t.UInt256),
      arg(gameSessionId.toString(), t.UInt64),
    ],
    limit: 999,
  })
}

// Step 3: Reveal phase (call after commit tx is sealed via fcl.tx(txId).onceSealed())
export async function revealMECHANIC_PASCAL(secret: bigint, gameSessionId: number) {
  return fcl.mutate({
    cadence: `/* paste reveal_{mechanic}.cdc contents here */`,
    args: (arg: any, t: any) => [
      arg(secret.toString(), t.UInt256),
      arg(gameSessionId.toString(), t.UInt64),
    ],
    limit: 999,
  })
}
```

Ask: "May I write this to `src/flow/vrf/{mechanic}.ts`?"

### 6. Write a test

Generate a Cadence test verifying the full commit/reveal cycle for this mechanic.

### 7. Summary

Show:
- Files written
- How the commit/reveal cycle works for this mechanic
- Key security guarantee: "The player cannot game the outcome because they commit before randomness is determined"
- Next step: wire the result into the game contract

## EVM Path (Solidity contracts on Flow EVM)

For Solidity contracts, use `FlowEVMVRF.sol` instead of `RandomVRF.cdc`.
The underlying randomness comes from the same Flow random beacon via the `cadenceArch` precompile.

**Same two phases apply:**
1. Player calls `vrf.commit(secret, gameId)` — stores hash commitment
2. Player calls `vrf.reveal(secret, gameId)` — verifies commitment, returns random result
3. Contract calls `vrf.boundedRandom(result, max)` — rejection-sampled bounded value

**When to use Cadence VRF vs EVM VRF:**

| Use Cadence `RandomVRF.cdc` | Use EVM `FlowEVMVRF.sol` |
|-----------------------------|--------------------------|
| Pure Cadence game logic | Solidity game contracts |
| NFT minting outcome | ERC-721 reveal |
| Cadence tournament brackets | EVM-based game mechanics |
| Scheduler-triggered actions | EVM loot box reveals |

**Never use `CADENCE_ARCH.revertibleRandom()` directly** — always use the commit/reveal wrapper.
The commit/reveal pattern is required on both paths for the same reason: validators can bias
`revertibleRandom()` by aborting unfavorable blocks. The commit locks the player in before
the random value is known; revealing after 1+ blocks breaks the bias window.
