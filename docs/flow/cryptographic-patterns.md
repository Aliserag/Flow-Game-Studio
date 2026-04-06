# Cryptographic Patterns for Flow Game Contracts

## Merkle Allowlists

Use Merkle trees to whitelist thousands of addresses with a single 32-byte root stored on-chain.

### How It Works

1. Build a Merkle tree off-chain from the list of allowed addresses
2. Store the root on-chain via admin transaction
3. Each user submits their proof path (log₂(n) hashes) to verify membership
4. Contract verifies using KECCAK_256 hash chaining

### Gas Efficiency

- Storing N addresses directly: O(N) storage
- Merkle tree: O(1) storage (just root), O(log N) verification gas

### Off-Chain Tool

```bash
npx ts-node cadence/scripts/crypto/generate_merkle_root.ts addresses.json proofs.json
```

## Blind Auctions (Commit/Reveal)

Prevent front-running in auctions by hiding bid amounts during the commit phase.

### Commit Phase

Bidder submits: `commitHash = keccak256(toBigEndianBytes(amount) || nonce)`

### Reveal Phase

Bidder submits plaintext `amount` and `nonce`. Contract verifies the hash matches.

### Security Properties

- Front-running resistant: no one can see bid amounts during commit phase
- Binding: bidder cannot change their bid amount after committing
- Private: bids are hidden until reveal window

## Hash Algorithms Available in Cadence

| Algorithm | Cadence Name | Notes |
|-----------|-------------|-------|
| SHA2-256 | `HashAlgorithm.SHA2_256` | Default for most uses |
| SHA3-256 | `HashAlgorithm.SHA3_256` | Flow default key hashing |
| KECCAK-256 | `HashAlgorithm.KECCAK_256` | EVM-compatible (use for cross-chain) |

## ZK-Readiness

Flow does not currently support native ZK proof verification at the VM level.
To prepare for future ZK integration:
- Use KECCAK_256 for all proof-related hashing (EVM-compatible)
- Keep verification logic isolated in dedicated contracts
- Use sparse Merkle trees where possible (easier to ZK-prove)
