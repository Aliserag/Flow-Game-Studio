<p align="center">
  <h1 align="center">Flow Game Studio</h1>
  <p align="center">
    Turn a single Claude Code session into a full game development studio — with Flow blockchain built in.
    <br />
    62 agents. 72+ skills. 20+ smart contracts. 4 runnable example games.
  </p>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License"></a>
  <a href=".claude/agents"><img src="https://img.shields.io/badge/agents-62-blueviolet" alt="62 Agents"></a>
  <a href=".claude/skills"><img src="https://img.shields.io/badge/skills-72%2B-green" alt="72+ Skills"></a>
  <a href=".claude/hooks"><img src="https://img.shields.io/badge/hooks-13-orange" alt="13 Hooks"></a>
  <a href=".claude/rules"><img src="https://img.shields.io/badge/rules-11-red" alt="11 Rules"></a>
  <a href="cadence/contracts"><img src="https://img.shields.io/badge/contracts-20%2B-00EF8B" alt="20+ Contracts"></a>
  <a href="examples"><img src="https://img.shields.io/badge/example%20games-4-FF6B35" alt="4 Example Games"></a>
  <a href="https://docs.anthropic.com/en/docs/claude-code"><img src="https://img.shields.io/badge/built%20for-Claude%20Code-f5f5f5?logo=anthropic" alt="Built for Claude Code"></a>
</p>

> **Fork of [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)** — the full AI studio framework extended with a complete Flow blockchain layer: Cadence 1.0 smart contracts, FCL client patterns, walletless UX, and 4 production-grade example games.

---

## Why This Exists

Building a game solo with AI is powerful — but a single chat session has no structure. No one stops you from hardcoding magic numbers, skipping design docs, or writing spaghetti code. There's no QA pass, no design review, no one asking "does this actually fit the game's vision?"

**Flow Game Studio** solves this by giving your AI session the structure of a real studio. Instead of one general-purpose assistant, you get 62 specialized agents organized into a studio hierarchy — directors who guard the vision, department leads who own their domains, and specialists who do the hands-on work.

And for teams building on Flow blockchain, it goes further: every contract pattern you'll need is already written, tested, and documented — from commit/reveal VRF to hybrid EVM+Cadence transactions.

---

## Table of Contents

- [What's Included](#whats-included)
- [Flow Blockchain Layer](#flow-blockchain-layer)
  - [Example Games](#example-games)
  - [Smart Contract Library](#smart-contract-library)
  - [Flow Skills](#flow-skills)
- [Studio Framework](#studio-framework)
  - [Studio Hierarchy](#studio-hierarchy)
  - [Slash Commands](#slash-commands)
  - [Automated Safety](#automated-safety)
  - [Path-Scoped Rules](#path-scoped-rules)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Design Philosophy](#design-philosophy)
- [Customization](#customization)
- [Platform Support](#platform-support)
- [Upstream Sync](#upstream-sync)
- [License](#license)

---

## What's Included

| Category | Count | Description |
|----------|-------|-------------|
| **Agents** | 62 | Specialized subagents across design, programming, art, audio, narrative, QA, and production |
| **Skills** | 72+ | Slash commands for every workflow phase — plus Flow-specific blockchain skills |
| **Hooks** | 13 | Automated validation on commits, pushes, asset changes, session lifecycle, agent audit trail, and Cadence pattern enforcement |
| **Rules** | 11 | Path-scoped coding standards enforced when editing gameplay, engine, AI, UI, network code, and more |
| **Templates** | 39 | Document templates for GDDs, UX specs, ADRs, sprint plans, HUD design, accessibility, and more |
| **Contracts** | 20+ | Production Cadence 1.0 smart contracts: VRF, NFTs, marketplace, governance, EVM bridge, and more |
| **Example Games** | 4 | Runnable end-to-end demos: coin flip, NFT battler, chess, prize pool |

---

## Flow Blockchain Layer

### Example Games

Four runnable games, each demonstrating a different Flow capability. Every example includes Cadence contracts, a TypeScript/FCL client, and a passing test suite.

#### 🪙 Coin Flip — Provably Fair VRF
`examples/coin-flip/`

The clearest demo of Flow's randomness guarantee. Players commit a secret hash; Flow's `RandomBeaconHistory` seals the randomness for that block before anyone can see it. The reveal is deterministic and verifiable on-chain — nobody can cheat, including the developer. Sponsored transactions mean players never pay gas.

**Demonstrates:** Commit/reveal VRF · Transaction sponsorship · FCL React integration

---

#### ⚔️ NFT Battler — Composable NFT Attachments
`examples/nft-battler/`

Walletless onboarding: the app creates a Flow account automatically — no wallet install required. Fighter NFTs gain stats from PowerUp attachments, a Cadence-native composability pattern that's impossible to replicate cleanly in Solidity. Wins and losses are recorded directly on the NFT resource on-chain.

**Demonstrates:** HybridCustody (walletless) · NFT attachments · On-chain battle records

---

#### ♟️ Chess on Flow — On-Chain Game State
`examples/chess-game/`

Fully playable chess with every move recorded on-chain. Exercises the full contract library simultaneously: GameNFT, NFT Attachments, EmergencyPause, VRF, and MetadataViews. Sponsored transactions mean players never touch gas.

**Demonstrates:** On-chain game state · Multi-contract composition · Emergency pause · Sponsored transactions

---

#### 🏆 Prize Pool — EVM + Cadence in One Transaction
`examples/prize-pool/`

The most technically unique demo in this repo — and only possible on Flow. MetaMask players deposit Solidity-side (Flow EVM). A single Cadence transaction uses `RandomBeaconHistory` to pick the winner, calls the Solidity contract via COA, releases prize funds, and mints a trophy NFT — all atomically. No other chain can do this.

**Demonstrates:** Flow EVM bridge · COA (Cadence-Owned Accounts) · Atomic cross-layer transactions · Hybrid Solidity + Cadence

---

### Smart Contract Library

20+ production Cadence 1.0 contracts, all tested with `flow test`.

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

### Flow Skills

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

A `validate-cadence.sh` hook automatically checks every commit touching `.cdc` files for Cadence 0.x patterns (`pub`/`priv`), hardcoded addresses, and force-unwrap on capabilities.

---

## Studio Framework

### Studio Hierarchy

Agents are organized into three tiers, matching how real studios operate:

```
Tier 1 — Directors (Opus)
  creative-director    technical-director    producer

Tier 2 — Department Leads (Sonnet)
  game-designer        lead-programmer       art-director
  audio-director       narrative-director    qa-lead
  release-manager      localization-lead

Tier 3 — Specialists (Sonnet/Haiku)
  gameplay-programmer  engine-programmer     ai-programmer
  network-programmer   tools-programmer      ui-programmer
  systems-designer     level-designer        economy-designer
  technical-artist     sound-designer        writer
  world-builder        ux-designer           prototyper
  performance-analyst  devops-engineer       analytics-engineer
  security-engineer    qa-tester             accessibility-specialist
  live-ops-designer    community-manager
```

#### Engine Specialists

The template includes agent sets for all three major engines:

| Engine | Lead Agent | Sub-Specialists |
|--------|-----------|-----------------|
| **Godot 4** | `godot-specialist` | GDScript, Shaders, GDExtension, C# |
| **Unity** | `unity-specialist` | DOTS/ECS, Shaders/VFX, Addressables, UI Toolkit |
| **Unreal Engine 5** | `unreal-specialist` | GAS, Blueprints, Replication, UMG/CommonUI |

### How Agents Coordinate

Agents follow a structured delegation model:

1. **Vertical delegation** — directors delegate to leads, leads delegate to specialists
2. **Horizontal consultation** — same-tier agents can consult each other but can't make binding cross-domain decisions
3. **Conflict resolution** — disagreements escalate up to the shared parent (`creative-director` for design, `technical-director` for technical)
4. **Change propagation** — cross-department changes are coordinated by `producer`
5. **Domain boundaries** — agents don't modify files outside their domain without explicit delegation

### Collaborative, Not Autonomous

This is **not** an auto-pilot system. Every agent follows a strict collaboration protocol:

1. **Ask** — agents ask questions before proposing solutions
2. **Present options** — agents show 2-4 options with pros/cons
3. **You decide** — the user always makes the call
4. **Draft** — agents show work before finalizing
5. **Approve** — nothing gets written without your sign-off

You stay in control. The agents provide structure and expertise, not autonomy.

---

### Slash Commands

Type `/` in Claude Code to access all skills:

**Onboarding & Navigation**
`/start` `/help` `/project-stage-detect` `/setup-engine` `/adopt`

**Game Design**
`/brainstorm` `/map-systems` `/design-system` `/quick-design` `/review-all-gdds` `/propagate-design-change`

**Art & Assets**
`/art-bible` `/asset-spec` `/asset-audit`

**UX & Interface Design**
`/ux-design` `/ux-review`

**Architecture**
`/create-architecture` `/architecture-decision` `/architecture-review` `/create-control-manifest`

**Stories & Sprints**
`/create-epics` `/create-stories` `/dev-story` `/sprint-plan` `/sprint-status` `/story-readiness` `/story-done` `/estimate`

**Reviews & Analysis**
`/design-review` `/code-review` `/balance-check` `/content-audit` `/scope-check` `/perf-profile` `/tech-debt` `/gate-check` `/consistency-check`

**QA & Testing**
`/qa-plan` `/smoke-check` `/soak-test` `/regression-suite` `/test-setup` `/test-helpers` `/test-evidence-review` `/test-flakiness` `/skill-test` `/skill-improve`

**Production**
`/milestone-review` `/retrospective` `/bug-report` `/bug-triage` `/reverse-document` `/playtest-report`

**Release**
`/release-checklist` `/launch-checklist` `/changelog` `/patch-notes` `/hotfix`

**Creative & Content**
`/prototype` `/onboard` `/localize`

**Team Orchestration** (coordinate multiple agents on a single feature area)
`/team-combat` `/team-narrative` `/team-ui` `/team-release` `/team-polish` `/team-audio` `/team-level` `/team-live-ops` `/team-qa`

**Flow Blockchain**
`/flow-vrf` `/flow-nft` `/flow-entitlements` `/flow-contract` `/flow-audit` `/flow-economy` `/flow-scheduled` `/flow-amm` `/flow-attachments` `/flow-compliance`

---

### Automated Safety

Hooks run automatically on every session:

| Hook | Trigger | What It Does |
|------|---------|--------------|
| `validate-commit.sh` | PreToolUse (Bash) | Checks for hardcoded values, TODO format, JSON validity, design doc sections |
| `validate-push.sh` | PreToolUse (Bash) | Warns on pushes to protected branches |
| `validate-assets.sh` | PostToolUse (Write/Edit) | Validates naming conventions and JSON structure for `assets/` files |
| `validate-cadence.sh` | PreToolUse (Bash) | Checks `.cdc` commits for Cadence 0.x patterns, hardcoded addresses, force-unwrap |
| `session-start.sh` | Session open | Shows current branch and recent commits for orientation |
| `detect-gaps.sh` | Session open | Detects fresh projects (suggests `/start`) and missing design docs |
| `pre-compact.sh` | Before compaction | Preserves session progress notes |
| `post-compact.sh` | After compaction | Reminds Claude to restore session state from `active.md` |
| `notify.sh` | Notification event | Shows OS toast notification |
| `session-stop.sh` | Session close | Archives `active.md` to session log and records git activity |
| `log-agent.sh` | Agent spawned | Audit trail start — logs subagent invocation with timestamp |
| `log-agent-stop.sh` | Agent stops | Audit trail stop — completes subagent record |
| `validate-skill-change.sh` | PostToolUse (Write/Edit) | Advises running `/skill-test` after any `.claude/skills/` change |

> **Note**: Hooks that fire on every tool call (validate-commit, validate-assets, validate-skill-change) exit immediately (exit 0) when the command or file path is not relevant. This is normal — not a performance concern.

**Permission rules** in `settings.json` auto-allow safe operations (git status, test runs) and block dangerous ones (force push, `rm -rf`, reading `.env` files).

---

### Path-Scoped Rules

Coding standards are automatically enforced based on file location:

| Path | Enforces |
|------|----------|
| `src/gameplay/**` | Data-driven values, delta time usage, no UI references |
| `src/core/**` | Zero allocations in hot paths, thread safety, API stability |
| `src/ai/**` | Performance budgets, debuggability, data-driven parameters |
| `src/networking/**` | Server-authoritative, versioned messages, security |
| `src/ui/**` | No game state ownership, localization-ready, accessibility |
| `design/gdd/**` | Required 8 sections, formula format, edge cases |
| `tests/**` | Test naming, coverage requirements, fixture patterns |
| `prototypes/**` | Relaxed standards, README required, hypothesis documented |

---

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`)
- [Flow CLI](https://docs.onflow.org/flow-cli/install/) v2.x (for running contracts and example games)
- Node.js 18+ (for example game clients)
- **Recommended**: [jq](https://jqlang.github.io/jq/) and Python 3 (for hook validation — hooks fail gracefully without them)

### Option A — Start a New Game with Flow

```bash
git clone https://github.com/Aliserag/Flow-Game-Studio.git my-game
cd my-game
claude
```

Then in Claude Code:
```
/start
```

The system asks where you are (no idea, vague concept, clear design, existing work) and guides you to the right workflow. No assumptions.

Or jump directly:
- `/brainstorm` — explore game ideas from scratch
- `/setup-engine godot 4.6` — configure your engine
- `/flow-vrf` — add VRF randomness to an existing mechanic

### Option B — Run an Example Game

```bash
# Coin Flip (easiest starting point — single player, clear VRF story)
cd examples/coin-flip
flow emulator start                          # terminal 1
flow project deploy                          # terminal 2
cd client && npm install && npm run dev      # terminal 3
```

For full testnet deployment see `docs/flow/testnet-deployment-guide.md`.

### Upgrading

Already using an older version? See [UPGRADING.md](UPGRADING.md) for migration instructions, a breakdown of what changed between versions, and which files are safe to overwrite vs. which need a manual merge.

---

## Project Structure

```
CLAUDE.md                           # Master configuration
.claude/
  settings.json                     # Hooks, permissions, safety rules
  agents/                           # 62 agent definitions
  skills/                           # 72+ slash commands (incl. Flow skills)
  hooks/                            # 13 hook scripts
  rules/                            # 11 path-scoped coding standards
  statusline.sh                     # Status line script
  docs/
    workflow-catalog.yaml           # 7-phase pipeline definition (read by /help)
    templates/                      # 39 document templates
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
assets/                             # Art, audio, VFX, shaders, data files
design/                             # GDDs, narrative docs, level designs
tests/                              # Game test suites
tools/                              # Build and pipeline tools
prototypes/                         # Throwaway prototypes (isolated from src/)
production/                         # Sprint plans, milestones, release tracking
```

---

## Design Philosophy

This project is grounded in professional game development practices:

- **MDA Framework** — Mechanics, Dynamics, Aesthetics analysis for game design
- **Self-Determination Theory** — Autonomy, Competence, Relatedness for player motivation
- **Flow State Design** — Challenge-skill balance for player engagement
- **Bartle Player Types** — Audience targeting and validation
- **Verification-Driven Development** — Tests first, then implementation

---

## Customization

This is a **template**, not a locked framework. Everything is meant to be customized:

- **Add/remove agents** — delete agent files you don't need, add new ones for your domains
- **Edit agent prompts** — tune agent behavior, add project-specific knowledge
- **Modify skills** — adjust workflows to match your team's process
- **Add rules** — create new path-scoped rules for your project's directory structure
- **Tune hooks** — adjust validation strictness, add new checks
- **Pick your engine** — use the Godot, Unity, or Unreal agent set (or none)
- **Set review intensity** — `full` (all director gates), `lean` (phase gates only), or `solo` (none). Set during `/start` or edit `production/review-mode.txt`

---

## Platform Support

Tested on **macOS** and **Windows 10** with Git Bash. All hooks use POSIX-compatible patterns and include fallbacks for missing tools. Works on Linux without modification.

---

## Upstream Sync

This fork auto-syncs with [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) daily via `.github/workflows/sync-upstream.yml`:
- **Clean merge** → auto-pushed to `main`
- **Conflicts** → PR opened for manual resolution

Flow-specific additions are never submitted upstream. This is a standalone fork.

---

## License

MIT License. Upstream copyright (c) 2026 Donchitos. See [LICENSE](LICENSE) for details.
