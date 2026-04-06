# NFT Battler on Flow

Walletless onboarding + NFT composability via Cadence attachments.

**Demonstrates:**
- App-managed accounts (HybridCustody concept) — no wallet needed to start
- NFT attachments — PowerUp NFTs physically attach to Fighter NFTs, boosting stats
- On-chain battle records stored directly on the NFT resource itself

## How it works

1. Open game → app creates a Flow account for you (no wallet needed)
2. App mints a free starter Fighter NFT to your account
3. Equip a PowerUp NFT (Sword / Shield / Spellbook / Gem) — it attaches to your Fighter
4. Battle other fighters — wins/losses are recorded on-chain on the NFT itself
5. Export your account to any Flow wallet when ready

## Combat System (RPS)

| Class | Beats | Loses to |
|-------|-------|----------|
| **Attack** (⚔) | Defense | Magic |
| **Defense** (🛡) | Magic | Attack |
| **Magic** (✨) | Attack | Defense |

Same class? Higher `effectivePower` wins. Exact tie → challenger wins.

`effectivePower = basePower + PowerUp.Boost.bonusPower (if attached)`

## Quickstart (2 terminals)

**Terminal 1 — Start the emulator:**
```bash
cd examples/nft-battler
flow emulator
```

**Terminal 2 — Deploy contracts and start the client:**
```bash
cd examples/nft-battler
flow project deploy --update --network emulator

# Mint some fighters for testing
flow transactions send cadence/transactions/setup_account.cdc \
  --signer emulator-account --network emulator

flow transactions send cadence/transactions/mint_starter.cdc \
  f8d6e0586b0a20c7 "Blaze" 0 50 \
  --signer emulator-account --network emulator

# Start the client
cd client && npm install && npm run dev
```

Open http://localhost:5174

## Run tests

```bash
cd examples/nft-battler
flow test cadence/tests/NFTBattler_test.cdc
```

## TypeScript type check

```bash
cd examples/nft-battler/client
npx tsc --noEmit
```

## Directory structure

```
examples/nft-battler/
├── flow.json                           ← Contract aliases + deployment config
├── package.json                        ← npm scripts (test, dev, deploy)
├── cadence/
│   ├── contracts/
│   │   ├── Fighter.cdc                 ← NFT with base stats + mutable W/L record
│   │   ├── PowerUp.cdc                 ← Attachment NFT that boosts Fighter stats
│   │   └── BattleArena.cdc             ← RPS battle logic
│   ├── transactions/
│   │   ├── setup_account.cdc           ← Create Fighter + PowerUp collections
│   │   ├── mint_starter.cdc            ← Admin mints a free Fighter
│   │   ├── mint_powerup.cdc            ← Admin mints a PowerUp
│   │   ├── attach_powerup.cdc          ← Consume PowerUp → attach Boost to Fighter
│   │   └── battle.cdc                  ← Battle two fighters (same account)
│   ├── scripts/
│   │   ├── get_fighter.cdc             ← Single fighter details
│   │   ├── get_fighters.cdc            ← All fighters for an account
│   │   └── get_battle_record.cdc       ← W/L stats for a fighter
│   └── tests/
│       └── NFTBattler_test.cdc         ← Cadence 1.0 Testing Framework tests
├── client/
│   ├── index.html                      ← Game UI with fighter cards + battle UI
│   └── src/
│       ├── fcl-config.ts               ← FCL emulator configuration
│       └── main.ts                     ← App logic: walletless + FCL + battle
└── tools/
    └── deploy.sh                       ← One-command emulator deploy
```

## Contract architecture

### Fighter.cdc

- Implements `NonFungibleToken` with `CombatClass` enum (Attack/Defense/Magic)
- `basePower` is immutable (set at mint); `wins`/`losses` are mutable via `BattleRecorder` entitlement
- `effectivePower()` reads `self[PowerUp.Boost]` — the Cadence attachment — to add bonus power
- `Minter` resource held by deployer account; `FighterMinter` entitlement required to mint

### PowerUp.cdc

- Two components:
  1. `PowerUp.NFT` — a standalone NFT stored in a collection before being consumed
  2. `PowerUp.Boost` — a Cadence `attachment` for `NonFungibleToken.NFT` that travels with the Fighter
- `createBoostAttachment()` on the NFT creates the attachment; the NFT is then destroyed
- `PowerUpType` enum: Sword (Attack), Shield (Defense), Spellbook (Magic), Gem (all)

### BattleArena.cdc

- Pure logic contract — no storage, no admin resource
- `battle()` accepts two `auth(Fighter.BattleRecorder) &Fighter.NFT` references
- RPS formula: `(challengerClass + 1) % 3 == opponentClass` → challenger wins

## HybridCustody in production

This example simulates the HybridCustody concept with a client-side keypair stored in
`localStorage`. In a production deployment:

1. User visits the game — no wallet required
2. Client generates a P-256 keypair
3. Client calls your sponsor-service API: `POST /create-account { publicKey }`
4. Sponsor-service uses `HybridCustody` contracts (deployed on Flow mainnet at
   `0xd8a7e05a7ac670c0` / `0x294e44e1ec6993c6`) to create a custodial account funded
   with a small FLOW balance for gas
5. User plays — the app signs transactions using the stored private key
6. "Export to wallet" gives the user their private key to import into Blocto / Dapper / etc.

See [Flow HybridCustody docs](https://developers.flow.com/build/guides/account-linking/hybrid-custody)
for the full production contract integration.
