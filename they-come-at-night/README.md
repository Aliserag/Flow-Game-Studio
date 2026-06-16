# They Come At Night

A grid-based, procedurally generated zombie apocalypse survival roguelike for **Godot 4**.

You start as a single survivor on a procedurally generated grid. Every day you make
one decision: move, scavenge, establish a base, build a wall, rest. Every night
the dead get a little closer. Other survivors might want to join you — most are
who they say they are. A few are not.

The goal is to survive long enough to face the **megahorde**, and survive that too.

> Content warning: depicts a zombie apocalypse with themes of death, betrayal,
> cannibalism, infection, hopelessness, and the loss of children. Pixel-art
> graphics — nothing explicit — but the tone is dark.

## Play

Pre-built artifacts in `dist/` after running `make export-all`:

- `dist/web/index.html` — open in any modern browser (~44MB)
- `dist/linux/they-come-at-night.x86_64` — ~70MB
- `dist/windows/they-come-at-night.exe` — ~98MB
- `dist/macos/` — operator must run `make export-macos` on a Mac

Controls and gameplay help: see `CONTROLS.txt` (shipped next to each binary)
or click CREDITS from the main menu.

## Develop

1. Install **Godot 4.4** or later.
2. Open the `they-come-at-night/` folder as a Godot project.
3. Press F5 to run.

All gameplay data is in `data/*.json`. No external runtime dependencies.

### Make targets

```bash
make verify-green   # editor scan + 418 tests + 158 E2E + smokes + playtest
make test           # unit tests only
make e2e            # 158-assertion programmatic playthrough
make smoke          # 50-turn solo run
make smoke-long     # 100-turn settled run
make playtest       # 45 seeded balance runs across difficulty × map matrix
make export-web     # → dist/web/index.html (CC0/MIT assets bundled)
make export-linux   # → dist/linux/they-come-at-night.x86_64
make export-windows # → dist/windows/they-come-at-night.exe
make sprites        # PixelLab sprite generation (requires PIXELLAB_SECRET)
make sprites-dry    # preview sprite-generation prompts at zero cost
```

### Browser smoke (validates the web export in a real headless Chromium)

```bash
PLAYWRIGHT_BROWSERS_PATH=/opt/pw-browsers NODE_PATH=/opt/node22/lib/node_modules \
    node tests/browser_smoke.js
```

## Project structure

```
they-come-at-night/
├── project.godot                Godot project file (v0.4.0)
├── LICENSE                      MIT
├── PRIVACY.md                   Privacy & content notice
├── CONTROLS.txt                 Ships next to each binary
├── Makefile                     verify-green + exports + sprites
├── assets/
│   ├── audio/sfx/               CC0 Kenney + MIT Godot demos
│   ├── audio/music/             MIT (Godot demos: ambient.ogg, menu.ogg)
│   ├── audio/licenses/          Auto-discovered by the credits screen
│   ├── sprites/                 Optional PNG overrides (auto-discovered)
│   └── theme.tres               Warm-brown UI theme
├── data/                        61 events, 12 factions, 32 items, 13 terrains
├── scripts/
│   ├── autoload/                GameState, EventBus, DataLoader, RNG,
│   │                            BuildInfo, CrashLogger, AudioDirector,
│   │                            SettingsService
│   ├── entities/                Survivor, Zombie, NPC
│   ├── systems/                 turn manager, combat, base, swarm, betrayal,
│   │                            parley, trade, save, sprite & audio generators
│   └── ui/                      Each scene's controller
├── scenes/                      Main, MainMenu, GameView, Settings, Settlement,
│                                Credits, plus modal/panel scenes
├── tests/                       418 unit + 158 E2E + browser smoke +
│                                playtest harness
└── tools/                       generate_sprites.py (PixelLab pipeline)
```

## Status (v0.4.0)

- **418/418 unit tests, 158/158 E2E assertions** — three deterministic runs
- **Browser-verified** — boots and renders in headless Chromium
- **Linux + Windows + Web builds** — all three packaged and tested
- **Real CC0/MIT audio** — 10 SFX cues + ambient + menu music
- **Procedural sprites** — distinguishable per terrain/entity
  (`make sprites` swaps in PixelLab-generated PNGs)
- **Save/load** with versioned migration framework
- **Settings menu**, **credits screen**, **pause overlay**, **F12 screenshot**,
  **content warning splash**, **local crash log**, **version stamp**
- **Automated playtest** — 45-run balance harness with findings report

### What's still missing for a real launch

- **Human playtest** — automated playtest can find balance issues but cannot
  judge fun
- **macOS build** — needs `make export-macos` on a Mac with Xcode CLI
- **Hand-drawn art polish** — procedural sprites are recognizable but not
  stylized; run `make sprites` for AI-generated, or commission an artist
- See `production/ralph/playtest-findings.md` for the balance issues the
  harness already uncovered (Tourist+Standard wipe-rate, Apocalypse food
  collapse)

## License

MIT — see `LICENSE`. Bundled assets retain their own licenses (CC0 and MIT);
the credits screen auto-discovers and lists them.


## Modes

- **Solo Survivor** — Start with nothing but a knife, a few bandages, and a map you don't know yet. Build a base on any tile. Buildings give defense but make escape harder; open ground is the reverse.
- **Settled** — Start with a base already established and a small surplus, so you can focus on building enhancements and weathering threats. Same end condition.

## Core systems

| System | What it does |
|---|---|
| **Grid + fog of war** | 14×14 procedurally generated map. Towns cluster around 2–3 town centres with a road or two carved between them. Vision radius extends from the player and is widened by a watchtower. |
| **Zombie AI** | Single zombies, packs, hordes, swarms, megahorde. Each turn they move randomly with bias toward the closest survivor when within their detection radius. They can walk off the map. Spawn weights shift with day index — early game is mostly singles, late game is mostly hordes. |
| **NPCs and hidden factions** | Strangers wander the map. Their faction is **hidden** until you interact. Factions include lone wolves, militia, raiders, scavengers, doctors, cultists, and **cannibals**. Cannibals look friendly. |
| **Recruitment** | NPCs can ask to join. You decide. Some have high betrayal chances — you might find out which the hard way. |
| **Inventory** | Shared stash plus per-character assignments. Weapons assigned to a survivor add their attack to combat; armor adds defense. Consumables (medkits, antibiotics) are used directly on a survivor. |
| **Base + enhancements** | Establish a base on any tile (building or open). Build barricades, watchtowers, gardens, fortified walls, infirmaries, armories, trap fields, generators, radio towers, and a bunker. Each enhancement has cost, build time, and prerequisites. |
| **Event system** | Europa Universalis-style: each turn rolls a chance to fire a contextual event. Each event has 1–4 options, each option has weighted random outcomes with effects (loot, morale, casualties, recruitment, forced movement, siege triggers). 17 starter events with hooks for many more. |
| **Swarm countdown** | After day 8, swarms can be scheduled with a 2–4 day warning — like Frostpunk's frost. You see the ETA and the threat type. |
| **Megahorde** | Unlocks on a randomly selected day between 20 and 50, then arrives 5–8 days after unlock. Killing the megahorde wins the run. |
| **Combat** | Resolved in one round per encounter. Attack power = sum of party attack + best weapon. Defense from armor + base + enhancements. Damage spread across the party; bites can infect. |
| **Infection** | Bitten survivors may turn at any night unless cured by antibiotics. Turning kills them and spawns a zombie on their tile. |

## Code layout

```
they-come-at-night/
├── project.godot           Godot project config (4.6)
├── icon.svg
├── scenes/
│   ├── Main.tscn           Loads the main menu
│   ├── MainMenu.tscn
│   ├── GameView.tscn       Main gameplay screen
│   └── EventModal.tscn     (currently embedded in GameView)
├── scripts/
│   ├── autoload/           GameState, EventBus, DataLoader, RNG (singletons)
│   ├── world/              tile.gd, grid.gd, map_generator.gd
│   ├── entities/           entity.gd, survivor.gd, zombie_unit.gd, npc.gd
│   ├── systems/            turn_manager, zombie_ai, event_system,
│   │                       combat_resolver, swarm_system, base_system,
│   │                       inventory_system
│   └── ui/                 main_menu, game_view, grid_renderer, event_modal,
│                           build_panel, assign_panel
├── data/
│   ├── terrain.json        10 terrain types with stats, glyphs, colors
│   ├── items.json          22 items (weapons, armor, consumables, materials)
│   ├── factions.json       7 factions with intro lines and betrayal chances
│   ├── zombie_units.json   5 zombie unit types (single → megahorde)
│   ├── enhancements.json   10 base enhancements across 3 tiers
│   └── events.json         17 events (humour, horror, moral choices, lore)
└── design/
    └── GAME_DESIGN.md      Full design document
```

## Authoring new content

Everything player-facing is data-driven — add a faction, item, terrain, enhancement,
zombie type, or event by editing the matching JSON file. No GDScript changes required.

### Adding an event

```json
"my_event": {
  "title": "What Happens Next",
  "weight": 8,
  "min_day": 5,
  "tags": ["horror"],
  "conditions": {"on_building": true, "has_party": true},
  "description": "...flavor text. {party_member} can be substituted.",
  "options": [
    {"text": "Do the thing", "cost": {"scrap": 1}, "outcomes": [
      {"weight": 70, "text": "It works.", "effects": {"morale": 2, "items": {"bandage": 1}}},
      {"weight": 30, "text": "It doesn't.", "effects": {"hp": -3}}
    ]}
  ]
}
```

Valid effect keys: `items`, `hp`, `morale`, `noise`, `recruit_random_faction`,
`recruit_specific_faction`, `kill_random_party`, `force_move`, `spawn_zombies_nearby`,
`spawn_hostile_npc`, `trigger_siege`, `supply_loss`, `knowledge`, `companion`,
`vetting_bonus`.

## Status

Playable prototype. Single-screen UI, text-and-glyph rendering. No saved games,
no audio, no localization, no settings menu. The core loop and progression are
in. Visuals are deliberately spartan so the simulation can be the centerpiece.

## Roadmap

See `design/GAME_DESIGN.md` for the design vision and unimplemented stretch features.
