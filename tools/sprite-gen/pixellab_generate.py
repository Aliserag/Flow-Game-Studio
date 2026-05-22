#!/usr/bin/env python3
"""
WARBAND sprite generator using the PixelLab API.

This is the GROUND-TRUTH sprite generator for WARBAND. It uses the official
`pixellab` Python client (https://pypi.org/project/pixellab/) and calls the
PixFlux model with WARBAND-specific prompts (see prompts.py) and the locked
48-color palette (data/palettes/warband_palette.png).

Usage:
    # Generate all 6 archetype base bodies:
    python3 tools/sprite-gen/pixellab_generate.py --archetypes

    # Generate all 10 enemies:
    python3 tools/sprite-gen/pixellab_generate.py --enemies

    # Generate one archetype:
    python3 tools/sprite-gen/pixellab_generate.py --archetype berserker

    # Generate gear overlay (requires --base-from existing base body):
    python3 tools/sprite-gen/pixellab_generate.py \\
        --gear weapon_twohanded-axe-common --base-from assets/chars/char_berserker_base_idle.png

    # Generate everything:
    python3 tools/sprite-gen/pixellab_generate.py --all

    # Dry-run (prints what would be generated without API calls):
    python3 tools/sprite-gen/pixellab_generate.py --all --dry-run

Setup:
    1. pip install pixellab Pillow python-dotenv
    2. Ensure .env.local has PIXELLAB_API_KEY=<your_key>
    3. Sandbox note: this script needs outbound HTTPS to api.pixellab.ai.
       The Claude Code web sandbox blocks this. Run from your local machine.

Output: assets/chars/, assets/enemies/, assets/chars/gear/, assets/chars/scars/

Determinism: seeds are set per-archetype via the SEED_BASE constant so the
same script run twice produces identical sprites. Adjust SEED_OFFSETS in
prompts.py if you want a different starting point.
"""

import argparse
import base64
import io
import os
import sys
from pathlib import Path

# Ensure the repo root is on sys.path so we can import prompts
sys.path.insert(0, str(Path(__file__).resolve().parent))

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("ERROR: Pillow not installed. Run: pip install Pillow\n")
    sys.exit(1)

try:
    import pixellab
except ImportError:
    sys.stderr.write("ERROR: pixellab not installed. Run: pip install pixellab\n")
    sys.exit(1)

import prompts


# --- Config ---
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
ENV_FILE = REPO_ROOT / ".env.local"
PALETTE_PATH = REPO_ROOT / "data" / "palettes" / "warband_palette.png"

GRUNT_SIZE = {"width": 24, "height": 32}
HERO_SIZE = {"width": 32, "height": 40}
BOSS_SIZE = {"width": 32, "height": 40}

SEED_BASE = 42_000

# Heroes (32x40), other archetypes (24x32)
HERO_ARCHETYPES = {"chieftain"}
BOSS_ENEMIES = {"iron-warden-boss"}


# --- Helpers ---

def load_env(env_file: Path) -> dict:
    """Tiny .env parser so we don't require python-dotenv."""
    out = {}
    if not env_file.exists():
        return out
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def get_api_key() -> str:
    env = load_env(ENV_FILE)
    key = os.environ.get("PIXELLAB_API_KEY") or env.get("PIXELLAB_API_KEY")
    if not key:
        sys.stderr.write(
            "ERROR: PIXELLAB_API_KEY not found. Set in .env.local or env.\n"
        )
        sys.exit(2)
    return key


def load_palette_image() -> Image.Image:
    if not PALETTE_PATH.exists():
        sys.stderr.write(
            f"ERROR: palette not found at {PALETTE_PATH}\n"
            "Run: python3 tools/sprite-gen/build_palette.py\n"
        )
        sys.exit(2)
    return Image.open(PALETTE_PATH).convert("RGB")


def archetype_size(archetype_id: str) -> dict:
    return HERO_SIZE if archetype_id in HERO_ARCHETYPES else GRUNT_SIZE


def enemy_size(enemy_id: str) -> dict:
    return BOSS_SIZE if enemy_id in BOSS_ENEMIES else GRUNT_SIZE


def decode_base64_image(b64: str) -> Image.Image:
    """The pixellab Base64Image type wraps a base64 PNG string."""
    raw = base64.b64decode(b64)
    return Image.open(io.BytesIO(raw))


def save_image(img: Image.Image, out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    # Convert to RGBA for transparent backgrounds
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    img.save(out_path)


# --- Generators ---

def generate_archetype(
    client: pixellab.Client, palette_img: Image.Image, archetype_id: str, dry_run: bool
) -> Path:
    prompt = prompts.archetype_prompt(archetype_id)
    size = archetype_size(archetype_id)
    out_path = REPO_ROOT / "assets" / "chars" / f"char_{archetype_id}_base_idle.png"
    print(f"[ARCHETYPE] {archetype_id}  size={size}  out={out_path.relative_to(REPO_ROOT)}")
    if dry_run:
        return out_path
    seed = SEED_BASE + abs(hash(archetype_id)) % 10_000
    resp = client.generate_image_pixflux(
        description=prompt["description"],
        negative_description=prompt["negative_description"],
        image_size=size,
        text_guidance_scale=10.0,
        no_background=True,
        color_image=palette_img,
        view="side",
        direction="east",
        seed=seed,
    )
    img = decode_base64_image(resp.image.base64)
    save_image(img, out_path)
    print(f"   saved ({out_path.stat().st_size} bytes)")
    return out_path


def generate_enemy(
    client: pixellab.Client, palette_img: Image.Image, enemy_id: str, dry_run: bool
) -> Path:
    prompt = prompts.enemy_prompt(enemy_id)
    size = enemy_size(enemy_id)
    out_path = REPO_ROOT / "assets" / "enemies" / f"enemy_{enemy_id}.png"
    print(f"[ENEMY]    {enemy_id}  size={size}  out={out_path.relative_to(REPO_ROOT)}")
    if dry_run:
        return out_path
    seed = SEED_BASE + abs(hash("enemy:" + enemy_id)) % 10_000
    resp = client.generate_image_pixflux(
        description=prompt["description"],
        negative_description=prompt["negative_description"],
        image_size=size,
        text_guidance_scale=10.0,
        no_background=True,
        color_image=palette_img,
        view="side",
        direction="west",
        seed=seed,
    )
    img = decode_base64_image(resp.image.base64)
    save_image(img, out_path)
    print(f"   saved ({out_path.stat().st_size} bytes)")
    return out_path


def generate_gear_overlay(
    client: pixellab.Client,
    palette_img: Image.Image,
    gear_key: str,
    base_image_path: Path,
    dry_run: bool,
) -> Path:
    description = prompts.gear_prompt(gear_key)
    out_path = REPO_ROOT / "assets" / "chars" / "gear" / f"char_gear_{gear_key}.png"
    print(f"[GEAR]     {gear_key}  base={base_image_path.name}  out={out_path.relative_to(REPO_ROOT)}")
    if dry_run:
        return out_path
    base_img = Image.open(base_image_path).convert("RGBA")
    size = {"width": base_img.width, "height": base_img.height}
    seed = SEED_BASE + abs(hash("gear:" + gear_key)) % 10_000
    # Use init_image conditioning to keep pose & alignment locked to the base body.
    resp = client.generate_image_pixflux(
        description=description + ", same exact pose as reference, transparent background",
        negative_description="anti-aliasing, smooth gradient, body changes, new pose",
        image_size=size,
        text_guidance_scale=8.0,
        no_background=True,
        color_image=palette_img,
        init_image=base_img,
        init_image_strength=600,
        seed=seed,
    )
    img = decode_base64_image(resp.image.base64)
    save_image(img, out_path)
    print(f"   saved ({out_path.stat().st_size} bytes)")
    return out_path


def cmd_archetypes(client, palette_img, dry_run: bool) -> None:
    for archetype_id in prompts.ARCHETYPE_PROMPTS.keys():
        generate_archetype(client, palette_img, archetype_id, dry_run)


def cmd_enemies(client, palette_img, dry_run: bool) -> None:
    for enemy_id in prompts.ENEMY_PROMPTS.keys():
        generate_enemy(client, palette_img, enemy_id, dry_run)


def cmd_gear(client, palette_img, base_from: Path, dry_run: bool) -> None:
    for gear_key in prompts.GEAR_OVERLAY_PROMPTS.keys():
        generate_gear_overlay(client, palette_img, gear_key, base_from, dry_run)


def cmd_all(client, palette_img, dry_run: bool) -> None:
    cmd_archetypes(client, palette_img, dry_run)
    cmd_enemies(client, palette_img, dry_run)
    # Default base for gear overlays = berserker (most generic torso)
    base = REPO_ROOT / "assets" / "chars" / "char_berserker_base_idle.png"
    if base.exists() or dry_run:
        cmd_gear(client, palette_img, base, dry_run)
    else:
        print("[WARN] No berserker base found; run --archetypes first")


def main() -> int:
    parser = argparse.ArgumentParser(description="WARBAND PixelLab sprite generator")
    parser.add_argument("--all", action="store_true", help="Generate everything")
    parser.add_argument("--archetypes", action="store_true", help="Generate all archetypes")
    parser.add_argument("--archetype", type=str, help="Generate single archetype by id")
    parser.add_argument("--enemies", action="store_true", help="Generate all enemies")
    parser.add_argument("--enemy", type=str, help="Generate single enemy by id")
    parser.add_argument("--gear", type=str, help="Generate single gear overlay")
    parser.add_argument(
        "--base-from", type=str, help="Base body PNG path for gear overlay conditioning"
    )
    parser.add_argument("--all-gear", action="store_true", help="Generate all gear overlays")
    parser.add_argument(
        "--dry-run", action="store_true", help="Print what would be done without API calls"
    )
    args = parser.parse_args()

    if not any([
        args.all, args.archetypes, args.archetype, args.enemies,
        args.enemy, args.gear, args.all_gear
    ]):
        parser.print_help()
        return 0

    api_key = get_api_key()
    palette_img = load_palette_image()

    if args.dry_run:
        print("[DRY RUN] No API calls will be made.")
        client = None
    else:
        client = pixellab.Client(secret=api_key)
        try:
            balance = client.get_balance()
            print(f"[INFO] PixelLab balance: {balance}")
        except Exception as exc:
            print(f"[WARN] Could not fetch balance: {exc}")

    if args.archetype:
        generate_archetype(client, palette_img, args.archetype, args.dry_run)
    if args.archetypes:
        cmd_archetypes(client, palette_img, args.dry_run)
    if args.enemy:
        generate_enemy(client, palette_img, args.enemy, args.dry_run)
    if args.enemies:
        cmd_enemies(client, palette_img, args.dry_run)
    if args.gear:
        if not args.base_from:
            sys.stderr.write("ERROR: --gear requires --base-from <path-to-base-body.png>\n")
            return 2
        generate_gear_overlay(client, palette_img, args.gear, Path(args.base_from), args.dry_run)
    if args.all_gear:
        base = Path(args.base_from) if args.base_from else REPO_ROOT / "assets" / "chars" / "char_berserker_base_idle.png"
        cmd_gear(client, palette_img, base, args.dry_run)
    if args.all:
        cmd_all(client, palette_img, args.dry_run)

    return 0


if __name__ == "__main__":
    sys.exit(main())
