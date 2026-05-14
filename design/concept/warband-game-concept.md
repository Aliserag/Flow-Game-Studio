# WARBAND — Game Concept Document

> **Working title.** Final name TBD. Internal codename `WARBAND` throughout
> documentation until a marketing pass renames it.

| Field | Value |
|---|---|
| Status | Concept Locked — pending /map-systems |
| Date Authored | 2026-05-14 |
| Engine | Godot 4.6 |
| Language | GDScript |
| Target Platform | Web (HTML5) primary, Desktop secondary |
| Scope Target | Full 1.0, 12-18 months |
| Authoring Skill | `/brainstorm` (Lean mode) |

---

## 1. One-Page Pitch

**WARBAND** is a single-player auto-battler campaign where you build, equip,
level, and grieve a warband of named orcs as you climb from farm-raid bandit to
warchief of the Northern Crags. Every battle is a side-on 2D auto-resolution
brawl in the spirit of Hearthstone Battlegrounds. Every orc has a name, a face,
a voice, traits, and a permanent death waiting to happen.

You play a hero orc — your own permanent identity in the campaign. Around the
hero you recruit a roster of 5-10 grunts drawn from a Souls-and-Sandbox style
candidate pool: each appears at the tavern with a portrait, an archetype, a
quirk, and a price you almost can't afford. Between battles you draft, gear up,
allocate stat points on every level-up, sell loot, and choose your next fight on
a campaign map. Then you press GO and watch the brawl resolve in 30-60 seconds
of pixel-art violence with floating damage numbers, kill banners, and red
crossouts when an orc you love takes a spear to the chest.

The pitch crystal: **Battle Brothers' permadeath saga, Battlegrounds' draft
loop, Slay the Spire's pace and clarity, told entirely through orcs who matter
because they have names.**

### Key Art Direction Note (handoff to art-director)

Pixel-art, expressive portraits, side-on battlefield framing. Visible
*progression on the body*: scars, missing teeth, gear swaps, banner heraldry.
The Pillar 1 contract — Growth Made Flesh — is an art contract more than a code
contract. Tone is *gallows-humor brutal*: orcs bicker on the way to the fight,
the dying ones get last words, the survivors carve names into their armor.

---

## 2. Player Fantasy

> *You are the orc who matters because the orcs around you matter.*

The fantasy is **the warlord with a heart**. Not a power fantasy. A
*relationship* fantasy. You aren't a god of war wading through chaff — you are
a hero orc trying to keep your scraping, swearing, hungry warband alive long
enough to make it to the next ridge, the next village, the next warchief's
throne.

The dominant emotion across a campaign is **earned pride mixed with grief**.
Pride at the warband you assembled, the battles you read correctly, the gear
you built. Grief at the orcs who didn't make it — Grog, killed by a spear in
the second raid; Skarra, the cleaver-girl you found in the cage, who outlived
the boss and died in the next ambush. The names matter because *you cannot
replace them with identical names*.

Sub-fantasies the game must support:
- **The Scout** — reading the next battle before committing. Information as
  power.
- **The Quartermaster** — gear and gold tetris. Tiny optimizations that
  compound.
- **The Mentor** — watching a level-1 candidate you almost passed on become
  your veteran champion three campaigns later.
- **The Mourner** — closing the eulogy menu, naming the gravestone, moving on.

What we explicitly do *not* deliver: solo-hero power trips, cinematic story
beats with named NPCs, real-time combat agency.

---

## 3. Genre & Reference Games

WARBAND lives at the **intersection of three sub-genres** plus a fourth as
tonal influence:

| Reference | What We Take | What We Leave |
|---|---|---|
| **Battle Brothers** | Permadeath, named-character roster, candidate hiring loop, dread, gear deep-dive, campaign map of regional threats | Hex-grid tactical turn-based combat. We auto-resolve instead. |
| **Slay the Spire** | Run pacing, clarity of UI, "every choice is a tradeoff," readable card-like effects on units, tight 30-60min sessions | Card-based combat. Single hero. |
| **Hearthstone Battlegrounds / Super Auto Pets** | The tavern draft beat, the watch-and-learn brawl, the comp-building meta layer, tier-up tempo | PvP, lobby of 8 players, real-money cosmetics |
| **Darkest Dungeon** *(tonal)* | Grim aesthetic, narrator-flavored eulogies, mental-toll-as-mechanic vibes, "this game does not love you" contract | Stress/Affliction system (too heavy for our scope), turn-based dungeon crawls |
| **Shadow of Mordor (Nemesis system)** *(meta layer inspiration)* | Orcs as named, lasting characters with grudges and reputations | Open-world structure, real-time combat |

Closest mechanical relative shipped: **Wartales** + **Super Auto Pets**.

---

## 4. Core Loops

### 4.1 The 30-Second Loop (Moment-to-Moment)

A battle has two beats stacked in series.

**Beat A — The Tavern (~30s)**
- Three named candidates rotate into view with portrait, archetype, traits,
  hire price.
- A scout report on the *next* battle is visible at the top of the screen.
- You have ~80% of the gold you need to fill every slot. Pass or pick.
- Once you commit, the candidates are gone forever.

**Beat B — The Brawl (~30-60s)**
- Warband at bottom of screen. Enemy comp at top. Press GO.
- Both sides advance, melee meets in the middle, ranged fires from behind.
- Big readable floating text: "**GROG** crits Bandit for 18!" "**SKARRA** is
  felled."
- Outcome announced with a kill-count summary and a gravestone shake animation
  for each lost orc.

**Why it satisfies (the core action analysis):**
- *Autonomy:* every meaningful choice is up-front (Beat A) and pre-committed.
- *Loss aversion drives Beat A* — the passed-on candidate is *forever* gone.
- *Delayed catharsis drives Beat B* — your draft choices made flesh, with
  meaningful loss as the receipt.
- *Transparency is non-negotiable.* Beat B must teach. No hidden RNG.

### 4.2 The 5-Minute Loop (Battle-to-Battle)

```
[Recruit] → [Gear & Stat-Allocate] → [Press GO] → [Watch] → [Resolution] → [Loot] → next
   ~30s          ~60-90s              ~5s         30-60s      ~10s         ~30s
```

- Survivors gain XP. On level-up, the player gets an S&S-style point pool to
  allocate per orc.
- Gold drips in from kills + a flat battle stipend.
- Gear is dropped by some enemies; rest is bought at market.

### 4.3 The Session Loop (30-60min — "a raid" or "campaign chapter")

A raid = **3-5 linked battles**, no respite between. Between raids:
- **Market** — sell loot, buy gear/consumables. Stock rotates per raid.
- **Tavern** — fresh candidate pool. Hiring is the main money sink.
- **Memorial** — read the eulogies of fallen orcs. Optional. No mechanical
  effect (anti-Pillar: not for power).
- **Map** — choose next destination from 2-3 branches with different risk/loot
  profiles.

### 4.4 The Progression Loop (Campaign Arc — 15-30 hours)

Campaign acts: **farm raids → village raids → rival clan wars → warchief
contenders → final warchief**. Each act introduces:
- New enemy archetypes
- New candidate archetypes at the tavern
- New gear tiers
- New campaign-map regions and hazards
- One major boss

**Hero death = campaign ends.** This is the contract that makes Pillar 2 (Loss
Has Weight) honest. When the hero dies the campaign closes; the run is
chronicled in the "Sagas" book.

### 4.5 The Meta Loop (Across Campaigns)

When a campaign ends — whether by hero death, total wipe, or warchief victory —
meta-progression unlocks:

- **Starting Hero Archetypes** — new templates for the next hero orc.
- **Legends** — orcs from past campaigns whose statues stand at the start of
  the next campaign. Their unique signature gear (the cleaver Skarra wielded
  for 47 battles) can drop in the new run.
- **Tavern Stock** — once-rare archetypes start appearing more often.
- **Cosmetic Banner & Warpaint** — visible identity upgrades.

The meta loop is **light by design**. The campaign is the unit of play; the
meta layer respects players who only do one campaign without punishing players
who do twenty.

---

## 5. Pillars & Anti-Pillars

### Pillar 1 — Growth Made Flesh
> Every progression beat must show on the orc's body, gear, or banner.
> Numbers go up only if pixels change too.

*Design test:* A new ability that grants +10% damage but no visual change → cut
or redesign.

### Pillar 2 — Loss Has Weight
> Death is permanent and named. The game must give you reasons to grieve, not
> just inventory holes.

*Design test:* A revive item that costs gold → reject. A "Final Words" voice
line on death → keep.

### Pillar 3 — Every Coin a Choice
> Gold is the resource you never have enough of. Recruit OR gear OR heal —
> pick. Drip gold in slowly. Price things generously.

*Design test:* A passive gold income that lets you buy everything → reject.
A gear piece priced at 80% of your purse → exactly right.

### Pillar 4 — Watch and Learn
> Combat is auto-resolved but transparent. The player can read why they lost
> and adjust. No hidden RNG punishes without teaching.

*Design test:* A "lucky crit" that swung the fight invisibly → reject. A
floating "**Berserker enrages — +damage**" toast → keep.

### Anti-Pillar A — Not a real-time micro game
No clicking units in combat. You set the table; the table cooks itself.

### Anti-Pillar B — Not power fantasy
Your warband is misfits — limps, missing teeth, bickering. Even at the top,
they're scrappy.

### Anti-Pillar C — Not a hero-solo story
The hero matters, but the *warband* is the protagonist. UI must give every orc
face time.

---

## 6. Bullseye Player & Audience Risk

### Bullseye Profile

**"The hybrid intersection player"** — the player who has, in the last 12
months, played at least two of: *Battle Brothers / Wartales / Darkest Dungeon /
Slay the Spire / Inscryption / Balatro / Super Auto Pets / Hearthstone
Battlegrounds*. They are:

- Comfortable with permadeath and roguelike framing.
- Patient enough to read tooltips and absorb 20+ archetypes.
- Hungry for *meaningful* run variance, not random chaos.
- Likely to play 50+ hours if hooked; likely to bounce in the first 30 minutes
  if onboarding is poor.

### Secondary Audience

Auto-battler crowd (Battlegrounds players) who want a single-player
campaign experience. They tolerate the tactics depth if the draft beat is
juicy enough.

### Tertiary

Streamers / content creators — the named-orc-permadeath loop is *naturally*
narrative; the kill-cam-with-name moment is naturally clip-worthy.

### Audience Risk (acknowledged, mitigated)

Designing for the intersection of three sub-genres risks producing a game that
is "almost" for each crowd and bullseye for none. **Mitigation strategy:**

1. The **emotional spine is Battle Brothers** — permadeath named-orc saga. This
   is non-negotiable. If a feature undermines this, it's cut.
2. **Slay the Spire / Battlegrounds / Super Auto Pets are UX/pacing influences**
   — they teach us how to make the saga *accessible*. Faster runs, cleaner
   draft UI, juicy combat readouts.
3. **Validation gates** at month 3-4 (vertical slice) and month 6-8 (public web
   demo) are how we confirm the intersection is real before we commit to the
   back half of production.

---

## 7. MVP Scope — Full 1.0 Target

### 7.1 Scope Inventory

| Category | Quantity Target |
|---|---|
| Grunt archetypes | ~20 |
| Hero archetypes | 5-7 (unlockable across campaigns) |
| Enemy types | ~80 |
| Bosses | 5 |
| Campaign biomes | 4-5 |
| Gear pieces | ~150 (weapons, armor, accessories, banners) |
| Items / consumables | ~40 |
| Traits (positive/negative) | ~60 |
| Music tracks | ~20 |
| Mod support | Light — JSON-data moddability for archetypes, enemies, gear |

### 7.2 Milestone Gates (each is a hard go/no-go)

| Gate | When | Goal | Pass Criteria |
|---|---|---|---|
| **G1 — Vertical Slice** | Month 3-4 | Prove the loop | 1 biome, 5 archetypes, 10 enemies, 1 boss, full Recruit→Battle→Loot cycle works end-to-end. Three internal playtesters complete a run and want to do another. |
| **G2 — Public Web Demo** | Month 6-8 | Prove the audience | 2 biomes, 10 archetypes, 30 enemies, 2 bosses. Public HTML5 release. Telemetry: median session >25min, day-1 retention >35%, qualitative reviews mention "named orcs" emotionally. |
| **G3 — Early Access** | Month 9-12 | Prove the economy | Steam EA + itch.io release. Content at ~70% of 1.0. Real customers pay real money. |
| **G4 — 1.0 Launch** | Month 12-18 | Ship | Full content inventory, mod support, polish, accessibility pass, localization (English + 2-3 priority languages). |

Each gate has its own milestone-review (`/milestone-review`) checkpoint and a
documented rollback plan (descope to next-lower scope tier).

### 7.3 Production Risk Register (initial)

| Risk | Severity | Mitigation |
|---|---|---|
| Solo-dev burnout over 12-18mo | HIGH | Aggressive vertical-slice gate; permission to descope at G1/G2. |
| Audience-intersection miss | MED | Web demo at G2 with real telemetry. |
| 80-enemy content burden | MED | Procedural variants from 20-30 base sprites with palette swaps and trait combos. |
| Auto-battler simulation balance | MED | Heavy unit-test coverage of combat resolver; deterministic seed for replays. |
| Pixel art production at this volume | HIGH | Modular sprite atlas: base body + gear overlays + scar overlays. Designed to scale. |

---

## 8. Open Design Questions

These remain unresolved at the brainstorm stage. They will be resolved during
`/map-systems` and individual GDD authoring with `/design-system`.

1. **Hero revive on death?** Does hero permadeath end the campaign immediately,
   or does the warband have a "carry the body home" mechanic for one chance to
   revive at a shrine? *Default assumption: no revive. Death is death.*
2. **Pre-battle scouting depth.** How much information does the player get
   about the next enemy comp? *Default assumption: archetype names + tier, no
   stats.*
3. **Stat-allocation depth on level-up.** How many stats per orc, how many
   points per level? *Default assumption: 3 stats (Brawn / Cunning / Hide), 2
   points per level.*
4. **Gear rarity / tier system.** Common-Uncommon-Rare-Unique, or a flat
   quality scale? *Default assumption: 4 tiers + Unique (Legend gear).*
5. **Trait stacking & interactions.** Do traits combo (e.g., "Berserker" +
   "Bloodthirsty")? *Default assumption: yes, with a published interaction
   matrix.*
6. **Memorial mechanical effect.** Does visiting the memorial confer any
   morale or buff? *Default assumption: no — Pillar 2 forbids gameplay reward
   for mourning.*
7. **Campaign map structure.** Slay-the-Spire-style branching node graph, or
   open-world hex map? *Default assumption: branching node graph for MVP.*
8. **Day/night cycle or time-of-battle.** Does battle time-of-day affect
   anything? *Default assumption: cosmetic only.*
9. **Multi-language launch scope.** Which languages at G4? *Default
   assumption: EN + DE + ES + ZH-Hans.*
10. **Accessibility floor.** Colorblind modes, text scaling, screen reader.
    *Default assumption: WCAG 2.1 AA minimum, scoped at G3.*

---

## 9. Decisions Log

All locked decisions from the `/brainstorm` flow.

| # | Decision | Date | Phase |
|---|---|---|---|
| D-001 | Genre: auto-battler × tactics-roguelite × squad-builder | 2026-05-14 | Phase 1 |
| D-002 | Engine: Godot 4.6, GDScript, HTML5-first | 2026-05-14 | Phase 1 (per technical-preferences) |
| D-003 | Setting/theme: orc warband, gritty pixel-art, gallows-humor tone | 2026-05-14 | Phase 2 |
| D-004 | Concept synthesis: WARBAND (Battlegrounds draft + Battle Brothers permadeath) | 2026-05-14 | Phase 2 |
| D-005 | Draft phase feel: tense & resource-pressured | 2026-05-14 | Phase 3 |
| D-006 | Death stakes: heavy permadeath always; hero death ends campaign | 2026-05-14 | Phase 3 |
| D-007 | Pillars: Growth Made Flesh · Loss Has Weight · Every Coin a Choice · Watch and Learn | 2026-05-14 | Phase 4 |
| D-008 | Anti-pillars: not real-time micro · not power fantasy · not hero-solo | 2026-05-14 | Phase 4 |
| D-009 | Bullseye audience: hybrid intersection (Battle Brothers ∩ Slay the Spire ∩ Super Auto Pets) | 2026-05-14 | Phase 5 |
| D-010 | Scope target: Full 1.0, 12-18 months, with G1/G2/G3/G4 milestone gates | 2026-05-14 | Phase 6 |

---

## 10. Handoff Notes

This brainstorm document is the **single source of concept truth** until
superseded by formal GDDs.

### Downstream Skills (in recommended order)

1. `/map-systems` — decompose WARBAND into individual systems, prioritize, and
   create `design/gdd/systems-index.md`.
2. `/art-bible` — visual identity, palette, character silhouette rules.
   *Required before any asset production.*
3. `/design-system [system-slug]` — per-system GDDs for the priority systems
   identified by `/map-systems`.
4. `/review-all-gdds` — once the MVP-relevant GDDs exist, run cross-doc
   consistency review.
5. `/create-architecture` — after GDDs are reviewed, produce the master
   architecture doc.
6. `/create-epics` then `/create-stories` — translate GDDs into implementable
   work.

### Required Reference Documents

- This concept doc — `design/concept/warband-game-concept.md`
- Engine reference — `docs/engine-reference/godot/VERSION.md`
- Technical preferences — `.claude/docs/technical-preferences.md`
- Coding standards — `.claude/docs/coding-standards.md`
- Coordination rules — `.claude/docs/coordination-rules.md`

### Sign-off

Concept locked by user, 2026-05-14, during `/brainstorm` Lean-mode session.
Next required action: `/map-systems`.
