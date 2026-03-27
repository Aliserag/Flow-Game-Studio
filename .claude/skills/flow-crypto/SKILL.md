# /flow-crypto

Generate advanced cryptographic contract patterns: Merkle allowlists, blind auctions, and ZK-readiness scaffolds.

## Usage

- `/flow-crypto merkle --list-name "Season3Whitelist" --addresses addresses.json`
- `/flow-crypto blind-auction --name "LegendaryArmor" --min-bid 100 --reveal-blocks 1000`

## Merkle Allowlist Workflow

1. Collect allowlist addresses into `addresses.json`
2. Run: `npx ts-node cadence/scripts/crypto/generate_merkle_root.ts addresses.json proofs.json`
3. Send admin transaction with the `rootBytes` array from `proofs.json`
4. Share individual proof + pathIndices with each user (via API or airdrop metadata)
5. User submits proof in transaction — contract verifies on-chain

## Blind Auction Workflow

1. Bidders commit: `keccak256(amount || nonce)` stored on-chain
2. Reveal window opens after `commitDeadlineBlock`
3. Bidders reveal: submit `amount` + `nonce`, contract verifies hash matches
4. Highest valid reveal wins
5. Losers get refund; winner pays bid amount

## ZK Readiness Notes

Flow does not currently have native ZK verification at the VM level.
Prepare for future integration by:
- Keeping proof verification logic in a dedicated contract
- Using `HashAlgorithm.KECCAK_256` for leaf hashing (EVM-compatible)
- Structuring state as sparse Merkle trees where possible
