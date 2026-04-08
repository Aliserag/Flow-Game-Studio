<p align="center">
  <h1 align="center">Flow Game Studio</h1>
  <p align="center">
    A complete game development studio for building on Flow blockchain —
    <br />
    production-ready smart contracts, 4 runnable example games, and 62 coordinated AI agents.
  </p>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href="cadence/contracts"><img src="https://img.shields.io/badge/contracts-20%2B-00EF8B" alt="20+ Contracts"></a>
  <a href="examples"><img src="https://img.shields.io/badge/example%20games-4-FF6B35" alt="4 Example Games"></a>
  <a href=".claude/agents"><img src="https://img.shields.io/badge/agents-62-blueviolet" alt="62 Agents"></a>
  <a href=".claude/skills"><img src="https://img.shields.io/badge/skills-72%2B-green" alt="72+ Skills"></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/built%20for-Claude%20Code-f5f5f5?logo=anthropic" alt="Built for Claude Code"></a>
</p>

> **Fork of [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)** — extends the base AI studio framework with a complete Flow blockchain layer: Cadence 1.0 smart contracts, FCL client patterns, walletless UX, and 4 production-grade example games.

---

## Why Flow for Games

Three problems kill most blockchain games. This project solves all three:

**1. Developers control their own RNG.** Flow's `RandomBeaconHistory` + commit/reveal means the randomness is sealed by the protocol before anyone can see it — including you. Nobody can cheat.

**2. Players need wallets and gas money just to start.** Flow's HybridCustody + transaction sponsorship means players log in with email. You pay their gas. From the player's perspective: it's just a game.

**3. Everyone reinvents the wheel.** This repo ships 20+ production-ready Cadence 1.0 contracts covering every pattern a game needs — VRF, NFTs, marketplace, tournaments, season passes, governance, EVM bridge, and more.

---

## Table of Contents

- [Flow Example Games](#flow-example-games)
- [Smart Contract Library](#smart-contract-library)
- [Flow Skills](#flow-skills)
- [Studio Framework](#studio-framework)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [License](#license)

---

## Flow Example Games

Four runnable games, each demonstrating a different Flow capability — Cadence contracts, TypeScript/FCL client, and passing test suite included.

### 🪙 Coin Flip — Provably Fair VRF
`examples/coin-flip/`

The clearest demo of Flow's randomness guarantee. Commit/reveal over `RandomBeaconHistory` — no one can predict or manipulate the outcome, including the developer. Sponsored transactions: players never pay gas.

**Demonstrates:** Commit/reveal VRF · Transaction sponsorship · FCL integration

### ⚔️ NFT Battler — Composable NFT Attachments
`examples/nft-battler/`

Walletless onboarding: the app creates a Flow account for the player automatically (no wallet install). Fighter NFTs gain stats from PowerUp attachments — a Cadence-native composability pattern impossible to replicate cleanly in Solidity.

**Demonstrates:** HybridCustody (walletless) · NFT attachments · On-chain battle records

### ♟️ Chess on Flow — On-Chain Game State
`examples/chess-game/`

Fully playable chess with all moves recorded on-chain. Exercises the full contract library: GameNFT, NFT Attachments, EmergencyPause, VRF, MetadataViews. Sponsored transactions mean players never touch gas.

**Demonstrates:** On-chain game state · Sponsored transactions · Multi-system contract composition

### 🏆 Prize Pool — EVM + Cadence in One Transaction
`examples/prize-pool/`

The most technically unique demo in this repo. MetaMask players deposit Solidity-side (Flow EVM). A single Cadence transaction uses `RandomBeaconHistory` to pick the winner, calls the Solidity contract via COA, releases funds, and mints a trophy NFT — all atomically. No other chain can do this.

**Demonstrates:** Flow EVM bridge · COA (Cadence-Owned Accounts) · Hybrid Solidity + Cadence · Atomic cross-layer transactions

---

## Smart Contract Library

20+ production Cadence 1.0 contracts. All tested with `flow test`.

| Category | Contracts |
|----------|-----------|
| **Primitives** | `GameNFT`, `GameToken`, `GameItem`, `GameAsset` |
| **Game Systems** | `RandomVRF`, `Tournament`, `Achievement`, `Crafting`, `StateChannel` |
| **Economy** | `Marketplace`, `BondingCurve`, `StakingPool` |
| **Live Ops** | `SeasonPass`, `DynamicPricing`, `FlashSale` |
| **Governance** | `Governance` (player DAO), `Multisig` |
| **Safety** | `EmergencyPause`, `VersionRegistry` |
| **EVM Bridge** | `EVMBridge.cdc`, `EVMSafe.sol`, `FlowEVMVRF.sol`, `ZKVerifier.sol` |

---

## Flow Skills

Flow-specific slash commands on top of the base studio framework:

| Skill | Description |
|-------|-------------|
| `/flow-vrf` | Add commit/reveal VRF randomness to a game mechanic |
| `/flow-nft` | Create a game NFT contract from the `GameNFT` base |
| `/flow-entitlements` | Design Cadence 1.0 entitlement structures |
| `/flow-contract` | Deploy or upgrade a Cadence contract |
| `/flow-audit` | Security audit Cadence contracts for 1.0 compliance |
| `/flow-economy` | Design a Flow token economy |
| `/flow-scheduled` | Add epoch-based scheduled mechanics |
| `/flow-amm` | Implement an AMM / bonding curve |
| `/flow-attachments` | Design NFT attachment (composability) systems |
| `/flow-compliance` | Review contracts for legal/compliance considerations |

All Flow contracts must pass `flow test` before commit. A `validate-cadence.sh` hook automatically checks for Cadence 0.x patterns (`pub`/`priv`), hardcoded addresses, and force-unwrap on capabilities on every commit.

---

## Studio Framework

The base [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) framework is fully intact and auto-synced daily from upstream.

| Category | Count | Description |
|----------|-------|-------------|
| **Agents** | 62 | Specialized subagents: directors, department leads, and specialists across design, programming, art, audio, narrative, QA, and production |
| **Skills** | 72+ | Slash commands for every workflow phase + Flow-specific skills |
| **Hooks** | 13 | Commit/push validation, asset checks, session lifecycle, agent audit trail, Cadence pattern enforcement |
| **Rules** | 11 | Path-scoped coding standards auto-enforced by file location |
| **Templates** | 39 | GDDs, UX specs, ADRs, sprint plans, HUD design, accessibility docs |

### Studio Hierarchy

```
Tier 1 — Directors
  creative-director    technical-director    producer

Tier 2 — Department Leads
  game-designer        lead-programmer       art-director
  audio-director       narrative-director    qa-lead
  release-manager      localization-lead

Tier 3 — Specialists
  gameplay-programmer  engine-programmer     ai-programmer
  network-programmer   tools-programmer      ui-programmer
  systems-designer     level-designer        economy-designer
  technical-artist     sound-designer        writer
  world-builder        ux-designer           prototyper
  performance-analyst  devops-engineer       analytics-engineer
  security-engineer    qa-tester             accessibility-specialist
  live-ops-designer    community-manager
```

### Engine Specialists

| Engine | Lead Agent | Sub-Specialists |
|--------|-----------|-----------------|
| **Godot 4** | `godot-specialist` | GDScript, Shaders, GDExtension, C# |
| **Unity** | `unity-specialist` | DOTS/ECS, Shaders/VFX, Addressables, UI Toolkit |
| **Unreal Engine 5** | `unreal-specialist` | GAS, Blueprints, Replication, UMG/CommonUI |

### Full Slash Command List

**Onboarding & Navigation**
`/start` `/help` `/project-stage-detect` `/setup-engine` `/adopt`

**Game Design**
`/brainstorm` `/map-systems` `/design-system` `/quick-design` `/review-all-gdds` `/propagate-design-change`

**Architecture**
`/create-architecture` `/architecture-decision` `/architecture-review` `/create-control-manifest`

**Stories & Sprints**
`/create-epics` `/create-stories` `/dev-story` `/sprint-plan` `/sprint-status` `/story-readiness` `/story-done` `/estimate`

**Reviews & Analysis**
`/design-review` `/code-review` `/balance-check` `/content-audit` `/scope-check` `/perf-profile` `/tech-debt` `/gate-check` `/consistency-check`

**QA & Testing**
`/qa-plan` `/smoke-check` `/soak-test` `/regression-suite` `/test-setup` `/test-helpers` `/test-evidence-review` `/test-flakiness` `/skill-test`

**Production**
`/milestone-review` `/retrospective` `/bug-report` `/bug-triage` `/reverse-document` `/playtest-report`

**Release**
`/release-checklist` `/launch-checklist` `/changelog` `/patch-notes` `/hotfix`

**Team Orchestration**
`/team-combat` `/team-narrative` `/team-ui` `/team-release` `/team-polish` `/team-audio` `/team-level` `/team-live-ops` `/team-qa`

**Flow Blockchain**
`/flow-vrf` `/flow-nft` `/flow-entitlements` `/flow-contract` `/flow-audit` `/flow-economy` `/flow-scheduled` `/flow-amm` `/flow-attachments` `/flow-compliance`

---

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
- [Flow CLI](https://docs.onflow.org/flow-cli/install/) v2.x (for running contracts and example games)
- Node.js 18+ (for example game clients)

### Clone and Run an Example Game

```bash
git clone https://github.com/Aliserag/Flow-Game-Studio.git
cd Flow-Game-Studio

# Run the Coin Flip demo (easiest starting point)
cd examples/coin-flip
flow emulator start          # terminal 1
flow project deploy          # terminal 2
cd client && npm install && npm run dev  # terminal 3
```

For full deployment instructions see `docs/flow/testnet-deployment-guide.md`.

### Start a New Game Project

```bash
claude  # open Claude Code in the repo root
/start  # guided onboarding: asks where you are, routes you to the right workflow
```

Or jump directly:
- `/brainstorm` — explore game ideas from scratch
- `/setup-engine godot 4.6` — configure your engine
- `/flow-vrf` — add VRF to an existing mechanic

---

## Project Structure

```
CLAUDE.md                           # Master configuration
.claude/
  agents/                           # 62 agent definitions
  skills/                           # 72+ slash commands (incl. Flow skills)
  hooks/                            # 13 hook scripts
  rules/                            # 11 path-scoped coding standards
cadence/
  contracts/                        # 20+ Cadence 1.0 smart contracts
    core/                           # GameNFT, GameToken, GameItem, GameAsset
    systems/                        # RandomVRF, Tournament, Marketplace, etc.
    evm/                            # EVMBridge, EVMSafe, FlowEVMVRF, ZKVerifier
    governance/                     # Governance, Multisig
    liveops/                        # SeasonPass, DynamicPricing, FlashSale
  transactions/                     # Signed transactions (mutate chain state)
  scripts/                          # Read-only scripts (query chain state)
  tests/                            # Cadence test suite (flow test)
examples/
  coin-flip/                        # VRF commit/reveal + sponsored transactions
  nft-battler/                      # Walletless onboarding + NFT attachments
  chess-game/                       # On-chain game state + multi-contract
  prize-pool/                       # EVM + Cadence hybrid, atomic cross-layer
docs/
  flow-reference/                   # Version-pinned Cadence 1.0 API snapshots
  flow/                             # Deployment guides, pattern docs
  engine-reference/                 # Engine API snapshots (Godot 4.6)
src/                                # Your game source code
design/                             # GDDs, narrative docs, level designs
tests/                              # Game test suites
production/                         # Sprint plans, milestones, release tracking
```

---

## Upstream Sync

This fork auto-syncs with [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) daily via `.github/workflows/sync-upstream.yml`:
- **Clean merge** → auto-pushed to `main`
- **Conflicts** → PR opened for manual resolution

Flow-specific additions are never submitted upstream. This is a standalone fork.

---

## License

MIT License. Upstream copyright (c) 2026 Donchitos. See [LICENSE](LICENSE) for details.
