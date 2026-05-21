# ADR-001 — Signal-Driven State via RunState Autoload

**Status:** Accepted
**Date:** 2026-05-14
**Authors:** Orchestrator (autonomous build)

## Context

WARBAND has many distinct UI screens (Tavern, Map, Scout, Battle, Resolution,
Market, Memorial, GameOver, Victory) and many systems that produce state changes
(combat resolution, hires, gold spending, permadeath). We need a discipline for
how state mutates and how the UI stays in sync — without coupling systems to
each other and without polling.

Three options were considered:
1. **Polling**: each UI screen reads RunState fields each frame in `_process()`.
2. **MVC with explicit controllers**: every screen owns a controller that
   subscribes to a per-domain event bus.
3. **Single autoload (RunState) emitting domain signals**: gameplay systems
   mutate RunState directly via well-defined methods; RunState fires Godot
   signals; UI subscribes.

## Decision

**Option 3** — `RunState` is a Godot autoload (singleton node) that:

- Holds the canonical campaign state (hero, roster, gravestone, gold, phase,
  candidates, map, market stock).
- Exposes mutation methods (`spend_gold`, `hire_candidate`,
  `record_orc_death`, `set_candidates`, `award_xp_to_warband`, …).
- Emits Godot `signal`s on every observable mutation (`gold_changed`,
  `roster_changed`, `phase_changed`, `orc_died`, `candidates_changed`,
  `map_changed`, `market_stock_changed`, `battle_won`, `battle_lost`,
  `run_started`, `run_ended`).

UI screens connect to the relevant signals in `_ready()` and disconnect in
`_exit_tree()` if needed. Gameplay systems (`CombatResolver`, `TavernRecruit`,
`Market`, `CampaignMap`) are RefCounted classes with no scene-tree dependencies;
they receive `RunState` as a dependency (via `CampaignController._init`) rather
than reaching for the autoload globally.

## Consequences

**Positive:**
- UI is reactive, not polled — 0 frame-rate overhead in the absence of changes.
- One source of truth for state — debugging is straightforward.
- New screens can be added without modifying any gameplay code.

**Negative:**
- A single autoload is a global. Tests that need RunState must `before_each` to
  reset its state. The autoload is unit-testable via direct method calls.
- The `set_phase()` mutation has a special property: only one consumer should
  trigger transitions to GAME_OVER or VICTORY. We've already had one bug
  (CampaignController setting RESOLUTION over GAME_OVER) — guard with
  `if run_state.run_active` checks.

## Alternatives Rejected

- **Polling**: rejected — wastes CPU and creates subtle race conditions where
  UI sees stale state for one frame.
- **Per-domain event buses**: rejected for G0/G1 scope — extra indirection
  with no clear benefit at current system count. Revisit at G2 if RunState
  signal list exceeds ~20.

## Validation

`tests/unit/test_run_state.gd` covers all mutation paths and signal emission
order. `tests/integration/test_g0_end_to_end.gd` drives the full loop via the
controller and verifies no signal-ordering hazards.
