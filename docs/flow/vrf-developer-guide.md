# VRF Developer Guide — Adding Fair Randomness to Flow Games

## TL;DR

| Situation | Use |
|-----------|-----|
| Cosmetic/low-stakes (coin flip, visual effect) | `revertibleRandom()` |
| Any competitive mechanic, loot with value, battle outcome | Commit/Reveal via `RandomVRF` |

## How Commit/Reveal Works

```
Turn 1 (Player commits):
  Player generates secret = crypto.getRandomValues(32 bytes) — CLIENT SIDE
  Player calls commit_move.cdc(secret, gameId)
  Contract stores hash(secret, player, gameId) + blockHeight

Turn 2 (After >=1 block — Player reveals):
  Player calls reveal_move.cdc(secret, gameId)
  Contract fetches RandomBeaconHistory[commitBlockHeight].value
  result = keccak256(beacon || secret)
  Game resolves using result
```

## Why Client-Side Secret Generation Matters

The secret MUST be generated client-side, in the player's browser:
- Server-generated secrets = server knows result before player
- Blockchain-visible secrets = anyone can front-run
- `crypto.getRandomValues()` = cryptographically secure, invisible until reveal

## Implementation Checklist

- [ ] `RandomVRF` contract deployed (`flow project deploy`)
- [ ] Secret generated with `crypto.getRandomValues()` (not `Math.random()`)
- [ ] Secret stored locally until reveal (sessionStorage or memory)
- [ ] Commit transaction sealed before showing "waiting for result" UI
- [ ] Reveal transaction called after commit is sealed (use FCL event watching)
- [ ] Result bounded with `RandomVRF.boundedRandom(result, max)` — not naive modulo

## Common Mistakes

- `secret = Math.random()` — predictable, not secure
- Committing and revealing in the same transaction — defeats the purpose
- Using `revertibleRandom()` for loot with monetary value — biasable
- Not waiting for commit tx to seal before revealing — race condition

## Quick Start

```typescript
import { generateSecret, commitLootDrop, revealLootDrop } from "./flow/vrf/loot-drop"

// On "Open Chest" click:
const secret = generateSecret()
sessionStorage.setItem("lootSecret", secret.toString())
const commitTx = await commitLootDrop(secret, chestId)
await fcl.tx(commitTx).onceSealed()

// After seal — reveal:
const savedSecret = BigInt(sessionStorage.getItem("lootSecret")!)
const revealTx = await revealLootDrop(savedSecret, chestId)
// Contract emits Revealed event with rarity — listen for it
```
