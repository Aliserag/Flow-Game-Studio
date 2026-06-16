#!/usr/bin/env bash
# WARBAND local release helper. Validates, tests, bumps version, builds, tags.
#
# Usage:
#   tools/release/local_release.sh --bump-patch [--push]
#   tools/release/local_release.sh --bump-minor [--push]
#   tools/release/local_release.sh --bump-major [--push]
#
# --push pushes the new tag to origin, which triggers CI deploy.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GODOT="${GODOT:-$HOME/.local/bin/godot}"

BUMP=""
PUSH=0

for arg in "$@"; do
  case "$arg" in
    --bump-patch) BUMP="patch" ;;
    --bump-minor) BUMP="minor" ;;
    --bump-major) BUMP="major" ;;
    --push) PUSH=1 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

if [ -z "$BUMP" ]; then
  echo "ERROR: must specify --bump-patch | --bump-minor | --bump-major" >&2
  exit 2
fi

# 1. Working tree must be clean
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: working tree is dirty. Commit or stash first." >&2
  git status --short >&2
  exit 3
fi

# 2. Tests must pass
echo "[1/5] Running tests..."
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit | tail -10
echo "[1/5] OK"

# 3. Read & bump version in project.godot
echo "[2/5] Bumping version..."
CURRENT=$(grep -oP 'config/version="\K[^"]+' project.godot || echo "0.0.0")
# Strip any pre-release suffix for bumping
BASE=${CURRENT%-*}
IFS='.' read -r MAJOR MINOR PATCH <<<"$BASE"
case "$BUMP" in
  patch) PATCH=$((PATCH + 1)) ;;
  minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
  major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
esac
NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}-alpha"
sed -i.bak "s|config/version=\"${CURRENT}\"|config/version=\"${NEW_VERSION}\"|" project.godot
rm -f project.godot.bak
echo "[2/5] $CURRENT -> $NEW_VERSION"

# 4. Build HTML5
echo "[3/5] Building HTML5..."
mkdir -p build
"$GODOT" --headless --path . --export-release "Web" build/index.html | tail -3
echo "[3/5] OK ($(du -sh build | cut -f1))"

# 5. Commit version bump and tag
echo "[4/5] Committing and tagging..."
git add project.godot
git commit -m "chore: bump version to v${NEW_VERSION}"
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
echo "[4/5] Tag v${NEW_VERSION} created"

# 6. Optionally push
if [ $PUSH -eq 1 ]; then
  echo "[5/5] Pushing branch + tag..."
  git push
  git push origin "v${NEW_VERSION}"
  echo "[5/5] Pushed — CI will deploy."
else
  echo "[5/5] Skipped push. Run 'git push && git push origin v${NEW_VERSION}' to trigger deploy."
fi

echo ""
echo "Done. Local build at: build/index.html"
