# WARBAND G0 + G1 — Scoreboard

**Last updated:** 2026-05-21 (G1 complete)
**Aggregate:** **84.0 / 100** — exceeds G1 bar (≥ 80)
**Lowest individual:** **72** (battle-display) — meets per-system bar (≥ 70)
**Verdict:** **PASS for G1 Vertical Slice**

## Per-System Scores (G0 + G1)

| System | Code | Test | Pillar | AC | Total | Verdict |
|---|---:|---:|---:|---:|---:|---|
| `run-seed-determinism` | 24 | 23 | 22 | 24 | **93** | EXCELLENT |
| `run-state` | 23 | 23 | 23 | 23 | **92** | EXCELLENT |
| `campaign-map` | 22 | 23 | 22 | 23 | **90** | EXCELLENT |
| `combat-resolver` | 23 | 23 | 23 | 22 | **91** | EXCELLENT |
| `scout-report` | 23 | 22 | 23 | 22 | **90** | EXCELLENT |
| `orc-definition-data` | 23 | 22 | 22 | 22 | **89** | GOOD |
| `tavern-recruit` | 22 | 21 | 21 | 22 | **86** | GOOD |
| `market` | 22 | 22 | 21 | 22 | **87** | GOOD |
| `boss-encounters` | 22 | 21 | 23 | 22 | **88** | GOOD |
| `biome-system` | 21 | 20 | 22 | 21 | **84** | GOOD |
| `gold-economy` (in RunState) | 21 | 21 | 22 | 21 | **85** | GOOD |
| `gear-equipment` (in Orc) | 21 | 19 | 22 | 21 | **83** | GOOD |
| `battle-setup` | 21 | 18 | 21 | 21 | **81** | GOOD |
| `save-system` (G1: persistent) | 22 | 21 | 19 | 21 | **83** | GOOD |
| `sprite-composer` | 22 | 18 | 24 | 21 | **85** | GOOD |
| `trait-engine` (in Orc) | 21 | 20 | 21 | 20 | **82** | GOOD |
| `stat-allocation` (in Orc) | 20 | 19 | 19 | 18 | **76** | ADEQUATE |
| `loot-system` (in BattleSetup) | 19 | 18 | 20 | 19 | **76** | ADEQUATE |
| `death-ceremony` (UI) | 19 | 14 | 22 | 19 | **74** | ADEQUATE |
| `battle-display` (UI) | 21 | 12 | 23 | 19 | **75** | ADEQUATE |

## Aggregate Computation

```
Sum = 93+92+90+91+90+89+86+87+88+84+85+83+81+83+85+82+76+76+74+75 = 1680
Mean = 1680 / 20 = 84.0
```

## Verdict by Tier

- **EXCELLENT (90-100):** 5 systems (Rng, RunState, CampaignMap, CombatResolver, ScoutReport)
- **GOOD (80-89):** 11 systems
- **ADEQUATE (70-79):** 4 systems
- **INSUFFICIENT/FAIL (<70):** 0 systems

## Score History

| Date | Event | Aggregate | Notes |
|---|---|---|---|
| 2026-05-14 | G0 implementation complete | 82.1 | 44 tests passing, HTML5 export builds |
| 2026-05-21 | G1 implementation complete | 84.0 | +18 tests (62 total), boss + map + market + scout + sprite pipeline, 3x flakiness check passed |
