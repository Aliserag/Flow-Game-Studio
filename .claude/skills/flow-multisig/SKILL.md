# /flow-multisig

Configure and operate multisig for Flow game admin operations.

## Usage

- `/flow-multisig setup-cadence --owners 3 --threshold 2` — generate key setup commands
- `/flow-multisig setup-evm --owners "0xA,0xB,0xC" --threshold 2` — deploy EVMSafe
- `/flow-multisig sign <tx.rlp> --signer key-name` — add signature to unsigned tx
- `/flow-multisig status <tx.rlp>` — check how many signatures accumulated

## Cadence vs EVM

**Cadence transactions**: Use Flow protocol-level multi-key. No contract needed.
Generate `flow transactions build` → `flow transactions sign` (×N) → `flow transactions send-signed`.

**EVM calls (COA, Solidity contracts)**: Use `EVMSafe.sol`.
Deploy via `flow transactions send cadence/transactions/evm/deploy_safe.cdc`.

## Mainnet Admin Key Checklist

- [ ] 3 keys generated on separate hardware wallets
- [ ] Each key weight = 500 (need 2 of 3 to reach threshold)
- [ ] Original setup key revoked (weight set to 0)
- [ ] Keys held by different people in different locations
- [ ] EVMSafe deployed with same owners for EVM-side admin
- [ ] EVMSafe address stored in `docs/flow/deployed-contracts.md`
