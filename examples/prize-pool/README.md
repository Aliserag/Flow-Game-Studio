# Prize Pool Wager on Flow

The only wagering game that can exist: Cadence VRF + EVM deposits + Cadence NFT trophies — in one atomic transaction.

## What makes this unique to Flow

Every other EVM-compatible chain forces you to choose: Solidity OR a native language. Flow does both **simultaneously in the same transaction**:

| Layer | Technology | Who interacts |
|-------|-----------|---------------|
| Deposits | Solidity ERC-20 contract on Flow EVM | MetaMask players |
| Ownership | Cadence Owned Account (COA) | Cadence-side control |
| Randomness | `RandomBeaconHistory` VRF | Cadence picks winner |
| Prize release | Cadence calls `closeRound(winner)` via COA | Same Cadence tx |
| Trophy | `WinnerTrophy` Cadence NFT minted | Same Cadence tx |

## How it works

```
Players                    Flow EVM                   Cadence
   │                          │                           │
   │──deposit(amount)────────►│                           │
   │                    PrizePool.sol                     │
   │                    (owned by COA)                    │
   │                          │                           │
                              │◄──closeRound transaction──┤
                              │    1. VRF picks winner     │
                              │    2. COA calls closeRound │
                              │    3. ERC-20 released      │
                              │    4. NFT minted  ────────►│
                                                  WinnerTrophy NFT
```

1. Players deposit ERC-20 tokens from MetaMask into `PrizePool.sol`
2. Admin sends a Cadence transaction:
   - Fetches depositor list (passed in as argument from EVM query)
   - Uses `RandomBeaconHistory.sourceOfRandomness()` to pick winner
   - Calls `PrizePool.closeRound(winner)` via the COA — prize released on EVM
   - Mints a `WinnerTrophy` NFT to the winner's Cadence account
3. Winner receives: ERC-20 prize (EVM side) + NFT trophy (Cadence side)

## Quickstart (3 terminals)

```bash
# Terminal 1: Flow emulator (Cadence RPC :8888, gRPC :3569)
flow emulator

# Terminal 2: Dev wallet (FCL auth)
flow dev-wallet

# Terminal 3: Deploy contracts + start client
cd examples/prize-pool
npm install
npm run compile                    # compile Solidity
bash scripts/deploy-cadence.sh     # deploy Cadence contracts + set up COA
npm run deploy-evm-cadence         # deploy MockToken + PrizePool via COA
# → copy the printed addresses into client/src/fcl-config.ts
cd client && npm install && npm run dev   # http://localhost:3000
```

> **No `flow evm gateway` needed.** EVM contracts are deployed from Cadence via the
> COA (`coa.deploy()`), making the COA the contract `owner()` directly — no
> `transferOwnership` step required.

## Run tests

```bash
# Solidity tests (tests PrizePool.sol in isolation)
cd examples/prize-pool
npm install
npm test

# Cadence tests (tests WinnerTrophy NFT in isolation)
cd examples/prize-pool
flow test cadence/tests/WinnerTrophy_test.cdc
```

## Architecture

### Contracts

| Contract | Layer | Purpose |
|----------|-------|---------|
| `PrizePool.sol` | Flow EVM (Solidity) | Accepts ERC-20 deposits, owned by COA |
| `MockToken.sol` | Flow EVM (Solidity) | Test ERC-20 token |
| `WinnerTrophy.cdc` | Cadence | NFT minted to round winners |
| `PrizePoolOrchestrator.cdc` | Cadence | VRF + COA call + trophy mint |

### Key: Cadence Owned Account (COA)

A COA is a Flow-native account that has both a Cadence identity (storage, capabilities)
and an EVM address (can be funded with FLOW, own EVM contracts). This lets Cadence code
call Solidity functions — the `PrizePool.sol` `owner()` is the COA's EVM address.

```
Cadence account (f8d6e0586b0a20c7)
  └── storage[/storage/evm] = COA
        └── EVM address = 0x... (owner of PrizePool.sol)
```

### ABI encoding in PrizePoolOrchestrator.cdc

The `closeRound(address)` call is encoded manually:
```
bytes = [0x95, 0x3e, 0xe6, 0x0d]  // keccak256("closeRound(address)")[0:4]
      + [0x00 × 12]                 // 12 zero-padding bytes
      + [winner address bytes]      // 20 bytes
```

This is the standard Ethereum ABI encoding for a function taking one `address` argument.

## Directory structure

```
examples/prize-pool/
├── contracts/          Solidity (PrizePool.sol, MockToken.sol)
├── cadence/
│   ├── contracts/      WinnerTrophy.cdc, PrizePoolOrchestrator.cdc
│   ├── transactions/   setup_coa, close_round, setup_trophy_collection
│   ├── scripts/        get_coa_address, get_round_info, get_trophies
│   └── tests/          WinnerTrophy_test.cdc
├── test/               PrizePool.test.ts (Hardhat)
├── scripts/            deploy-evm-cadence.mjs, deploy-cadence.sh, deploy-evm.ts
├── client/             TypeScript/Vite UI (MetaMask + FCL)
├── tools/              deploy.sh
├── flow.json
├── hardhat.config.ts
└── package.json
```
