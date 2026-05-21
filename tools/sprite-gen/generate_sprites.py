#!/usr/bin/env python3
"""
WARBAND procedural sprite generator.

Generates placeholder pixel sprites for archetypes and enemies following the
art bible §6 silhouette rules and §5 palette. This is the PIPELINE — real
hand-drawn sprites will replace these by overwriting the same paths.

Output: PNG files in assets/chars/ following the naming convention from
the art bible §11:  char_<archetype>_<layer>_<variant>.png

Layers:
  - base: archetype body silhouette, no gear
  - gear_<slot>_<tier>: per-slot gear overlay
  - scar_<N>: progressive scar overlay (0 = none, 3 = veteran)

Requires: Python 3.x + Pillow (PIL).
Install:  pip install Pillow
Run:      python3 tools/sprite-gen/generate_sprites.py
"""

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.stderr.write("ERROR: Pillow not installed. Run: pip install Pillow\n")
    sys.exit(1)


# ============================================================================
# WARBAND palette — anchor swatches from art-bible §5
# ============================================================================
PALETTE = {
    "transparent":  (0, 0, 0, 0),
    "orc_bruise":   (0x2E, 0x1F, 0x14, 255),  # flesh shadow
    "mudtusk":      (0x5C, 0x3A, 0x1E, 255),  # flesh mid
    "greenback":    (0x7A, 0x5C, 0x2E, 255),  # flesh highlight (warm-green)
    "tuskcream":    (0xC2, 0x94, 0x5A, 255),  # tusks, ivory
    "black_iron":   (0x1A, 0x1A, 0x1F, 255),  # dark metal
    "rust_coat":    (0x4A, 0x3C, 0x30, 255),  # common-tier metal
    "cold_edge":    (0x8A, 0x9A, 0xAA, 255),  # blade highlights
    "fell_red":     (0x8B, 0x1A, 0x1A, 255),  # blood, HP
    "spatter":      (0xC0, 0x39, 0x2B, 255),  # fresh blood
    "saddle_brown": (0x6B, 0x42, 0x26, 255),  # leather
    "iron_dawn":    (0x4A, 0x37, 0x28, 255),  # sky horizon
    "crow_blue":    (0x1C, 0x25, 0x35, 255),  # sky high
    "ember":        (0xD4, 0x5F, 0x12, 255),  # fire / unique glow
    "hex_viridian": (0x2E, 0xCC, 0x71, 255),  # magic only
    "warband_gold": (0xC9, 0xA8, 0x4C, 255),  # rare borders, UI accent
    "old_vellum":   (0xD4, 0xB8, 0x96, 255),  # parchment UI
}

# ============================================================================
# Archetype silhouette specs (art-bible §6)
#
# Each archetype is described as a list of (x, y, w, h, color_key) rectangles.
# Coordinates are in source pixels (24x32 for grunts, 32x40 for hero/boss).
# Rectangles are drawn in order, so later ones overlay earlier ones.
# ============================================================================

# Grunt canvas: 24 wide, 32 tall.
# Hero/Boss canvas: 32 wide, 40 tall.

ARCHETYPE_SPRITES = {
    # Chieftain (hero): tall, broad, gold-tinted accent
    "chieftain": {
        "size": (32, 40),
        "rects": [
            # Head (round, brow ridge)
            (10, 4, 12, 8, "mudtusk"),
            (11, 4, 10, 2, "greenback"),  # forehead highlight
            (13, 8, 6, 2, "orc_bruise"),  # brow shadow
            # Tusks
            (12, 9, 1, 2, "tuskcream"),
            (19, 9, 1, 2, "tuskcream"),
            # Eyes
            (13, 7, 2, 1, "fell_red"),
            (17, 7, 2, 1, "fell_red"),
            # Body (torso, broader than grunts)
            (8, 12, 16, 14, "mudtusk"),
            (10, 13, 12, 12, "greenback"),  # chest highlight
            # Arms
            (5, 14, 4, 10, "mudtusk"),
            (23, 14, 4, 10, "mudtusk"),
            # Legs (hunched, forward lean)
            (10, 26, 5, 12, "mudtusk"),
            (17, 26, 5, 12, "mudtusk"),
            # Feet
            (9, 38, 7, 2, "saddle_brown"),
            (16, 38, 7, 2, "saddle_brown"),
            # Banner attachment hint
            (4, 12, 2, 12, "warband_gold"),
        ],
    },
    "berserker": {
        "size": (24, 32),
        "rects": [
            # Head with wild hair crest
            (8, 4, 8, 6, "mudtusk"),
            (8, 1, 8, 4, "orc_bruise"),  # wild hair
            (10, 0, 4, 3, "fell_red"),   # blood-painted hair tip
            (9, 8, 6, 1, "orc_bruise"),  # brow
            # Tusks
            (9, 9, 1, 2, "tuskcream"),
            (14, 9, 1, 2, "tuskcream"),
            # Eyes
            (9, 7, 2, 1, "fell_red"),
            (13, 7, 2, 1, "fell_red"),
            # BARE upper body (no chest gear)
            (8, 10, 8, 10, "mudtusk"),
            (9, 11, 6, 8, "greenback"),
            # Arms (lean, sinewy)
            (5, 11, 3, 9, "mudtusk"),
            (16, 11, 3, 9, "mudtusk"),
            # Legs (forward lean)
            (8, 20, 4, 10, "mudtusk"),
            (12, 20, 4, 10, "mudtusk"),
            # Feet
            (7, 30, 5, 2, "saddle_brown"),
            (12, 30, 5, 2, "saddle_brown"),
        ],
    },
    "brute": {
        "size": (24, 32),
        "rects": [
            # Head (smaller, set low into wide shoulders)
            (9, 6, 6, 6, "mudtusk"),
            (10, 6, 4, 2, "greenback"),
            (10, 10, 4, 1, "orc_bruise"),
            (10, 11, 1, 2, "tuskcream"),
            (13, 11, 1, 2, "tuskcream"),
            (10, 8, 1, 1, "fell_red"),
            (13, 8, 1, 1, "fell_red"),
            # WIDE shoulders (signature)
            (3, 12, 18, 4, "mudtusk"),
            (4, 13, 16, 2, "greenback"),
            # Torso
            (5, 16, 14, 8, "rust_coat"),  # armor look
            (6, 17, 12, 6, "saddle_brown"),
            # Massive arms
            (1, 14, 4, 12, "mudtusk"),
            (19, 14, 4, 12, "mudtusk"),
            # Legs (planted)
            (7, 24, 4, 6, "mudtusk"),
            (13, 24, 4, 6, "mudtusk"),
            # Feet (huge)
            (5, 30, 7, 2, "black_iron"),
            (12, 30, 7, 2, "black_iron"),
        ],
    },
    "archer": {
        "size": (24, 32),
        "rects": [
            # Head (small, alert)
            (10, 3, 5, 6, "mudtusk"),
            (10, 3, 5, 2, "greenback"),
            (11, 8, 3, 1, "orc_bruise"),
            (11, 9, 1, 2, "tuskcream"),
            (13, 9, 1, 2, "tuskcream"),
            (10, 6, 2, 1, "fell_red"),  # focused eyes
            (13, 6, 2, 1, "fell_red"),
            # Lean torso
            (10, 9, 5, 12, "mudtusk"),
            (11, 10, 3, 10, "greenback"),
            # Arms (one extended forward — bow draw)
            (3, 11, 7, 2, "mudtusk"),    # drawn bow arm
            (15, 12, 3, 8, "mudtusk"),
            # Quiver on back
            (16, 9, 3, 8, "saddle_brown"),
            (17, 8, 1, 2, "tuskcream"),  # arrow tip showing
            # Long legs
            (10, 21, 4, 9, "mudtusk"),
            (13, 21, 4, 9, "mudtusk"),
            # Feet
            (9, 30, 5, 2, "saddle_brown"),
            (13, 30, 5, 2, "saddle_brown"),
        ],
    },
    "cleaver": {
        "size": (24, 32),
        "rects": [
            # Head
            (9, 4, 7, 6, "mudtusk"),
            (9, 4, 7, 2, "greenback"),
            (10, 9, 5, 1, "orc_bruise"),
            (10, 10, 1, 2, "tuskcream"),
            (14, 10, 1, 2, "tuskcream"),
            (10, 7, 2, 1, "fell_red"),
            (13, 7, 2, 1, "fell_red"),
            # Apron (butcher motif)
            (8, 11, 9, 12, "old_vellum"),
            (9, 12, 7, 10, "saddle_brown"),
            (10, 14, 5, 2, "fell_red"),  # bloodstain
            # Arms (one raised high)
            (5, 11, 3, 8, "mudtusk"),
            (16, 6, 3, 12, "mudtusk"),   # raised arm
            # Legs
            (9, 23, 4, 7, "mudtusk"),
            (13, 23, 4, 7, "mudtusk"),
            # Feet
            (8, 30, 5, 2, "saddle_brown"),
            (12, 30, 5, 2, "saddle_brown"),
        ],
    },
    "shaman": {
        "size": (24, 32),
        "rects": [
            # Bone-crown above head (signature)
            (9, 0, 7, 2, "tuskcream"),
            (10, 0, 1, 3, "tuskcream"),  # bone spike left
            (13, 0, 1, 3, "tuskcream"),  # bone spike right
            # Head
            (10, 3, 6, 6, "mudtusk"),
            (10, 3, 6, 2, "greenback"),
            (11, 8, 4, 1, "orc_bruise"),
            (11, 9, 1, 2, "tuskcream"),
            (13, 9, 1, 2, "tuskcream"),
            (10, 6, 2, 1, "hex_viridian"),  # magic eyes
            (13, 6, 2, 1, "hex_viridian"),
            # Draped cloth body
            (8, 10, 9, 16, "rust_coat"),
            (9, 11, 7, 14, "saddle_brown"),
            (10, 13, 5, 2, "hex_viridian"),  # ritual sigil
            # Arms
            (5, 11, 3, 10, "mudtusk"),
            (17, 11, 3, 10, "mudtusk"),
            # Cloth hem at feet
            (7, 26, 10, 4, "rust_coat"),
            (8, 30, 8, 2, "saddle_brown"),
        ],
    },
}


# ============================================================================
# Enemy silhouette specs (subset — see ARCHETYPE_SPRITES philosophy)
# ============================================================================

ENEMY_SPRITES = {
    "bandit-thug": {
        "size": (24, 32),
        "rects": [
            (9, 3, 6, 6, "tuskcream"),  # human pale head
            (10, 3, 4, 2, "saddle_brown"),  # dirty hair
            (10, 7, 1, 1, "black_iron"), (13, 7, 1, 1, "black_iron"),  # eyes
            (9, 9, 6, 11, "rust_coat"),  # dirty tunic
            (10, 10, 4, 9, "saddle_brown"),
            (6, 10, 3, 9, "tuskcream"),
            (15, 10, 3, 9, "tuskcream"),
            (10, 20, 3, 10, "black_iron"),  # dark trousers
            (13, 20, 3, 10, "black_iron"),
            (9, 30, 4, 2, "saddle_brown"),
            (13, 30, 4, 2, "saddle_brown"),
        ],
    },
    "bandit-archer": {
        "size": (24, 32),
        "rects": [
            (10, 2, 5, 6, "tuskcream"),
            (10, 6, 1, 1, "black_iron"), (13, 6, 1, 1, "black_iron"),
            (11, 8, 4, 12, "rust_coat"),
            (3, 11, 7, 2, "saddle_brown"),  # bow arm
            (15, 12, 3, 8, "tuskcream"),
            (16, 8, 3, 8, "saddle_brown"),  # quiver
            (11, 20, 3, 10, "black_iron"),
            (13, 20, 3, 10, "black_iron"),
            (10, 30, 4, 2, "saddle_brown"),
            (13, 30, 4, 2, "saddle_brown"),
        ],
    },
    "bandit-captain": {
        "size": (24, 32),
        "rects": [
            (9, 3, 6, 6, "tuskcream"),
            (10, 3, 4, 2, "fell_red"),  # red bandana
            (10, 7, 1, 1, "black_iron"), (13, 7, 1, 1, "black_iron"),
            (8, 9, 8, 12, "black_iron"),  # dark chestplate
            (9, 10, 6, 10, "rust_coat"),
            (10, 12, 4, 2, "warband_gold"),  # captain insignia
            (5, 10, 3, 10, "tuskcream"),
            (16, 10, 3, 10, "tuskcream"),
            (9, 21, 3, 9, "black_iron"),
            (12, 21, 3, 9, "black_iron"),
            (8, 30, 5, 2, "saddle_brown"),
            (11, 30, 5, 2, "saddle_brown"),
        ],
    },
    "farmhand": {
        "size": (24, 32),
        "rects": [
            (10, 4, 5, 6, "tuskcream"),
            (10, 8, 1, 1, "black_iron"), (13, 8, 1, 1, "black_iron"),
            (10, 10, 5, 12, "old_vellum"),  # tunic
            (11, 11, 3, 10, "saddle_brown"),
            (7, 12, 3, 9, "tuskcream"),
            (15, 12, 3, 9, "tuskcream"),
            (10, 22, 3, 8, "saddle_brown"),
            (13, 22, 3, 8, "saddle_brown"),
            (9, 30, 4, 2, "saddle_brown"),
            (13, 30, 4, 2, "saddle_brown"),
        ],
    },
    "village-guard": {
        "size": (24, 32),
        "rects": [
            (9, 3, 6, 6, "tuskcream"),
            (10, 2, 4, 2, "cold_edge"),  # helmet
            (10, 7, 1, 1, "black_iron"), (13, 7, 1, 1, "black_iron"),
            (8, 9, 8, 12, "cold_edge"),  # mail
            (9, 10, 6, 10, "rust_coat"),
            (5, 11, 3, 10, "cold_edge"),
            (16, 11, 3, 10, "cold_edge"),
            (9, 21, 3, 9, "black_iron"),
            (12, 21, 3, 9, "black_iron"),
            (8, 30, 5, 2, "saddle_brown"),
            (11, 30, 5, 2, "saddle_brown"),
        ],
    },
    "hedge-witch": {
        "size": (24, 32),
        "rects": [
            (9, 1, 6, 4, "black_iron"),  # pointed hat
            (10, 0, 4, 2, "black_iron"),
            (10, 5, 4, 4, "tuskcream"),
            (10, 7, 1, 1, "hex_viridian"), (13, 7, 1, 1, "hex_viridian"),
            (8, 9, 9, 16, "black_iron"),  # dark robe
            (9, 10, 7, 14, "saddle_brown"),
            (10, 12, 5, 2, "hex_viridian"),
            (5, 11, 3, 10, "tuskcream"),
            (16, 11, 3, 10, "tuskcream"),
            (7, 25, 10, 5, "black_iron"),
            (8, 30, 8, 2, "saddle_brown"),
        ],
    },
    "mastiff": {
        "size": (24, 32),
        "rects": [
            # Low body, four-legged
            (3, 14, 18, 8, "saddle_brown"),
            (4, 15, 16, 6, "mudtusk"),
            (2, 14, 4, 4, "saddle_brown"),  # head
            (1, 15, 2, 2, "fell_red"),  # eye / collar
            (4, 14, 1, 1, "tuskcream"),  # tooth
            (4, 22, 2, 8, "saddle_brown"),
            (8, 22, 2, 8, "saddle_brown"),
            (14, 22, 2, 8, "saddle_brown"),
            (18, 22, 2, 8, "saddle_brown"),
            (19, 16, 4, 4, "saddle_brown"),  # tail / haunch
        ],
    },
    "hunter": {
        "size": (24, 32),
        "rects": [
            (9, 3, 6, 6, "tuskcream"),
            (9, 2, 6, 2, "saddle_brown"),  # leather cap
            (10, 7, 1, 1, "black_iron"), (13, 7, 1, 1, "black_iron"),
            (9, 9, 6, 12, "saddle_brown"),
            (10, 10, 4, 10, "rust_coat"),
            (3, 11, 7, 2, "saddle_brown"),  # bow arm
            (15, 12, 3, 8, "tuskcream"),
            (16, 8, 3, 8, "saddle_brown"),  # quiver
            (10, 21, 3, 9, "rust_coat"),
            (13, 21, 3, 9, "rust_coat"),
            (9, 30, 4, 2, "saddle_brown"),
            (13, 30, 4, 2, "saddle_brown"),
        ],
    },
    "veteran-mercenary": {
        "size": (24, 32),
        "rects": [
            (9, 3, 6, 6, "tuskcream"),
            (10, 2, 4, 2, "cold_edge"),
            (11, 7, 1, 1, "black_iron"), (13, 7, 1, 1, "black_iron"),
            (10, 4, 2, 1, "fell_red"),  # scar
            (7, 9, 10, 14, "cold_edge"),
            (8, 10, 8, 12, "rust_coat"),
            (9, 13, 6, 2, "warband_gold"),  # campaign medals
            (4, 11, 3, 12, "rust_coat"),
            (17, 11, 3, 12, "rust_coat"),
            (9, 23, 3, 7, "black_iron"),
            (12, 23, 3, 7, "black_iron"),
            (8, 30, 5, 2, "black_iron"),
            (11, 30, 5, 2, "black_iron"),
        ],
    },
    "iron-warden-boss": {
        "size": (32, 40),
        "rects": [
            # Massive head + helmet
            (11, 2, 10, 4, "cold_edge"),  # helmet
            (12, 0, 8, 3, "black_iron"),  # crest
            (12, 6, 8, 6, "tuskcream"),
            (13, 9, 2, 1, "fell_red"), (17, 9, 2, 1, "fell_red"),  # eyes
            # Iron plates body — broader than hero
            (6, 12, 20, 16, "cold_edge"),
            (7, 13, 18, 14, "rust_coat"),
            (8, 15, 16, 2, "warden_or_ember:warband_gold"),  # plate trim — interpreted below
            (10, 17, 12, 2, "ember"),  # glowing forge marks
            # Arms (massive)
            (2, 14, 4, 14, "cold_edge"),
            (26, 14, 4, 14, "cold_edge"),
            # Legs
            (10, 28, 5, 10, "black_iron"),
            (17, 28, 5, 10, "black_iron"),
            # Feet
            (9, 38, 7, 2, "black_iron"),
            (16, 38, 7, 2, "black_iron"),
        ],
    },
}


# ============================================================================
# Gear overlays (additive layers above base body)
# Positioned for grunt 24x32 canvas; hero overlays scale up implicitly.
# ============================================================================

GEAR_OVERLAYS = {
    "weapon_iron-sword-common": {
        "size": (24, 32),
        "rects": [
            (18, 8, 1, 14, "cold_edge"),  # blade
            (17, 22, 3, 2, "saddle_brown"),  # hilt
            (18, 24, 1, 2, "black_iron"),  # pommel
        ],
    },
    "weapon_twohanded-axe-common": {
        "size": (24, 32),
        "rects": [
            (18, 4, 1, 18, "saddle_brown"),  # haft
            (15, 4, 6, 4, "cold_edge"),  # blade
            (16, 5, 4, 2, "rust_coat"),
        ],
    },
    "weapon_short-bow-common": {
        "size": (24, 32),
        "rects": [
            (2, 9, 1, 8, "saddle_brown"),  # bow
            (1, 11, 1, 4, "saddle_brown"),
            (3, 9, 1, 1, "saddle_brown"),
            (3, 16, 1, 1, "saddle_brown"),
            (3, 12, 6, 1, "tuskcream"),  # arrow / string
        ],
    },
    "weapon_club-common": {
        "size": (24, 32),
        "rects": [
            (18, 12, 1, 8, "saddle_brown"),
            (17, 10, 3, 4, "rust_coat"),
            (18, 11, 1, 1, "black_iron"),  # spike
            (17, 9, 1, 1, "black_iron"),
            (19, 9, 1, 1, "black_iron"),
        ],
    },
    "weapon_cleaver-common": {
        "size": (24, 32),
        "rects": [
            (18, 8, 4, 1, "cold_edge"),  # broad blade
            (18, 9, 4, 6, "cold_edge"),
            (17, 15, 3, 2, "saddle_brown"),  # hilt
            (19, 9, 1, 6, "fell_red"),  # blood streak
        ],
    },
    "weapon_bone-staff-common": {
        "size": (24, 32),
        "rects": [
            (3, 4, 1, 18, "tuskcream"),  # bone staff
            (2, 4, 3, 2, "tuskcream"),  # ornament
            (3, 3, 1, 1, "hex_viridian"),  # magic crystal
        ],
    },
    "chest_leather-tunic-common": {
        "size": (24, 32),
        "rects": [
            (8, 10, 8, 12, "saddle_brown"),
            (9, 11, 6, 10, "rust_coat"),
            (10, 12, 4, 1, "warband_gold"),  # stitching
        ],
    },
    "offhand_wooden-shield-common": {
        "size": (24, 32),
        "rects": [
            (4, 12, 4, 10, "saddle_brown"),  # shield
            (5, 13, 2, 8, "rust_coat"),
            (5, 16, 2, 1, "warband_gold"),  # boss
        ],
    },
    "accessory_lucky-charm-common": {
        "size": (24, 32),
        "rects": [
            (11, 18, 2, 2, "warband_gold"),  # tiny charm on belt
        ],
    },
    "accessory_warband-banner-uncommon": {
        "size": (24, 32),
        "rects": [
            (3, 2, 1, 12, "saddle_brown"),  # pole
            (4, 2, 5, 6, "fell_red"),  # banner
            (5, 3, 3, 4, "warband_gold"),  # sigil
        ],
    },
}


# ============================================================================
# Scar overlays (additive damage on body)
# ============================================================================

SCAR_OVERLAYS = {
    "scar_1": {
        "size": (24, 32),
        "rects": [
            (10, 5, 3, 1, "fell_red"),  # cheek cut
        ],
    },
    "scar_2": {
        "size": (24, 32),
        "rects": [
            (10, 5, 3, 1, "fell_red"),
            (9, 7, 1, 1, "black_iron"),  # eye damage
        ],
    },
    "scar_3": {
        "size": (24, 32),
        "rects": [
            (10, 5, 3, 1, "fell_red"),
            (9, 7, 1, 1, "black_iron"),
            (14, 9, 1, 2, "tuskcream"),  # broken tusk replaced bone
            (5, 14, 4, 2, "saddle_brown"),  # arm wrap
        ],
    },
}


# ============================================================================
# Renderer
# ============================================================================

def hex_to_rgba(key: str):
    """Resolve a palette key or special 'or:' fallback to RGBA."""
    if key.startswith("warden_or_ember:"):
        # Fallback handling for shorthand referenced above
        key = key.split(":")[1]
    return PALETTE.get(key, (255, 0, 255, 255))


def render_sprite(spec: dict, out_path: Path) -> None:
    w, h = spec["size"]
    img = Image.new("RGBA", (w, h), PALETTE["transparent"])
    draw = ImageDraw.Draw(img)
    for r in spec["rects"]:
        x, y, rw, rh, color = r
        if x >= w or y >= h:
            continue
        x2 = min(x + rw, w)
        y2 = min(y + rh, h)
        if x2 <= x or y2 <= y:
            continue
        draw.rectangle([(x, y), (x2 - 1, y2 - 1)], fill=hex_to_rgba(color))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path)


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent.parent
    out_root = repo_root / "assets" / "chars"
    enemies_root = repo_root / "assets" / "enemies"
    generated = 0

    # Archetype base bodies
    for arch_id, spec in ARCHETYPE_SPRITES.items():
        out = out_root / f"char_{arch_id}_base_idle.png"
        render_sprite(spec, out)
        generated += 1

    # Enemy sprites
    for enemy_id, spec in ENEMY_SPRITES.items():
        out = enemies_root / f"enemy_{enemy_id}.png"
        render_sprite(spec, out)
        generated += 1

    # Gear overlays
    overlay_root = repo_root / "assets" / "chars" / "gear"
    for gear_key, spec in GEAR_OVERLAYS.items():
        out = overlay_root / f"char_gear_{gear_key}.png"
        render_sprite(spec, out)
        generated += 1

    # Scar overlays
    scar_root = repo_root / "assets" / "chars" / "scars"
    for scar_id, spec in SCAR_OVERLAYS.items():
        out = scar_root / f"char_{scar_id}.png"
        render_sprite(spec, out)
        generated += 1

    print(f"Generated {generated} sprites under {repo_root / 'assets'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
