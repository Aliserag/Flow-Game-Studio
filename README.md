# WARBAND

A gritty pixel-art auto-battler where you recruit, equip, and grieve a warband of named orcs as you climb from farm-raid bandit to warchief. Every battle is a 30-60 second resolved skirmish. Every orc has a name, a face, and permanent death waiting to happen.

## What is this?

WARBAND is a single-player roguelike campaign in the spirit of Battle Brothers' permadeath saga merged with Slay the Spire's pacing and Hearthstone Battlegrounds' draft loop. You assemble a roster of 5-10 grunts from a rotating candidate pool, equip them from loot and market stock, allocate stat points on level-up, then press GO and watch the auto-resolved 2D pixel-art brawl unfold with floating damage numbers and gravestone animations for the fallen. The core loop is 30-60 minutes per campaign run. Death is permanent and named — the game gives you reasons to grieve, not just inventory holes.

## Current Status

**Alpha — G1 Vertical Slice**

Playable: 1 biome (farmland), 1 boss (Hog Baron), 6 archetypes (Berserker, Archer, Brute, Cleaver, Shaman, Pikeman), 10 enemy types, full Recruit→Battle→Loot cycle. Not yet: additional biomes, archetypes, gear tiers, and campaign progression.

## Play It

[Link to live demo — TBD]

Or run locally from source:

```bash
godot --path . --main-scene src/scenes/Main.tscn
```

Requires: Godot 4.6+

## Develop

Clone the repo and open in Godot 4.6:

```bash
git clone <repo-url>
cd Flow-Game-Studio
godot --path .
```

Run tests:

```bash
godot --headless --script tests/run_tests.gd
```

Build HTML5 export:

```bash
godot --headless --export-release "Web"
```

## Architecture

High-level system overview: [Systems Index](docs/architecture/systems-index.md)

Key ADRs:

- [ADR-001: Signal-based state management](docs/architecture/ADR-001-run-state-signals.md)
- [ADR-002: Additive item multiplier stacking](docs/architecture/ADR-002-item-stacking.md)
- [ADR-003: FlowBridge as exclusive blockchain gateway](docs/architecture/ADR-003-flow-bridge-gateway.md)

Game design: [Concept Document](design/concept/warband-game-concept.md) | [Art Bible](design/art-bible/warband-art-bible.md)

## Credits

**Game Design & Programming:** [your name here]

**Art Assets:** [CC0/CC-BY packs — TBD]

**Audio:** [CC0/CC-BY packs — TBD]

**Fonts:** Cinzel (OFL), Courier Prime (OFL)

**Engine:** Godot 4.6 (MIT License)

**Testing Framework:** GUT 9.6 (MIT License)

Built with Claude Code.

## License

Code: TBD (recommend MIT)

Assets: TBD (recommend CC-BY 4.0 or proprietary)

See [LICENSE](LICENSE) for details.
