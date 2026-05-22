---
name: generate-sprite
description: Generate a WARBAND sprite via the PixelLab API. Use when the user asks to "generate a sprite", "make sprite", "regenerate the [archetype] sprite", or "run the sprite pipeline". Wraps `tools/sprite-gen/pixellab_generate.py`. Requires PIXELLAB_API_KEY in .env.local. Note: must run outside the Claude Code web sandbox (sandbox blocks api.pixellab.ai).
allowed-tools: Read, Glob, Grep, Bash, Edit
model: sonnet
---

# /generate-sprite — WARBAND PixelLab Pipeline

You are running the WARBAND sprite generation pipeline. Most heavy lifting is
already done by `tools/sprite-gen/pixellab_generate.py` — your job is to:

1. Verify the environment is correctly set up
2. Choose the right invocation (single archetype, all archetypes, gear, etc.)
3. Run it, surface errors, and verify outputs landed
4. If running in a sandboxed Claude Code web session: detect the 403 from
   api.pixellab.ai early and tell the user to run from their local machine

## Inputs

- `$ARGUMENTS`: the target to generate. Forms:
  - `(empty)` → show options
  - `all` → generate all archetypes + enemies + gear
  - `archetypes` → all 6 archetype base bodies
  - `enemies` → all 10 enemies + boss
  - `gear` → all 10 gear overlays (requires berserker base already generated)
  - `<archetype-id>` → e.g., `berserker`, `chieftain`, `shaman`, `cleaver`, `brute`, `archer`
  - `enemy:<enemy-id>` → e.g., `enemy:iron-warden-boss`
  - `gear:<gear-key>` → e.g., `gear:weapon_twohanded-axe-common`

## Procedure

### Step 1 — Preflight

Run these checks, in order. Stop and surface the issue if any fails:

```bash
# 1.1 Palette PNG exists; if not, build it
test -f data/palettes/warband_palette.png || python3 tools/sprite-gen/build_palette.py

# 1.2 .env.local has the API key
grep -q "^PIXELLAB_API_KEY=" .env.local || echo "MISSING API KEY"

# 1.3 Python deps installed
python3 -c "import pixellab, PIL" 2>&1
```

If any preflight fails, halt and report.

### Step 2 — Sandbox detection

In Claude Code web sandbox, api.pixellab.ai is blocked. Run a 5-second probe:

```bash
curl -sL --max-time 5 -o /dev/null -w "%{http_code}" https://api.pixellab.ai/v1/ 2>&1
```

If the response is `403` or `000`, you are in a sandboxed environment. Stop
and tell the user:

> Sandbox blocks `api.pixellab.ai`. Run this from your local machine:
> `python3 tools/sprite-gen/pixellab_generate.py [args]`
> Or activate via Claude Code Desktop where the sandbox is permissive.

### Step 3 — Dispatch

Parse `$ARGUMENTS` and run the appropriate command. Always run with `--dry-run`
first to preview the file list; ask the user to confirm before the real run
(unless they explicitly said "go" or "auto").

```bash
# Examples:
python3 tools/sprite-gen/pixellab_generate.py --archetype berserker
python3 tools/sprite-gen/pixellab_generate.py --archetypes
python3 tools/sprite-gen/pixellab_generate.py --all-gear --base-from assets/chars/char_berserker_base_idle.png
python3 tools/sprite-gen/pixellab_generate.py --all
```

### Step 4 — Verify outputs

After each run, list new sprites:

```bash
find assets/chars assets/enemies -name "*.png" -newer data/palettes/warband_palette.png
```

If the file count doesn't match the dry-run expectation, surface the gap.

### Step 5 — Reload sprite cache

The `SpriteComposer` autoloads sprites and caches them. If the game is running
in the editor, the user must restart Godot OR call `SpriteComposer.clear_cache()`
from a debug console. Document this for the user.

### Step 6 — Cost reporting

Print the PixelLab balance before and after (the script prints
`[INFO] PixelLab balance: ...` if available). Surface that to the user so they
know what was spent.

## Failure modes

| Symptom | Action |
|---|---|
| `403 Forbidden` from api.pixellab.ai | Sandbox blocking; run locally |
| `401 Unauthorized` | API key invalid — check .env.local |
| `429 Too Many Requests` | Rate limit; pause 60s and retry |
| `requests.exceptions.Timeout` | Network flake; retry once |
| `Palette path not found` | Run `python3 tools/sprite-gen/build_palette.py` |
| `ModuleNotFoundError: pixellab` | `pip install pixellab Pillow` |

## Notes

- The script is deterministic via per-archetype seeds. Same input → same output.
- Generated sprites land at paths the `SpriteComposer` already reads from.
  No code changes needed in the game to pick up new sprites.
- For gear overlays, the base body PNG is used as `init_image` conditioning to
  keep pose alignment. If the base is the previous procedural placeholder, the
  gear overlay alignment may drift; regenerate the base bodies first, then gear.
- Procedural placeholder sprites (from `tools/sprite-gen/generate_sprites.py`)
  remain in the repo as a no-network fallback. Real PixelLab output simply
  overwrites them at the same paths.
