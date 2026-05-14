# WARBAND Orchestration Plan

**Mode:** Autonomous multi-agent build
**Scope:** G0 — Playable Prototype
**Started:** 2026-05-14
**Orchestrator:** Main Claude session

## Mission

Build a fully playable, tested, end-to-end G0 Playable Prototype of WARBAND.
Validate the core loop. Produce evidence of working software.

## Architecture

```
                          ┌───────────────────┐
                          │   ORCHESTRATOR    │  (main Claude)
                          │  Plan · Route ·   │
                          │  Triage · Verify  │
                          └─────────┬─────────┘
                                    │
        ┌────────────────────────────┼────────────────────────────┐
        │                            │                            │
   ┌────▼─────┐                 ┌────▼─────┐                ┌─────▼─────┐
   │  DESIGN  │                 │   DEV    │                │    QA     │
   │          │                 │          │                │           │
   │ game-    │ → systems map   │ godot-   │ → implements   │ qa-lead   │ → strategy
   │ designer │                 │ specialist│                │ qa-tester │ → cases+bugs
   │          │                 │          │                │           │
   │ art-     │ → art bible     │ godot-   │                │           │
   │ director │                 │ gdscript │                │           │
   │          │                 │          │                │           │
   │          │                 │ gameplay-│                │           │
   │          │                 │ programmer│                │           │
   │          │                 │          │                │           │
   │          │                 │ ai-      │                │           │
   │          │                 │ programmer│                │           │
   │          │                 │          │                │           │
   │          │                 │ ui-      │                │           │
   │          │                 │ programmer│                │           │
   └──────────┘                 └────┬─────┘                └─────┬─────┘
                                    │                              │
                                    │     ┌───────────────┐        │
                                    │     │ lead-programmer│       │
                                    └────►│ Code review +  │◄──────┘
                                          │ scoring        │
                                          └───────────────┘
```

## Phase Plan

### Phase 1 — Design (in flight)
- `game-designer` produces systems map (draft → user review skipped under autonomous mandate → write)
- `art-director` produces art bible

### Phase 2 — Scaffolding
- Godot 4.6 project structure
- Autoloads registered
- Test framework (GUT) installed
- CI hook stubbed
- Placeholder asset pipeline

### Phase 3 — System Implementation
Order (derived from systems map, Foundation → Core → Feature):

1. **Run State** (autoload) — single source of truth for run progress
2. **Combat Resolver** — deterministic auto-battle simulation
3. **Stat & Trait System** — orc stats, traits, level-up
4. **Gold Economy** — earn/spend, scarcity tuning
5. **Tavern / Recruit** — candidate generation, hire flow
6. **Gear System** — equip, swap, stat modifiers
7. **Permadeath & Memorial** — death triggers + gravestone wall
8. **Campaign Flow** — Tavern → Battle → Resolution loop
9. **UI Screens** — each phase's screen
10. **Audio Stubs** — event hooks (no real audio in G0)

Each system gets:
- GDD authored by game-designer
- Implementation by appropriate dev specialist
- Unit tests by the dev specialist
- QA test plan by qa-lead
- QA test cases + bug reports by qa-tester
- Code review + score by lead-programmer

### Phase 4 — Integration
- End-to-end headless test scripting a full G0 run
- HTML5 export build
- Smoke check

### Phase 5 — Feedback Loop
- All open bugs from Phase 4 routed back to dev agents
- Re-test until empty
- Re-score

### Phase 6 — Final Verification & Report
- All systems scored
- Aggregate score computed
- Completion criteria checked
- Final report to user

## Feedback Loop Protocol

See `feedback-loop.md`.

## Scoring

See `score-rubric.md` and the `/score-feature` skill.

## Completion Criteria

See `completion-criteria.md`. **Done = all hard criteria met AND aggregate score ≥ 80.**

## Risk Mitigations

- **Subagent context drift**: every spawn includes the orchestration plan path + relevant GDD paths
- **Implementation churn**: every system has a written GDD before code; no code without an authored spec
- **Test flakiness**: deterministic seeds enforced; no time-dependent assertions
- **HTML5 export breakage**: export tested after every 3 systems landed
- **Cross-agent file conflicts**: each system has a single owning dev agent; orchestrator routes
