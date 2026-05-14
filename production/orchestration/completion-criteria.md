# WARBAND G0 — Completion Criteria

**Mandate:** Autonomous build. Orchestrator returns to user when ALL criteria
below are met. If a hard criterion cannot be met, orchestrator must stop and
escalate to user with a specific blocker description.

## Hard Criteria (all must be TRUE)

### H1 — Project Builds
- [ ] Godot 4.6 project opens without errors
- [ ] No script parse errors in any `.gd` file
- [ ] No missing scene references
- [ ] No autoload load failures

### H2 — Tests Pass
- [ ] All GUT unit tests pass (target ≥ 30 unit tests for G0)
- [ ] The headless end-to-end integration test passes
- [ ] No flaky tests (3 consecutive runs identical results)

### H3 — Core Loop Plays End-to-End
- [ ] Player can start a new run from main menu
- [ ] Player can hire candidates at the tavern (gold deducted, candidate joins roster)
- [ ] Player can press GO and watch a battle resolve to completion
- [ ] Battle outcome is correctly applied (XP gained, gold gained, dead orcs removed)
- [ ] Dead orcs trigger the gravestone wall entry
- [ ] Run continues after a battle (return to tavern)
- [ ] Hero death ends the run with a campaign summary screen
- [ ] Player can start a new run after the previous one ends

### H4 — Pillar Demonstrability
- [ ] **Pillar 1 (Growth Made Flesh)**: equipping a weapon visibly changes the orc sprite OR the orc sprite shows a level-up tier change
- [ ] **Pillar 2 (Loss Has Weight)**: dead orcs are PERMANENTLY removed from the roster, named in the gravestone wall, and not recoverable
- [ ] **Pillar 3 (Every Coin a Choice)**: starting gold + battle income makes a full roster fill UNAFFORDABLE in run 1 (player must skip candidates or sell gear)
- [ ] **Pillar 4 (Watch and Learn)**: every combat event (attack, hit, crit, kill, status) produces a readable on-screen log entry

### H5 — HTML5 Export Builds
- [ ] `godot --headless --export-release "Web" build/warband.html` succeeds
- [ ] Output is < 25 MB total
- [ ] Index file loads without 404 errors when served locally

### H6 — Score Threshold
- [ ] Aggregate score across all G0 systems ≥ 80/100
- [ ] No individual system scores < 70/100
- [ ] Scoreboard updated in `production/orchestration/scoreboard.md`

### H7 — Bug Backlog
- [ ] Zero open Severity-1 or Severity-2 bugs
- [ ] All open bugs are documented with reproduction steps in `production/qa/bugs/`

### H8 — Documentation
- [ ] Every G0 system has an authored GDD in `design/gdd/[system-slug].md`
- [ ] Every G0 system has at least one ADR in `docs/architecture/` if it required an architectural decision
- [ ] `production/session-state/active.md` reflects current state
- [ ] `production/orchestration/scoreboard.md` shows the final scores

## Soft Criteria (advisory — included in report, not blocking)

### S1 — Polish Indicators
- Animation timing feels weighted (not jittery)
- Floating damage numbers readable for ≥ 0.5s
- Audio stubs in place (silent OK, hooks called)
- Color palette consistent across screens

### S2 — Code Quality
- All public methods have doc comments
- No `print()` debug calls left in code
- Lead-programmer code review score ≥ 20/25 per system

### S3 — Performance
- 60fps sustained during battle on a mid-2020 dev laptop in browser
- HTML5 first-paint < 3 seconds
- No memory leaks observed across 5 sequential runs

## Stop Conditions (orchestrator MUST halt if hit)

The orchestrator must stop work and escalate to user immediately if:

- A subagent reports BLOCKED on a question only the user can answer
- An architectural decision requires a tradeoff that crosses pillars
- A required tool/capability is unavailable (e.g., Godot not installed)
- The same bug reappears in 3 consecutive QA cycles (suggests fundamental design issue)
- Aggregate score plateaus below 80 after 3 fix-cycles
- Session token budget exceeds 80% of context window (compact and resume signal)

## Final Report Template

When all hard criteria are met, the orchestrator produces a final report at
`production/orchestration/final-report-G0.md` containing:

1. Completion criteria checklist (all H1-H8 marked PASS)
2. Aggregate score with per-system breakdown
3. Test results summary (unit pass count, integration pass, smoke pass)
4. Open soft items (S1-S3) with status
5. Recommended next milestone scope (G1) and any open questions
6. Path to run the game locally + path to HTML5 build artifact
