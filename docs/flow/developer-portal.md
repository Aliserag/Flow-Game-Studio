# Flow Game Studio — Developer Portal

Welcome. This portal covers everything a new developer needs to start contributing.

## Quick Start (30 minutes)

1. **Install Flow CLI**: `sh -ci "$(curl -fsSL https://raw.githubusercontent.com/onflow/flow-cli/master/install.sh)"`
2. **Start emulator**: `flow emulator` (leave running in terminal)
3. **Deploy contracts**: `flow project deploy --network emulator`
4. **Run tests**: `flow test ./cadence/tests/...`
5. **Try a transaction**: `flow transactions send cadence/transactions/vrf/commit_move.cdc --arg UInt256:12345 --arg UInt64:1`

## Repository Map

| Directory | Purpose |
|-----------|---------|
| `cadence/contracts/core/` | NFT and token contracts |
| `cadence/contracts/systems/` | VRF, scheduler, marketplace, tournament |
| `cadence/contracts/governance/` | DAO voting |
| `cadence/contracts/liveops/` | Season pass, dynamic pricing |
| `cadence/contracts/crypto/` | Merkle allowlist, blind auction |
| `cadence/contracts/evm/` | Flow EVM bridge |
| `cadence/transactions/` | All player and admin transactions |
| `cadence/scripts/` | Read-only queries |
| `cadence/tests/` | Cadence testing framework tests |
| `tools/indexer/` | Off-chain event indexer |
| `tools/metadata-pipeline/` | IPFS pinning |
| `src/flow-bridge/` | Godot and Unity REST bridge clients |
| `examples/` | Reference game implementation |
| `.claude/skills/` | Claude Code skills for this studio |
| `.claude/agents/` | Specialized AI agents |
| `docs/flow/` | This documentation |
| `docs/legal/` | Compliance guides (not legal advice) |

## Skills Reference

| Skill | Purpose |
|-------|---------|
| `/flow-vrf <mechanic>` | Generate VRF commit/reveal for any game mechanic |
| `/flow-entitlements <contract>` | Design Cadence 1.0 entitlement schema |
| `/flow-schedule <action>` | Generate epoch-based scheduled action |
| `/flow-metadata <contract>` | Generate MetadataViews resolver + IPFS pipeline |
| `/flow-migrate <contract>` | Safe contract upgrade with migration |
| `/flow-incident` | Incident response playbook |
| `/flow-evm` | Flow EVM / Cadence cross-VM patterns |
| `/flow-liveops` | Season, pricing, and sale admin transactions |
| `/flow-governance` | DAO proposal and voting transactions |
| `/flow-crypto` | Merkle allowlists and blind auctions |
| `/flow-team <feature>` | Full feature from design to deploy |
| `/flow-launch` | Pre-mainnet launch checklist |
| `/flow-economics-audit` | Token economy health check |
| `/flow-game-state` | On-chain state snapshot for debugging |
| `/flow-compliance` | Legal/compliance self-assessment |

## Agents Reference

| Agent | When to Use |
|-------|-------------|
| `cadence-specialist` | All Cadence 1.0 contract code |
| `flow-architect` | Contract architecture decisions (produces ADR) |
| `flow-indexer` | Event indexer queries and schema changes |
| `flow-godot-bridge` | Godot 4 ↔ Flow integration |
| `flow-unity-bridge` | Unity ↔ Flow integration |
| `flow-evm-specialist` | Solidity ↔ Cadence cross-VM |

## Common Mistakes

1. **Using `self.account` in transaction `execute` block** — doesn't exist. Capture `signer.address` in `prepare`.
2. **Using `pub`/`priv`** — Cadence 0.x syntax. Use `access(all)` / `access(self)`.
3. **Using `revertibleRandom()` directly** — biasable by validators. Use RandomVRF commit/reveal.
4. **Publishing Minter capability to public path** — never do this.
5. **Forgetting to call `EmergencyPause.assertNotPaused()`** — CI audit will catch this but add it proactively.
