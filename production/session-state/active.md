# Active Session State

**Last updated:** 2026-05-21
**Branch:** `claude/orc-arena`
**Stage:** **G1 Vertical Slice — COMPLETE**

## Current Status

WARBAND G1 Vertical Slice is **DONE**. 62/62 tests pass 3x consecutively.
HTML5 export builds. Aggregate score: 84.0/100.

See `production/orchestration/final-report-G1.md` for full report.

## G1 Deliverables

- **New systems**: CampaignMap, ScoutReport, Market, BossPhases (extended CombatResolver),
  BiomeSystem, SpriteComposer, persistent SaveSystem
- **New UI**: CampaignMapScreen, ScoutScreen, MarketScreen, VictoryScreen
- **Updated UI**: Tavern (→ map), Resolution (→ map/victory/game-over), Memorial (→ map), Battle (sprites)
- **Content**: 6 archetypes, 10 enemies + 1 boss, 8 compositions, 20 gear, 12 traits, 1 biome
- **Art pipeline**: procedural sprite generator (29 sprites), modular composite system
- **ADRs**: 4 authored (signal-state, deterministic RNG, pure-function combat, modular sprites)
- **Tests**: 62 (was 44 in G0)

## Files Modified or Created This G1 Session

### Source
- `src/gameplay/campaign_map.gd` (new)
- `src/gameplay/scout_report.gd` (new)
- `src/gameplay/market.gd` (new)
- `src/gameplay/sprite_composer.gd` (new)
- `src/gameplay/combat_resolver.gd` (rewritten — boss phases, biome mods, traits)
- `src/gameplay/campaign_controller.gd` (rewritten — full G1 flow)
- `src/core/run_state.gd` (+phases, +map/market state, +signals)
- `src/core/save_system.gd` (rewritten — persistent via user://)
- `src/core/item_registry.gd` (+biomes loader, +gear_ids)
- `src/ui/CampaignMapScreen.tscn` + `campaign_map_screen.gd` (new)
- `src/ui/ScoutScreen.tscn` + `scout_screen.gd` (new)
- `src/ui/MarketScreen.tscn` + `market_screen.gd` (new)
- `src/ui/VictoryScreen.tscn` + `victory_screen.gd` (new)
- `src/ui/tavern_screen.gd`, `resolution_screen.gd`, `memorial_screen.gd`, `battle_screen.gd` (updated)

### Data
- `data/orc-archetypes.json` (+2 archetypes: cleaver, shaman)
- `data/enemy-types.json` (+7 enemies, +1 boss, +5 compositions)
- `data/gear-pieces.json` (+12 pieces, uncommon/unique tiers)
- `data/traits.json` (+6 traits)
- `data/biomes.json` (new — farm-village biome)

### Tests
- `tests/unit/test_campaign_map.gd` (new, 9 tests)
- `tests/unit/test_scout_report.gd` (new, 3 tests)
- `tests/unit/test_market.gd` (new, 5 tests)
- `tests/integration/test_g0_end_to_end.gd` (rewritten for G1 flow + boss phase test)

### Assets
- `assets/chars/char_<archetype>_base_idle.png` × 6
- `assets/enemies/enemy_<id>.png` × 10
- `assets/chars/gear/char_gear_<slot>_<id>.png` × 10
- `assets/chars/scars/char_scar_<N>.png` × 3

### Tools
- `tools/sprite-gen/generate_sprites.py` (new — 600 lines, procedural sprite generator)

### Docs
- `docs/architecture/ADR-001-signal-driven-state.md` (new)
- `docs/architecture/ADR-002-deterministic-rng.md` (new)
- `docs/architecture/ADR-003-pure-function-combat.md` (new)
- `docs/architecture/ADR-004-modular-sprite-atlas.md` (new)
- `production/orchestration/completion-criteria-g1.md` (new)
- `production/orchestration/final-report-G1.md` (new)
- `production/orchestration/scoreboard.md` (updated)

## Test Results (Final)

```
Scripts: 11
Tests:   62
Pass:    62
Fail:     0
Asserts: 341
Time:    0.46s
```

3 consecutive runs identical. No flakiness.

## Build Artifact

`build/index.html` — HTML5 build (38 MB). Within 50 MB G1 threshold. Verified builds cleanly.

## Score Summary

| Category | G0 | G1 |
|---|---:|---:|
| Aggregate | 82.1 | **84.0** |
| EXCELLENT | 2 | **5** |
| GOOD | 7 | **11** |
| ADEQUATE | 5 | 4 |
| FAIL | 0 | 0 |

## Next Required Action

Two options:

1. **G2 scope**: 3 more biomes, 4 more bosses, full 60-trait library, Sagas/Legends
   meta-progression UI, audio implementation, real artist content, localization,
   telemetry. Concept doc calls this 3-6 months of work.

2. **Polish G1 for a public alpha demo**: replace placeholder sprites with hand-drawn
   art (requires an artist), polish UI typography (Cinzel + Courier Prime per art bible),
   add the missing per-system GDDs, audio implementation.

<!-- STATUS -->
Epic: G1 Vertical Slice
Feature: Complete
Task: G1 verified — ready for user review or G2 kickoff
<!-- /STATUS -->
