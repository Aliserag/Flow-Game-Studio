#!/usr/bin/env python3
"""
Build the WARBAND 48-color palette PNG from the art-bible §5 hex anchors.

The palette PNG is consumed by:
  - pixellab generate_image_pixflux(color_image=...) for palette enforcement
  - tools/sprite-gen/quantize_to_palette.py for post-process snap-to-palette

Output: data/palettes/warband_palette.png (48 pixels arranged 8x6)
"""

from pathlib import Path
import sys

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("ERROR: Pillow not installed. Run: pip install Pillow\n")
    sys.exit(1)


# Art-bible §5 anchor colors plus extrapolated family members to fill 48 slots.
# Order: flesh (6) | metal (7) | leather/cloth (6) | blood (4) | sky/env (8) |
#        fire (5) | magic (4) | UI chrome (8) = 48 total.
PALETTE_HEX = [
    # Flesh / skin (6)
    "#2E1F14", "#5C3A1E", "#7A5C2E", "#C2945A", "#8A6B3D", "#D9C8A8",
    # Metal (7)
    "#1A1A1F", "#4A3C30", "#8A9AAA", "#3A3A45", "#5A5A65", "#9AAAB5", "#C5D5E0",
    # Leather / cloth (6)
    "#6B4226", "#3A2818", "#8A5836", "#A86E48", "#D4B896", "#B8A480",
    # Blood / wound (4)
    "#8B1A1A", "#C0392B", "#5E1010", "#3A0808",
    # Sky / environment (8)
    "#4A3728", "#1C2535", "#0E1118", "#3E4858", "#6A7480", "#8A8A6A", "#4A5A3A", "#2E3826",
    # Fire / light (5)
    "#D45F12", "#F0A828", "#E03020", "#FFE0A0", "#FFF8D8",
    # Magic (4) — strictly rationed per SP-4
    "#2ECC71", "#5EE090", "#A8F0C0", "#1E9050",
    # UI chrome (8)
    "#C9A84C", "#A88A30", "#E0BC60", "#3A2818", "#6A5040", "#FFFFFF", "#999999", "#333333",
]


def hex_to_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent.parent
    out = repo_root / "data" / "palettes" / "warband_palette.png"
    out.parent.mkdir(parents=True, exist_ok=True)

    # Build 8x6 grid PNG (one swatch per pixel) for use as PIL palette source
    img = Image.new("RGB", (8, 6))
    pixels = img.load()
    for i, h in enumerate(PALETTE_HEX):
        if i >= 48:
            break
        x = i % 8
        y = i // 8
        pixels[x, y] = hex_to_rgb(h)
    img.save(out)

    # Also write a human-viewable larger version (scaled 16x for inspection)
    big = img.resize((128, 96), Image.NEAREST)
    big.save(out.with_name("warband_palette_view.png"))

    print(f"Wrote {out} ({len(PALETTE_HEX)} colors)")
    print(f"Wrote {out.with_name('warband_palette_view.png')} (16x scaled preview)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
