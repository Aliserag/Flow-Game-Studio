# They Come At Night — Test Plan

**Status**: Living document. Revised at the start of each milestone. Aligned with
`EXPANSION_PLAN.md`.

---

## 1. Test Strategy

A four-layer test pyramid optimized for a single-developer Godot project:

```
                ┌─────────────────────────┐
                │  Playtest (~weekly)     │   subjective, irreplaceable
                ├─────────────────────────┤
                │  Manual smoke (per PR)  │   golden path, 5 minutes
                ├─────────────────────────┤
                │  Integration (CI)       │   multi-system flows
                ├─────────────────────────┤
                │  Unit (CI)              │   pure formulas
                └─────────────────────────┘
```

**Principles**:
- Every formula has a unit test. No exceptions.
- Every cross-system flow has at least one integration test.
- Visual / feel checks live in playtest — not in automated test suite.
- All tests are deterministic — seed `RNG` at suite start; never call `randomize()` in tests.
- Tests fail fast and loud. No silent skips.

**Tooling**:
- **GUT** (Godot Unit Testing) — `addons/gut/`. Configured in M0.3.
- **GitHub Actions** — headless runner per `coding-standards.md`.
- **Bug tracker** — `production/qa/bugs/` markdown files (one per bug, severity prefix).

---

## 2. Coverage Goals

| System | Target Coverage | Test Type |
|---|---|---|
| `chip economy` (n/a here) | — | — |
| `Tile` / `Grid` | 90% | unit |
| `MapGenerator` | 70% | unit + property |
| `Survivor` / `ZombieUnit` / `Npc` | 80% | unit |
| `CombatResolver` | 95% | unit (formulas) |
| `EventSystem` | 90% | unit + integration |
| `BaseSystem` | 90% | unit + integration |
| `InventorySystem` | 90% | unit |
| `SwarmSystem` | 95% | unit (countdown invariants) |
| `TurnManager` | 80% | integration |
| `ZombieAi` | 60% | integration (statistical) |
| `BetrayalSystem` (M1.1) | 95% | unit |
| `SaveSystem` (M1.5) | 95% | integration (round-trip) |
| UI controllers | 30% | manual smoke |

**Aggregate target**: ≥ 75% by M3, ≥ 85% by release.

---

## 3. Unit Test Matrix

### 3.1 Tile (`tests/unit/world/tile_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| TT-01 | New tile reads terrain config | `defense_bonus`, `escape_bonus`, `glyph` match `terrain.json` |
| TT-02 | Add entity then remove | `entities.size() == 0`, no duplicates |
| TT-03 | `has_hostile()` with mixed entities | `true` only when zombie present |
| TT-04 | `is_building()` on each terrain | matches JSON spec for all 10+ terrains |
| TT-05 | Color parses as valid Color | no NaN, all RGBA in [0,1] |

### 3.2 Grid (`tests/unit/world/grid_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| TG-01 | `in_bounds` corner cases | (0,0), (size-1,size-1), (-1,0), (size,size) |
| TG-02 | `chebyshev` symmetry | `dist(a,b) == dist(b,a)` |
| TG-03 | `manhattan` symmetry | same |
| TG-04 | `neighbors4` corner | exactly 2 valid neighbors |
| TG-05 | `neighbors8` edge | exactly 5 valid neighbors |
| TG-06 | `step_toward` reaches target in finite steps | converges within `chebyshev(a,b)` steps |
| TG-07 | `add_entity` then `move_entity` | entity is on new tile only |
| TG-08 | `nearest_entity` with filter | returns matching entity at min distance |
| TG-09 | `recompute_visibility` updates `explored` flag | tiles within radius marked explored permanently |
| TG-10 | `random_edge_position` returns edge tile | one of x in {0, size-1} OR y in {0, size-1} |

### 3.3 MapGenerator (`tests/unit/world/map_generator_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| TM-01 | Generate 14×14, seed=42 | every tile has a valid terrain_id |
| TM-02 | Generate 100 maps, count terrains | each terrain appears at frequency proportional to spawn weight (±20%) |
| TM-03 | Town clusters present | at least 2 contiguous building clusters of size ≥ 3 |
| TM-04 | Road carving | at least one path of road tiles edge-to-edge |
| TM-05 | Supply roll bounds | every tile's supplies ∈ [supply_min, supply_max] |
| TM-06 | Determinism | same seed → identical map (compare serialized) |

### 3.4 CombatResolver (`tests/unit/systems/combat_resolver_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| TC-01 | `party_attack_power` with no items | sum of party.attack |
| TC-02 | `party_attack_power` with assigned weapon | adds best weapon attack only |
| TC-03 | `party_attack_power` with armory | adds armory bonus |
| TC-04 | `party_defense` with multiple armor | sums all armor.defense |
| TC-05 | `party_defense` with base + walls | sums base + enhancement bonuses |
| TC-06 | `resolve_attack` kills weak zombie | `zombie_killed == true`, casualties == 0 expected |
| TC-07 | `resolve_attack` overwhelmed by horde | casualties > 0 |
| TC-08 | Megahorde killed triggers victory | `GameState.phase == GAME_OVER` and `victory == true` |
| TC-09 | `resolve_flee` open terrain success | escape_bonus +3 → success at roll ≥3 |
| TC-10 | `resolve_flee` building failure path | escape_bonus -2 → failure deals damage |
| TC-11 | Bite chance on damage | seed-controlled: with seeded RNG, infection lands deterministically |

### 3.5 SwarmSystem (`tests/unit/systems/swarm_system_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| TS-01 | Day < SWARM_UNLOCK_DAY | no warning, no scheduling |
| TS-02 | Megahorde unlock day rolls into [20,50] | always within range |
| TS-03 | After unlock, megahorde_eta in [5,8] | always within range |
| TS-04 | Megahorde countdown ticks | eta decrements by 1 per `on_day_advanced` |
| TS-05 | Megahorde at eta 0 spawns megahorde unit | grid contains exactly one entity with unit_id="megahorde" |
| TS-06 | Swarm warning persists across days | pending dict not cleared until eta hits 0 |
| TS-07 | Two swarms can't be pending simultaneously | scheduling guarded by `swarm_pending.is_empty()` |

### 3.6 EventSystem (`tests/unit/systems/event_system_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| TE-01 | `roll_for_event` returns {} when chance fails | seeded RNG producing >0.32 |
| TE-02 | Event with `min_day:5` doesn't fire on day 4 | filtered out of pool |
| TE-03 | Event with `on_building:true` requires building tile | filtered when on plains |
| TE-04 | `_substitute` replaces `{party_member}` | replacement taken from current party |
| TE-05 | `resolve_choice` applies all effect kinds | iterate all 15+ effect kinds, assert state change |
| TE-06 | Cost paid only when affordable | when not affordable, returns "can't afford" without state change |
| TE-07 | Outcome weights select correctly | seeded RNG → predictable outcome |
| TE-08 | Recruit effect adds party member | party.size +1; assignments has new id |
| TE-09 | kill_random_party never targets lead | run 100 times, lead never removed |
| TE-10 | Force_move teleports lead to safe neighbor | new pos != old pos, no hostile on new tile |

### 3.7 BaseSystem (`tests/unit/systems/base_system_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| TB-01 | `establish` on building tile | defense_bonus matches tile config |
| TB-02 | `establish` when has_base already | returns false, logs warning |
| TB-03 | `can_build` requires prerequisites | fails when prereq not built |
| TB-04 | `can_build` validates cost | fails when missing materials |
| TB-05 | `start_build` consumes materials | inventory reflects deduction |
| TB-06 | `tick_day` decrements build days | reaches 0, enhancement appears in built list |
| TB-07 | Enhancement passive yields | garden adds 1 food/day; infirmary heals all members 1 HP |
| TB-08 | `abandon` clears all base state | has_base=false, enhancements empty, building reset |

### 3.8 InventorySystem (`tests/unit/systems/inventory_system_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| TI-01 | `assign` deducts from stash | inventory reduced by 1 |
| TI-02 | `assign` adds to assignments | survivor's list contains item |
| TI-03 | `unassign` reverses | items returned to stash |
| TI-04 | `use_consumable` heal | hp increases by item's heal value, capped at max_hp |
| TI-05 | `use_consumable` cure_infection | survivor.infected becomes false |
| TI-06 | `scavenge_tile` marks searched | tile.searched=true after call |
| TI-07 | `scavenge_tile` produces correct category bias | military terrain → mostly weapons/ammo over 100 rolls |
| TI-08 | `scavenge_tile` already searched | returns ok=false |

### 3.9 BetrayalSystem (M1.1) (`tests/unit/systems/betrayal_system_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| BT-01 | Betrayal chance scales with tension | hunger=true → effective chance ×1.5 |
| BT-02 | Lone wolf with 5% never fires in 100 trials at low tension | statistical bound |
| BT-03 | Cannibal with 85% reliably betrays within 5 days | seeded run |
| BT-04 | Steal-and-flee outcome removes member + items | party.size -1, inventory reduced |
| BT-05 | Open-the-gates spawns hostile near base | grid contains new zombie at chebyshev ≤ 1 from base_pos |

### 3.10 SaveSystem (M1.5) (`tests/integration/save_load_test.gd`)

| TC | Scenario | Expected |
|---|---|---|
| TSV-01 | Save then load mid-run | GameState scalars match exactly |
| TSV-02 | Party serialization round-trip | each survivor's HP, faction, assignments preserved |
| TSV-03 | Grid serialization round-trip | every tile's terrain, searched, supplies preserved |
| TSV-04 | Entity references rewired | post-load, party[0].pos refers to a real tile in grid |
| TSV-05 | Corrupt save handled | load returns false, offers delete option |
| TSV-06 | Save during build progress | `building_days_left` resumes correctly |

---

## 4. Integration Test Matrix

| TC | Flow | Expected |
|---|---|---|
| INT-01 | Full turn cycle | move → end_turn → zombie ticks → event roll → vision recomputes; all signals fire in order |
| INT-02 | Combat collision after movement | move onto zombie → end_turn → resolve_attack runs |
| INT-03 | Recruit via event then equip weapon | new survivor receives item; combat reflects new attack |
| INT-04 | Build enhancement over multiple days | day 1: started; day N: completed; passive yield begins day N+1 |
| INT-05 | Megahorde unlock → arrival → defeat | eta countdown, spawn, combat, victory screen |
| INT-06 | Morale collapse end run | feed members below need for 7 days → game_over |
| INT-07 | Lead infection → turn into zombie | infect → tick → entity replaced by zombie |
| INT-08 | Swarm survival → continue run | swarm spawned, defeated, run continues |
| INT-09 | Save during event modal | save serializes pending event; load resumes modal |
| INT-10 | Scavenge → equip → combat in 3 turns | end-to-end loot → assign → kill chain |

---

## 5. Smoke Test Checklist

Run before every PR merge to main. ~5 minutes.

```text
[ ] Project boots without console errors in Godot 4.6
[ ] Main menu renders; "Solo Survivor" button starts game
[ ] Map generates; player visible at center
[ ] Vision shows ~25 tiles, rest are dark
[ ] Click "Move" then click adjacent tile → player moves
[ ] HUD updates (Day 2)
[ ] Click "Scavenge tile" on a building → items added to stash
[ ] Click "Establish base here" → base flag visible, defense bonus shown
[ ] Click "Open Build menu" → build panel opens with 10 enhancements
[ ] Start any tier-1 enhancement → countdown shown in HUD
[ ] Click "Open Inventory / Assign" → assign panel opens; weapon assigns to lead
[ ] Click "End Day" 5x → at least one event modal fires
[ ] Resolve event → outcome displayed; continue button returns to game
[ ] Press Esc during Move mode → exits move mode without moving
[ ] Continue until megahorde unlock log line appears (~day 20-50)
[ ] Continue until megahorde arrives → combat resolves
[ ] On megahorde death → victory screen; on party wipe → defeat screen
[ ] Click "Return to Menu" → back to main menu
```

If any line fails → smoke fail → PR blocked.

---

## 6. Manual QA Test Cases

For deeper QA passes (per milestone gate). Severity per `coding-standards.md`.

### 6.1 Critical path

| TC | Steps | Expected |
|---|---|---|
| QA-01 | Solo run, day 1-30 with no base | survives or dies fairly; combat triggers correctly on collision |
| QA-02 | Solo run, day 1-30 with base on supermarket | scavenges yield matches terrain bias; defense reflects building bonus |
| QA-03 | Settled run start | base is auto-established; extra starting materials present; tutorial flag respects setting |
| QA-04 | Build all tier-1 enhancements over 10 days | each builds in expected time; passive yields apply |
| QA-05 | Recruit 3 NPCs via different paths (event accept, parley, abandoned-kid event) | all 3 in party; faction shown when revealed; assignment per character works |
| QA-06 | Trigger megahorde at minimum unlock (day 20) | unlock fires, ETA 5-8 days, spawn at edge |
| QA-07 | Trigger megahorde at maximum unlock (day 50) | runs require seeding to exceed prior swarms; eventual victory possible |
| QA-08 | Lose a run via party wipe | game-over screen accurate stats; menu return works |
| QA-09 | Lose a run via morale | morale shown decreasing; game-over fires at 0 |
| QA-10 | Lose a run via lead death | game-over fires; lead death is the trigger |

### 6.2 Edge cases

| TC | Steps | Expected |
|---|---|---|
| QA-E1 | Move-mode click on own tile | nothing happens; mode stays active |
| QA-E2 | Click off-map tile | no error; nothing happens |
| QA-E3 | Open multiple panels in sequence | only one visible; closing returns to gameplay |
| QA-E4 | Spam End Day button | no double-fires; turn advances once per click |
| QA-E5 | Empty inventory + use consumable button | button disabled; no crash |
| QA-E6 | Empty party (after wipe) | no actions render; game-over screen shows |
| QA-E7 | Save mid-event then quit | load resumes inside modal |
| QA-E8 | Open build menu without base | menu inaccessible; no crash if force-opened |
| QA-E9 | Load corrupted save file | error dialog; offers delete; menu stays accessible |
| QA-E10 | Resolution change mid-game | UI rescales without overlapping elements |

### 6.3 Faction-specific

| TC | Steps | Expected |
|---|---|---|
| QA-F1 | Recruit cannibal, observe 5 nights | betrayal fires within probabilistic window |
| QA-F2 | Parley a doctor while injured | heal action available |
| QA-F3 | Parley a raider with high supplies | extort/intimidate option appears |
| QA-F4 | Cultist refuses to fight zombies | observable in combat |
| QA-F5 | Pacifist (M3.2) refuses combat orders | enforced by dialog |

### 6.4 Performance

| TC | Steps | Expected |
|---|---|---|
| QA-P1 | 14×14 map, 30+ entities active | frame time < 16.6ms |
| QA-P2 | 20×20 map, 60+ entities | frame time < 16.6ms after M3 |
| QA-P3 | Memory after 100-day run | < 200MB heap |
| QA-P4 | HTML5 export load time | < 8s on broadband |
| QA-P5 | HTML5 save/load via IndexedDB | round-trip < 1s |

---

## 7. Playtest Protocol

**Cadence**: weekly during M1-M3; twice-weekly during M4-M5.

**Format**: 30-minute single-run session.

**Observer questions** (logged per session):

1. What was the most interesting decision you made?
2. What was the most boring stretch?
3. Did any event surprise you?
4. Did any UI element confuse you?
5. Did you feel the megahorde was approachable or hopeless?
6. Did you ever feel safe? When?
7. Did you ever feel out of control? When?
8. Did the run feel too short / too long / right?

**Output**: `production/qa/playtests/playtest-<date>-<tester>.md` per session.

**Recurring patterns** flagged in retrospective at end of each milestone (use
`/retrospective` skill).

---

## 8. Performance Test Cases

Use Godot's built-in profiler (`Debugger > Profiler`).

| TC | Scenario | Budget | Notes |
|---|---|---|---|
| PERF-01 | Idle on base tile | < 1ms gameplay logic | should be near zero |
| PERF-02 | End turn with 30 entities | < 5ms | dominant cost: AI tick + visibility |
| PERF-03 | Map generation, 14×14 | < 50ms | one-time at run start |
| PERF-04 | Map generation, 20×20 (M3.6) | < 100ms | proportional |
| PERF-05 | Event modal show/hide | < 16ms | prevent frame skip |
| PERF-06 | Build panel populate (M4) | < 20ms | cache where possible |

---

## 9. Regression Suite

Maintained in `tests/regression-suite.md`. Updated whenever a bug is fixed:

> Every fixed bug at Sev 1 or Sev 2 must add a regression test before close.

**Suite content** (initial):

- Each TC from §3-§4 above (auto-run in CI).
- Each fixed-bug regression test (added over time).
- Each balance-change verification test (after `/balance-check` runs).

---

## 10. Bug Severity Definitions

| Severity | Definition | Example | Response |
|---|---|---|---|
| **Sev 1** | Game crashes, data loss, unwinnable state | crash on map gen; save file deletes itself | fix immediately, no merge until fixed |
| **Sev 2** | Major mechanic broken, blocks progression | megahorde never spawns; cannot build past tier 1 | fix this sprint |
| **Sev 3** | Minor mechanic wrong, workaround exists | armor bonus off by 1; UI text overlaps | fix when convenient |
| **Sev 4** | Cosmetic only | tooltip typo; off-color glyph | fix during polish phase |

**Triage cadence**: weekly. Use `/bug-triage` skill.

**Bug location**: `production/qa/bugs/sev[1234]-<slug>.md`. Template:

```markdown
# [SEV-N] Title

**Reported**: YYYY-MM-DD by <name>
**Status**: open | in-progress | fixed | wontfix
**Affects version**: v0.X
**Fixed in**: v0.Y (PR #N)

## Reproduction
1. ...
2. ...

## Expected
...

## Actual
...

## Notes
- ...

## Regression test
- `tests/regression/<test_file>.gd` (added in PR #N)
```

---

## 11. CI/CD Integration

### 11.1 GitHub Actions workflow (M0.3)

`.github/workflows/test.yml` runs on push and PR:

```yaml
- Install Godot 4.6 headless
- Pull GUT addon
- Run `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/`
- Fail build on any test failure
- Upload test results as artifact
```

### 11.2 Pre-merge gates

Per `coding-standards.md`:

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Smoke checklist passes (manual)
- [ ] No new Sev-1 or Sev-2 bugs introduced
- [ ] Code review by appropriate specialist (godot-gdscript-specialist for `.gd`)
- [ ] If GDD-affecting: `/design-review` passed
- [ ] If formula-affecting: regression test added

### 11.3 Release gates

Per phase acceptance gate (M0-M5 in EXPANSION_PLAN.md):

- [ ] All open Sev-1 and Sev-2 bugs closed
- [ ] Coverage hits target for the phase
- [ ] Performance budgets respected (§8)
- [ ] Playtest sessions completed (§7)
- [ ] `/gate-check` skill returns PASS

---

## 12. Test Data Management

### 12.1 Fixtures

`tests/fixtures/`:

- `map_seed_42.tres` — deterministic 14×14 map
- `party_full.tres` — 5-member party with mixed factions
- `inventory_loaded.tres` — diverse stash
- `events_subset.json` — minimal event set for fast tests

### 12.2 Helpers

`tests/helpers/` (M0.3):

- `test_helpers.gd` — `make_lead_with_hp(n)`, `make_zombie(unit_id, size)`, `seed_rng(n)`
- `assert_helpers.gd` — `assert_signal_emitted(bus, sig, fn)`, `assert_party_size(n)`

Use `/test-helpers` skill to scaffold.

### 12.3 Determinism guarantees

- Seed `RNG` at start of each test method.
- Replace `randi()` calls with `RNG.randi_range_inclusive` in production code (M0).
- Tests must NOT call `RandomNumberGenerator.randomize()`.
- Time-dependent tests use mocked `Time.get_unix_time_from_system()` (wrap in singleton).

---

## 13. Acceptance — When is testing "done"?

Per phase, testing is complete when:

- [ ] All test cases for new features authored
- [ ] All tests passing
- [ ] Coverage target hit for the system
- [ ] Smoke checklist updated with any new actions
- [ ] Regression suite updated with any bug fixes
- [ ] Playtest report filed (M1+)
- [ ] Retrospective notes captured (`/retrospective`)

---

## 14. Cross-references

- Roadmap: `design/EXPANSION_PLAN.md`
- Vision: `design/GAME_DESIGN.md`
- Coding standards: `../.claude/docs/coding-standards.md`
- Bug template: this doc, §10
- Regression suite: `tests/regression-suite.md` (created in M0.3)
- Test fixtures: `tests/fixtures/`
- CI workflow: `.github/workflows/test.yml` (created in M0.3)

---

## 15. Decision Log

| Date | Decision | Rationale | Made by |
|---|---|---|---|
| 2026-05-03 | Initial test plan drafted | Establish QA baseline pre-M0 | claude-code |
| 2026-05-03 | GUT chosen over alternatives | Already pinned in technical-preferences.md | claude-code |
| 2026-05-03 | Skip visual regression testing | Glyph-based UI doesn't warrant it; revisit at M4 sprite work | claude-code |
