# Coin Flip on Flow

Provably fair coin flip using Flow's RandomBeaconHistory VRF and sponsored transactions.

**Demonstrates:**
- Commit/reveal randomness — nobody can cheat, including the developer
- Transaction sponsorship — players never pay gas

## How it works

1. Player commits `SHA3_256(secret + address)` to chain, recording the current block height N
2. Block N's randomness is sealed by the Flow protocol (immutable after 1 block)
3. Player reveals secret — contract fetches `RandomBeaconHistory[N]`, XORs with secret, modulo 2 → heads or tails
4. The sponsor service pays gas for both commit and reveal transactions

```
Player                      CoinFlip Contract              RandomBeaconHistory
  │                               │                               │
  │── commit(hash, choice) ──────►│                               │
  │◄─ flipId ─────────────────────│ stores {hash, blockHeight N}  │
  │                               │                               │
  │   (wait ≥ 1 block)            │                               │
  │                               │                               │
  │── reveal(flipId, secret) ────►│── sourceOfRandomness(N) ─────►│
  │                               │◄─ randomValue ────────────────│
  │◄─ won/lost ───────────────────│ XOR → result                  │
```

## Quickstart (3 terminals)

**Terminal 1 — Flow Emulator:**
```bash
cd examples/coin-flip
flow emulator
```

**Terminal 2 — Deploy contracts:**
```bash
cd examples/coin-flip
flow project deploy --update --network emulator
```

**Terminal 3 — Client (Vite dev server):**
```bash
cd examples/coin-flip/client
npm install
npm run dev
```

Open http://localhost:5173, connect the dev wallet, and flip!

**Optional Terminal 4 — Sponsor service (gasless):**
```bash
cd examples/coin-flip/sponsor-service
npm install
npm run start
```

## Run contract tests

```bash
cd examples/coin-flip
flow test cadence/tests/CoinFlip_test.cdc
```

## TypeScript typecheck

```bash
cd examples/coin-flip/client
npm install
npx tsc --noEmit
```

## Project structure

```
examples/coin-flip/
├── flow.json                         # Flow project config
├── cadence/
│   ├── contracts/CoinFlip.cdc        # Main contract (commit/reveal VRF)
│   ├── transactions/
│   │   ├── commit_flip.cdc           # Submit commitment hash
│   │   ├── reveal_flip.cdc           # Reveal secret and resolve flip
│   │   └── setup_account.cdc         # No-op setup (gasless onboarding hook)
│   ├── scripts/
│   │   ├── get_flip.cdc              # Query single flip
│   │   └── get_all_flips.cdc         # Query all flips for a player
│   └── tests/CoinFlip_test.cdc       # Cadence 1.0 test suite
├── client/                           # Vite + TypeScript frontend
│   └── src/
│       ├── fcl-config.ts             # FCL emulator configuration
│       ├── sponsorship.ts            # Gasless tx wrapper
│       └── main.ts                   # UI logic
└── sponsor-service/
    └── server.ts                     # Express payer service
```

## Deploying to testnet

1. Update `flow.json` — set your testnet account address and key index
2. Update `client/src/fcl-config.ts` — set `accessNode.api` to testnet endpoint
3. Remove `RandomBeaconHistory` from deployments (it is a protocol contract at `0x8c5303eaa26202d6`)
4. Run: `flow project deploy --network testnet`
