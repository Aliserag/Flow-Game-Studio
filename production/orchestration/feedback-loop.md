# WARBAND Orchestration — Feedback Loop Protocol

## State Machine

```
                          ┌──────────────┐
                          │  IMPLEMENTED  │  (dev agent reports done)
                          └───────┬──────┘
                                  │
                          ┌───────▼──────┐
                          │   IN REVIEW   │  (qa-tester + lead-programmer)
                          └───────┬──────┘
                                  │
                          ┌───────▼──────┐
                          │   TRIAGE      │  (orchestrator inspects results)
                          └───┬───────┬──┘
                              │       │
                  pass ◄──────┘       └─────► fail
                   │                            │
            ┌──────▼──────┐              ┌──────▼──────┐
            │   SCORED     │              │   BUGFIX     │
            │ → scoreboard │              │ (route to    │
            │              │              │  owner)      │
            └──────────────┘              └──────┬──────┘
                                                  │
                                                  └────► back to IN REVIEW
```

## Bug Report Format

Every bug filed by `qa-tester` lands in `production/qa/bugs/[YYYY-MM-DD]-[seq]-[slug].md` with this template:

```markdown
# Bug [YYYY-MM-DD]-[seq] — [Short Title]

**Status:** Open
**Severity:** S1 / S2 / S3 / S4
**System:** [system-slug from systems-index]
**Owner Agent:** [agent-type from routing rules]
**Filed By:** qa-tester
**Filed:** [date]

## Description
[Plain-language description of the bug.]

## Reproduction Steps
1. ...
2. ...
3. ...

## Expected
[What should happen.]

## Actual
[What happens instead.]

## Test Reference
[Path to failing test, or "manual smoke check"]

## Severity Justification
[Why this severity? Hard-block / playable-but-broken / cosmetic / edge case]

## Fix Attempts
- [date] [agent] — [what was tried, outcome]
```

## Severity Levels

| Severity | Definition | Impact on G0 |
|---|---|---|
| **S1** | Game crashes, data loss, unrecoverable state | BLOCKING — must fix before completion |
| **S2** | Core loop broken, AC unmet, test failure | BLOCKING — must fix before completion |
| **S3** | Visual/audio bug, minor flow issue, edge-case logic error | Advisory — fix if cycles allow |
| **S4** | Cosmetic, polish, nice-to-have | Defer to G1+ |

## Triage Rules (orchestrator)

1. Open every new bug as soon as filed
2. Route to the system's owner agent per `agent-roster.md`
3. Set a fix budget: S1/S2 = 2 cycles, S3 = 1 cycle, S4 = 0 cycles (deferred immediately)
4. After fix attempt, re-run the failing test/check
5. If passes: close bug, append fix log
6. If fails: log second attempt; if 3rd attempt fails, escalate

## Escalation

After 3 fix attempts on the same bug:
- Orchestrator promotes to ESCALATED status
- Spawns `lead-programmer` for architectural review
- If `lead-programmer` cannot resolve, orchestrator stops and surfaces blocker to user

## Closure Criteria for G0

- All S1 bugs: CLOSED
- All S2 bugs: CLOSED
- S3 bugs: documented, may carry over to G1
- S4 bugs: documented and deferred

## Bug Audit Trail

`production/qa/bug-log.md` maintains a chronological index of every bug filed, its severity, owner, and outcome.

The orchestrator updates `bug-log.md` on every bug state transition.
