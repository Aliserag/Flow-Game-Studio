# Ralph Loop — M2→M5 Completion Criteria

The loop runs until **every line under "Completion" below is checked**. Each line
is machine-verifiable via the E2E harness, a unit test, or a file existence check.

**Hard limits**: items marked `HUMAN-BLOCKED` cannot be completed by the orchestrator
alone. They are excluded from the auto-completion check and tracked separately at
the bottom.

---

## Loop algorithm

1. Read `production/ralph/state.md`.
2. Find the first task with `[ ]`.
3. Execute it. Modify code/data/docs as required.
4. Run verification command (`make verify-mN` if Makefile exists, else direct godot invocation).
5. If verification passes: mark `[x]`, append entry to `state.md::recent`. Continue.
6. If verification fails: mark `[!]` (blocked), log root cause, escalate after 3 attempts.
7. Stop when no `[ ]` items remain OR step counter exceeds `MAX_STEPS` (50).

---

## Verification commands

```bash
# Run the full E2E + unit test gauntlet:
godot --headless res://scenes/Main.tscn -- --e2e   # 118+ assertions across 20 pieces
godot --headless res://scenes/Main.tscn -- --test  # 261 unit tests

# Smoke runs:
godot --headless res://scenes/Main.tscn -- --smoke      # 50-turn solo
godot --headless res://scenes/Main.tscn -- --smoke-long # 100-turn settled

# Editor parse + class-cache refresh (must produce zero SCRIPT ERROR lines):
godot --headless --editor --quit
```

---

## M2 — Settlement Depth — Completion

### M2.1 — Per-survivor stats
- [ ] `Survivor` has `strength: int`, `smarts: int`, `stealth: int` (range 1-5)
- [ ] Unit test verifies stats are rolled within bounds for `make_random_recruit()`
- [ ] Lead survivor has elevated stats (≥ 3 on at least one dimension)
- [ ] E2E asserts party stats sum > 0 after init

### M2.2 — Task system
- [ ] `scripts/systems/task_system.gd` exists, with at least 5 tasks (Guard, Scavenge-task, Heal-task, Build-assist, Forage)
- [ ] Task assignment stored on `Survivor.daily_task: String` (resets each day)
- [ ] `TurnManager.end_turn` invokes each survivor's task before AI tick
- [ ] Task effect rolls reference survivor stats (Strength for Guard, Smarts for Build-assist, etc.)
- [ ] Unit test for each task's effect formula
- [ ] E2E asserts assigning Build-assist accelerates a build by ≥ 1 day

### M2.3 — Settlement detail screen
- [ ] `scenes/SettlementView.tscn` exists with a script controller
- [ ] Shows: party list with stats, food/water reserves with daily burn rate, enhancements, current task assignments
- [ ] Accessible from Game View when at base tile
- [ ] E2E asserts scene loads and instantiates without errors

### M2.4 — Settled-mode unique events
- [ ] `data/events.json` contains ≥ 8 new events tagged `settled_only`
- [ ] EventSystem filters them so they only fire when `GameState.mode == SETTLED`
- [ ] E2E asserts at least 3 distinct settled-mode events fire in a 30-roll sample

### M2.5 — Tier-3 enhancements expansion
- [ ] `data/enhancements.json` includes `scout_network`, `greenhouse`, `sniper_nest`
- [ ] Each has cost, build_days, prerequisites, and effect fields
- [ ] E2E asserts each can be built (cost deducted, days tick, completion fires)

### M2.6 — Daily settlement flavor
- [ ] `data/events.json` has ≥ 4 low-impact daily-at-base flavor events
- [ ] All have `conditions.has_base: true`, weight ≤ 3 (minor noise)
- [ ] E2E asserts at least 2 fire across a 30-day at-base sample

---

## M3 — Content — Completion

### M3.1 — +30 events
- [ ] `data/events.json` has ≥ 49 total events (was 19)
- [ ] New events distributed across tags: horror (≥6), humor (≥4), moral (≥6), lore (≥3), faction-specific (≥4)
- [ ] No two events share a `title` field
- [ ] Each event has ≥ 2 options
- [ ] E2E asserts ≥ 15 distinct events fire in a 200-roll sample

### M3.2 — +5 factions
- [ ] `data/factions.json` has ≥ 12 factions (was 7)
- [ ] New: `federal_remnant`, `free_traders`, `void_children`, `pacifists`, `salvage_engineers`
- [ ] Each has intro_lines, betrayal_chance, join_chance, weight
- [ ] At least 2 new events reference each new faction in their effects or descriptions
- [ ] E2E asserts random recruit can roll any of the 12 factions

### M3.3 — +10 items
- [ ] `data/items.json` has ≥ 32 items (was 22)
- [ ] New items span categories: weapon, armor, consumable, material, ammo
- [ ] Each new item appears in at least one loot table (terrain bias) or event reward
- [ ] E2E asserts at least 5 new items can be scavenged

### M3.4 — +3 terrain types
- [ ] `data/terrain.json` has ≥ 13 terrains (was 10)
- [ ] New: `junkyard`, `police_station`, `farm`
- [ ] MapGenerator spawn weights updated to include them
- [ ] E2E asserts each new terrain appears on a generated map within 5 attempts

### M3.5 — Difficulty modes
- [ ] `GameState.Difficulty` enum with TOURIST / STANDARD / APOCALYPSE / PERMADEATH
- [ ] Selectable from main menu before starting a run
- [ ] Difficulty modifies: zombie spawn rate, megahorde unlock day range, food consumption
- [ ] E2E asserts TOURIST has fewer zombies than APOCALYPSE in matched runs

### M3.6 — Map size variants
- [ ] Main menu lets player pick 10×10 / 14×14 / 20×20
- [ ] MapGenerator handles all three sizes
- [ ] Megahorde unlock day scales with map size
- [ ] E2E asserts 10×10 and 20×20 maps both generate successfully

---

## M4 — Polish — Completion (partial; asset-blocked items HUMAN-BLOCKED)

### M4.1 — Audio system (asset-blocked)
- [ ] `scripts/systems/audio_director.gd` exists with master/music/sfx buses
- [ ] Stub plays silent AudioStream samples (procedurally generated tones acceptable)
- [ ] `EventBus` signals route to AudioDirector for: button click, combat hit, swarm warning, megahorde arrival, victory, defeat
- [ ] Audio settings panel can mute each bus
- [HUMAN-BLOCKED] Replace stub tones with real licensed audio (3+ music tracks, ~20 SFX)

### M4.2 — Sprite art (asset-blocked, partial procedural fallback)
- [ ] Procedural sprite generator writes 32×32 PNG-equivalent icons for each terrain type at runtime
- [ ] Procedural entity sprites distinguish player / recruit / zombie variants / NPC faction colors
- [ ] GridRenderer can switch between glyph mode (debug) and sprite mode (default)
- [HUMAN-BLOCKED] Replace procedural sprites with hand-authored pixel art

### M4.3 — Animations
- [ ] Lead-tile move uses tween animation (not snap)
- [ ] Combat hit produces visible red flash overlay (1 frame, then fade)
- [ ] Tile reveal from fog-of-war fades in over 0.2s
- [ ] Megahorde arrival triggers camera shake

### M4.4 — UI polish
- [ ] `theme.tres` defines warm-brown / muted-red palette
- [ ] Buttons, labels, panels use the theme (no default Godot styling)
- [ ] Layout responsive at 1280×720, 1920×1080, fullscreen
- [ ] Keyboard navigation: arrow keys move, space confirms, esc backs out

### M4.5 — Accessibility
- [ ] Colorblind-safe palette toggle in settings (verified vs simulated protanopia/deuteranopia)
- [ ] Text scale slider (0.8× to 1.5×) in settings
- [ ] Reduce-motion toggle disables tweens and shake
- [ ] All action buttons have accessible-name strings

### M4.6 — Localization scaffold
- [ ] All UI strings routed through `tr("KEY")`
- [ ] `localization/en.po` exists with every string
- [ ] Language switcher in settings
- [ ] At minimum 50% of UI translated to a second language (e.g., Spanish)

### M4.7 — Settings menu
- [ ] `scenes/SettingsMenu.tscn` exists, accessible from main menu and pause menu
- [ ] Audio: master / music / sfx sliders (0-100)
- [ ] Display: resolution dropdown, fullscreen toggle, vsync toggle
- [ ] Gameplay: difficulty, autosave on/off
- [ ] Accessibility: text scale, reduce motion, colorblind
- [ ] Settings persist to `user://settings.cfg` across launches

### M4.8 — Tutorial
- [ ] First-run interactive tutorial: 5 guided steps (move, scavenge, base, event, end-day)
- [ ] Skippable from main menu
- [ ] Tutorial-shown flag in settings

---

## M5 — Release — Completion (mostly HUMAN-BLOCKED)

### M5.1 — Web export
- [ ] `export_presets.cfg` configured for Web (HTML5)
- [ ] `make export-web` produces `dist/web/index.html` + .wasm + .pck
- [HUMAN-BLOCKED] Test in actual browser; verify save/load via IndexedDB

### M5.2 — Desktop exports
- [ ] `export_presets.cfg` configured for Linux/X11, Windows Desktop, macOS
- [ ] `make export-all` produces all three artifacts in `dist/`
- [HUMAN-BLOCKED] Code signing (Windows EV cert, macOS notarization)

### M5.3 — Store presence
- [HUMAN-BLOCKED] Steam page submission
- [HUMAN-BLOCKED] itch.io page setup
- [HUMAN-BLOCKED] Trailer recording (requires GUI)
- [HUMAN-BLOCKED] Capsule art and screenshots

### M5.4 — Final QA gate
- [ ] All M0-M3 acceptance criteria still pass on green build
- [ ] E2E harness at ≥ 150 assertions, all green
- [ ] 261+ unit tests pass
- [ ] Stderr clean across 3 consecutive runs
- [ ] Performance: 14×14 map gen < 100ms; turn end < 5ms
- [HUMAN-BLOCKED] 30 hours of cumulative human playtest

### M5.5 — Launch
- [HUMAN-BLOCKED] Live on Steam / itch
- [HUMAN-BLOCKED] Day-one patch ready

---

## Auto-completion check

The loop is **DONE** when every `[ ]` above (excluding `[HUMAN-BLOCKED]`) is `[x]`.

Sum of auto-completable items: **~50**.
Sum of human-blocked items: **~12**.

After the loop exits, write a final report at `production/ralph/final-report.md`
listing what shipped, what's blocked, and what the operator's next actions are.

---

## Human-blocked items (tracked separately)

These ride alongside the loop but never block it:

- M4.1: real audio assets
- M4.2: hand-drawn sprite art
- M5.1: browser-platform save/load verification
- M5.2: platform code signing
- M5.3: Steam + itch pages, trailer, capsule art, screenshots
- M5.4: 30+ hours human playtest
- M5.5: actual launch
