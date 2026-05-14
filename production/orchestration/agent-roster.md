# WARBAND Orchestration — Agent Roster

## Roles & Responsibilities

### Orchestrator (main Claude)
- Owns the orchestration plan and completion criteria
- Routes work to specialist agents
- Triages bugs back to dev agents
- Computes scores after each system landing
- Decides when G0 is complete

### Design Tier
| Agent | Domain | Output |
|---|---|---|
| `game-designer` | System decomposition, mechanic GDDs | `design/gdd/[system].md` |
| `art-director` | Visual identity, modular sprite atlas spec | `design/art-bible/warband-art-bible.md` |
| `systems-designer` | Detailed formulas, balance numbers, interaction matrices | Per-GDD §4-§7 |
| `narrative-director` | Eulogy templates, archetype voice, bark-line philosophy | Inline in `design/gdd/sagas-memorial.md` |
| `ux-designer` | Screen flow, interaction patterns for tavern/battle/resolution | `design/ux/[screen].md` |

### Implementation Tier
| Agent | Domain | Owns |
|---|---|---|
| `godot-specialist` | Project structure, autoloads, scene hierarchy | `project.godot`, autoload wiring |
| `godot-gdscript-specialist` | All `.gd` code quality | Code style, typing, signal patterns |
| `engine-programmer` | Core systems, run state machine, save | `src/core/` |
| `gameplay-programmer` | Mechanics, combat, economy | `src/gameplay/` |
| `ai-programmer` | Combat AI, target selection, behavior trees | `src/ai/` |
| `ui-programmer` | All UI screens and widgets | `src/ui/` |
| `technical-artist` | Sprite atlas pipeline, shader for palette swap | `assets/` pipeline, shaders |

### Quality Tier
| Agent | Domain | Output |
|---|---|---|
| `qa-lead` | Test strategy per system | `production/qa/test-plans/[system].md` |
| `qa-tester` | Test cases, bug reports, manual smoke checks | `tests/`, `production/qa/bugs/` |
| `lead-programmer` | Code review, quality scoring | Inline review notes + score input |
| `performance-analyst` | Frame budget verification, memory checks | `production/qa/perf-reports/` |

### Cross-Cutting
| Agent | Domain | When Invoked |
|---|---|---|
| `accessibility-specialist` | A11y review against WCAG 2.1 AA | After UI screens land |
| `security-engineer` | Save tampering, exploit surface | Before HTML5 export |
| `localization-lead` | String externalization audit | At G2 (skip for G0) |
| `producer` | Risk surfacing, scope check | When orchestrator detects scope drift |

## Routing Rules

| File extension / system | Owner agent |
|---|---|
| `.gd` (GDScript) | `godot-gdscript-specialist` |
| `.tscn` / `.tres` | `godot-specialist` |
| `.gdshader` | `godot-shader-specialist` |
| `src/core/*.gd` | `engine-programmer` (implementation), `godot-gdscript-specialist` (style review) |
| `src/gameplay/*.gd` | `gameplay-programmer` |
| `src/ai/*.gd` | `ai-programmer` |
| `src/ui/*.gd` + `src/ui/*.tscn` | `ui-programmer` |
| `tests/*.gd` | `qa-tester` (writing), system-owning dev (fixing) |
| `design/gdd/*.md` | `game-designer` (authoring) |
| `design/art-bible/*.md` | `art-director` |
| `docs/architecture/ADR-*.md` | varies by ADR — usually `lead-programmer` or specialist |

## Parallel Execution Policy

The orchestrator MUST spawn agents in parallel when:
- Two systems have no dependency between them at the implementation stage
- Design + implementation can overlap (design ahead one system)
- Multiple QA passes on different landed systems

The orchestrator MUST NOT parallelize when:
- One agent's output is required as input for another
- Two agents would write to the same file
- The work is small enough that orchestration overhead exceeds parallel gain
