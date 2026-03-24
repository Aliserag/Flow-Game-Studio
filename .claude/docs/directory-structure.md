# Directory Structure

```text
/
├── CLAUDE.md                    # Master configuration
├── .claude/                     # Agent definitions, skills, hooks, rules, docs
├── src/                         # Game source code (core, gameplay, ai, networking, ui, tools)
├── cadence/                     # Cadence 1.0 smart contracts
│   ├── contracts/               # Deployable contracts
│   │   ├── core/                # Core game primitives (NFT, Token, Asset)
│   │   ├── systems/             # Game systems (VRF, Scheduler, Marketplace)
│   │   └── interfaces/          # Cadence interfaces
│   ├── transactions/            # Signed transactions (mutate chain state)
│   │   ├── setup/               # Account initialization
│   │   ├── vrf/                 # Commit/reveal randomness
│   │   ├── nft/                 # NFT operations
│   │   ├── marketplace/         # Marketplace operations
│   │   └── scheduler/           # Epoch scheduler
│   ├── scripts/                 # Read-only scripts (query chain state)
│   └── tests/                   # Cadence test files (flow test)
├── docs/flow-reference/         # Version-pinned Flow/Cadence API snapshots
├── docs/flow/                   # Developer guides for Flow features
├── assets/                      # Game assets (art, audio, vfx, shaders, data)
├── design/                      # Game design documents (gdd, narrative, levels, balance)
├── docs/                        # Technical documentation (architecture, api, postmortems)
│   └── engine-reference/        # Curated engine API snapshots (version-pinned)
├── tests/                       # Test suites (unit, integration, performance, playtest)
├── tools/                       # Build and pipeline tools (ci, build, asset-pipeline)
├── prototypes/                  # Throwaway prototypes (isolated from src/)
└── production/                  # Production management (sprints, milestones, releases)
    ├── session-state/           # Ephemeral session state (active.md — gitignored)
    └── session-logs/            # Session audit trail (gitignored)
```
