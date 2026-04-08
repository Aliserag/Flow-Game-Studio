# Technical Preferences

<!-- Configured 2026-04-06 for Lucky Strike / Godot 4.6 / GDScript -->

## Engine & Language

- **Engine**: Godot 4.6
- **Language**: GDScript (primary) — C++ via GDExtension only for verifiable performance bottlenecks
- **Rendering**: Godot 4.6 default renderer (Vulkan/GLES3 compatibility mode for HTML5)
- **Physics**: Jolt Physics (Godot 4.6 default) — only for UI collision; no physics gameplay

## Naming Conventions (GDScript)

- **Classes**: PascalCase — `ChipEconomy`, `FlowBridge`, `RunState`
- **Variables/Functions**: snake_case — `current_chips`, `apply_chip_delta()`
- **Signals**: snake_case past-tense verb — `chips_changed`, `deal_locked`, `run_ended`
- **Constants**: UPPER_SNAKE_CASE — `STARTING_CHIPS`, `WIN_THRESHOLD`, `MIN_BET`
- **Enums**: PascalCase enum name, UPPER_SNAKE_CASE values — `enum RunPhase { BETTING_ROOM, DEAL_PENDING }`
- **Files**: snake_case matching class — `flow_bridge.gd`, `run_state.gd`
- **Scenes**: PascalCase matching root node — `BettingTable.tscn`, `HUD.tscn`
- **Data files**: kebab-case — `chip-economy.json`, `bet-types.json`, `items.json`
- **Private members**: `_prefix` for methods/vars not intended for external use

## File Organization

- `src/core/` — Autoload singletons (RunState, FlowBridge, ItemInventory, ItemEffectEngine)
- `src/gameplay/` — VRF Tx Manager, Bet Resolution, Room Generator
- `src/ui/` — BettingTable, HUD, RunEndScreen, ItemStack
- `src/data/` — Data loading helpers (reads from `data/*.json`)
- `data/` — All JSON config files (chip_economy.json, bet_types.json, items.json, etc.)
- `assets/` — Art, audio, fonts (no logic)
- `prototypes/` — Throwaway spike code (not imported into `src/`)

## Performance Budgets

- **Target Framerate**: 60fps (browser target)
- **Frame Budget**: 16.6ms total; gameplay logic < 1ms per frame
- **Single deal resolution**: < 1ms (Bet Resolution + Item Effect Engine combined)
- **RunState signal processing**: < 0.1ms per call
- **Draw Calls**: < 50 per frame (2D game; budget is generous)
- **Memory Ceiling**: < 128MB (browser tab constraint)
- **Startup time**: < 3 seconds to main menu (HTML5 export)

## Testing

- **Framework**: GUT (Godot Unit Testing) — `addons/gut/`
- **Minimum Coverage**: All formulas in Chip Economy, Bet Resolution, Item Effect Engine
- **Required Tests**:
  - Chip Economy: net_delta formula, chip phase thresholds, win/bust conditions
  - Bet Type Configuration: all 4 win conditions, boundary values (e.g., VRF=50 for Low/High)
  - Item Effect Engine: payout_mult accumulation, chip_save cap, stacking
  - VRF integer derivation: same bytes always produce same integers
  - RunState: apply_chip_delta clamping, phase transitions, signal emission
- **Test location**: `tests/unit/` for formula tests; `tests/integration/` for multi-system flows

## Autoloads (Singletons)

All autoloads registered in Project Settings. Load order matters:

1. `FlowBridge` (src/core/flow_bridge.gd) — must initialize before any blockchain calls
2. `RunState` (src/core/run_state.gd) — must initialize before any gameplay systems
3. `ItemEffectEngine` (src/core/item_effect_engine.gd) — stateless; order not critical

## Forbidden Patterns

- **No hardcoded gameplay values** — all constants in `data/*.json`, never in GDScript
- **No direct JavaScript interop outside FlowBridge** — all JS calls route through FlowBridge
- **No polling for state changes** — use signals; no `while` loops waiting on RunState fields
- **No cross-system state writes** — only the owning system writes its state
  (e.g., only Bet Resolution calls RunState.apply_chip_delta; no other system does)
- **No float chip storage** — chips are always integers; floor() before storing
- **No synchronous blockchain calls** — all FlowBridge operations are async/signal-based

## Allowed Libraries / Addons

- **GUT** (Godot Unit Testing) — testing framework
- **FCL JS SDK** — bundled in HTML5 export template (not a GDScript dependency)
- No other third-party addons approved yet — add via `/architecture-decision` when needed

## Architecture Decisions Log

- [ADR-001] Signal-based state management via RunState singleton — `docs/architecture/ADR-001-run-state-signals.md`
- [ADR-002] Additive item multiplier stacking — `docs/architecture/ADR-002-item-stacking.md`
- [ADR-003] FlowBridge as exclusive blockchain gateway — `docs/architecture/ADR-003-flow-bridge-gateway.md`
