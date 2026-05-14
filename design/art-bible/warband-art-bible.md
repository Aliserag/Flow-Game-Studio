# WARBAND — Art Bible

**Version:** 1.0 (LOCKED under autonomous orchestration)
**Date:** 2026-05-14
**Author:** Art Director
**Status:** Locked for G0 production. Open Questions resolved per recommendations.

> This document is the visual source of truth for WARBAND. No asset production
> begins without this document being at v1.0-APPROVED. All downstream agents are
> bound by the choices defined here.

---

## 1. Vision Statement

WARBAND is the last campfire before the raid. Visually, it is gritty pixel-art
rendered in a constrained, mud-and-rust palette where every orc looks like it
has survived at least one bad night — and the ones who have survived three look
unmistakably different from the ones who haven't. The game's visual identity is
built on the contract between player and pixel: **progression must be legible
on the body, loss must leave a mark, and the battlefield must be readable at a
glance.** Portraits are expressive caricatures, not polished heroes; the world
is cold, the skies are the wrong shade of orange, and nothing glows unless it
is on fire or about to kill someone. The unmistakable identity: Battle Brothers'
raw permanence, drawn in the pixel-art shorthand of Slay the Spire's cards,
with Darkest Dungeon's willingness to make things ugly.

---

## 2. Tonal Anchors

| Reference | What We Take | What We Leave |
|---|---|---|
| **Battle Brothers** | Muted iron-and-mud palette, gear differentiation by silhouette, grimy parchment UI texture, portraits where damage shows as missing teeth and eye patches | Static head-portrait-only art style; we add full side-on body sprites with modular overlays |
| **Slay the Spire** | Card-frame clarity, high-contrast floating combat text, UI that treats information as art, readable archetypes at thumbnail size | Blue-dungeon saturation and sci-fi/fantasy hybrid palette. Our world is warmer and dirtier. |
| **Darkest Dungeon** | Grim caricature expressiveness, visual ugliness as storytelling tool, UI panel framing a roster of doomed faces | Painterly hand-drawn line art (too expensive, wrong scale), purple-hellscape palette, stress meters as gameplay |
| **Hades (portraits only)** | High-contrast ink-style portraits with strong jaw/brow reads, expressive eyebrows that survive small sizes | Greek art-deco gold filigree, saturated divine palette, particle density. We are not divine. |
| **Mordheim: City of the Damned (concept art)** | Tactile metal/leather texture language, warbands that look assembled rather than designed, trophy-laden veterans | 3D realisation; we reinterpret in 2D pixel shorthand |

---

## 3. Style Pillars

**SP-1 — Growth Made Flesh**
Every orc's sprite must visually encode current state: gear tier, scar count,
renown level. A Tier-1 grunt and a Tier-3 veteran must be distinguishable at
32px height without reading any text.
*Test:* Cover all UI text. Can a tester rank every orc by experience from
silhouette alone? If no, art has failed SP-1.

**SP-2 — Silhouette Primacy**
Every archetype has a unique silhouette that survives reduction to 32x32 and
cannot be confused with an adjacent archetype. Silhouette is defined by head
shape, weapon profile, and stance — not by color.
*Test:* Convert the sheet to pure black. Every archetype must be named
correctly by a blind tester at 32px.

**SP-3 — Controlled Chaos**
Mid-battle 10-20 sprites move simultaneously. The screen must never become
unreadable. Player warband (bottom) must be distinguishable from enemy warband
(top) without relying solely on screen position.
*Test:* Screenshot the most chaotic mid-battle frame. A tester must identify
the winning side within 5 seconds.

**SP-4 — Scarcity Is Beautiful**
The world does not glow, shimmer, or saturate without narrative justification.
Rare gear earns visual weight by contrast with deliberate drabness. Magic
effects are earned punctuation, not ambient noise.
*Test:* Count high-chroma pixels in any baseline battle frame. >15% of screen
area at high chroma (excluding UI) fails SP-4.

---

## 4. Resolution & Pixel-Art Spec

**Base canvas:** 480x270 (16:9, native pixel-perfect). Scaled to 1440x810 on
desktop. HTML5 canvas scales responsively with nearest-neighbor. Bilinear
filtering NEVER applied to game sprites.

**Character sprites:**
- Base body: 24x32 (grunts), 32x40 (hero, bosses)
- Display: 2-3x scale (48x64 to 72x96 on 1080p browser)
- Minimum legible: 32px height

**Portraits:**
- Full: 48x64 source, displayed 3x (144x192)
- Thumbnail: 16x16

**Tiles/environment:** 16x16 base tile. Parallax strips: no grid constraint.

**Scaling policy:**
- Godot: `stretch_mode = canvas_items`, `stretch_aspect = keep`
- Integer pixel snapping for game/character layers
- UI layer may use sub-pixel for text rendering only
- No runtime rotation/scale at non-integer multiples except VFX (<0.5s)

---

## 5. Color Palette — 48 Colors, 8 Families

Hard cap: adding a color requires removing one. Philosophy: desaturated
iron-cold mid-tones as foundation; warm amber and bloodfire as accent. Magic
earns three or four colors as the only fully-saturated hue family.

### Key Anchor Swatches (16)

| Role | Name | Hex | Usage |
|---|---|---|---|
| Flesh shadow | Orc Bruise | `#2E1F14` | Deep skin shadow, baseline dermis |
| Flesh mid | Mudtusk | `#5C3A1E` | Standard orc skin |
| Flesh highlight | Greenback | `#7A5C2E` | Warm-green undertone |
| Flesh bright | Tuskcream | `#C2945A` | Tusks, teeth, pale enemy skin |
| Metal dark | Black Iron | `#1A1A1F` | Dark armor, blade shadow |
| Metal mid | Rust Coat | `#4A3C30` | Common gear, weathered iron |
| Metal bright | Cold Edge | `#8A9AAA` | Blade highlights, Rare+ metal |
| Blood | Fell Red | `#8B1A1A` | Blood decals, HP bars, death |
| Blood bright | Spatter | `#C0392B` | Fresh blood VFX, kill flash |
| Leather | Saddle Brown | `#6B4226` | Armor straps, pouches |
| Sky dawn | Iron Dawn | `#4A3728` | Default battle sky horizon |
| Sky high | Crow Blue | `#1C2535` | Upper sky, all biomes |
| Fire | Ember | `#D45F12` | Torchlight, fire VFX, Unique glow |
| Magic | Hex Viridian | `#2ECC71` | Magic effects ONLY |
| UI Gold | Warband Gold | `#C9A84C` | Gold cost, XP, Rare borders |
| UI Parchment | Old Vellum | `#D4B896` | Tavern cards, text panels |

### Family Distribution (48 total)
- Flesh/skin: 6 colors
- Metal: 7 colors
- Leather/cloth: 6 colors
- Blood/wound: 4 colors
- Sky/environment: 8 colors (4 biome tints)
- Fire/light: 5 colors
- Magic: 4 colors (strictly rationed)
- UI chrome: 8 colors

---

## 6. Character Silhouette Rules

### Orc Read-At-A-Glance
Short neck, wide jaw, protruding lower jaw with visible tusk tips (even at
24px), heavy brow ridge, hunched forward-lean idle stance. Small cocked-back
ears (NOT pointed-elf). Orcs are shorter and wider than human enemies at the
same tier.

### Archetype Silhouettes (must survive 32px)

| Archetype | Silhouette Signature | Weapon Profile |
|---|---|---|
| Berserker | Bare upper body, wild hair crest, leaning forward | Two-handed axe wider than shoulders |
| Archer | Taller, leaner, quiver protrusion at back shoulder | Bow drawn (arm extended) |
| Brute | Widest shoulder profile (+30% over base) | Shield left, club/maul right |
| Cleaver | Medium build, one hand raised high at rest | Single cleaver angled upward |
| Shaman | Bone-ornament crown above head, draped cloth hem | Staff with top ornament |
| Pikeman | Longest vertical silhouette (pole exceeds head) | Pole weapon above head height |

### Modular Sprite Atlas — Production Contract

**Three-layer composite system (HARD STRUCTURAL REQUIREMENT):**

1. **Base body layer** — archetype body, idle pose, no gear. ~20 grunt
   archetypes = 20 base sprites. Defines pose + silhouette.
2. **Gear overlay layer** — per slot: head, chest, weapon, off-hand, back
   (quiver/banner/trophy). ~150 gear pieces in a shared atlas. Position via
   anchor points relative to base body.
3. **Scar/wound overlay layer** — additive overlays: cuts, bruises,
   missing-tooth mouth, eye-patch, wrapped arm. NEVER cleared. ~12-20 variants
   per archetype.

**Math:** 20 archetypes × 150 gear = 3000 combinations. With overlays: 20 base
+ 150 gear + 20 scar-sets = ~190 source sprites. This is the only feasible path
to scope.

**Atlas layout:** Per-archetype gear atlas (Godot AtlasTexture). Shared
base-body atlas. Shared scar atlas. Composite at draw time via Z-order — no
CPU blending.

---

## 7. Gear & Progression Visuals

### Tier Visual Vocabulary

| Tier | Visual Language |
|---|---|
| **Common** | Raw iron, crude stitching, no embellishment. Rust Coat palette. No sheen. |
| **Uncommon** | Leather reinforcement, even metal color (no rust), Cold Edge highlights on blade tips. One Saddle Brown accent stitch. |
| **Rare** | Clean metalwork, geometric inlay, thin Warband Gold border on armor edges. Blade has 2-3px highlight line. |
| **Unique / Legend** | Named item. Distinctive silhouette addition. Faint Ember 1px ambient rim. Illustrated name-card in inspect UI. |

Rule: **No tier-jumping visual language.** Common must not accidentally read as Rare.

### Scar Accumulation
- Battle 1-3: minor cuts, no permanent overlays
- Battle 4-7: scar overlay 1 (cheek cut or arm wrap)
- Battle 8-14: scar overlay 2 (eye damage or broken tusk)
- Battle 15+: full veteran scar set + "grizzled" recolor on portrait

**Scars are added, never removed.** Healing does not remove scars (Pillar 2).

### Renown Expression
1. **Banner:** back-attachment slot. Earns heraldry icons at milestones.
2. **Warpaint:** face-overlay layer (distinct from scars). Meta-progression cosmetic unlock.
3. **Trophy rack:** rare enemy drops on belt slot. Dedicated z-layer.

---

## 8. Environment & Battlefield

### Side-On Framing
- **Sky band** (top 40%): parallax layers 2 + 3
- **Ground band** (mid 35%): layer 1, terrain, unit feet-anchors
- **Foreground fringe** (bottom 25%): layer 0

Back-row ranged units sit 2-3px higher on Y to avoid front-row overlap.

### Parallax Scroll Rates
- Layer 3 (sky): 0.05x
- Layer 2 (distant terrain): 0.25x
- Layer 1 (midground): 0.6x
- Layer 0 (fringe): 1.0x

### Biome Differentiation

| Biome | Sky Palette | Ground | Signature | Mood |
|---|---|---|---|---|
| Farm/Village | Iron Dawn + warm amber smear | Dry brown + green field strip | Hay bale, fence post | Exposed, daylit dread |
| Clan Territory | Crow Blue + flat grey | Rocky pale, sparse brush | Cairn stones, clan banner BG | Cold, territorial |
| Warchief Stronghold | Dark Crow Blue + fire-lit | Dark flagstone, torchlit | Fortress arch, flame sconces | Imposing, orange-lit |
| Northern Crags | Near-black + snow light | Blue-white stone, ice cracks | Rock spire, wind particle | Hostile, endgame dread |

Unit palettes do NOT shift per biome — readability preserved.

### Team Read Mid-Battle
- Player bottom-third Y, enemy upper-third Y, collision in center
- Player units: 1px desaturated warm-tone rim on left side
- Enemy units: 1px cool-tone rim on right side
- Floating text: white with 1px black shadow. No color-coded damage (colorblind-safe).

---

## 9. VFX & Animation Direction

### Animation Philosophy
**Economy of motion.** Every frame communicates. Browser memory is the budget.

**Frame budget per state:**
- Idle: 4 frames
- Walk/advance: 6 frames
- Attack swing: 4 frames (windup-contact-follow-return)
- Hit reaction: 2 frames (snap back, snap forward)
- Death: 6 frames (the most important animation in the game)
- Victory (hero only): 4 frames

### Hit Reaction
Hard snap-back 2px on hit. Screen shake: 3px / 6f normal; 6px / 10f crits/kills.
**No additive shake stacking** — largest simultaneous event only.

### Death Animation Contract
Plays at **0.75x speed** (deliberate slow). Steps:
1. Stagger back 1 step
2. Weapon drops (detached sprite, gravity arc)
3. Collapse to ground
4. Dust mote particles (4-8 max)
5. Grayscale overlay fades in over orc sprite (2f fade)
6. After battle resolves: 12-frame dissolve, gravestone shake plays in UI

### Blood Policy
**Moderate and purposeful.** 2-4px splatter decal on struck unit on hit. Kill
blow: 6-8px splatter. Fade over 1s (12f). Fell Red + Spatter only. No pools.
No spray beyond unit boundary. **Grim, not gratuitous.**

### Particle Budget
**Hard cap: 24 simultaneous particles** across all sources.
Reserved for: death dust, blood splatter, fire VFX, kill-banner trail.
No ambient environment particles.

---

## 10. UI Visual Identity

### Design Language
**Worn parchment and black iron.** Panels: Old Vellum with dark-stained wood
or cold iron border. No rounded corners. Warband Gold as accent on
interactive elements only.

### Tavern Card Frame
- Portrait: top 55%
- Name (stamped serif) below portrait
- Archetype icon + trait list: bottom 45%
- Border: worn wood with iron nail-head corners
- Hire price: Warband Gold on torn parchment ribbon, bottom-right
- Cards face up; passed card: 3-frame card-flip off-screen

### Combat Toasts (Kill-Cam)
On killing blow:
- Format: **[KILLER] fells [TARGET]**
- Black bg, white all-caps serif text
- 0.4s fade in / 0.6s hold / 0.3s fade out
- Killed name in Fell Red with Fell Red underline
- Fires for player kills AND player deaths equally (Pillar 2)

### Gravestone / Memorial Wall
- Each stone: 16x16 thumbnail portrait in greyscale on carved stone silhouette
- Hover/click opens eulogy panel
- Eulogy: Old Vellum bg, stamped header with name + dates, body recaps
  battles/kills/cause of death
- Body text: slab-serif/monospace (see typography)

### Typography (LOCKED per art-director recommendation)

- **Headers / orc names:** **Cinzel** (Roman gravitas, open license). Fallback: Georgia, serif.
- **UI body / tooltips:** **Courier Prime** (military-log feel). Fallback: Courier New, monospace.
- **Combat floating text:** Pixel-font sprite (8x8 at 2x scale). Only font that ships as sprite asset.

All text passes WCAG 2.1 AA contrast (4.5:1 minimum).

---

## 11. Asset Pipeline & Modularity

### Path Convention
```
assets/
  chars/        # Character sprite atlases (base, gear overlays, scars)
  env/          # Environment tiles and parallax strips
  ui/           # UI elements, frames, icons
  vfx/          # Particle sprites, hit-flash, blood decals
  fonts/        # Bitmap/pixel fonts (system fonts loaded at runtime)
  portraits/    # Full portrait sprites (tavern, eulogy, roster)
  fx/           # Screen-space effects (shake, overlay fades)
```

### Naming Convention
`[category]_[name]_[variant]_[size].[ext]`

Examples:
- `char_berserker_base_idle.png`
- `char_berserker_gear_chest_rare.png`
- `char_berserker_scar_02.png`
- `env_farmland_bg_layer2.png`
- `ui_card_tavern_frame.png`
- `vfx_blood_splatter_small.png`
- `portrait_grunt_archer_default.png`

### Atlas Policy
- One body atlas per archetype (all animation frames)
- One shared gear atlas per category
- **Target: ≤ 40 texture atlases total**
- **Max single atlas: 512x512** (GLES3 HTML5 compatibility)

### Palette Swap for Enemy Variants
20-30 base enemy sprites + per-sprite palette remap JSON sidecar. Custom
shader handles swap at GPU. Delegated to `godot-shader-specialist`.

### Export Format
PNG, indexed color where possible, sRGB profile. No JPEG. No embedded ICC.
Godot import: `Texture2D` with `filter: nearest`.

---

## 12. Accessibility Visual Floor

### Colorblind Safety
Fell Red (death) and Hex Viridian (magic) fail deuteranopia/protanopia without mitigation. Required:

1. Death/damage uses BOTH Fell Red AND a skull marker icon on HP bars
2. Magic VFX uses BOTH Hex Viridian AND a distinct shape (star/hex vs blood-circle)
3. "High contrast UI" toggle at G3: yellow/blue accent pair, safe for all common colorblindness

### Contrast Targets
- UI text: 4.5:1 minimum (WCAG 2.1 AA)
- Interactive borders: 3:1 minimum
- HP bars: text label always present

### Scaling
- Godot canvas stretch fills browser viewport
- Min viewport: 640x360
- Font floor: 8px rendered (16px on 2x display) for non-combat text
- Combat floating text: 12px rendered minimum

---

## 13. Out of Scope

| Excluded | Reason |
|---|---|
| 3D rendering | 2D pixel-art only, always |
| Hand-painted / painterly | Pixel-art exclusively |
| Cinematic cutscenes | Story via portrait + text |
| Real-time lighting / dynamic shadows | Pre-baked lit sprites only |
| Motion-capture / rotoscope | Hand-keyed pixel animation |
| Full voice acting | Short grunts only; no dialogue VO |
| Animated background environments | Static parallax strips |
| Per-orc unique full sprites | Modular atlas mandatory |

---

## 14. Locked Decisions (Art-Director Recommendations Adopted)

| OQ | Resolution | Rationale |
|---|---|---|
| OQ-1 (palette saturation) | **Desaturated foundation locked** | Makes magic and rare gear pop harder by contrast |
| OQ-2 (blood policy) | **Moderate, purposeful** | Grim weight lives in narrative, not gore. Avoids storefront age-rating risk. |
| OQ-3 (fonts) | **Cinzel + Courier Prime** | Military-ledger feel. Both open license. HTML5-safe with fallbacks. |
| OQ-4 (portrait resolution) | **48x64px pixel-caricature** | Holds modular scope. Expressiveness, not resolution. |
| OQ-5 (warpaint) | **Meta-progression cosmetic** | Earned across campaigns, signals veteran-status meta achievement |

All five locked under autonomous mandate. Revisit at G1+ if desired.
