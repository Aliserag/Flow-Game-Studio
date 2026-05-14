---
name: orchestrate-e2e
description: Drive a game project to full E2E-verified completion using a multi-agent orchestrator. Spawns dev specialists in parallel for fixes, runs an E2E playthrough harness, scores each piece, and iterates until all pieces pass. Use when the user wants the project to reach a "demonstrably working end-to-end" state with autonomous fix cycles. Returns a final scorecard and the commit hash of the green build.
---

# Orchestrate E2E Completion

**Purpose**: Take a project from "code compiles and unit tests pass" to "every user-visible flow has been demonstrated end-to-end in an automated harness." Replaces guesswork ("looks right to me") with measurement ("piece X scored 95/100, here's the evidence").

## When to use

- A game/app prototype is "done" but never been driven end-to-end
- The user wants a hands-off completion: spawn agents, iterate, report
- A regression sweep is needed before a release gate

## When NOT to use

- The unit test suite is failing — fix that first with `/dev-story` or direct edits
- The project has no harness at all — first create one with the engine specialist
- The user wants to drive iteration manually — this skill is for autonomy

## Inputs

- Project root (e.g. `they-come-at-night/`)
- Engine binary path (e.g. `/tmp/Godot_v4.4-stable_linux.x86_64`)
- Optional: list of named pieces to score (defaults to the rubric in `production/e2e/completion-criteria.md`)

## Outputs

- `production/e2e/scorecard-YYYY-MM-DD.md` — per-piece score with evidence
- `production/e2e/iteration-log.md` — append-only log of each iteration
- A clean git commit on the development branch with the green build

## Workflow

### Phase 0 — Initialize

1. Read `production/e2e/completion-criteria.md`. If missing, generate it from the GDD and per-system test plan.
2. Read the most recent `production/e2e/scorecard-*.md`. If none, treat all pieces as `pending`.
3. Verify the engine binary is available; verify the harness mode (`--e2e`) is wired in.

### Phase 1 — Baseline run

1. Run the E2E harness: `<engine> --headless res://scenes/Main.tscn -- --e2e`.
2. For each piece, parse the assertion output. Record PASS / FAIL / ERROR with the assertion that surfaced the result.
3. Write the baseline scorecard.

### Phase 2 — Iterate (loop)

For each piece with `FAIL` or `ERROR`:

1. **Classify** the failure type:
   - Compile/parse → `godot-gdscript-specialist`
   - Logic bug → `gameplay-programmer`
   - UI/widget issue → `ui-programmer`
   - Data/balance → `economy-designer` or `systems-designer`
   - Engine quirk → `godot-specialist`
2. **Spawn** a dev specialist subagent (use `Task` with the matching `subagent_type`). Brief it with:
   - The failing piece name and current score
   - The exact assertion that failed
   - Relevant file paths and line numbers
   - A request to fix and report back the changed files
3. **In parallel**, spawn a `qa-tester` subagent to write a regression test for the bug being fixed.
4. After all spawned subagents complete, re-run the harness.
5. Re-score affected pieces. Pieces that moved from FAIL → PASS earn their full points; pieces that regressed lose them.
6. Append to iteration log.

### Phase 3 — Done conditions

Iteration stops when:

- All pieces score ≥ their threshold (defined in `completion-criteria.md`), OR
- Hard limit reached: 8 iterations (escalate to user), OR
- Same piece has failed 3 consecutive iterations with the same root cause (escalate).

### Phase 4 — Final report

1. Run the harness one more time as the green-build confirmation.
2. Commit & push with message: `chore(e2e): green build — all pieces score ≥ threshold`.
3. Write the final scorecard.
4. Report: scorecard summary, total iterations, total subagents spawned, commit hash.

## Scoring rubric (default)

Each piece scores 0-100 based on:

| Dimension | Weight | What |
|---|---|---|
| Passes assertions | 60 | Hard check: the harness assertions for this piece succeed |
| No engine warnings | 15 | Headless run produces no warnings tagged to this system |
| Determinism | 10 | Same seed → same outcome (verified on 3 runs) |
| Performance | 10 | Operation completes within budget (defined per-piece) |
| Test coverage | 5 | Unit tests exist for the piece's pure functions |

A piece **passes** if score ≥ 80. The whole project **completes** if every piece passes.

## Agent budget

- Max 8 iterations
- Max 5 parallel subagents per iteration (one per failing piece, capped)
- Each subagent gets ≤ 20k tokens of context (brief them tightly)

## Files this skill writes to

- `production/e2e/completion-criteria.md` (created once, updated on scope changes)
- `production/e2e/scorecard-YYYY-MM-DD.md` (one per run)
- `production/e2e/iteration-log.md` (append-only)

## Files this skill reads

- All design docs in `design/`
- All test files in `tests/`
- The engine specialist's reference docs in `docs/engine-reference/`
- The skill must NOT modify game code directly — that's the dev subagents' job.
