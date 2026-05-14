# E2E Scorecard — They Come At Night

**Date**: 2026-05-14
**Engine**: Godot 4.4 (project pinned to 4.6)
**Branch**: claude/they-come-at-night-G455m
**Verdict**: ✅ **GREEN — all 20 pieces pass**

---

## Results summary

```
[E2E] Total assertions: 118  Passed: 118  Failed: 0
[E2E] RESULT: GREEN
```

- **261/261 unit tests pass** (8 suites)
- **118/118 E2E assertions pass** (20 pieces)
- **Stderr clean** — zero `SCRIPT ERROR` or `Parse Error` lines across all runs
- **Determinism**: 3 consecutive runs at the same seed → identical results
- **50-turn solo smoke + 100-turn settled smoke**: both complete without engine errors

---

## Per-piece scores

Each piece scored against the 5-dimension rubric in
[`completion-criteria.md`](completion-criteria.md). Threshold to pass = 80/100.

| # | Piece | Assertions | Engine errors | Determinism | Performance | Test coverage | **Total** | Pass? |
|---|---|---|---|---|---|---|---|---|
| P01 | Boot | 60 | 15 | 10 | 10 | 4 | **99** | ✅ |
| P02 | Map gen | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P03 | Vision/fog | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P04 | Movement | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P05 | Scavenge | 60 | 15 | 10 | 10 | 5 | **100** | ✅ |
| P06 | Combat | 60 | 15 | 10 | 10 | 5 | **100** | ✅ |
| P07 | Base | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P08 | Build | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P09 | Inventory | 60 | 15 | 10 | 10 | 5 | **100** | ✅ |
| P10 | Parley | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P11 | Faction AI | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P12 | Trade | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P13 | Betrayal | 60 | 15 | 10 | 10 | 5 | **100** | ✅ |
| P14 | Swarm | 60 | 15 | 10 | 10 | 5 | **100** | ✅ |
| P15 | Megahorde | 60 | 15 | 10 | 10 | 5 | **100** | ✅ |
| P16 | Save/Load | 60 | 15 | 10 | 10 | 5 | **100** | ✅ |
| P17 | Events | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P18 | Knowledge | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P19 | Defeat paths | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| P20 | UI scenes | 60 | 15 | 10 | 10 | 3 | **98** | ✅ |
| **Total** | | **1200** | **300** | **200** | **200** | **76** | **1976/2000** | ✅ |

**Average per piece: 98.8 / 100. All pieces ≥ threshold of 80.**

> Test coverage dimension: pieces with a dedicated unit test suite score 5/5;
> pieces relying only on the E2E harness for coverage score 3/5. The harness
> itself is a comprehensive integration test, so the lower coverage scores
> still pass.

---

## Assertion breakdown by piece

```
P01 (Boot)            6/6   autoloads + data integrity
P02 (Map gen)         4/4   perf + size + building count + road count
P03 (Vision/fog)      4/4   explored count + radius + far-tile + watchtower
P04 (Movement)        3/3   move returns true + pos updated + party follows
P05 (Scavenge)        4/4   ok + searched flag + inventory grew + double-block
P06 (Combat)          5/5   damage + kill + megahorde victory + flee + flee-result
P07 (Base)            3/3   establish + flag + defense bonus
P08 (Build)           7/7   start + flag + days + completion + cleared + wood + scrap
P09 (Inventory)       4/4   assign + unassign + consumable + hp restored
P10 (Parley)          2/2   payload built + options present
P11 (Faction AI)      4/4   doctors + scavengers + raiders + cultists
P12 (Trade)           6/6   stock + buy + has-item + scrap-deducted + sell + scrap-credited
P13 (Betrayal)        5/5   fires + stats + tension-low + tension-high + loyal-survives
P14 (Swarm)           3/3   scheduled + eta-range + spawned
P15 (Megahorde)       2/2   spawned + victory
P16 (Save/Load)       12/12 save/load + scalars + 4 details + pos + lead-flag + hp + assignments
P17 (Events)          6/6   distinct + items + knowledge + tension + defense_temp magnitude + turns
P18 (Knowledge)       4/4   added + reset + multiple + dataloader-has
P19 (Defeat paths)    6/6   lead + morale + wipe + infected + starvation + perf
P20 (UI scenes)       28/28 load/instantiate + 6 panels × (exists + hidden + show + hide)
```

---

## Iterations

| # | Date | Failing pieces | Spawned | Fixes | Result |
|---|---|---|---|---|---|
| 1 | 2026-05-14 | 0 (baseline ran green) | 0 dev agents | n/a | 68/68 green |
| 2 | 2026-05-14 | 0 (but reviewers found gaps) | 2 review agents (qa-tester + godot-gdscript-specialist) | Strengthened harness (+50 assertions); 5 production fixes | 118/118 green |

Total iterations: **2**. Spawned **2 subagents in parallel** (qa-tester + godot-gdscript-specialist) for the feedback loop.

---

## Bugs fixed in iteration 2

From the code-review subagent's report:

1. **`save_system.gd::save()`** — `FileAccess.store_string` returns `bool` in Godot 4.4+; we now check it. A failed write was previously silently reported as `true`, then `delete_save()` cleans up the half-written file.
2. **`save_system.gd::delete_save()`** — was using `globalize_path(SAVE_PATH)` which doesn't reach the IndexedDB-backed `user://` on HTML5 export. Now passes the raw `user://` path so DirAccess handles platform resolution.
3. **`save_system.gd::load_run()`** — was calling `reset_run(Mode.SOLO)` unconditionally before deserializing the saved mode, causing any signal handler to see the wrong mode briefly. Now reads the saved mode and passes it to `reset_run`.
4. **`npc_behavior.gd` raider mug path** — was using two-step `lead.hp -= dmg; adjust_lead_hp(0)` pattern that bypassed the canonical death-check route. Now uses single `adjust_lead_hp(-dmg)`.
5. **All `emit_signal("name", ...)`** sites (52 total across 15 files) — converted to typed `.emit()` form for Godot 4.x best practice and to avoid deprecation warnings in 4.6.

## Coverage gaps closed in iteration 2

From the qa-tester subagent's report (BLOCKER items, all closed):

1. **P16** — `lead.pos`, `lead.is_lead`, `lead.hp` now asserted after save/load round-trip
2. **P16** — `assignments` dict integrity (int keys preserved) now asserted
3. **P12** — `scrap` ledger now verified on both buy (deducted) and sell (credited)
4. **P06** — `resolve_flee` now exercised with success/failure branch assertions
5. **P08** — Build cost deduction now verified in inventory
6. **P13** — Betrayal stats counter incremented on fire
7. **P19** — Starvation defeat path exercised through `_daily_upkeep` integration
8. **P20** — Panel `show()`/`hide()` transitions verified for all 6 GameView panels

---

## Evidence

- Harness: [`they-come-at-night/tests/e2e_harness.gd`](../../they-come-at-night/tests/e2e_harness.gd)
- Run command: `godot --headless res://scenes/Main.tscn -- --e2e`
- Reproducibility: same seed (`42424242`) → identical assertions across 3 runs

## Sign-off

**Commit**: pending (next commit on this branch)
**Approver**: claude-code orchestrator
**Date**: 2026-05-14
**Status**: GREEN

A green build is one where every piece scores ≥ 80, no piece scores 0 on its
assertion dimension, all 261 unit tests pass, and stderr is clean. All four
conditions are met.
