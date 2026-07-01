# They Come At Night — Expansion Plan

**Status**: Living document. v0.1 prototype is committed. This plan describes the
path from prototype to full release, organized into phased milestones with
acceptance criteria, effort estimates, and dependencies.

**Estimation legend**: XS = ≤4h, S = 1d, M = 2-3d, L = 1wk, XL = 2wk+. Estimates
assume a single experienced GDScript developer; halve for a team of two.

---

## 1. North Star

A grid-based zombie survival roguelike where the **clock is visible**, **strangers
are stories**, and **every base decision is a tradeoff**. Runs are 30-90 minutes,
fail fast, and end on the megahorde — survived or otherwise.

**Pillars** (from `GAME_DESIGN.md`):

1. Spatial decisions — base vs mobile, building vs open ground
2. Story-driven events — EU4-style choices with weighted outcomes
3. Pressure with a clock — Frostpunk-style countdowns

**Non-goals** (out of scope for v1.0):
- Real-time gameplay
- Multiplayer
- 3D rendering
- Per-tile combat tactics (combat stays one-roll-per-encounter)
- Branching campaign / metaprogression beyond run stats

---

## 2. Roadmap Overview

```
v0.1  PROTOTYPE       (DONE) — playable end-to-end, no audio, glyph-only
v0.2  M0  VERIFICATION    1 wk    boot fixes, smoke test, GUT setup
v0.3  M1  CORE COMPLETION 3 wks   betrayal, parley, faction AI, save/load
v0.4  M2  SETTLEMENT      3 wks   per-survivor tasks, trade, settled mode content
v0.5  M3  CONTENT         3 wks   +30 events, +5 factions, +10 items, difficulty
v0.9  M4  POLISH          4 wks   audio, sprites, UI polish, accessibility, i18n
v1.0  M5  RELEASE         2 wks   HTML5 export, Steam page, certification, launch
                          ─────
                          16 wks  total to v1.0
```

---

## 3. Phase M0 — Verification & Bug-fix (1 wk)

**Goal**: Confirm v0.1 prototype boots cleanly in Godot 4.6 and survives a full
30-day smoke run without engine errors. No new features.

### M0.1 — Boot validation (XS)
- Open project in Godot 4.6, resolve any parse / UID / class registration errors.
- Verify autoload registration order (FlowBridge-era preferences in CLAUDE.md don't
  apply here — confirm `GameState`, `EventBus`, `DataLoader`, `RNG` register).
- **Acceptance**: project runs without console errors on fresh checkout.

### M0.2 — Smoke run (XS)
- Play 30 days in Solo and 30 days in Settled.
- Validate: move, scavenge, base, build, recruit, event modal, swarm warning,
  megahorde unlock, megahorde combat, victory + defeat screens.
- **Acceptance**: full run completes; bug list filed for any issues.

### M0.3 — GUT framework install (S)
- Add GUT addon to `addons/gut/` per `technical-preferences.md`.
- Configure `tests/unit/` and `tests/integration/` directory structure.
- Add a single sanity test (`test_data_loader_loads_all_categories`) to verify pipeline.
- Hook GUT into a basic GitHub Actions workflow (headless run on PR).
- **Acceptance**: `godot --headless --script addons/gut/gut_cmdln.gd -gdir=res://tests/` exits 0.

### M0.4 — Bug-fix backlog from M0.2 (S-M)
- Reactive — fix whatever the smoke run surfaces.

**M0 acceptance gate**: prototype is provably runnable; CI runs tests; smoke passes.

---

## 4. Phase M1 — Core Mechanic Completion (3 wks)

**Goal**: Finish the systems v0.1 stubbed but didn't wire. The game already says
betrayal exists; in M1 it actually happens. The game says faction is hidden;
in M1 there's a way to discover it through play, not just events.

### M1.1 — Betrayal rolls at night (M)
- In `TurnManager._daily_upkeep`, after morale upkeep, iterate party members.
- Roll `RNG.randf_unit() < member.betrayal_chance * tension_modifier`.
- Three betrayal outcomes (weighted):
  - **Steal & flee**: removes member, takes random items.
  - **Open the gates**: spawns zombie group on base tile next dawn.
  - **Knife in the dark**: damages a random other party member (1d6).
- New event: `the_betrayal_revealed` — fired from this system, not random pool.
- **Tuning knob**: `BETRAYAL_TENSION_MODIFIER` based on hunger / morale state.
- **Files**: `scripts/systems/betrayal_system.gd` (new), `scripts/systems/turn_manager.gd`, `data/events.json`.
- **Acceptance**: a 60%-betrayal raider in the party reliably betrays within ~5 days; logs and event narrate it.

### M1.2 — Parley / interact action (S)
- Add **Talk** action when an NPC stands on a neighboring tile.
- Opens a dialogue modal with intro line from `factions.json:intro_lines`.
- Three default options: **Recruit** (rolls join_chance), **Trade** (M1.4 stub), **Walk away**.
- Recruit reveals the faction immediately (`faction_revealed = true`).
- **Acceptance**: every NPC can be parleyed; faction revealed reliably; recruiting a cannibal sets visible warning flag.

### M1.3 — Faction-aware NPC AI (M)
- Replace random walk with per-faction behavior trees:
  - **Lone Wolf**: drift toward player, low aggression.
  - **Doctors**: drift toward injured survivors (any), heal adjacent allies.
  - **Militia**: patrol roads, defensive against zombies.
  - **Raiders**: stalk player when out of base; attack on contact if armed.
  - **Cannibals**: friendly until adjacent, then attack at night.
  - **Cultists**: drift toward zombie hordes, "worship" them.
  - **Scavengers**: scavenge buildings, willing to trade.
- **Files**: `scripts/entities/npc.gd` (extended), `scripts/systems/npc_behavior.gd` (new).
- **Acceptance**: each faction shows distinct movement signature in a 30-day observation run.

### M1.4 — Trade system (M)
- New `TradeSystem` static class. Each NPC has procedurally-generated inventory weighted by faction.
- Trade modal: NPC offer / your offer with relative-value calculation (rarity × usefulness).
- Faction-modified rates: militia/doctors fair; scavengers shrewd; raiders extort.
- **Files**: `scripts/systems/trade_system.gd` (new), `scenes/TradeModal.tscn` (new).
- **Acceptance**: completing a trade transfers items and closes; refusing exits with no state change.

### M1.5 — Save / load (M)
- Single slot per run. Save state to `user://save.json` on `end_turn`.
- Encode: GameState scalars, party, inventory, assignments, knowledge, swarm/megahorde, grid (tiles + entities).
- Load reconstructs entity instances and rewires references.
- Continue button on main menu detects existing save.
- **Files**: `scripts/systems/save_system.gd` (new).
- **Acceptance**: quit and reopen mid-run resumes identically; corrupt save is detected and offered as "delete" rather than crashing.

### M1.6 — Effect kind completion (XS-S)
- Implement `defense_temp` (additive defense for N turns), `preparation_bonus`
  (defense buff against next swarm), `tension` (modifies betrayal chance).
- Wire each into the appropriate system. Document in README authoring section.
- **Acceptance**: events that rely on these effects produce measurable in-game changes.

### M1.7 — Faction warning UI (XS)
- Once `cannibal_warning` knowledge is acquired, color cannibals' intro line red
  in parley modal.
- Add **Knowledge** panel listing acquired knowledge entries.
- **Acceptance**: a player who learns about cannibals can recognize them on second meeting.

**M1 acceptance gate**: a recruit can betray you, a stranger can be parleyed
without an event roll, save resumes a run, and faction behavior is observable.

---

## 5. Phase M2 — Settlement Depth (3 wks)

**Goal**: Make the base feel populated and purposeful. Today the base is a stat
container; in M2 it's a screen with named survivors doing named tasks.

### M2.1 — Per-survivor tasks (M)
- Daily task assignment: **Scavenge** (auto-search adjacent tile), **Guard**
  (defense bonus), **Heal** (heal adjacent injured), **Build** (accelerate
  enhancement progress), **Forage** (chance of food).
- Survivor stats: **Strength**, **Smarts**, **Stealth** influence task outcomes.
- Add stat fields to `Survivor` class; roll on creation.
- **Files**: `scripts/systems/task_system.gd`, extended `survivor.gd`, settlement screen.
- **Acceptance**: assigning a high-Strength member to Build cuts construction time 30%.

### M2.2 — Settlement detail screen (M)
- Second screen accessible from base tile: lists survivors, tasks, enhancements,
  food/water reserves with daily burn rate, morale breakdown.
- Implemented as separate scene `SettlementView.tscn`, transitioned on action.
- **Acceptance**: visible burn-rate forecast ("Food runs out in 4 days") drives player decisions.

### M2.3 — Settled-mode unique events (S)
- 8 events that require `mode == SETTLED`: refugee delegations, faction tribute
  demands, internal disputes, religious converts, generator breakdowns.
- Different opening narration depending on mode at run start.
- **Acceptance**: at least 2 of 8 events fire in a 20-day Settled run on average.

### M2.4 — Tier-3 enhancements expansion (S)
- Three new enhancements: **Scout Network** (reveals 3 random tiles per day),
  **Greenhouse** (food/day +3, requires Garden), **Sniper Nest** (ranged
  zombie-killing per turn, requires Watchtower + Armory).
- **Acceptance**: each is buildable, costs balanced against existing tier 3.

### M2.5 — Daily settlement events (S)
- "Quiet day" / "Strange noises" / "Ammo audit" minor events that fire only when
  player is at base. Add color, surface state.
- **Acceptance**: a 10-day base stay has at least 4 daily-flavor lines logged.

**M2 acceptance gate**: settled-mode runs feel mechanically distinct; the base is
a screen, not a stat sheet.

---

## 6. Phase M3 — Content Expansion (3 wks)

**Goal**: Triple authored content. Goal is "every run feels different."

### M3.1 — +30 events (M)
- New events grouped by tag:
  - **Horror** (8): the radio at night, the photograph in the wallet, the locked basement, the room that wasn't on the map, the quiet town, the running children, the screaming wind, the writing on the wall.
  - **Humor** (6): the karaoke machine, the cat, the door that won't close, the stuck shopping cart, the very polite zombie, the time capsule.
  - **Moral** (8): the surrender, the prisoner, the resource hoarder, the deserter, the wounded enemy, the broken promise, the ration cut, the mercy killing.
  - **Lore** (4): the lab, the broadcast tower, the diary, the patient zero rumor.
  - **Faction-specific** (4): one per major hostile faction encounter.
- Each event has 2-4 options with weighted outcomes; min 1 effect kind exercised.
- **Files**: `data/events.json` extension; possibly split into `data/events/*.json` and merge.
- **Acceptance**: 47 events total; tag distribution balanced; no duplicate titles.

### M3.2 — +5 factions (S)
- **Federal Remnant** (lawful, militaristic, demands tribute)
- **Free Traders** (neutral, pure trade focus, runs barter caravans)
- **Children of the Void** (hostile, nihilist cult)
- **Pacifists** (lawful, refuse violence even at cost)
- **Salvage Engineers** (neutral, build enhancements faster if hired)
- Each gets intro lines, betrayal/join chance, and at least 1 event.
- **Acceptance**: 12 total factions; each spawns at least once in a 50-day run.

### M3.3 — +10 items (XS)
- **Suppressor** (weapon mod), **Backpack** (capacity), **Compass** (vision),
  **Crowbar** (utility), **Molotov** (consumable AOE), **Walkie-Talkies** (recruit chance),
  **Lockpicks** (locked-loot bonus), **Improvised Spear** (early weapon),
  **Body Armor** (heavy armor), **First Aid Manual** (heal+).
- **Acceptance**: 32 total items; each scavengable; each appears in at least one event.

### M3.4 — +3 terrain types (XS)
- **Junkyard** (high material yield, low food)
- **Police Station** (military-tier loot, tier-2 defense)
- **Farm** (food yield, gardenable on capture)
- **Acceptance**: 13 total terrains; each generates correctly in `MapGenerator`.

### M3.5 — Difficulty modes (S)
- **Tourist** (zombies +25% slower, megahorde unlock day 35-50)
- **Standard** (current balance)
- **Apocalypse** (zombies +25% faster, megahorde 15-30, food costs ×1.5)
- **Permadeath** (no save; runs are committed)
- Mode selected at run start; persists in GameState.
- **Acceptance**: clear difficulty differences in outcome stats over 10 runs each.

### M3.6 — Map size variants (XS)
- 10x10 (Quick), 14x14 (Standard), 20x20 (Long).
- Affects megahorde unlock day proportionally.
- **Acceptance**: 20x20 runs feel meaningfully longer; 10x10 feels tense.

**M3 acceptance gate**: a 50-day run encounters at least 10 unique events, 5
faction types, and a varied loot distribution.

---

## 7. Phase M4 — Polish (4 wks)

**Goal**: Take the prototype from "playable" to "shippable."

### M4.1 — Audio (L)
- Per Audio Director protocol from `.claude/`:
  - Ambient: wind, distant moans (loops), rain layer, calm-hours music.
  - SFX: tile hover, button click, scavenge, combat hit, footstep, build complete.
  - Stingers: swarm warning, megahorde arrival, victory, defeat.
  - Music: 3 tracks (calm exploration, tension, megahorde theme).
- Use `AudioStreamPlayer` for music, pooled `AudioStreamPlayer2D` for SFX.
- Master mix via Audio Buses.
- **Files**: `assets/audio/`, `scripts/systems/audio_director.gd`.
- **Acceptance**: full audio scene; mute toggle in settings; no clipping.

### M4.2 — Sprite art (L)
- 32×32 pixel art tile sprites for each terrain (10 + 3 from M3).
- Sprite per entity: lead, recruits (3 variants), zombies (5 tiers).
- Replace `_draw` glyph rendering with `TileMap` / `Sprite2D` rendering.
- Keep glyph mode as a debug toggle.
- **Acceptance**: visible identity per terrain and entity; readable at default zoom.

### M4.3 — Animations (M)
- Idle bob for entities; walk tween between tiles.
- Combat hit flash (red overlay).
- Tile reveal fade-in for fog of war.
- Camera shake on megahorde spawn.
- **Acceptance**: no abrupt state changes; transitions feel intentional.

### M4.4 — UI polish (M)
- Custom theme matching art style (warm browns, muted reds, candlelight).
- Responsive layout with anchors that work at 1280×720, 1920×1080, and HTML5 fullscreen.
- Tooltips on every action button.
- Keyboard navigation (WASD/arrows + space to confirm + esc to back).
- **Acceptance**: full game playable on keyboard; no truncated text at any supported resolution.

### M4.5 — Accessibility pass (S)
- Per `accessibility-specialist`:
  - Colorblind-safe palette (validate with simulator).
  - Text scaling 0.8× to 1.5× via settings.
  - Screen reader hooks for action buttons (Godot 4.5+ AccessKit).
  - Optional reduce-motion mode (disables shake/tween).
- **Acceptance**: WCAG 2.1 AA contrast on all text; passes color blindness simulators.

### M4.6 — Localization scaffold (S)
- Extract all hardcoded UI strings to `localization/en.po`.
- Wire CSV/PO loader; default to English.
- Translate intro screen + menu to one additional language as proof (Spanish recommended for breadth).
- **Acceptance**: language can be switched at runtime; all menu UI translates.

### M4.7 — Settings menu (S)
- Audio (master, music, sfx volumes).
- Graphics (resolution, fullscreen, vsync).
- Gameplay (difficulty, autosave on/off, fast forward speed).
- Accessibility (text scale, reduce motion, high contrast).
- Saved to `user://settings.cfg`.
- **Acceptance**: settings persist across launches; defaults are sensible.

### M4.8 — Tutorial / onboarding (M)
- First-run interactive tutorial: 5 guided turns introducing move, scavenge,
  base, event, end-day.
- Skippable. Tutorial flag in settings.
- **Acceptance**: a non-roguelike player can complete tutorial and immediately understand the verbs.

**M4 acceptance gate**: build feels like a v1.0 product. No placeholder art, no
prototype rough edges in surface UI.

---

## 8. Phase M5 — Release Prep (2 wks)

### M5.1 — HTML5 export (S)
- Configure Godot HTML5 export template.
- Test in Chrome/Firefox/Safari.
- Verify save/load via IndexedDB.
- Optimize asset sizes for web (target <50MB total).
- **Acceptance**: itch.io-deployable build under 50MB, loads in <8s on broadband.

### M5.2 — Desktop exports (XS)
- Windows, macOS, Linux exports.
- Code signing if budget permits.
- **Acceptance**: exports launch on each target without admin privileges.

### M5.3 — Steam page (M)
- Capsule art, screenshots (8), short trailer (60s).
- Steam description copy by writer agent.
- Tags, age rating, Steam Deck verified pass.
- **Acceptance**: Steam page goes through approval; coming-soon page live.

### M5.4 — itch.io page (XS)
- Cover art, screenshots, description, demo HTML5 build embedded.

### M5.5 — Marketing materials (S)
- Trailer (60s), short clips (15s) for socials.
- Press kit: screenshots, logos, fact sheet, dev bio.
- Devlog post on itch.io.
- **Acceptance**: press kit complete and downloadable.

### M5.6 — Final QA gate (M)
- Run full TEST_PLAN.md regression suite.
- 100 hours of cumulative playtest across M0+M1+M2+M3+M4 features.
- Severity-based bug triage; only Sev-3+ ships unfixed.
- **Acceptance**: zero Sev-1; ≤3 Sev-2; documented Sev-3 list with workarounds.

### M5.7 — Launch (XS)
- Coordinated drop: Steam, itch, social media, devlog.
- Day-one patch ready (use `/day-one-patch` skill).
- **Acceptance**: game is buyable; first 24h crash report < 1% of sessions.

**M5 acceptance gate**: game is live, stable, and refundable.

---

## 9. Backlog (uncategorized / post-1.0)

These didn't make the M0–M5 cut but should not be lost.

### Mechanical
- Per-survivor traits (Brave, Cowardly, Loyal, Greedy) influencing event outcomes.
- Disease system beyond infection (cholera in dirty water, frostbite in winter).
- Day/night cycle (zombies more aggressive at night).
- Seasonal weather (winter reduces food spawns).
- Permadeath cemetery: each dead survivor has a persistent gravestone meta.
- Vehicles (one-time fast travel with fuel cost).
- Factions can capture territory (NPCs claim tiles).
- Player-built outposts (sub-bases away from main).

### Narrative
- Origin pre-collapse vignette (1 turn flashback).
- Optional ending arcs based on knowledge accumulated (Site 3 cure ending,
  Truth ending, Faith ending, Empty ending).
- Survivor diary entries — auto-generated journals for each member.
- "Last Letter" mechanic on death — write a final entry into a meta journal.

### Systems
- Procedural event generation (event templates + slot-fill).
- Steam Cloud sync.
- Replay export (turn log → text file).
- Daily challenge mode (deterministic seed, leaderboard).
- Mod tools / steam workshop integration.

### Tech
- Mobile port (touch controls).
- Native ports (Switch, Steam Deck verified).
- Server-side analytics (opt-in).
- Crash reporter integration (Sentry).

---

## 10. Risk Register

| ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | M1.5 save/load complexity blows estimate (entity references hard to serialize) | M | M | Prototype save/load on day 1 of M1; descope to "save at base only" if needed |
| R2 | M4.2 sprite art scope balloons (60+ sprites needed) | H | L | Commission single artist or use a coherent asset pack; lock sprite size early |
| R3 | M4.1 audio licensing — using unlicensed loops | M | H | Use CC0 or commission custom; track every asset's license in `assets/AUDIO_LICENSES.md` |
| R4 | M3.1 +30 events at quality bar requires writer time | M | M | Schedule writer agent in 2-week sprint; require all events to pass `/design-review` |
| R5 | Megahorde balance — too easy or impossible | H | M | Run telemetry on M5.6 playtests; tune in day-one patch |
| R6 | Godot 4.6 stability for HTML5 export | L | H | Test web export at end of M0; if blocked, stay on 4.5 LTS |
| R7 | Scope creep (every M-phase has obvious adds) | H | H | `/scope-check` at start of each phase; `/sprint-plan` enforces capacity |
| R8 | Solo dev burnout on a 16-week timeline | M | H | Each phase has a clean stop-and-ship cut; v0.5 is defensible as a release |

---

## 11. Effort Roll-up

| Phase | Effort | Cumulative |
|---|---|---|
| M0 | 1 wk | 1 wk |
| M1 | 3 wks | 4 wks |
| M2 | 3 wks | 7 wks |
| M3 | 3 wks | 10 wks |
| M4 | 4 wks | 14 wks |
| M5 | 2 wks | 16 wks |

**Single-dev plan**: 16 weeks (4 months).
**Two-dev plan**: ~10 weeks if M2/M3 parallelized and M4 art/code split.
**Plus 25% buffer**: 20 weeks recommended for solo, 12 weeks for pair.

---

## 12. Defensible Stop Points

If the project must ship before 16 weeks, these are clean cuts:

- **End of M1 (4 wks)** — "Mechanically complete prototype." Itch.io free release.
- **End of M3 (10 wks)** — "Content-rich early access." Steam Early Access viable.
- **End of M4 (14 wks)** — "Polished, missing Steam page only." Soft launch on itch.

---

## 13. Cross-references

- Design vision: `design/GAME_DESIGN.md`
- Test plan: `design/TEST_PLAN.md`
- Run-state files (post-launch): `production/session-state/active.md`
- Architecture decisions (to be created): `docs/architecture/ADR-*.md`
- Engine reference: `../docs/engine-reference/godot/VERSION.md`

---

## 14. Decision Log

This section records expansion-plan-level decisions made during execution. Append rows; never delete.

| Date | Decision | Rationale | Made by |
|---|---|---|---|
| 2026-05-03 | Initial expansion plan drafted | Baseline scope post-prototype | claude-code |
