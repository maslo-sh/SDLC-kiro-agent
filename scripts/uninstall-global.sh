#!/usr/bin/env bash
#
# uninstall-global.sh — remove the globally installed SDLC agents from ~/.kiro.
# Removes exactly what install-global.sh created; leaves the rest of ~/.kiro intact.
#
# Usage:
#   ./scripts/uninstall-global.sh
#   KIRO_HOME=/custom/.kiro ./scripts/uninstall-global.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_ROOT/.kiro"

KIRO_HOME="${KIRO_HOME:-$HOME/.kiro}"
DEST="$KIRO_HOME/sdlc-agent"
AGENTS_DEST="$KIRO_HOME/agents"
SKILLS_DEST="$KIRO_HOME/skills"

AGENTS=(orchestrator lead researcher developer reviewer janitor)

echo "SDLC agent — global uninstall (kiro home: $KIRO_HOME)"

# Remove the five agent configs (only these, not other agents you may have).
for a in "${AGENTS[@]}"; do
  f="$AGENTS_DEST/$a.json"
  [ -f "$f" ] && rm -f "$f" && echo "  removed agents/$a.json"
done

# Remove the skills this installer put in place. Prefer the manifest written by
# install-global.sh (authoritative list of what we installed); fall back to the
# repo's current .kiro/skills/ or the installed payload.
MANIFEST="$DEST/.installed-skills"
if [ -f "$MANIFEST" ]; then
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    [ -d "$SKILLS_DEST/$name" ] && rm -rf "${SKILLS_DEST:?}/$name" && echo "  removed skills/$name"
  done < "$MANIFEST"
else
  skill_src="$SRC/skills"
  [ -d "$skill_src" ] || skill_src="$DEST/skills"
  if [ -d "$skill_src" ]; then
    for skill_dir in "$skill_src"/*/; do
      name="$(basename "$skill_dir")"
      [ -d "$SKILLS_DEST/$name" ] && rm -rf "${SKILLS_DEST:?}/$name" && echo "  removed skills/$name"
    done
  fi
fi

# Remove the sdlc-agent payload dir.
[ -d "$DEST" ] && rm -rf "$DEST" && echo "  removed sdlc-agent/"

echo "Done."
