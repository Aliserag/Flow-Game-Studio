# ADR-002 — Deterministic RNG via Central Singleton

**Status:** Accepted
**Date:** 2026-05-14
**Authors:** Orchestrator (autonomous build)

## Context

The concept doc names "deterministic seed for replays" as a production
risk-mitigation requirement (concept §13). Pillar 4 ("Watch and Learn")
requires that nothing in combat be hidden from the player — including the
random number stream. We also need test determinism: the same seed must
produce the same campaign so we can reproduce bugs and run regression tests.

GDScript exposes `randi()`, `randf()`, etc. as global functions tied to the
engine's global RandomNumberGenerator. There is no built-in way to enforce
that gameplay code routes through a single seed.

## Decision

**A single `Rng` autoload owns the only RandomNumberGenerator used by
gameplay code.** Direct calls to `randi()` / `randf()` are forbidden in
gameplay code (enforced by code review and documented in
`.claude/docs/technical-preferences.md` "Forbidden Patterns").

The `Rng` autoload exposes:
- `set_seed(int)` — re-seed; called once at run start with the run_seed.
- `roll_int(low, high)` — inclusive int roll.
- `roll_float()` — [0, 1) float.
- `roll_chance(p)` — Bernoulli trial.
- `pick(arr)` — uniform pick from array.
- `pick_weighted(choices, weights)` — weighted pick.
- `shuffle(arr)` — in-place shuffle.

All randomness in the game — combat crit rolls, tavern candidate generation,
campaign map layout, market stock, loot drops, event gold gifts —
routes through this autoload. The result: a campaign is fully reconstructable
from its seed.

## Consequences

**Positive:**
- Same seed → same campaign. Tests use this for determinism.
- Replay mode is implementable (post-G1): record the seed and the player's
  choices (hire decisions, map node selections); replay reconstructs the run.
- Cheat detection (post-G2): any state inconsistent with the seed + choices
  log is a tampered save.

**Negative:**
- Discipline burden. New code can violate the rule by calling `randi()`
  directly. Mitigation: code review checklist + a future static check
  (forbidden-substring grep in CI).
- Visual-only randomness (e.g., particle jitter) should NOT consume the
  seeded stream. Use a separate, un-seeded RNG for cosmetic systems.

## Validation

`tests/unit/test_rng.gd` verifies: same seed → same int/float/shuffle/pick
sequence; pick_weighted respects weights within tolerance; roll_chance(0)
and roll_chance(1) honor extremes.

`tests/integration/test_g0_end_to_end.gd::test_g1_deterministic_run_same_seed_same_outcome`
runs two full campaigns with seed 123456 and asserts identical
battles_completed, battles_won, final_gold, and terminal phase.
