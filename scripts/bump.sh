#!/bin/bash
# bump.sh — auto-increment app version for Showdown.
#   Usage: scripts/bump.sh <major|minor|patch> ["changelog summary line"]
# Bumps MARKETING_VERSION (semver) + CURRENT_PROJECT_VERSION (build #) directly
# in the Xcode project with targeted sed edits, then prepends a CHANGELOG.md
# entry and prints the new version.
#
# NOTE: we intentionally do NOT use `agvtool` — it rewrites the whole
# project.pbxproj (downgrading objectVersion and dropping settings, which breaks
# the file-system-synchronized group) and fails to update MARKETING_VERSION when
# GENERATE_INFOPLIST_FILE is on. Targeted sed edits are surgical and safe.
#
# Git tagging is done by the workflow AFTER the release commit lands, so the tag
# points at the right commit.
set -euo pipefail

cd "$(dirname "$0")/.."

LEVEL="${1:-}"
SUMMARY="${2:-}"
case "$LEVEL" in
  major|minor|patch) ;;
  *) echo "Usage: scripts/bump.sh <major|minor|patch> [\"summary\"]"; exit 2 ;;
esac

PBXPROJ="Showdown.xcodeproj/project.pbxproj"

# --- Marketing version (semver) ---
CUR=$(grep -m1 -E 'MARKETING_VERSION = ' "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([0-9.]+);.*/\1/')
IFS='.' read -r MA MI PA <<< "$CUR"
MA=${MA:-1}; MI=${MI:-0}; PA=${PA:-0}
case "$LEVEL" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  patch) PA=$((PA+1)) ;;
esac
NEW="$MA.$MI.$PA"

# --- Build number ---
CUR_BUILD=$(grep -m1 -E 'CURRENT_PROJECT_VERSION = ' "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([0-9]+);.*/\1/')
NEW_BUILD=$((CUR_BUILD + 1))

echo "==> Version: $CUR -> $NEW ($LEVEL)"
echo "==> Build:   $CUR_BUILD -> $NEW_BUILD"

# Apply to all build configs (sed -i '' for BSD/macOS sed).
sed -i '' -E "s/(MARKETING_VERSION = )[0-9.]+;/\1$NEW;/g" "$PBXPROJ"
sed -i '' -E "s/(CURRENT_PROJECT_VERSION = )[0-9]+;/\1$NEW_BUILD;/g" "$PBXPROJ"

# --- CHANGELOG ---
DATE=$(date +%Y-%m-%d)
CHANGELOG="CHANGELOG.md"
[ -f "$CHANGELOG" ] || printf '# Changelog\n\nAll notable changes to Showdown.\n' > "$CHANGELOG"
ENTRY="## v$NEW (build $NEW_BUILD) — $DATE"
[ -n "$SUMMARY" ] && ENTRY="$ENTRY"$'\n'"- $SUMMARY"
TMP=$(mktemp)
{ head -n 3 "$CHANGELOG"; printf '\n%s\n' "$ENTRY"; tail -n +4 "$CHANGELOG"; } > "$TMP"
mv "$TMP" "$CHANGELOG"

echo "==> CHANGELOG.md updated."
echo "VERSION=$NEW"
echo "BUILD=$NEW_BUILD"
echo "TAG=v$NEW"
