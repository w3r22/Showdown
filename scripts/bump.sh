#!/bin/bash
# bump.sh — auto-increment app version for Showdown.
#   Usage: scripts/bump.sh <major|minor|patch> ["changelog summary line"]
# Bumps MARKETING_VERSION (semver) + CURRENT_PROJECT_VERSION (build #) in the
# Xcode project via agvtool, prepends a CHANGELOG.md entry, and prints the new
# version. (Git tagging is done by the workflow AFTER the release commit lands,
# so the tag points at the right commit.)
set -euo pipefail

cd "$(dirname "$0")/.."

LEVEL="${1:-}"
SUMMARY="${2:-}"
case "$LEVEL" in
  major|minor|patch) ;;
  *) echo "Usage: scripts/bump.sh <major|minor|patch> [\"summary\"]"; exit 2 ;;
esac

PBXPROJ="Showdown.xcodeproj/project.pbxproj"

# Current marketing version (read from the project; both configs share one value).
CUR=$(grep -m1 -E 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([0-9]+\.[0-9]+\.[0-9]+).*/\1/' || true)
[ -z "$CUR" ] && CUR=$(grep -m1 -E 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([0-9]+\.[0-9]+).*/\1.0/' || true)
[ -z "$CUR" ] && CUR="1.0.0"

IFS='.' read -r MA MI PA <<< "$CUR"
MA=${MA:-1}; MI=${MI:-0}; PA=${PA:-0}
case "$LEVEL" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  patch) PA=$((PA+1)) ;;
esac
NEW="$MA.$MI.$PA"

echo "==> Version: $CUR -> $NEW ($LEVEL)"
agvtool new-marketing-version "$NEW" >/dev/null
agvtool next-version -all >/dev/null
BUILD=$(agvtool what-version -terse 2>/dev/null || echo "?")
echo "==> Build number: $BUILD"

# Prepend a concise CHANGELOG entry.
DATE=$(date +%Y-%m-%d)
CHANGELOG="CHANGELOG.md"
[ -f "$CHANGELOG" ] || printf '# Changelog\n\nAll notable changes to Showdown.\n' > "$CHANGELOG"
ENTRY="## v$NEW (build $BUILD) — $DATE"
[ -n "$SUMMARY" ] && ENTRY="$ENTRY"$'\n'"- $SUMMARY"
TMP=$(mktemp)
{ head -n 3 "$CHANGELOG"; printf '\n%s\n' "$ENTRY"; tail -n +4 "$CHANGELOG"; } > "$TMP"
mv "$TMP" "$CHANGELOG"

echo "==> CHANGELOG.md updated."
echo "VERSION=$NEW"
echo "BUILD=$BUILD"
echo "TAG=v$NEW"
