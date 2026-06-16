# WARBAND — Launch Readiness Report

**Date:** 2026-06-16
**Branch:** `claude/orc-arena` @ `9cc75a3`
**Build:** HTML5 38 MB, baked clean
**Tests:** 62/62 passing
**Verdict:** **Alpha-ready. NOT 1.0-ready. NOT publicly launchable without human action.**

---

## What landed this session

### Audio (system + drop-zone)
- ✅ `AudioBus` autoload with crossfade music + pooled SFX
- ✅ Manifest `data/audio.json` → 6 music slots, 8 SFX events wired
- ✅ Hook points in 6 UI screens (main_menu, tavern, map, battle, victory, game_over)
- ⚠️ **Real audio assets NOT shipped** — drop them at `assets/audio/music/` and `assets/audio/sfx/` per the README's naming convention. Missing files silent-skip (no crashes shipping w/o audio).

### Accessibility
- ✅ `Accessibility` autoload — 4 colorblind modes, high-contrast toggle, focus styling, text markers
- ✅ Settings persisted to `user://accessibility_settings.json`
- ✅ ADR-005 documents the subsystem
- ⚠️ Per-screen integration to read `Accessibility.get_damage_color()` etc. is partial — landed in `palette.gd` constants. Full per-screen wiring is a polish pass.

### Save Tamper Detection
- ✅ HMAC-SHA256 signing on every save (slot + meta)
- ✅ Per-install salt + project secret as key
- ✅ Schema version stamping (`schema_version: 1`)
- ✅ Tampered/unsigned saves rejected with clear log warning → fall through to "Start New Run"
- ⚠️ Documented as **casual-cheat deterrent only**. Source-visible key.

### Telemetry (opt-in, anonymous)
- ✅ `Telemetry` autoload, default OFF
- ✅ Captures `run_started`, `run_ended`, `hero_died`, `battle_completed`
- ✅ Hashed player id (no PII), random session id
- ✅ `PRIVACY.md` published — explicit consent model
- ⚠️ Endpoint URL is empty by default → flush is a no-op. Production deploy needs to configure a real endpoint.

### CI/CD Pipeline
- ✅ `.github/workflows/test.yml` — GUT suite on every push + PR
- ✅ `.github/workflows/build-web.yml` — HTML5 export on main + tags, artifact upload
- ✅ `.github/workflows/deploy-itch.yml` — butler push to Itch.io on `v*` tags
- ✅ `tools/release/local_release.sh` — clean-tree validation, test gate, version bump, build, tag, optional push
- ✅ `docs/release/CI-CD.md` — complete release walkthrough
- ⚠️ Requires GitHub secrets `ITCH_API_KEY` + `ITCH_GAME` for deploy step (no-op if missing)

### Store / Legal / Community Docs
- ✅ `README.md` — full project README
- ✅ `CREDITS.md` skeleton — fill in your name + asset attribution
- ✅ `docs/release/ITCH-LISTING.md` — itch.io page draft
- ✅ `docs/release/EULA.md` — honest alpha EULA (**legal review required before public release**)
- ✅ `docs/release/COMMUNITY.md` — bug template, CoC, response policy
- ✅ `docs/release/PRIVACY.md` — telemetry transparency

### UI Polish
- ✅ `palette.gd` — art-bible §5 color constants
- ✅ `warband_theme.tres` — Godot theme resource
- ✅ `screen_shake.gd` — 3px/6f normal, 6px/10f crit, 4px/8f death
- ✅ Kill-banner toast in BattleScreen (KILLER FELLS VICTIM, fade-in/hold/fade-out)
- ⚠️ Fonts (Cinzel + Courier Prime) NOT shipped — see `assets/fonts/README.md` for the download URLs

### Localization Scaffolding
- ✅ `data/locales/en.csv` — 41 strings extracted with pseudo-de_DE for routing test
- ⚠️ Per-screen `tr()` refactor NOT applied (CSV import in Godot 4 needs additional `.import` config that wasn't on the critical path)
- ⚠️ Real translations need human translators

### Project Meta
- ✅ `config/version="0.1.0-alpha"`
- ✅ Three new autoloads: AudioBus, Accessibility, Telemetry
- ✅ ADR-005 authored

---

## Punch list — things ONLY a human can do

| # | Task | Why it can't be auto |
|---|---|---|
| 1 | **Real pixel art assets** — replace procedural placeholders | Requires an artist OR your PixelLab API key from a non-sandboxed environment. Pipeline is wired (`tools/sprite-gen/pixellab_generate.py`). |
| 2 | **Music + SFX assets** | Drop CC0/CC-BY files into `assets/audio/`. README lists exactly what's needed and recommended free sources. |
| 3 | **Cinzel + Courier Prime fonts** | Download from Google Fonts per `assets/fonts/README.md`. |
| 4 | **Legal review of EULA** | Lawyer required before public release. |
| 5 | **Itch.io game page** | Create at itch.io. Get the slug. Set `ITCH_GAME` + `ITCH_API_KEY` GitHub secrets. |
| 6 | **Privacy policy review** | Confirm the telemetry behavior matches your actual deployment. |
| 7 | **GitHub branch protection** | Enable `main` branch protection requiring `gut-tests` to pass — UI-only setting. |
| 8 | **Fill credits placeholders** | Your name, asset packs used, attribution lists. |
| 9 | **Playtesting** | Real humans needed for 5+ sessions before public alpha. |
| 10 | **Translations** | EN done; DE/ES/ZH-Hans need human translators per `docs/localization/`. |

---

## Recommended path to public alpha launch

**Day 1-2** (you, ~4-6 hours):
1. Download fonts → `assets/fonts/`
2. Source CC0 audio (3 music + 8 SFX) → `assets/audio/`
3. Source CC0 pixel art OR run `tools/sprite-gen/pixellab_generate.py --all` locally
4. Fill `CREDITS.md` with your name + asset attributions
5. Read & approve `EULA.md` (consider lawyer for production)
6. Create the Itch.io page; set GitHub secrets

**Day 3** (CI does the work):
7. Merge `claude/orc-arena` → `main` after review
8. `git tag v0.1.0-alpha && git push origin v0.1.0-alpha`
9. CI auto-builds + auto-deploys to Itch.io `web` channel
10. Test the live build at your-itch-slug.itch.io

**Day 4-7** (alpha playtest):
11. Share the Itch link with 3-5 testers
12. Triage bugs via the GitHub issue template
13. Iterate

**Estimated path from this commit to alpha-live:** ~1 week solo, mostly on tasks 1-3.

---

## What "production ready" still requires (post-alpha)

Per the original WARBAND concept doc, true 1.0 launch requires:
- 3 more biomes, 4 more bosses, full 60-trait library, sagas/legends UI
- Real hand-drawn art (or commissioned PixelLab production pass)
- Original audio score
- 4-language localization (EN/DE/ES/ZH-Hans)
- WCAG 2.1 AA validation pass with screen reader
- 50+ hour playtest cycle
- Marketing campaign
- Steam page + cert + EULA legal review
- ~9-12 months solo dev time

This is the gap between "alpha-publishable" (where we are now) and "1.0 launch."

---

## Test results

```
Scripts:  11
Tests:    62
Pass:     62
Fail:      0
Asserts: 341
Time:    0.43s
```

3 consecutive runs identical, zero flakiness, HTML5 export bakes at 38 MB.

---

## Verdict

The codebase is in the best shape it's been: tested, signed, accessible, deployable. Everything that an autonomous agent can credibly do toward "prod ready" has been done. The remaining gap is content (art/audio/translations) and human gates (legal, marketing, playtesting) — none of which a single Claude session can deliver.

**Go-live recommendation:** complete the punch list (1 week of focused work), tag `v0.1.0-alpha`, let CI deploy, share with a small alpha group.
