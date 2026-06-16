# Automated Playtest Findings — v0.4.x

Source: `make playtest` (45 seeded runs across 3 difficulties × 3 map sizes).

The harness uses a deterministic "reasonable median player" policy:
- Establish base on day 1
- Scavenge unsearched tiles, move toward new ones otherwise
- Build the cheapest available enhancement at base
- Rest if HP < 50%
- End day if nothing else applies

It does **not** open event modals or recruit — those require a human (or a
smarter policy with combat heuristics). So these findings are about the
base game's mechanical pressure curve, not its event/recruit balance.

## Cells (diff × size, runs=5 per cell)

| Difficulty | Map | avg days | zombies killed | wipes | morale deaths | victories |
|---|---|---|---|---|---|---|
| 0 Tourist     | 10×10 | 21.0 | 7  | 5/5 | 0 | 0 |
| 0 Tourist     | 14×14 | 23.6 | 2  | 5/5 | 0 | 0 |
| 0 Tourist     | 20×20 | 30.2 | 1  | 5/5 | 0 | 0 |
| 1 Standard    | 10×10 | 15.0 | 6  | 5/5 | 0 | 0 |
| 1 Standard    | 14×14 | 20.2 | 3  | 5/5 | 0 | 0 |
| 1 Standard    | 20×20 | 25.6 | 4  | 5/5 | 0 | 0 |
| 2 Apocalypse  | 10×10 | 13.0 | 3  | 0/5 | 5/5 | 0 |
| 2 Apocalypse  | 14×14 | 13.2 | 3  | 1/5 | 4/5 | 0 |
| 2 Apocalypse  | 20×20 | 12.6 | 0  | 0/5 | 5/5 | 0 |

## Real findings, with proposed fixes

### F1 — Tourist + Standard are AI-unwinnable; 100% wipe rate
**Signal**: median-player simulator dies to zombies on every cell.
**Interpretation**: a non-recruiting solo player has no path to enough
combat power to beat hordes. The recruit/equip loop is mandatory for
survival, but the game doesn't *teach* this.
**Proposed fixes**:
- Adjust starting kit on Tourist to include a `pistol` + 2 ammo so day-1
  combat is winnable
- Raise the first NPC spawn weight so a recruit is offered within ~5 days

### F2 — Apocalypse is a food-collapse difficulty, not a zombie difficulty
**Signal**: 80-100% of Apocalypse runs end in morale collapse (starvation),
not party wipe. 1.5× food consumption multiplier outweighs the higher zombie
threat.
**Interpretation**: the Apocalypse modifier is currently a single-axis
("food x1.5") rather than what its name implies ("more zombies, more
betrayals, more dangerous events").
**Proposed fixes**:
- Drop food consumption to 1.25× on Apocalypse
- Stack a second axis: spawn-rate +25% (already in code) + horde-tier
  weight bias earlier in the day curve
- Or split into two named modes: "Hard" (combat-heavy) and "Endurance"
  (food-tight)

### F3 — Map size doesn't strongly influence outcome at Standard
**Signal**: avg_days on Standard is 15 / 20 / 26 across 10×10 / 14×14 /
20×20. Larger maps give the AI more time, but it always dies to wipes.
**Interpretation**: map size correctly scales megahorde timing but does
not change the kill-pressure curve. Acceptable.

### F4 — Zombie-kill rate inverts with map size on Tourist
**Signal**: Tourist 10×10 = 7 kills/run, 20×20 = 1 kill/run.
**Interpretation**: bigger maps spread the AI thinner; fewer encounters
overall. This is correct behavior, just worth noting for marketing copy
("longer runs are tense, not bloody").

## What the harness cannot tell us

- Whether the event text actually lands emotionally
- Whether morale economy *feels* fair to a human (vs the simulator's
  deterministic policy)
- Whether the UI is discoverable
- Whether the megahorde feels climactic vs anticlimactic
- Whether betrayal narratively pays off

Those still require five strangers playing for 30 minutes each. The harness
substitutes for "is anything fundamentally broken" — it cannot substitute
for "is this fun."

## How to re-run

```bash
make playtest
```

Exit 0 if no degenerate cells, exit 1 if any cell triggers a finding.
CI-suitable for gating balance changes.
