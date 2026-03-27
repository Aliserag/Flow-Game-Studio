# New Developer Onboarding Checklist

## Day 1: Environment Setup

- [ ] Clone repository
- [ ] Install Flow CLI (see developer-portal.md)
- [ ] Install Node.js 20+ and TypeScript
- [ ] Install Claude Code and configure with project
- [ ] Run `flow emulator` and confirm it starts
- [ ] Run `flow project deploy --network emulator` — all contracts deploy
- [ ] Run `flow test ./cadence/tests/...` — all tests pass
- [ ] Read `docs/flow/developer-portal.md` completely
- [ ] Read `docs/flow-reference/cadence-1.0-changes.md`

## Day 1: First Skill Run

- [ ] Run `/flow-vrf jump` — generate a VRF pattern for a mechanic called "jump"
- [ ] Run `/flow-game-state global` — snapshot current emulator state
- [ ] Browse `examples/dungeon-crawler/` — understand the reference game

## Day 2: First Contribution

- [ ] Read `docs/architecture/` — understand existing ADRs
- [ ] Pick a small task from the sprint board
- [ ] Use `cadence-specialist` agent for contract code
- [ ] Write tests before implementation
- [ ] Confirm CI passes on your PR

## Flow Blockchain Fundamentals

If new to Flow/Cadence, read in order:
1. Flow architecture overview: https://developers.flow.com/build/basics/network-architecture
2. Cadence language guide: https://cadence-lang.org/docs/
3. Cadence 1.0 migration: docs/flow-reference/cadence-1.0-changes.md
4. This studio's patterns: docs/flow/developer-portal.md
