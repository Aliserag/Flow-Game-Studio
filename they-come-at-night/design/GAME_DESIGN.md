# They Come At Night — Game Design

## 1. Overview

A single-screen, grid-based, turn-based zombie apocalypse survival roguelike. The
player begins as a lone survivor on a procedurally generated map. Every turn is a
decision: move, scavenge, build, rest, or open a panel. Threats escalate over
time, culminating in a megahorde event the player must survive to win.

The game leans on three pillars:

1. **Spatial decisions.** A grid you can see; dangers you can locate. Buildings
   trade defense for escape risk; open ground is the inverse.
2. **Story-driven events.** Every few turns, a Europa Universalis-style event
   asks a question. Outcomes shift the run's tone and the player's relationship
   with their party.
3. **Pressure with a clock.** Frostpunk's frost analogue: swarms have a visible
   countdown; the megahorde has an unlock day and an arrival ETA. The player can
   prepare — or be caught.

## 2. Player Fantasy

> "You're alone in a small town. The dead are slow but they don't tire. Maybe
> you'll find someone to trust. Probably you won't. The horizon is getting darker
> every day, and you can already see how this ends — but you can choose how you
> get there."

We want the player to feel:

- **Isolated** at first. The map is fog-bound; every unknown tile is a question.
- **Reluctantly social.** Strangers are valuable and dangerous. Some are exactly
  what they say they are. Some are not. You won't always find out which is which.
- **Resigned and defiant.** The end is coming. You can prepare for it. The win
  state is "you broke the megahorde", not "you escaped".

## 3. Detailed Rules

### 3.1 Turn structure

One turn = one day. On the player's turn they may:

- **Move** to one of eight neighboring tiles.
- **Scavenge** the current tile (one-shot per tile per run).
- **Establish base** on the current tile (one base per run; can abandon).
- **Open Build menu** (only at base tile) to start an enhancement.
- **Open Inventory / Assign** (no time cost; informational + assignment).
- **Rest** (heal 1 HP on lead; spends the day).
- **End Day** (do nothing; spends the day).

After the player's action, the game ticks:

1. Zombie units move (random + bias toward nearest survivor when within detection radius).
2. NPC units move (random walk, slight bias toward player when nearby).
3. New zombie/NPC spawns at edge based on weighted pool for the day phase.
4. Combat resolves if a hostile shares the player's tile.
5. Day counter increments; noise decays.
6. Base build progress and daily yields tick.
7. Hunger upkeep (1 food per party member; -1 morale if not met).
8. Swarm/megahorde countdown ticks; event roll fires.
9. Visibility recomputed.

### 3.2 Spatial design

**Tile types** (10): plains, forest, road, ruins, house, supermarket, hospital,
military, gas_station, church. Each has a defense bonus, escape bonus, supply
range, and rendering glyph.

**Vision** is Chebyshev distance 2 (default), +2 with a watchtower. Outside
vision, tiles are dark; explored-but-not-visible tiles are darkened.

**Procedural map**:
- Pass 1: weighted random fill.
- Pass 2: 2-3 town centres each seeding a 1-3 radius cluster of buildings.
- Pass 3: at least one road carved from edge to edge.
- Pass 4: per-tile supply roll from terrain config.

### 3.3 Combat

**Attack power** = sum of party member attacks + best assigned weapon attack +
armory bonus (if built).

**Defense** = sum of assigned armor + base defense bonus + enhancement bonuses.

**Resolve**:
- Damage to zombie = attack + 1d4
- Damage to party = max(0, zombie_attack + size*0.5 - defense + 1d6 - 2)
- Damage spread among party; each hit has 10% bite chance (infection)
- Casualties removed; on lead death or empty party, game over

Killing the megahorde wins the run.

### 3.4 Fleeing

Open terrain favors fleeing (escape_bonus +2 to +3); buildings make it costly
(escape_bonus -1 to -2). Fleeing rolls 1d10 + escape_bonus; success >= 6.

Failure deals damage similar to combat but lower; success teleports lead to a
random non-hostile neighbor.

### 3.5 Recruitment & factions

Strangers (NPCs) appear on the map. Their faction is **hidden** — they all show
"?" until interacted with. Faction reveals through:

- An "Offer to Join" event the player accepts.
- A "Vetted" recruitment outcome (sets `faction_revealed = true`).
- Contextual events that name them.

Factions have weighted spawn rates:

| Faction | Weight | Alignment | Betrayal % |
|---|---|---|---|
| Lone Wolf | 25 | neutral | 5% |
| Scavenger Crew | 15 | neutral | 15% |
| Free Militia | 12 | lawful | 2% |
| Raiders | 10 | hostile | 60% |
| Children of the Risen | 6 | hostile | 50% |
| Long Pig Society (cannibals) | 5 | hostile | 85% |
| Mercy Corps | 4 | lawful | 0% |

Betrayal triggers (planned, not yet implemented in v0.1): random nightly check
when faction is hostile and party size > 1; betrayal can steal supplies, attack
in the night, or open the gates during a siege.

### 3.6 Threat curve

| Day range | Spawn pool dominant | Notes |
|---|---|---|
| 1 - 11 | single zombies (70%) | early breathing room |
| 12 - 29 | packs (50%), singles (30%) | groups become the norm |
| 30+ | hordes (60%), packs (30%) | constant pressure |

**Swarms** (mid- to late-game): unlock day 8. Each day past unlock, ~18% chance
to schedule a swarm. Schedules give 2-4 days warning. Swarm = horde or true swarm.

**Megahorde**: unlocks on a randomly-rolled day in [20, 50]. Once unlocked, the
megahorde arrives in 5-8 days. The countdown is always visible.

### 3.7 Morale

Range 0-10. Starts at 7. Lost from: hunger, casualties, dark events, abandoning
NPCs in need. Gained from: victories, generators, certain wholesome events
(rain, books, dogs).

If morale hits 0, the run ends — your party falls apart.

## 4. Formulas

```
attack_power = sum(party_member.attack)
              + max(item.attack for item in all_assigned_weapons)
              + armory_bonus

defense_power = sum(item.defense for item in all_assigned_armor)
              + base_defense_bonus
              + sum(enh.defense_bonus for enh in built_enhancements)

zombie_unit_attack = base_attack + floor(size * 0.5)

dmg_to_zombie = attack_power + randi(0, 4)
dmg_to_party = max(0, zombie_attack - defense_power + randi(-2, 3))

flee_roll = randi(1, 10) + tile.escape_bonus
flee_success = flee_roll >= 6

aggro_chance(zombie, player) = clamp(0.1 + 0.04 * (10 - dist), 0.0, 0.85)
                               for dist in chebyshev distance

zombie_spawn_chance_per_turn = min(0.85, 0.35 + 0.01 * day)

event_roll_chance_per_turn = 0.32

megahorde_unlock_day = randi(20, 50)
megahorde_grace = randi(5, 8)

swarm_warning_days = randi(2, 4)
swarm_schedule_chance = 0.18 + 0.01 * day  (after day 8)
```

## 5. Edge Cases

- **Party of 1, lead infected**: lead can turn — game over.
- **Force-move when no safe neighbor**: skipped silently; player keeps base flag.
- **Build menu opened off-base**: button only shown when on the base tile.
- **Scavenge already-searched tile**: action button hidden.
- **Inventory empty mid-event cost**: option button disabled in modal.
- **Zombie walks off map**: removed from grid, gone forever.
- **NPC walks off map**: removed (lost potential recruit).
- **Two zombies on one tile**: combat resolves each in sequence.
- **All party dead at once**: game over with appropriate summary.
- **Megahorde spawned but flees off map**: cannot — megahorde aggression keeps it on screen.

## 6. Dependencies

- **DataLoader** (autoload) — all systems read from this.
- **GameState** (autoload) — single source of truth for run state.
- **EventBus** (autoload) — all signals route through this; no direct cross-system coupling.
- **RNG** (autoload) — single deterministic-seedable randomness source.
- **Grid** owns spatial layout; **TurnManager** owns turn order.

## 7. Tuning Knobs

In `data/`:
- Terrain spawn weights and supply ranges (`terrain.json`)
- Zombie size, attack, hp, spawn weights per phase (`zombie_units.json`)
- Item attack/defense/heal/rarity (`items.json`)
- Faction weights, join chance, betrayal chance (`factions.json`)
- Enhancement cost, build days, bonuses, prerequisites (`enhancements.json`)
- Event weight, min_day, conditions, option costs, outcome weights & effects (`events.json`)

In `scripts/systems/swarm_system.gd`:
- `SWARM_UNLOCK_DAY`
- `MEGAHORDE_UNLOCK_DAY_MIN/MAX`
- `MEGAHORDE_GRACE_MIN/MAX`

In `scripts/systems/zombie_ai.gd`:
- `BASE_SPAWN_CHANCE`
- `PROXIMITY_BONUS_PER_TILE`

In `scripts/systems/event_system.gd`:
- `BASE_EVENT_CHANCE`

In `scripts/systems/turn_manager.gd`:
- `VISION_RADIUS_BASE`

## 8. Acceptance Criteria

- [x] Map generates with at least 2 town clusters and a road on launch.
- [x] Player can move 1 tile per turn via click after pressing Move.
- [x] Scavenging a tile yields terrain-biased loot and locks the tile.
- [x] Establishing a base sets defense bonus from terrain.
- [x] Building enhancement consumes resources and ticks down build days.
- [x] Zombie spawns shift from singles → packs → hordes by day 30.
- [x] Swarm warning appears with visible countdown after day 8.
- [x] Megahorde unlocks 20-50 days; ETA always shown once unlocked.
- [x] Killing megahorde triggers victory game-over screen.
- [x] At least one event triggers per ~3 turns on average.
- [x] Recruitment via event adds NPC to party with hidden faction.
- [x] Per-character item assignment works (assign/unassign).
- [x] Consumables can be used to heal/cure.
- [x] Party member infection can turn into a zombie at night.
- [x] Casualties remove members and clean up assignments.
- [x] Morale collapse ends the run.
- [x] HP/party-wipe ends the run.
- [x] Game is playable end-to-end without engine errors.

## 9. Stretch / Roadmap

- Faction-aware AI for NPCs (raiders gang up, doctors heal nearby survivors)
- Automatic betrayal rolls at night for high-betrayal-chance party members
- Trade with NPC factions
- A second screen — settlement detail view with named characters and tasks
- Audio (ambient wind, distant moans, rain)
- Sprites instead of glyphs (still grid-based)
- Save/load
- Daily news feed flavor text generated from world events
- Settled mode unique events (faction politics, tribute demands)
- Difficulty modes (hours-of-rationing per day, infection chance scaling)
- Mod support via additional JSON files

## 10. Why this feels different

- **No safe option.** Building a base trades escape risk for defense; staying mobile trades defense for escape. Both cost time you don't have.
- **The clock is visible.** You always know how many days until the next swarm and the megahorde, but never quite what you'll roll between now and then.
- **NPCs are stories, not stats.** Faction betrayal chance creates real cost-benefit decisions every recruit.
- **Events do the heavy lifting on tone.** Mixing scary, funny, sad, and absurd events keeps the run varied.
