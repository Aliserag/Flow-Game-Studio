# They Come At Night

A grid-based, procedurally generated zombie apocalypse survival roguelike for **Godot 4.6**.

You start as a single survivor on a procedurally generated grid. Every day you make
one decision: move, scavenge, establish a base, build a wall, rest. Every night
the dead get a little closer. Other survivors might want to join you — most are
who they say they are. A few are not.

The goal is to survive long enough to face the **megahorde**, and survive that too.

## Running it

1. Install **Godot 4.6** (project pinned to 4.6 in `project.godot`).
2. Open the `they-come-at-night/` folder as a Godot project.
3. Press F5 (run main scene). The main menu appears — pick a mode and play.

The game has no external dependencies. All data is in `data/*.json`.

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
