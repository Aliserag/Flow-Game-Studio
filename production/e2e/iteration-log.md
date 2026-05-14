# E2E Orchestration — Iteration Log

Append-only. Each iteration records: timestamp, baseline state, agents spawned,
findings, fixes, post-iteration state.

---

## Iteration 1 — 2026-05-14T17:30

### Baseline
- Branch: `claude/they-come-at-night-G455m`
- Last commit: `4623f9c` (verification pass; 261/261 unit tests pass)
- E2E harness: not yet built

### Actions
- Built `tests/e2e_harness.gd` covering pieces P01-P20
- Wired `--e2e` CLI flag into `main_launcher.gd`
- Wrote `production/e2e/completion-criteria.md` (scoring rubric)
- Authored `.claude/skills/orchestrate-e2e/SKILL.md`

### Result
- E2E run: 68 assertions, 0 fails → **GREEN baseline**
- Determinism check: 3 runs identical
- Stderr: clean

### Spawned agents
None. Baseline ran green on first attempt — no fix cycle needed.

### Decision
Baseline accepted as GREEN, but suspicion that 68 assertions across 20 pieces
might be too light. Strengthened harness in same iteration (+25 assertions
covering P03, P11, P13, P17 [missing entirely], P18, P19, P20 panel-exist).

Re-ran: 93 assertions, 0 fails. Still GREEN.

---

## Iteration 2 — 2026-05-14T17:45

### Baseline
- E2E green at 93/93 assertions
- Suspicion: harness may pass-by-accident in some places

### Actions
- Spawned 2 parallel subagents:
  1. `qa-tester` — review harness for coverage gaps
  2. `godot-gdscript-specialist` — review production code for real bugs

### Findings

**qa-tester** (8 gaps, 4 BLOCKER + 3 SHOULD + 1 NICE):
- P16: lead.pos/hp/is_lead not asserted after load — BLOCKER
- P16: assignments dict integrity not verified — BLOCKER
- P12: scrap balance ledger not checked — BLOCKER
- P06: resolve_flee never tested — BLOCKER
- P08: build cost deduction not asserted — SHOULD
- P13: betrayal side-effects unverified — SHOULD
- P19: starvation defeat path not exercised — SHOULD
- P20: panel show/hide transitions untested — NICE

**godot-gdscript-specialist** (5 BLOCKER/SHOULD bugs, 2 NICE):
- save_system.gd: store_string return ignored (4.4+ silent-failure bug) — BLOCKER
- save_system.gd: globalize_path breaks HTML5 delete path — BLOCKER
- All emit_signal("name") string-based calls (52 sites) — SHOULD
- npc_behavior.gd: two-step HP write bypasses canonical death check — SHOULD
- save_system.gd: reset_run wipes mode before correct restore — SHOULD

### Fixes applied
- Strengthened harness: closed all 8 coverage gaps (added 25 assertions)
- save_system.gd: store_string return value now checked; cleanup on failure
- save_system.gd: delete_save now uses raw `user://` path
- save_system.gd: load_run reads saved mode and passes to reset_run
- npc_behavior.gd: raider mug uses single adjust_lead_hp call
- Bulk conversion: 52 emit_signal sites → typed `.emit()` form

### Result
- E2E run: **118 assertions, 0 fails → GREEN**
- Determinism: 3 runs identical
- Stderr: clean (no SCRIPT ERROR or deprecation warnings)
- Unit tests: 261/261 pass
- Smoke runs: both complete cleanly

### Decision
**Green build confirmed.** All 20 pieces pass at scores ≥ 98. No further iterations needed.

---

## Orchestration metrics

| Metric | Value |
|---|---|
| Iterations | 2 |
| Subagents spawned | 2 (parallel: qa-tester + godot-gdscript-specialist) |
| Harness assertions | 68 → 93 → 118 |
| Production code files modified in iteration 2 | 15 (mostly emit_signal conversion) |
| Real bugs caught by review-loop that baseline missed | 5 (4 prod + 1 silent-failure save) |
| Coverage gaps caught by review-loop that baseline missed | 8 |
| Total run time (human-equivalent) | ~30 minutes |
| Cost: token budget | ~100k orchestrator + ~100k subagents combined |

The feedback loop was net positive: 2 subagents caught 13 issues that the
baseline harness would have shipped with. Without the review cycle, the project
would have looked "green" while quietly carrying a silent-save-failure bug, a
broken HTML5 delete path, and 50 deprecation warnings on the way to Godot 4.6.
