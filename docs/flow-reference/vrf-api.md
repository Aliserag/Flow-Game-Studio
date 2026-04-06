# Flow VRF / Randomness API Reference

## Available Randomness Sources

### 1. revertibleRandom() — Simple Use Cases

Available in **transaction** context only (not scripts).

```cadence
transaction {
    execute {
        // WARNING: revertible — post-condition abort can bias result.
        // Use ONLY when outcome doesn't affect whether tx succeeds.
        let rand: UInt64 = revertibleRandom()
        let roll = rand % 6 + 1  // 1-6 dice roll
    }
}
```

**When to use**: Low-stakes RNG (cosmetic drops, non-competitive rewards).
**When NOT to use**: High-stakes outcomes a player controls reverting on.

### 2. RandomBeaconHistory — Commit/Reveal (Recommended for Games)

The secure pattern: commit in block N, reveal using block N's beacon in block N+1+.

```cadence
import "RandomBeaconHistory"

// REVEAL PHASE: called after commit block is finalized
transaction(commitBlockHeight: UInt64, secret: UInt256) {
    execute {
        // Get the random source for the committed block
        let sourceOfRandomness = RandomBeaconHistory.sourceOfRandomness(
            atBlockHeight: commitBlockHeight
        )
        // XOR with player secret for unpredictability
        let randomValue = sourceOfRandomness.value ^ secret
        let result = randomValue % 100  // 0-99
    }
}
```

**RandomBeaconHistory contract address:**
- Testnet: `0x8c5303eaa26202d6`
- Mainnet: `0xd7431fd358660d73`

## Commit/Reveal Pattern Overview

```
Block N:   Player sends commit transaction
           Stores hash(secret + playerAddress + gameId) on-chain
           Records commitBlockHeight = N

Block N+1: Block N's randomness is finalized (cannot change)

Block N+1+: Player sends reveal transaction
            Passes secret, game fetches RandomBeaconHistory[N]
            Derives result = f(beacon[N], secret)
```

## Deriving Bounded Random Values

```cadence
// From a UInt256 source, get a value in [0, max)
fun boundedRandom(source: UInt256, max: UInt64): UInt64 {
    // Rejection sampling for unbiased results when max is not a power of 2
    let maxUInt256 = UInt256.max
    let threshold = maxUInt256 - (maxUInt256 % UInt256(max))
    var r = source
    while r >= threshold {
        // In practice derive new r from source (hash-based)
        r = r >> 1
    }
    return UInt64(r % UInt256(max))
}
```
