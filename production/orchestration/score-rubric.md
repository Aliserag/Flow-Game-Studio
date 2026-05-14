# WARBAND Scoring Rubric

Each system is scored on four axes. Each axis is 0-25. Total: 0-100.

## Axis 1 — Code Quality (0-25)

Reviewed by `lead-programmer` agent.

| Range | Criteria |
|---|---|
| 23-25 | Idiomatic GDScript, fully type-annotated, all public APIs have doc comments, no dead code, no magic numbers, dependency injection where appropriate |
| 18-22 | Mostly clean; 1-2 minor style violations; type annotations present; doc comments on public API |
| 13-17 | Functional but has clear improvement opportunities; some missing types; minor coupling issues |
| 8-12 | Works but technical debt visible: untyped vars, magic numbers, copy-paste code |
| 0-7 | Multiple violations of coding standards; not ready for downstream work |

Hard fail under 13.

## Axis 2 — Test Coverage (0-25)

Reviewed by `qa-tester` agent.

| Range | Criteria |
|---|---|
| 23-25 | 100% of acceptance criteria covered by passing tests, includes edge cases and boundary values, deterministic, isolated |
| 18-22 | All happy-path AC covered, most edge cases tested |
| 13-17 | Happy path tested only |
| 8-12 | Partial happy path coverage |
| 0-7 | No tests OR tests do not pass |

Hard fail under 13.

## Axis 3 — Pillar Alignment (0-25)

Reviewed by `lead-programmer` + cross-checked against GDD by orchestrator.

| Range | Criteria |
|---|---|
| 23-25 | System actively serves all stated pillars; design test from GDD passes; system embodies the pillar identity in implementation |
| 18-22 | All stated pillars served; minor opportunity to deepen pillar alignment |
| 13-17 | Pillars functionally supported but not embodied |
| 8-12 | At least one pillar weakly supported |
| 0-7 | Violates a stated pillar OR violates an anti-pillar |

Hard fail under 13. A violation of an anti-pillar = automatic 0 on this axis.

## Axis 4 — Acceptance Criteria Met (0-25)

Reviewed by `qa-tester` + verified by orchestrator.

| Range | Criteria |
|---|---|
| 23-25 | 100% of GDD acceptance criteria pass, verified by automated test or evidence |
| 18-22 | ≥ 90% of AC pass |
| 13-17 | ≥ 75% of AC pass |
| 8-12 | ≥ 50% of AC pass |
| 0-7 | < 50% of AC pass |

Hard fail under 13.

## Aggregate Score Interpretation

| Score | Verdict |
|---|---|
| 90-100 | EXCELLENT — production-quality |
| 80-89 | GOOD — meets bar, minor polish opportunities |
| 70-79 | ADEQUATE — meets minimum, needs improvement before next milestone |
| 60-69 | INSUFFICIENT — must be remediated before merge |
| < 60 | FAIL — back to dev queue |

## Orchestration Use

- Per-system score is recorded in `production/orchestration/scoreboard.md`
- Aggregate score = mean of all G0 system scores
- **G0 completion bar: aggregate ≥ 80 AND no individual system < 70**
- Any system scoring < 70 triggers the feedback loop and is re-implemented
- Three consecutive cycles failing to break 70 escalates to the user
