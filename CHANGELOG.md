# Changelog

All notable changes to They Come At Night.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Version: SemVer-ish (0.X = pre-release; 1.0 = launch).

## [Unreleased]

### Planned (M2 onward)
- Per-survivor tasks and stats
- Settlement detail screen
- +30 events, +5 factions, +10 items
- Audio, sprite art, settings menu

## [0.2.1] — Verification pass

### Added
- `scripts/ui/main_launcher.gd` — top-level launcher routing on `--test`,
  `--smoke`, `--smoke-long`, `--gameview-boot` CLI args
- `--test` runs the full test suite (alternative to broken `--script` mode)
- `--smoke` simulates a 50-turn solo run (CI smoke)
- `--smoke-long` simulates a 100-turn Settled-mode run with mixed-faction party
- CI workflow updated to use `Main.tscn -- --test` and adds smoke job

### Fixed — bugs found by running Godot 4.4 locally
- `grid.gd:65` and `turn_manager.gd:109` — `:=` inference failed on `e.pos` /
  `lead.pos`; now explicit `: Vector2i`.
- `map_generator.gd:57,61` — Variant inference warning treated as error;
  added explicit types on `dist` and `pick`.
- `betrayal_system.gd:65` — declared `var pick: int` but `RNG.weighted_pick`
  returns String; type runtime-mismatch caused outcome dispatch to fail
  silently (betrayal fired but no outcome ran). Fixed type to `String`.
- `build_panel.gd:33,34,61` — Variant inference fixes (`built`/`building`/`build_id`).
- `assign_panel.gd:42,54,55,83,91` — Variant inference fixes (`sid`/`iid`/`sid2`).
- `trade_panel.gd:50,74` — Variant inference fixes (`iid`).
- `game_view.gd:173,234,264` — Variant inference fixes (`base_t`/`t`).
- `tests/run_tests.gd` — replaced with a deprecation stub; tests now run via
  `Main.tscn -- --test` because `--script` mode doesn't resolve autoload names.

### Verified
- 261 tests pass (DataLoader 133, Grid 65, Tile 15, CombatResolver 9,
  InventorySystem 12, SwarmSystem 6, BetrayalSystem 7, SaveLoad 14)
- Solo smoke (50 turns) completes without engine errors
- Settled smoke (100 turns, 5-person party) exercises betrayal, swarm
  scheduling, combat, hunger upkeep — all clean
- `GameView.tscn` boots and `_ready()` completes without errors

## [0.2.0] — M0 + M1

### Added — M0 Verification
- `.gitignore` for Godot cache and exports
- Test infrastructure under `tests/`:
  - Zero-dependency `TestFramework` (assertion API mirrors GUT for easy upgrade)
  - `TestHelpers` factories (seed_rng, make_lead_at, make_zombie, make_grid)
  - 6 unit suites: DataLoader, Grid, Tile, CombatResolver, InventorySystem, SwarmSystem
  - 1 integration suite: SaveLoad round-trip
  - Headless runner: `godot --headless --script res://tests/run_tests.gd`
- GitHub Actions workflow `.github/workflows/they-come-at-night-tests.yml`
- `tests/regression-suite.md` — bug → test mapping

### Added — M1.1 Betrayal System
- `BetrayalSystem.nightly_check(grid)` runs in `TurnManager.end_turn`
- Three weighted outcomes when betrayal fires:
  - **Steal & flee** (50%) — member vanishes with 1-3 stack-halving items
  - **Open the gates** (25%) — member dies; spawns a zombie pack near base/lead
  - **Knife in the dark** (25%) — member damages a random other survivor for 2-5 HP
- Tension modifier scales effective betrayal chance:
  - morale ≤ 5 → ×1.5
  - morale ≤ 3 → ×2.0
  - active `tension` event effect → +0.25
- New event `argument_at_dinner` exercises the `tension` effect
- `stats.npcs_betrayed` counter tracked

### Added — M1.2 Parley
- New action **Talk to <name>** appears when an NPC is on or adjacent to the lead
- 4 dialogue options: Recruit (faction's join_chance), Question carefully (reveals faction), Trade, Walk away
- Hostile factions accepting your invite is bad — they join with their full betrayal_chance intact
- Cannibal NPCs flagged `⚠ LONG PIG` when `cannibal_warning` knowledge is held

### Added — M1.3 Faction-aware NPC AI
- `NpcBehavior.step(npc, grid)` replaces random-walk with per-faction movement
  - **Doctors** drift toward injured survivors; heal adjacent allies for 1 HP
  - **Militia** patrol road tiles
  - **Raiders** stalk lead; chance to mug for 1-3 HP on adjacency
  - **Cannibals** stalk cautiously, maintain distance until parley
  - **Cultists** drift toward zombies
  - **Scavengers** drift toward unsearched buildings
  - Others fall through to default drift toward player

### Added — M1.4 Trade System
- `TradeSystem` with faction-tinted stocks and price markups
- New `TradePanel` UI: their stock (BUY) vs your inventory (SELL)
- Currency proxy: `scrap`
- Faction markups: doctors/militia 1.0× (fair), lone_wolf/scavengers 1.2× (savvy), raiders/cannibals 1.6× (extort), cultists 0.9× (don't care)
- Faction-restricted stock pools (doctors don't sell weapons; militia doesn't sell scrap)
- Wired through Parley → Trade option

### Added — M1.5 Save / Load
- `SaveSystem` with single-slot `user://save.json`
- Save action available every turn
- Continue button on main menu (disabled when no save)
- Round-trips: GameState scalars, party with faction state, inventory, knowledge, grid (terrain/searched/explored/has_base), entities (zombies + NPCs)
- Stable entity IDs preserved; `Entity._next_id` bumped past max on load
- Version field for forward-compat detection
- Integration test verifies round-trip preserves party, faction reveal, assignments

### Added — M1.6 Effect Kinds Wired
- `defense_temp` — adds N defense for M turns; supports both `int` (uses default 3 turns) and `[mag, turns]` array forms
- `preparation_bonus` — one-shot defense buff consumed at next swarm/megahorde combat
- `tension` — adds turns of betrayal-chance multiplier
- New events `fortify_drill` (defense_temp) and `scout_returns` (preparation_bonus) exercise these

### Added — M1.7 Knowledge Panel
- `data/knowledge.json` with 3 entries (cannibal_warning, immunity_exists, the_truth)
- `KnowledgePanel` UI accessible from action bar (shows count)
- Empty state message when no knowledge yet
- Cannibal_warning auto-added when player parleys a cannibal NPC

### Fixed (Bug-fix backlog M0.4)
- **BUG-001** `_lose_supplies` mutated Dictionary during iteration → could crash. Now iterates a key snapshot.
- **BUG-002** Combat damage used `randi()` instead of seeded `RNG.randi_range_inclusive` — broke determinism for tests.
- **BUG-003** Lead death left party leaderless. Now promotes the next-in-line and reveals their faction.
- Removed meaningless `s.has_method("get")` check in infection tick.

### Changed
- `DataLoader` now loads `knowledge.json`
- `EventBus` adds `open_trade_request(npc_id: int)` signal
- `TurnManager.end_turn` now also runs nightly betrayal check and decays temporary defense buffs
- `Npc.choose_move` delegates to `NpcBehavior` (no more inline random walk)
- `MainMenu` now shows a Continue button (disabled when no save exists)

### Tests added
- 7 unit suites: DataLoader, Grid, Tile, CombatResolver, InventorySystem, SwarmSystem, BetrayalSystem
- 1 integration suite: SaveLoad
- ~50 individual test cases total

### Files added
```
+ they-come-at-night/.gitignore
+ they-come-at-night/CHANGELOG.md
+ they-come-at-night/data/knowledge.json
+ they-come-at-night/scripts/systems/betrayal_system.gd
+ they-come-at-night/scripts/systems/npc_behavior.gd
+ they-come-at-night/scripts/systems/parley_system.gd
+ they-come-at-night/scripts/systems/save_system.gd
+ they-come-at-night/scripts/systems/trade_system.gd
+ they-come-at-night/scripts/ui/knowledge_panel.gd
+ they-come-at-night/scripts/ui/trade_panel.gd
+ they-come-at-night/tests/README.md
+ they-come-at-night/tests/regression-suite.md
+ they-come-at-night/tests/test_framework.gd
+ they-come-at-night/tests/run_tests.gd
+ they-come-at-night/tests/helpers/test_helpers.gd
+ they-come-at-night/tests/unit/test_data_loader.gd
+ they-come-at-night/tests/unit/world/test_grid.gd
+ they-come-at-night/tests/unit/world/test_tile.gd
+ they-come-at-night/tests/unit/systems/test_combat_resolver.gd
+ they-come-at-night/tests/unit/systems/test_inventory_system.gd
+ they-come-at-night/tests/unit/systems/test_swarm_system.gd
+ they-come-at-night/tests/unit/systems/test_betrayal_system.gd
+ they-come-at-night/tests/integration/test_save_load.gd
+ .github/workflows/they-come-at-night-tests.yml
```

## [0.1.0] — Prototype

### Added
- Godot 4.6 project scaffolding (`project.godot`, scenes, autoloads)
- Procedural 14×14 grid map with town clusters and a road
- Lead survivor + party + zombies + NPCs entities
- Click-to-move turn loop with fog of war
- Combat resolver (one-roll-per-encounter)
- Inventory system with per-character assignments and scavenging
- Base system with 10 enhancements across 3 tiers
- Swarm system with Frostpunk-style countdown and megahorde win condition
- EU4-style event system with 17 starter events
- Two modes: Solo Survivor and Settled
- Main menu, game view, event modal, build panel, assign panel, game over screen
- Design documents: `GAME_DESIGN.md`, `EXPANSION_PLAN.md`, `TEST_PLAN.md`
