# They Come At Night — E2E Completion Criteria

**Project root**: `they-come-at-night/`
**Engine**: Godot 4.4 (verified locally; project pinned to 4.6 for production)
**Harness**: `godot --headless res://scenes/Main.tscn -- --e2e`

The project is **done** when every piece below scores **≥ 80/100**.

---

## Scoring per piece (each scored 0-100)

| Dimension | Weight | Failure looks like |
|---|---|---|
| **Assertions pass** | 60 | Harness prints `FAIL piece.assertion` |
| **No engine errors** | 15 | Godot stderr contains "SCRIPT ERROR" or "Parse Error" tagged to that file |
| **Determinism** | 10 | Two runs with same seed produce different stats |
| **Performance** | 10 | Operation exceeds budget (see per-piece column) |
| **Test coverage** | 5 | No unit test file references the system |

---

## Pieces

| # | Piece | Description | Perf budget | Threshold |
|---|---|---|---|---|
| **P1** | Boot | Project loads; main scene resolves; all autoloads ready | < 3s | 80 |
| **P2** | Map gen | Procedural 14×14 map with town clusters + at least one road | < 100ms | 80 |
| **P3** | Vision/fog | Fog of war updates on movement; tiles flip explored=true correctly | per-call < 1ms | 80 |
| **P4** | Movement | Click-equivalent move resolves; party follows lead; signals fire | < 1ms | 80 |
| **P5** | Scavenge | Tile.searched flag set; loot added to inventory by terrain category | < 5ms | 80 |
| **P6** | Combat | Zombie collision → resolve_attack → damage + casualties + zombie hp updated | < 5ms | 80 |
| **P7** | Base | Establish base; tile flagged; defense bonus from terrain | < 1ms | 80 |
| **P8** | Build | Start enhancement; resources deducted; days tick; on completion, enhancement enters `base_enhancements` | n/a | 80 |
| **P9** | Inventory | Assign/unassign item; use consumable heals; stash reflects changes | < 1ms | 80 |
| **P10** | Parley | Adjacent NPC produces parley payload; recruit branch adds to party with faction | n/a | 80 |
| **P11** | Faction AI | NPC movement varies by faction across 20 turns (doctors approach injured, raiders stalk player) | per-tick < 2ms | 80 |
| **P12** | Trade | TradePanel-driven buy/sell mutates stash & NPC stock; markups apply | < 1ms | 80 |
| **P13** | Betrayal | High-betrayal-chance recruit fires within 15 nights at high tension | n/a | 80 |
| **P14** | Swarm warning | After day 8, eventually schedules a swarm with eta in [2,4]; spawns at eta 0 | n/a | 80 |
| **P15** | Megahorde | Unlocks in [20,50]; arrives 5-8 days later; killing it ends run in VICTORY | n/a | 80 |
| **P16** | Save/Load | Mid-run save round-trips: state, party, inventory, knowledge, grid, entities | < 500ms | 80 |
| **P17** | Event system | At least one event from each tag (horror, humor, social, loot) fires across a long run | n/a | 80 |
| **P18** | Knowledge | Parleying a cannibal adds `cannibal_warning`; subsequent parleys show the warning label | n/a | 80 |
| **P19** | Defeat paths | Each of: party wipe, lead death, morale 0, lead infected → game_over | n/a | 80 |
| **P20** | UI scenes | MainMenu, GameView, BuildPanel, AssignPanel, TradePanel, KnowledgePanel, GameOver all instantiate without errors | per-scene < 200ms | 80 |

---

## How the harness assertions map to pieces

The `--e2e` mode runs a scripted playthrough. Each piece's check is a named
section in the output. The orchestrator parses lines of the form:

```
[E2E] P03 vision_on_move ........... PASS
[E2E] P15 megahorde_victory ........ FAIL  expected phase=GAME_OVER victory=true, got victory=false
```

The piece scores are calculated by `production/e2e/score_pieces.py` (or
inline in the orchestrator) from the harness output + the engine stderr log.

---

## Definition of green build

- Every piece scores ≥ 80
- Sum of scores ≥ 1800 (out of 2000)
- No piece scores 0 on any of its 60-weight `assertions pass` dimension
- All 261 unit tests still pass
- A 50-turn solo smoke and a 100-turn settled smoke both complete without engine errors

---

## Escalation conditions

The orchestrator escalates to the user when:

1. A piece has failed for 3 consecutive iterations with the **same root cause**.
2. A fix in one piece regresses another piece in two consecutive iterations.
3. Cumulative subagent spawns exceed 20.
4. Same code file has been modified by ≥ 4 different subagents.

When escalating, write a clear summary to `production/e2e/escalation-YYYY-MM-DD.md`
including the failing piece, the fixes attempted, and the leading hypothesis.
