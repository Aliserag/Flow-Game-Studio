---
name: score-feature
description: Score a single WARBAND system on the 4-axis rubric (code quality, test coverage, pillar alignment, AC met) and update the scoreboard. Run after a system has been implemented and QA-reviewed. Use when a system is ready for evaluation, e.g. "score the combat resolver", "/score-feature gold-economy".
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, Task
model: sonnet
---

# /score-feature — Score a WARBAND System

You are scoring a single WARBAND system against the 4-axis rubric defined in
`production/orchestration/score-rubric.md`. Produce a score, write it to the
scoreboard, and emit a structured verdict that the orchestrator can consume.

## Inputs

- `$ARGUMENTS`: the system slug to score (e.g. `combat-resolver`)
- If empty: read `production/session-state/active.md` to find the most recently
  landed system

## Required Reading

1. `production/orchestration/score-rubric.md` — the rubric
2. `design/gdd/[system-slug].md` — the GDD with acceptance criteria
3. `src/**/*.gd` — the implementation files for the system
4. `tests/unit/[system-slug]/` — the unit tests
5. `production/qa/bugs/` — any open bugs against this system

## Scoring Procedure

### Step 1 — Code Quality (0-25)
Delegate to `lead-programmer` agent for code review. Provide:
- Path to the system's implementation files
- Coding standards reference (`.claude/docs/coding-standards.md`)
- Technical preferences (`.claude/docs/technical-preferences.md`)

Lead-programmer returns: numeric score, list of style/quality findings.

### Step 2 — Test Coverage (0-25)
Delegate to `qa-tester` agent. Provide:
- Path to the system's GDD (for acceptance criteria list)
- Path to the system's test files
- Path to test runner output (run `godot --headless --script tests/gut_runner.gd -- -gtest=res://tests/unit/[system]/` first if needed)

Qa-tester returns: numeric score, list of uncovered AC.

### Step 3 — Pillar Alignment (0-25)
Score directly. Read the GDD's "Player Fantasy" and "Detailed Rules" sections.
Cross-reference against `design/concept/warband-game-concept.md` §5 (pillars).

For each pillar the system claims to serve:
- Read the pillar's design test
- Verify the implementation passes that test
- Note any anti-pillar violations (automatic 0)

### Step 4 — Acceptance Criteria Met (0-25)
Count AC from the GDD's "Acceptance Criteria" section.
- Count those covered by passing automated tests: count_passing
- Count total AC: count_total
- Score = round(25 * count_passing / count_total)

### Step 5 — Total + Verdict
```
total = code_quality + test_coverage + pillar_alignment + ac_met
```

Verdict map:
- 90-100: EXCELLENT
- 80-89: GOOD
- 70-79: ADEQUATE — needs improvement before next milestone
- 60-69: INSUFFICIENT — back to dev queue
- < 60: FAIL — back to dev queue

Hard-fail rule: any axis < 13 forces verdict to INSUFFICIENT regardless of total.
Anti-pillar violation forces verdict to FAIL.

### Step 6 — Update Scoreboard
Edit `production/orchestration/scoreboard.md`:
- Update the row for this system with all four sub-scores, total, verdict
- Append entry to the Score History section with date, system, cycle number, total, delta from previous cycle
- Recompute the aggregate at the top of the file

### Step 7 — Update Session State
Edit `production/session-state/active.md` to reflect the system's new score and verdict.

## Output Format

Print to user a structured verdict:

```
═══════════════════════════════════════════
SCORE: [system-slug]
═══════════════════════════════════════════
Code Quality:     [X] / 25
Test Coverage:    [X] / 25
Pillar Alignment: [X] / 25
AC Met:           [X] / 25
───────────────────────────────────────────
TOTAL:            [XX] / 100
VERDICT:          [EXCELLENT/GOOD/ADEQUATE/INSUFFICIENT/FAIL]
═══════════════════════════════════════════

Top findings:
- [finding 1]
- [finding 2]
- [finding 3]

Recommended action:
[Pass / Re-review after fix / Back to dev queue]
```

## Orchestrator Integration

When the orchestrator runs `/score-feature [slug]`:
1. The scoring produces a verdict
2. If GOOD or EXCELLENT: orchestrator marks system DONE, moves to next system
3. If ADEQUATE: orchestrator logs improvement opportunities, optionally moves on if cycle budget tight
4. If INSUFFICIENT or FAIL: orchestrator routes top findings as bug reports to the system's owner agent, increments cycle counter, re-implements/re-tests
5. After 3 cycles of INSUFFICIENT, escalate to user

## Notes

- This skill is the orchestrator's quality gate. Be rigorous.
- Do NOT inflate scores to make G0 look complete. Honest scoring is the only path to a real prototype.
- If a score is borderline (e.g., 79), choose the lower bucket — false confidence costs more than re-work.
