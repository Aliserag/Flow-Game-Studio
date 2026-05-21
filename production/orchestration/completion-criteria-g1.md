# WARBAND G1 — Completion Criteria

**Mandate:** Autonomous build of G1 Vertical Slice on top of completed G0.
**Source of Truth:** `design/concept/warband-game-concept.md` G1 pass criteria + `design/gdd/systems-index.md` Feature Tier.

## Hard Criteria (all must be TRUE)

### H1 — Project Still Builds
- [ ] Godot 4.6 project opens with all G0 + G1 systems
- [ ] No script parse errors
- [ ] All autoloads load (G0 set + any new G1 autoloads)
- [ ] All scene references resolve

### H2 — Tests Pass
- [ ] All G0 tests still pass (regression-free)
- [ ] New G1 unit tests pass (target ≥ 60 unit tests total)
- [ ] Updated G1 integration test passes (full multi-battle run including boss)
- [ ] 3 consecutive runs identical (no flakiness)

### H3 — G1 Core Loop Plays End-to-End
- [ ] Player starts a run, hires from tavern (G0 carry)
- [ ] Player enters campaign map and sees branching node graph
- [ ] Player can choose between 2-3 branches at each junction
- [ ] Player encounters scout report before each battle (archetype names + tier visible)
- [ ] Player can visit Market between battles to buy/sell gear
- [ ] Biome modifier appears in scout report and applies in combat
- [ ] Player reaches boss node at end of biome
- [ ] Boss has a visible phase-2 trigger at 50% HP
- [ ] Defeating boss completes the biome and ends the campaign with a victory screen
- [ ] Hero death anywhere = run ends with permadeath summary
- [ ] localStorage save persists across browser refresh (HTML5 only — desktop uses memory)

### H4 — Pillar Demonstrability (G1 expanded)
- [ ] **Pillar 1**: Equipping gear visibly changes the orc sprite (gear overlay on procedural atlas)
- [ ] **Pillar 2**: Permadeath verified by integration test (G0 carry) + new: hero with kills records to Legends
- [ ] **Pillar 3**: Player cannot fully equip all orcs in one campaign — must make gold trade-offs (verified by scripted budget test)
- [ ] **Pillar 4**: Scout report exposes enemy archetype names + tier + biome modifier BEFORE battle commit

### H5 — Art Pipeline
- [ ] Modular sprite atlas system implemented (3 layers: body + gear + scar)
- [ ] Procedural placeholder sprite generator script in `tools/sprite-gen/` produces sprites following art-bible §6 silhouettes and §5 palette
- [ ] Generated sprites loaded by the game at runtime
- [ ] Palette swap shader for enemy variants implemented (or stubbed with comment of TODO)
- [ ] Asset naming convention enforced (`char_<archetype>_<layer>_<variant>.png`)
- [ ] All sprite atlases ≤ 512x512 per art-bible §11

### H6 — HTML5 Export
- [ ] Builds cleanly
- [ ] Output ≤ 50 MB (revised from G0's unrealistic 25 MB target)
- [ ] localStorage persists run state across page reloads

### H7 — Score Threshold
- [ ] Aggregate score across G1 + G0 systems ≥ 80
- [ ] No individual system < 70
- [ ] Scoreboard updated

### H8 — Bug Backlog
- [ ] Zero open S1 or S2 bugs
- [ ] All bugs documented

### H9 — Documentation
- [ ] G1 system GDDs authored: campaign-map, scout-report, biome-system, boss-encounters, market, meta-progression
- [ ] Updated session-state and scoreboard
- [ ] Final report at `production/orchestration/final-report-G1.md`

## Stop Conditions

Same as G0. Add:
- If procedural sprite generator produces output that violates art-bible silhouette rules (SP-2 fails the blind-test heuristic), halt and escalate.
- If localStorage save corrupts on round-trip in 2 consecutive tests, halt.

## What's NOT in G1 (explicit deferrals)

- Multiple biomes (only Farm/Village in G1; rest at G2-G3)
- Full 60-trait library (G1 has ~12 traits; full library at G2)
- Saga / Legends UI (data tracked, polished UI at G2)
- Audio implementation (hooks present; assets at G2)
- Localization (strings English-only; externalization at G2)
- Hand-painted pixel art (procedural placeholders only; artist content is post-G1)
