# WARBAND — Systems Index

**Status:** Locked (authored 2026-05-14 under autonomous orchestration)
**Source of Truth:** `design/concept/warband-game-concept.md`
**Authoring Agent:** game-designer
**Total Systems:** 24

---

## 1. Overview

WARBAND is built from 24 distinct systems organized into five layers: the **data
and save foundations** that every other system depends on; the **core
simulation systems** (combat, economy, unit lifecycle) that define whether the
game works; the **feature systems** (map, tavern, gear, traits, progression)
that define whether the game is fun; the **presentation systems** (battle
display, death ceremony, memorial) that deliver the emotional contract; and the
**polish systems** (audio, telemetry, accessibility) that determine whether the
game ships. This index is the canonical dependency map. Every GDD authored for
WARBAND must reference this index for its upstream dependencies and downstream
dependents. Authoring order follows dependency order — no system is designed
before its foundations are defined.

---

## 2. Systems List

Ordered Foundation → Core → Feature → Presentation → Polish within each tier.
Priority codes map to the milestone gates (G0/G1/G2/G3/G4). G0 = the
playable prototype currently under construction.

### Foundation Tier

| Slug | Pillars | Deps Up | Deps Down | Priority | Effort |
|---|---|---|---|---|---|
| `run-seed-determinism` | Watch and Learn | — | combat, loot, tavern, map | G0 | S |
| `save-system` | Loss Has Weight | seed | all stateful | G0 | M |
| `orc-definition-data` | GMF, LHW | — | hero, roster, trait, gear, combat, stat | G0 | M |
| `enemy-definition-data` | WL, ECC | — | combat, loot, map, scout, boss | G0 schema; G3 content | L |

### Core Tier

| Slug | Pillars | Deps Up | Deps Down | Priority | Effort |
|---|---|---|---|---|---|
| `combat-resolver` | WL, LHW | seed, orc-def, enemy-def, trait, gear | battle-display, loot, roster, hero | G0 | L |
| `gold-economy` | ECC | orc-def, enemy-def | tavern, gear, market, loot | G0 | M |
| `stat-allocation` | GMF, ECC | orc-def, combat | roster, hero, battle-display | G0 | M |
| `trait-engine` | GMF, LHW, WL | orc-def, seed | combat, tavern, battle-display, stat | G0 core; G2 full library | L |
| `hero-orc` | LHW, GMF | orc-def, stat, trait, save | combat, map, meta, sagas | G0 | M |
| `grunt-roster` | LHW, GMF | orc-def, stat, trait, save | combat, tavern, battle-display, sagas, gear | G0 | M |

### Feature Tier

| Slug | Pillars | Deps Up | Deps Down | Priority | Effort |
|---|---|---|---|---|---|
| `tavern-recruit` | ECC, LHW | orc-def, trait, gold, seed, meta | roster | G0 | M |
| `gear-equipment` | GMF, ECC | orc-def, combat, seed | market, loot, battle-display, gold | G0 schema + Common; G2/G3 higher | L |
| `loot-system` | ECC, GMF | enemy-def, gear, gold, seed | market, gold | G0 | M |
| `campaign-map` | ECC, WL | seed, enemy-def, save | scout, biome, boss, market, tavern | G1 (G0 uses single-battle harness) | M |
| `scout-report` | WL, ECC | enemy-def, map, seed | tavern, battle-display | G1 | S |
| `biome-system` | WL, GMF | enemy-def, map | combat, battle-display | G1 (1 biome); G2/G3 full | M |
| `boss-encounters` | LHW, WL | enemy-def, combat, map, loot | meta, biome | G1 (1 boss); G2/G3 full | M |
| `market` | ECC | gear, gold, seed, map | gold, loot | G1 | S |

### Presentation Tier

| Slug | Pillars | Deps Up | Deps Down | Priority | Effort |
|---|---|---|---|---|---|
| `battle-display` | WL, GMF, LHW | combat, orc-def, enemy-def, stat, gear | death-ceremony | G0 | M |
| `death-ceremony` | LHW | battle-display, roster, sagas | sagas, roster | G0 | S |
| `sagas-memorial` | LHW | roster, hero, death-ceremony, save | meta | G2 | S |

### Polish Tier

| Slug | Pillars | Deps Up | Deps Down | Priority | Effort |
|---|---|---|---|---|---|
| `meta-progression` | GMF, LHW | sagas, hero, save, tavern, gear | tavern, hero, loot | G2 | M |
| `audio-cue-system` | LHW, WL | battle-display, death-ceremony, map, tavern | — | G2 | S |
| `run-statistics-telemetry` | WL | combat, gold, roster, hero, save | sagas, meta | G2 | S |
| `localization-accessibility` | (cross-cutting) | all text systems | — | G3 (schema at G2) | M |

> **Note:** `audio-cue-system`, `run-statistics-telemetry`, and
> `localization-accessibility` were proposed by the game-designer agent as
> systems implied (but not named) in the concept doc. Accepted under
> autonomous mandate; revisit during G1 design pass if desired.

---

## 3. Recommended Authoring Order (G0 subset only)

Only G0 systems are listed here; full 24-system order is in §4 below.

1. `run-seed-determinism`
2. `orc-definition-data`
3. `enemy-definition-data`
4. `save-system`
5. `gold-economy`
6. `stat-allocation`
7. `trait-engine`
8. `combat-resolver`
9. `hero-orc`
10. `grunt-roster`
11. `gear-equipment`
12. `loot-system`
13. `tavern-recruit`
14. `battle-display`
15. `death-ceremony`

For G0, items 4-15 are scoped down to "MVP-of-MVP":
- `save-system` = in-memory only for G0; localStorage at G1
- `enemy-definition-data` = 3 enemy types only
- `gear-equipment` = 8 pieces across 2 weapon + 1 armor + 1 accessory slots
- `trait-engine` = 6 traits, additive-only stacking model
- `grunt-roster` = 3 archetypes (Brute / Archer / Berserker)
- `hero-orc` = 1 hero archetype (Chieftain)
- `tavern-recruit` = static 3-candidate pool per visit, no rotation rules

---

## 4. Full Authoring Order (G0 → G3)

1. `run-seed-determinism`
2. `orc-definition-data`
3. `enemy-definition-data`
4. `save-system`
5. `gold-economy`
6. `stat-allocation`
7. `trait-engine`
8. `combat-resolver`
9. `hero-orc`
10. `grunt-roster`
11. `gear-equipment`
12. `loot-system`
13. `scout-report`
14. `campaign-map`
15. `biome-system`
16. `tavern-recruit`
17. `market`
18. `boss-encounters`
19. `battle-display`
20. `death-ceremony`
21. `sagas-memorial`
22. `meta-progression`
23. `audio-cue-system`
24. `run-statistics-telemetry`
25. `localization-accessibility`

---

## 5. Open Questions (resolved under autonomous mandate)

| ID | Question | Resolution for G0 |
|---|---|---|
| OQ-A | Injury short of death? | **No.** Orcs are alive or dead. No incapacitation state in G0. |
| OQ-B | Boss phase hooks? | **No phase hooks for G0** (no bosses in G0). Combat-resolver stays simple. |
| OQ-C | Biome modifiers? | **None for G0** (no biomes in G0). Defer to G1. |
| OQ-D | Candidate expiry? | **Expire on map departure** (G0 has no map; expire on entering Battle). |
| OQ-E | Epitaph model? | **Template Mad Libs** from orc archetype + kill count + cause of death. |
| OQ-F | Save slots? | **One slot in-memory for G0**. localStorage with 1 slot at G1. |

---

## 6. Out of Scope (excluded from 1.0)

| Non-System | Reason |
|---|---|
| Real-time combat / unit micro | Anti-Pillar A |
| Dialogue trees | Orcs bark, they don't converse |
| Multiplayer / PvP | Anti-Pillar |
| Open-world hex map | Branching node graph instead |
| Stress / Affliction | Concept doc: "too heavy for scope" |
| Hero revive | Death is death |
| Skill tree / talent web | Point-buy stat allocation |
| Inventory weight | Slot-count constraint instead |
| IAP / cosmetics for money | Off-tone |
| Mod editor UI | Light JSON moddability only |
| Procedural arena layouts | Fixed side-on layout |
