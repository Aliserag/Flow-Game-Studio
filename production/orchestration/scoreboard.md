# WARBAND G0 — Scoreboard

**Last updated:** 2026-05-14 (final)
**Aggregate:** **82.1 / 100** — meets G0 bar (≥ 80)
**Lowest individual:** **72** (battle-display) — meets per-system bar (≥ 70)
**Verdict:** **PASS for G0**

## Per-System Scores

| System | Code | Test | Pillar | AC | Total | Verdict |
|---|---:|---:|---:|---:|---:|---|
| `run-seed-determinism` | 24 | 23 | 22 | 24 | **93** | EXCELLENT |
| `run-state` | 22 | 22 | 23 | 23 | **90** | EXCELLENT |
| `orc-definition-data` | 23 | 22 | 22 | 22 | **89** | GOOD |
| `combat-resolver` | 22 | 22 | 22 | 22 | **88** | GOOD |
| `tavern-recruit` | 22 | 21 | 21 | 22 | **86** | GOOD |
| `gold-economy` (in RunState) | 21 | 21 | 22 | 21 | **85** | GOOD |
| `gear-equipment` (in Orc) | 21 | 19 | 21 | 20 | **81** | GOOD |
| `battle-setup` | 21 | 18 | 21 | 21 | **81** | GOOD |
| `save-system` | 21 | 21 | 18 | 20 | **80** | GOOD |
| `trait-engine` (in Orc) | 20 | 19 | 20 | 19 | **78** | ADEQUATE |
| `stat-allocation` (in Orc) | 20 | 19 | 19 | 18 | **76** | ADEQUATE |
| `loot-system` (in BattleSetup) | 19 | 18 | 20 | 19 | **76** | ADEQUATE |
| `death-ceremony` (UI) | 19 | 14 | 22 | 19 | **74** | ADEQUATE |
| `battle-display` (UI) | 19 | 12 | 22 | 19 | **72** | ADEQUATE |

## Aggregate Computation

```
Sum = 93 + 90 + 89 + 88 + 86 + 85 + 81 + 81 + 80 + 78 + 76 + 76 + 74 + 72 = 1149
Mean = 1149 / 14 = 82.07
```

## Verdict by Tier

- **EXCELLENT (90-100):** 2 systems (Rng, RunState)
- **GOOD (80-89):** 7 systems
- **ADEQUATE (70-79):** 5 systems
- **INSUFFICIENT/FAIL (<70):** 0 systems

## Score Notes

- Test coverage scores for UI systems (battle-display, death-ceremony) are lower because
  UI testing is advisory in the test-evidence matrix (visual/feel verification, not unit-testable).
- Pillar alignment is strong overall — every G0 system serves at least one of the four pillars
  and no system violates an anti-pillar.
- Acceptance Criteria scores are tied to the systems index defaults (Open Question resolutions
  documented in `design/gdd/systems-index.md` §5).

## What's Above the G0 Bar but Should Improve Pre-G1

- battle-display + death-ceremony: need automated visual regression OR scripted playback tests
- trait-engine: only 4 traits implemented; full library is G2 scope but a few more for G1
- loot-system: drop pity timer not yet implemented (deferred to G1)

## Score History

| Date | Event | Aggregate | Notes |
|---|---|---|---|
| 2026-05-14 | Initial G0 implementation complete | 82.1 | All 44 unit + integration tests pass 3x consecutively |
