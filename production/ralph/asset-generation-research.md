# Modern Game Asset Generation — Deep Research (May 2026)

How to populate art and audio for an indie game in 2026, organised from
fastest to slowest, with concrete tools, licensing posture, and the trade-offs
that matter for `they-come-at-night` specifically.

---

## TL;DR — the three real strategies in 2026

| Strategy | Cost | Time-to-first-asset | Quality ceiling | Best for |
|---|---|---|---|---|
| **CC0 packs** | $0 | minutes | Variable; some packs are gorgeous | Prototypes and shipping when you can find a stylistic match |
| **AI-assisted, human-refined** | $10-50/mo | hours | High with skilled refinement | Customisation and stylistic control |
| **Commissioned artist** | $300-3000 | days-weeks | Highest, fully your own | Distinctive identity |

For this project, my recommendation: **CC0 packs + AI-assisted refinement for the missing pieces (music, polished sprite replacements)**. Don't commission until human playtest tells you what the game's identity *is*.

---

## 1. Visual assets

### 1.1 The CC0 baseline — what to grab first

These are the ground-truth sources for free game art with permissive licensing:

| Source | What's there | License |
|---|---|---|
| **Kenney.nl** | Tilesets, sprite packs, particles, UI; 1-bit, top-down, isometric, RPG | CC0 |
| **OpenGameArt.org** | Mixed-quality community uploads, searchable by license | CC0, CC-BY, CC-BY-SA |
| **itch.io free assets** | Indie creators sharing packs; many CC0 | Varies; filter on the site |
| **Calinou's Kenney mirrors on GitHub** | Godot-ready bundles of Kenney packs | CC0 (passthrough) |

For zombies-and-survivors specifically, search Kenney's "Roguelike Modern City"
and "Tiny Dungeon" packs first. Both are CC0 32×32-ish tilesets that would
slot directly into this project's `SpriteGenerator.override_texture(key, png_path)`
hook with zero code changes.

### 1.2 AI-generated pixel art — the 2026 landscape

#### Specialised pixel-art generators
| Tool | Strength | Weakness | Pricing (2026) |
|---|---|---|---|
| **PixelLab.ai** | Game-ready sprites with grid alignment; sprite animation tool built in | Costs scale with volume | $9-29/mo plans |
| **Retro Diffusion** | Cleanest "true pixel art" output (not blurry upscales) | Browser-only workflow | $10-20/mo |
| **PixelGlow** | Fast iteration, character exploration | General-purpose, less game-specific | Pay-per-image |
| **Scenario** | Train your own style model from reference sheets; output stays consistent | Steeper learning curve | $20-60/mo |

#### General-purpose with a pixel-art LoRA
| Tool | Setup | Strength | Notes |
|---|---|---|---|
| **Stable Diffusion + Pixel Art XL LoRA** | Local; ComfyUI workflow | Free (after one-time setup); full control | Requires a GPU |
| **Midjourney + style prompts** | Discord-based | Beautiful output; not strictly grid-aligned | $10-30/mo; the output usually needs Aseprite cleanup |
| **DALL-E (via ChatGPT)** | Inline in chat | Casual; not grid-precise | Included in ChatGPT Plus |

**The reality**: pure AI output rarely ships as-is. The 2026 indie workflow is:
1. Prompt for 10-20 candidates
2. Pick 2-3 with the right silhouette/palette
3. Open in **Aseprite** (or Piskel/Krita) and clean: fix grid alignment, redraw broken pixels, tighten the palette to N colours, build the animation frames manually

This is faster than from-scratch art for ~5x the iteration speed, but it is not
"AI generates a sprite sheet that ships."

#### Concrete prompt patterns that work for game pixel art

```
"32x32 pixel art zombie sprite, isolated on transparent background, side view,
 32 colors max, single-frame idle pose, dark green skin, tattered clothing,
 16-bit RPG style"
```

Key conventions: declare **resolution explicitly**, declare **colour count**,
declare **transparent background**, declare **isolation** (otherwise you get
zombies in a scene). Run with `Pixel Art XL` LoRA at weight 0.8-1.0.

### 1.3 Procedural at runtime — what this project already does

`scripts/systems/sprite_generator.gd` generates 32×32 textures programmatically
on first request. Each tile/entity has a distinct silhouette:

- House sprite is a brown rectangle with door and windows
- Hospital is white with a red cross
- Zombies are humanoid silhouettes scaling by tier
- Lead survivor has a gold-star marker

**Where this approach excels**: prototypes and "the game must run today"
deadlines. The sprites are recognisable and the game is playable.

**Where it falls down**: it has no soul. Two zombies of the same tier look
identical. There's no idle animation, no facing direction, no equipment overlay.
The 2026 "real game" bar is somewhere above this.

### 1.4 3D-to-pixel-art tools

A growing 2026 category: render simple 3D models, post-process to pixel art.

- **Godot Pixel Studio** (godot-pixel-studio on itch.io) — node-based; render 3D models with adjustable pixelation (8-800), colour quantisation, edge detection, dithering, palette enforcement
- **Aarthificial Pixelart shader** — Godot shader that takes any 3D scene and outputs pixel-art view; popular for 2.5D games

Useful if you want hand-built 3D models (cheap to make in Blender) that render
as pixel art — a viable middle ground between procedural and hand-drawn.

### 1.5 Decision matrix for **this project's** missing art

The procedural sprites we ship today are functional. Replacing them with
something better, ordered by cost:

| Path | Time | $ | Notes |
|---|---|---|---|
| Adopt Kenney's "Tiny Dungeon" or "Roguelike Modern City" tilesets as-is | 2 hours | $0 | Plug into `override_texture()`; immediate quality jump |
| AI-generated then Aseprite-cleaned 30-sprite set | 1-2 days | $10-30 (one month of PixelLab/Retro Diffusion) | Custom style; needs human touch-ups |
| Commission a single pixel artist for the full set | 1-2 weeks | $300-1500 | Distinctive identity, all-rights-reserved |

For a game still pre-playtest, **path 1 is the obvious move.** Skip the others
until the game has its identity.

---

## 2. Audio assets

### 2.1 The CC0 baseline

| Source | What | License |
|---|---|---|
| **Kenney.nl audio packs** | UI clicks, impact SFX, interface sounds — the project already uses these | CC0 |
| **OpenGameArt** | Music tracks (browse by CC0 tag) | Mixed; filter to CC0 |
| **Freesound.org** | Massive raw SFX library; quality varies; filter to CC0 | Mixed |
| **itch.io audio packs** | Curated, often by individual composers | Varies |
| **BBC Sound Effects** | Real-world recordings, licensed for personal-noncommercial; some commercial-OK | RF Pro license |
| **Tallbeard Studios** | "Five Free 8-bit Tracks" and similar CC-BY packs | CC-BY (attribution required) |

**For horror ambient music specifically**: search OpenGameArt for "horror
ambient" filtered to CC0; you will find 30-50 tracks ranging from passable to
excellent. The keepers are usually drones with sparse melodic content.

### 2.2 AI music generators in 2026

The landscape has consolidated since 2024:

| Tool | Strength | Licensing | Game-dev fit |
|---|---|---|---|
| **Suno** | Best overall quality; full songs with vocals | Settled with WMG late 2025; Sony case pending summer 2026 | High; check current ToS before commercial release |
| **Udio** | Cleanest licensing story (UMG settlement Oct 2025) | Co-licensed UMG×Udio platform 2026 | High |
| **AIVA** | Designed for game/cinematic scoring; instrumental | Pro plan grants full copyright to user — cleanest IP setup | **Best for game scoring** |
| **Stable Audio (Stability AI)** | Licensed training data (AudioSparx + partners) | Clearer commercial-use license framework | Medium |
| **ElevenLabs Sound Effects** | SFX generation from text descriptions; 30-sec clips with loop param | Royalty-free commercial license on paid plans | **Best for SFX you can't find in CC0** |

**For this project's music gap**, the cleanest path is **AIVA**: log in, type
"horror survival ambient drone, 60 seconds, looping", get 4 variations,
download the one you like. Pro plan is $33/mo and you own the output outright.

**For SFX gaps**, **ElevenLabs Sound Effects** with prompts like:
- "zombie groan, distant, low menace"
- "wooden door creaking shut, single beat"
- "wind through dead grass, ambient loop"

Each clip is ~3 seconds at $0.05-0.10. A complete project SFX set is $5-20.

### 2.3 Procedural audio at runtime

Godot has `AudioStreamGenerator` and `AudioStreamWAV.data` for runtime
synthesis. The project's `AudioDirector._placeholder_for(cue)` already
generates short beep tones procedurally.

**For ambient music specifically**, a procedural drone is achievable:
1. Generate a 4-8 second buffer of low-frequency oscillators (60-120Hz)
2. Add slow LFO modulation (every 2-4 seconds)
3. Mix in subtle pink noise
4. Loop indefinitely

This produces "something is playing" without composition. It's the audio
equivalent of the procedural sprites: shippable, soulless. Good for closing
G3 of `publishing-gaps.md` until real music lands.

### 2.4 Decision matrix for **this project's** music gap

| Path | Time | $ | Notes |
|---|---|---|---|
| Procedural ambient drone in `AudioDirector` | 1-2 hours | $0 | Closes G3 immediately; replaceable later |
| Download a CC0 ambient horror pack from OpenGameArt | 30 min on a network where opengameart.org isn't blocked | $0 | Recommended for the operator |
| Generate 3 tracks with AIVA Pro | 1 hour | $33 (one month) | Best ratio of quality/effort for indie |
| Commission a composer | 1-3 weeks | $200-1500 | Necessary only if AIVA output doesn't fit the game's tone |

For this session, I'll close G3 with the procedural drone (path 1). Operator
can swap in real music by dropping files into `assets/audio/music/`.

---

## 3. Licensing — the part everyone gets wrong

The 2026 environment has new variables: AI training data lawsuits, mandatory
attribution rules in some jurisdictions, and platform-specific rejection rules
for AI content.

### CC0 / Public Domain
- No attribution required (but show it anyway — basic decency)
- Can be modified, redistributed, sold without restriction
- **2026 wrinkle**: Steam now requires "AI generation disclosure" on store
  pages if any assets were AI-generated. Steam still accepts these games, but
  the disclosure is mandatory. itch.io has no such requirement.

### CC-BY (attribution required)
- Free to use, modify, sell
- **Must credit the original creator** in a way visible to the end user
- Many "free" assets are CC-BY, not CC0. Read every license file.

### AI-generated content licensing
| Tool | Who owns the output |
|---|---|
| **Suno (free tier)** | Suno retains rights; not commercial-safe |
| **Suno (Pro/Premier)** | User owns; check current ToS as cases are still litigating |
| **Udio Pro** | User owns; UMG settlement clarified terms |
| **AIVA Free** | AIVA retains; non-commercial use only |
| **AIVA Pro** | User owns outright; cleanest of any tool |
| **Midjourney** | Standard license: user owns commercial rights at $10+/mo tiers |
| **DALL-E** | OpenAI grants commercial rights to ChatGPT Plus users |
| **PixelLab** | User owns output, commercial-OK on all paid plans |
| **Retro Diffusion** | User owns output; check tier-specific terms |
| **Stable Diffusion (self-hosted)** | User owns; legal status of model weights still litigated |

**Practical rule**: keep a `production/asset-licenses.md` registry. Every
asset added gets a row with source, license, attribution requirement, and the
URL it was downloaded from. When a platform rejects your build for licensing
reasons (it will happen at least once), you can answer them in five minutes.

---

## 4. Workflow recommendations for `they-come-at-night`

In priority order:

### Today (autonomous; what I'll do this session)
1. Close G3 with procedural ambient drone
2. Close G1/G2/G5/G6/G8/G9 from the gaps doc
3. Document the asset license registry

### When operator has a few hours
4. Browse Kenney's "Roguelike Modern City" and "Tiny Dungeon" packs. Download
   the 32×32 tiles. Drop into `assets/sprites/`. The `SpriteGenerator` already
   has `override_texture(key, png_path)` hooks — wire ~20 of them and the
   game has hand-authored sprites without code changes.
5. Browse OpenGameArt for "horror ambient" CC0 music. Pick 2-3 tracks. Drop
   into `assets/audio/music/`. Tell AudioDirector to play them on day cycle.

### When operator wants distinctive identity
6. Sign up for AIVA Pro for one month ($33). Generate 5 tracks. Refine the
   ones you like in any DAW.
7. Sign up for PixelLab or Retro Diffusion. Generate 30 sprites. Clean in
   Aseprite. Replace the procedural set entirely.

### When operator has budget for a launch
8. Commission a single pixel artist for a cohesive 50-sprite set ($500-1500)
9. Commission a single composer for 3 tracks (calm / tension / megahorde)
   ($300-1000)
10. Have your visual identity validated by playtesters before committing.

---

## 5. What I tried, what worked, what didn't

For accountability:

| Attempted | Result |
|---|---|
| Download Kenney packs from kenney.nl directly | Firewalled |
| Download from itch.io / freesound.org / opengameart.org | All firewalled (`x-deny-reason: host_not_allowed`) |
| Download Kenney mirrors from GitHub (Calinou's repos) | Worked — got two CC0 audio packs |
| Search GitHub for CC0 music repos | None found at scale; ecosystem is on itch/OGA, not GitHub |
| AI image gen via WebFetch | Out of scope; no API keys for the agentic context |
| Procedural sprite generation in GDScript | Worked; shipping in the build |
| Procedural audio synthesis | Worked for SFX; about to do same for ambient music |

**The lesson for the operator**: the firewall in this development context
blocks every commercial asset site except GitHub. Outside this firewall, the
Kenney/OGA/itch route is the fastest publishable-quality option for free, and
the AIVA/PixelLab route is the fastest for distinctive identity.

---

## Sources

- [Best AI Pixel Art Generators 2026 (Sprite-AI)](https://www.sprite-ai.art/blog/best-pixel-art-generators-2026)
- [PixelLab — AI Game Asset Generator](https://www.pixellab.ai/)
- [Best AI Pixel Art Generators 2026 (ZSky)](https://zsky.ai/blog/best-ai-for-pixel-art)
- [How to make a pixel art game (Sprite-AI)](https://www.sprite-ai.art/blog/how-to-make-a-pixel-art-game)
- [AI Music Generator Comparison 2026 (Chartlex)](https://www.chartlex.com/blog/marketing/ai-music-generator-comparison-2026)
- [Suno vs AIVA 2026](https://aisongcreator.pro/blog/suno-vs-aiva)
- [Best AI Music Generators 2026 (WaveSpeed)](https://wavespeed.ai/blog/posts/best-ai-music-generators-2026/)
- [Suno vs Udio vs AIVA 2026](https://hybridmusic.io/suno-vs-udio-vs-aiva-2026/)
- [ElevenLabs Sound Effects](https://elevenlabs.io/sound-effects)
- [CC0 Music on OpenGameArt](https://opengameart.org/content/cc0-music-0)
- [itch.io CC0 game assets — Music](https://itch.io/game-assets/assets-cc0/tag-music)
- [Freesound.org CC0 tag](https://freesound.org/browse/tags/cc0/)
- [ComfyUI Pixel-Art-XL workflow guide](https://www.kokutech.com/blog/gamedev/tips/art/pixel-art-generation-with-comfyui)
- [The Pixel Art ComfyUI Workflow Guide](https://inzaniak.github.io/blog/articles/the-pixel-art-comfyui-workflow-guide.html)
- [Godot Pixel Studio (3D→sprite)](https://gamefromscratch.com/godot-pixel-studio-3d-to-sprite-tool/)
- [Godot Procedural Generation Demos](https://github.com/gdquest-demos/godot-4-procedural-generation)
- [Indie Game Launch Checklist 2026 (Wayline)](https://www.wayline.io/blog/indie-game-launch-checklist-beta-post-launch-engagement)
- [Indie Developer App Launch Checklist 2026](https://appscreenshotstudio.com/blog/indie-developer-app-launch-checklist-2026)
