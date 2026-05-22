# Publishing Gaps — They Come At Night

What's actually missing to call this a publishable build, with Store/launch
operations descoped (the operator owns those). The bar here is: "a stranger
could download, run, and form an opinion about it."

---

## Currently shipping

- Three platform binaries: Linux (70MB), Windows (98MB), Web (44MB)
- 418 unit tests, 158 E2E assertions, browser-verified boot
- Real CC0 audio (10 Kenney SFX cues)
- Procedural pixel-art sprites (13 terrains, 5 zombie tiers, survivor + faction NPCs)
- Save/load, settings menu, difficulty + map size modes
- 61 events, 12 factions, 32 items
- Theme + responsive layout + keyboard input + fog of war

## Engineering gaps that affect publish-readiness

Sorted by impact, highest first.

### G1 — No version identifier baked into the build
**Symptom**: A bug report says "the game crashed" — there's no way to tell which build the user ran.
**Status**: BLOCKER for any non-trivial release
**Fix**: Add `config/version` to `project.godot`. Read it at runtime and:
- Append `vX.Y.Z (commit-hash)` to the window title at boot
- Show it in the bottom corner of the main menu
- Include it in save files for forward-compat checks
- Print it on startup via the autoload chain

Effort: 1 hour. Doable autonomously.

### G2 — No credits screen
**Symptom**: Kenney CC0 SFX are shipping but the player never sees attribution. CC0 doesn't *require* visible attribution, but releasing a game with bundled third-party assets and no credits is unprofessional.
**Status**: Important; embarrassing to ship without
**Fix**: `scenes/CreditsScreen.tscn` accessible from main menu. Reads `assets/audio/licenses/*.txt` and lists: project authorship, engine credit, audio attribution, art attribution. Auto-discovers license files so new attribution updates automatically when assets are added.

Effort: 1 hour. Doable autonomously.

### G3 — No music tracks
**Symptom**: The game has SFX but is silent during play. For a horror-survival game, this is a notable gap.
**Status**: Important for tone; the buses are already wired in `AudioDirector`
**Fix**: Three paths, in order of preference:
- (a) Drop in a CC0 ambient-horror loop (firewalled hosts blocked us, but operator can do this in 5 minutes from itch.io/Freesound/OpenGameArt)
- (b) Generate a procedural ambient drone with Godot's `AudioStreamGenerator` so there's *something* playing
- (c) Commission ~3 tracks (calm exploration / tension / megahorde) for $50-200 total

Effort autonomously: 2 hours (path b). Path (a) is faster but needs operator network access.

### G4 — macOS export
**Symptom**: Linux + Windows + Web exports work; macOS export needs Apple notarization tooling.
**Status**: Blocked unless operator has access to a Mac
**Fix**: Run `make export-macos` on a Mac with Xcode CLI tools installed; sign with `codesign` if distributing outside the App Store. Procedure is in Godot docs.

Effort: 1 hour with a Mac; impossible without one.

### G5 — No pause functionality
**Symptom**: There's no way to step away from the game mid-turn except by ending the day. No "I need to think about this" pause.
**Status**: Quality issue
**Fix**: Bind Esc (when not in a modal) to a pause overlay. Pause overlay shows: Resume / Save / Settings / Quit to Menu. While paused, `get_tree().paused = true` and `process_mode = PROCESS_MODE_ALWAYS` for the pause UI.

Effort: 1 hour. Doable autonomously.

### G6 — No build metadata in save files
**Symptom**: When content changes (events.json grows, item IDs renamed), old saves break with no way to detect the cause.
**Status**: Will bite within the first content patch
**Fix**: Save format already has `version` field. Add `build_version` (from G1) so when a save fails to load, we can tell which build it came from and either migrate or refuse with a clear message.

Effort: 30 minutes. Doable autonomously.

### G7 — No crash report / telemetry hook
**Symptom**: After launch, you'll have no way to know what's failing on real machines without players manually filing issues.
**Status**: Critical for a real launch; out-of-scope for "publishable" if you don't have a backend
**Fix**: Either:
- (a) Catch unhandled errors in autoloads with a `_on_error` shim, append to `user://crash.log`, surface a copy-to-clipboard button in the main menu on next launch
- (b) Wire Sentry's GDScript SDK (community-maintained); requires an operator-owned Sentry account

Effort autonomously: 2 hours (path a). Path b needs operator account.

### G8 — No screenshot capture in-game
**Symptom**: Players can't share moments; impossible to capture good marketing material.
**Status**: Quality issue, easy to fix
**Fix**: Bind F12 to `get_viewport().get_texture().get_image().save_png("user://screenshots/...")`. Show a toast notification.

Effort: 30 minutes. Doable autonomously.

### G9 — README doesn't ship with the build
**Symptom**: Someone downloading the Linux/Windows binary sees no controls help.
**Status**: Quality issue
**Fix**: Ship `CONTROLS.txt` next to the binary; add a "Controls" page to the main menu listing the action buttons + their keyboard shortcuts.

Effort: 30 minutes. Doable autonomously.

### G10 — No human playtest
**Symptom**: The game has never been played to completion by a person.
**Status**: Truly blocked until a human plays
**Fix**: There is no engineering substitute. Get five strangers to play 30 minutes each. Take notes. Iterate. The E2E harness is a great regression net; it is not a substitute for hands.

Effort: External time, not engineering time.

---

## Items I can close right now in this session

G1 (version stamp), G2 (credits screen), G3b (procedural ambient drone),
G5 (pause), G6 (save build_version), G8 (screenshot), G9 (controls page).

That leaves G4 (macOS, hardware-blocked), G7 (crash report — partial OK, full
needs account), G10 (human playtest, by definition).

---

## What "publishable" means after closing those

- Identified, versioned, signed (where possible) builds for Linux/Windows/Web
- Credits screen acknowledging CC0 audio sources
- Background music (procedural drone; replace with real track at launch)
- Pause functionality
- Save versioning
- F12 screenshot capture
- In-game controls help
- A README inside each download

The game becomes something a stranger can download, identify, and form an
opinion about, with the failure modes that remain (no real music, no
hand-drawn art, no human playtest) clearly disclosed.