# Technical Preferences — WARBAND

<!-- Realigned 2026-05-14 from prior Lucky Strike project to WARBAND -->

## Engine & Language

- **Engine**: Godot 4.6 stable (official 89cea1439)
- **Language**: GDScript (primary) — C++ via GDExtension only for verifiable performance bottlenecks
- **Rendering**: GLES3 / Compatibility renderer (HTML5 compatible)
- **Physics**: None for gameplay. Side-on 2D positions are kinematic. No physics simulation.

## Input & Platform

- **Target Platforms**: Web (HTML5 primary), Desktop (dev/testing)
- **Input Methods**: Keyboard/Mouse (desktop), Touch (mobile browser)
- **Primary Input**: Mouse (point-and-click tavern, GO button on battle)
- **Gamepad Support**: None for G0; consider at G2
- **Touch Support**: Tap-equivalent of click for tavern card selection at G2

## Naming Conventions (GDScript)

- **Classes**: PascalCase — `RunState`, `CombatResolver`, `Orc`, `TavernCard`
- **Variables/Functions**: snake_case — `current_gold`, `apply_damage()`, `roll_candidates()`
- **Signals**: snake_case past-tense verb — `orc_died`, `gold_changed`, `battle_ended`
- **Constants**: UPPER_SNAKE_CASE — `STARTING_GOLD`, `MAX_ROSTER_SIZE`, `MIN_HIRE_PRICE`
- **Enums**: PascalCase enum name, UPPER_SNAKE_CASE values — `enum BattlePhase { TAVERN, DEAL, BATTLE, RESOLUTION }`
- **Files**: snake_case matching class — `run_state.gd`, `combat_resolver.gd`
- **Scenes**: PascalCase matching root node — `TavernScreen.tscn`, `BattleScreen.tscn`
- **Data files**: kebab-case — `orc-archetypes.json`, `enemy-types.json`, `gear-pieces.json`
- **Private members**: `_prefix` for methods/vars not intended for external use

## File Organization

- `src/core/` — Autoload singletons (RunState, Rng, ItemRegistry, SaveSystem, Logger)
- `src/gameplay/` — Combat Resolver, Gold Economy, Trait Engine, Loot
- `src/ui/` — Tavern, Battle Display, Resolution, Memorial screens
- `src/data/` — Data loaders (reads from `data/*.json`)
- `src/ai/` — Combat target selection logic
- `data/` — All JSON config (orc-archetypes, enemy-types, gear-pieces, traits, etc.)
- `assets/` — Art, audio, fonts (no logic)
- `tests/unit/` — GUT unit test scripts
- `tests/integration/` — Headless multi-system tests
- `prototypes/` — Throwaway spike code (not imported into `src/`)

## Performance Budgets

- **Target Framerate**: 60fps (browser target)
- **Frame Budget**: 16.6ms total; gameplay logic < 1ms per frame
- **Combat tick resolution**: < 1ms per tick
- **RunState signal processing**: < 0.1ms per call
- **Draw Calls**: < 100 per frame (10-20 sprites + UI)
- **Memory Ceiling**: < 128MB (browser tab constraint)
- **Startup time**: < 3 seconds to main menu (HTML5 export)
- **Particle cap**: 24 simultaneous (per art bible §9)

## Testing

- **Framework**: GUT (Godot Unit Testing) — `addons/gut/`
- **Minimum Coverage**: All formulas in Combat Resolver, Gold Economy, Stat Allocation, Trait Engine
- **Test location**: `tests/unit/[system-slug]/` per system; `tests/integration/` for cross-system flows
- **Headless runner**: `~/.local/bin/godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`

## Autoloads (Singletons)

All autoloads registered in `project.godot`. Load order matters:

1. `Logger` (src/core/logger.gd) — must be first; everything logs through it
2. `Rng` (src/core/rng.gd) — must initialize before any random call
3. `ItemRegistry` (src/core/item_registry.gd) — data loader; depends on data files
4. `RunState` (src/core/run_state.gd) — must initialize before any gameplay system
5. `SaveSystem` (src/core/save_system.gd) — in-memory for G0; localStorage at G1
6. `CombatResolver` is a *node*, not autoload — instantiated per battle

## Forbidden Patterns

- **No hardcoded gameplay values** — all constants in `data/*.json` (exception: max collection caps)
- **No direct random calls** — always go through `Rng.roll()` to keep determinism
- **No polling for state changes** — use signals
- **No cross-system state writes** — only the owning system writes its state
- **No float gold storage** — gold is always integer; floor() before storing
- **No `process()` for game logic** — use signals or explicit tick functions
- **No raw `print()`** — use `Logger` always

## Tooling

- **Godot binary**: `~/.local/bin/godot` (linked to `~/godot-install/Godot_v4.6-stable_linux.x86_64`)
- **Headless invocation**: `~/.local/bin/godot --headless --path .`
- **Test runner**: `~/.local/bin/godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`

## Engine Specialists

| File Extension / Type | Specialist to Spawn |
|---|---|
| `.gd` (GDScript) | `godot-gdscript-specialist` |
| `.gdshader` / `.gdshaderinc` | `godot-shader-specialist` |
| `.tscn` / `.tres` | `godot-specialist` |
| `.cpp` / `.h` (GDExtension) | `godot-gdextension-specialist` |
| General architecture review | `godot-specialist` |
