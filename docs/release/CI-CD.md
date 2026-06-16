# WARBAND CI/CD

Three GitHub Actions workflows automate testing, building, and deploying.

## Workflows

| File | Trigger | Purpose |
|---|---|---|
| `.github/workflows/test.yml` | Every push + PR | GUT test suite (62/62) |
| `.github/workflows/build-web.yml` | Push to `main`, tags `v*`, manual | HTML5 export → artifact |
| `.github/workflows/deploy-itch.yml` | Tags `v*`, manual | Build + `butler push` to Itch.io |

All workflows cache Godot 4.6 binary and export templates aggressively — first run takes ~3 min, subsequent runs ~90 seconds.

## Required GitHub secrets

Set these in `Settings → Secrets and variables → Actions`:

| Secret | Format | Purpose |
|---|---|---|
| `ITCH_API_KEY` | Butler API key (https://itch.io/user/settings/api-keys) | Authenticates the deploy |
| `ITCH_GAME` | `username/game-slug` (e.g., `aliserag/warband`) | Itch target page |

Deploy workflow is a no-op if either secret is missing — safe to merge before secrets are configured.

## Release flow

```bash
# 1. Verify locally:
bash tools/release/local_release.sh --bump-patch

# 2. Push the tag created by the script:
git push origin v0.1.1

# 3. CI runs automatically:
#    - test.yml (gates the deploy via branch protection)
#    - build-web.yml on the tag
#    - deploy-itch.yml on the tag, pushes to Itch.io channel `web`
```

## Branch model

- `main`: stable. Tags cut from here.
- `claude/<topic>`: feature branches. PRs merge to `main` after green CI.
- Tags `v0.1.0`, `v0.1.1-alpha`, etc. follow SemVer (alpha → beta → rc → stable).

## Branch protection (recommended)

In `Settings → Branches → Add rule`:
- Pattern: `main`
- Require status check: `gut-tests`
- Require pull request reviews
- Dismiss stale reviews on new commits

This blocks merging code that fails tests — a safety net for solo or small-team dev.

## Manual local export

If you want to build locally without the script:

```bash
~/.local/bin/godot --headless --path . --export-release "Web" build/index.html
```

Then `cd build && python3 -m http.server 8000` and visit http://localhost:8000.

## Butler local install

For manual Itch.io uploads outside CI:

```bash
curl -L -o /tmp/butler.zip \
  https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default
unzip -o /tmp/butler.zip -d ~/butler
chmod +x ~/butler/butler
~/butler/butler login   # one-time
~/butler/butler push build/ aliserag/warband:web --userversion 0.1.1
```
