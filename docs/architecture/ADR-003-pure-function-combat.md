# ADR-003 — Combat Resolver as Pure-Function Event Emitter

**Status:** Accepted
**Date:** 2026-05-14
**Authors:** Orchestrator (autonomous build)

## Context

Combat is the most complex system in WARBAND. It must:
1. Simulate a full battle from inputs (player warband + enemy composition).
2. Be deterministic (per ADR-002).
3. Surface every decision for the UI to animate (Pillar 4 — Watch and Learn).
4. Support boss phase hooks, biome modifiers, trait interactions, gear effects.
5. Be unit-testable in isolation — no scene tree, no display dependencies.

Two patterns were considered:
1. **Display-coupled simulation**: Combat is a Node in the scene tree.
   The display watches it tick and renders as it goes.
2. **Pure-function simulation**: Combat is a static method on a RefCounted
   class. Inputs go in; an event log + outcome come out. The display
   consumes the event log offline and animates at its own pace.

## Decision

**Option 2** — `CombatResolver.resolve(player_orcs, comp, registry, rng, biome_mod)`
is a static function that returns:

```gdscript
{
  "victory": bool,
  "rounds": int,
  "events": Array[Dictionary],     # battle_start, round_start, attack, death, heal, phase_change, battle_end
  "player_survivors": Array,
  "player_dead": Array,
  "enemy_dead": Array,
  "rewards": Dictionary,           # (populated by CampaignController on win)
}
```

The simulation has zero scene-tree dependencies. The `BattleScreen` UI:
1. Triggers resolution via `CampaignController.resolve_battle()`.
2. Reads the returned event log.
3. Animates events one at a time with a configurable delay (currently 0.2s).
4. Renders HP bars and floating text based on event content, never by querying
   any in-progress combat state (because there is none).

Boss phase changes appear as a `phase_change` event mid-stream. The UI plays
a special toast when it consumes one. The simulation has already applied the
stat bonus by then.

## Consequences

**Positive:**
- Combat is fully unit-testable without a SceneTree. Tests run in 0.1s.
- The simulation is deterministic by construction — no async, no scene loading,
  no frame-timing dependencies.
- The display can pause, scrub backwards, fast-forward, or skip — all without
  touching simulation code. (Pause/skip are planned UX features.)
- Replay is trivial: the event log IS the replay.

**Negative:**
- The full event log is held in memory. For a 30-round boss fight, this is
  ~100-150 dictionaries — negligible. For a hypothetical 200-round endless
  mode, this would grow into MB territory; would need pagination.
- Adding new event types requires updating both the resolver and any UI that
  consumes the events. Mitigated by the `EV_*` string constants on
  `CombatResolver` — UI code matches on them rather than hardcoded strings.

## Validation

`tests/unit/test_combat_resolver.gd`: same seed reproducibility, battle
termination, victory/defeat conditions, brute-vs-thug expected outcome,
attack event count > 0, archer-vs-pack non-crash.

`tests/integration/test_g0_end_to_end.gd::test_g1_boss_phase_change_event_emitted_in_boss_fight`:
verifies the phase_change event fires when boss HP crosses the threshold.
