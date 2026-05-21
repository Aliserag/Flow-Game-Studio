# ADR-004 — Modular Sprite Atlas: Body + Scar + Gear Overlays

**Status:** Accepted
**Date:** 2026-05-14
**Authors:** Orchestrator (autonomous build)

## Context

The art bible's Pillar SP-1 (Growth Made Flesh) requires every orc's sprite
to visually encode current state: gear tier, scar count, renown. The concept
doc's scope plan calls for 20 grunt archetypes × 150 gear pieces × ~16 scar
variants — naively, that's 48,000 unique sprite combinations. That's not
producible by any team, indie or AAA.

The art bible §6 specifies a modular three-layer atlas as the
production contract. We need to operationalize it in code.

## Decision

**Sprites are composited at runtime from three independent layers:**

1. **Base body** (per archetype): `assets/chars/char_<archetype>_base_idle.png`
   — silhouette + flesh + non-gear features (tusks, eyes, hair). ~20 sprites
   for the full archetype set.

2. **Scar overlay** (per scar level): `assets/chars/scars/char_scar_<N>.png`
   where N ∈ {1, 2, 3}. Cumulative — N=3 includes the visuals of N=1 and N=2.
   ~3 sprites cover the full scar progression.

3. **Gear overlays** (per slot per gear piece):
   `assets/chars/gear/char_gear_<slot>_<gear_id>.png`. One per piece. ~150
   sprites for the full gear library.

**Compositing** (`src/gameplay/sprite_composer.gd`):
- Loaded in order: base → scar → gear (slot z-order: chest, offhand,
  accessory, weapon, head).
- Alpha-blended on the CPU via `Image.set_pixel`. Result wrapped in
  `ImageTexture` for the UI.
- Cached per-orc via key `orc:<archetype>:scars=<N>:slot=gear,...`.
- Cache invalidated on gear change via `SpriteComposer.invalidate(orc)`.

**Sprite content** (G1): generated procedurally by
`tools/sprite-gen/generate_sprites.py` from rectangle specs following the
art-bible §6 silhouettes and §5 palette. Hand-drawn replacements drop
straight into the same paths.

## Consequences

**Positive:**
- Storage cost: ~173 sprites instead of 48,000.
- Adding a new gear piece adds 1 sprite, not 20 (one per archetype).
- The "Growth Made Flesh" pillar is mechanically testable: invalidate the
  cache and verify the resulting texture's pixel count changes when gear
  is equipped.
- Real hand-drawn art replaces procedural art with zero code changes —
  same paths, same compositing.

**Negative:**
- Composite cost: ~24×32 pixels × 3-5 layers = ~3000 pixel reads per orc.
  Acceptable for once-per-equip-change. Would NOT be acceptable per frame —
  the cache prevents that.
- Z-order between slots is hardcoded. If a future archetype needs a
  different layering (e.g., shaman cloak draped over chest armor), we'd
  need per-archetype slot order rules.
- The procedural generator is a stand-in. Real art quality is gated on
  artist availability, not pipeline capability.

## Validation

`tools/sprite-gen/generate_sprites.py` produces 29 sprites including 6
archetype bodies, 10 enemies, 10 gear overlays, 3 scar overlays. The
`SpriteComposer` is exercised by `BattleScreen` which renders every
combatant via the composite path.

Manual visual verification: the produced sprites adhere to the silhouette
rules (Berserker bare-chested forward-leaning, Brute wide-shouldered low-set
head, Archer tall-lean with quiver, Shaman bone-crowned, etc.).
