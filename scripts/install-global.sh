#!/usr/bin/env bash
#
# install-global.sh — install the SDLC orchestrator and its sub-agents into ~/.kiro
# so they are available as global agents in every Kiro workspace.
#
# The pipeline definition lives under this repo's .kiro/ directory:
#   .kiro/agents/     the five agent configs
#   .kiro/prompts/    the role prompt bodies
#   .kiro/skills/     domain skills (jira-*, gitlab-*, knowledge-source, quality-gate, task-framing-*)
#   .kiro/templates/  the artifact templates
#   AGENTS.md         cross-tool entry point (repo root), referenced by the orchestrator
#
# What this does:
#   1. Copies prompts/, skills/, templates/ and AGENTS.md into  $KIRO_HOME/sdlc-agent/
#   2. Copies each skill into                                    $KIRO_HOME/skills/<name>/  (global auto-discovery)
#   3. Writes every .kiro/agents/*.json config into              $KIRO_HOME/agents/
#      with prompt/resources rewritten to absolute paths under sdlc-agent/.
#
# Re-run any time to refresh the global copy after editing prompts or skills.
# Uninstall with scripts/uninstall-global.sh.
#
# Usage:
#   ./scripts/install-global.sh
#   KIRO_HOME=/custom/.kiro ./scripts/install-global.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_ROOT/.kiro"

KIRO_HOME="${KIRO_HOME:-$HOME/.kiro}"
DEST="$KIRO_HOME/sdlc-agent"
AGENTS_DEST="$KIRO_HOME/agents"
SKILLS_DEST="$KIRO_HOME/skills"

echo "SDLC agent — global install"
echo "  repo:        $REPO_ROOT"
echo "  kiro home:   $KIRO_HOME"
echo

# --- sanity check: required source dirs exist ------------------------------
for d in .kiro/agents .kiro/prompts .kiro/skills .kiro/templates; do
  if [ ! -d "$REPO_ROOT/$d" ]; then
    echo "ERROR: expected '$d' in the repo but it is missing. Run this from a full clone." >&2
    exit 1
  fi
done

# --- 1. copy prompts / skills / templates + AGENTS.md into sdlc-agent/ ------
echo "==> Copying prompts, skills, templates to $DEST"
mkdir -p "$DEST"
for d in prompts skills templates; do
  rm -rf "${DEST:?}/$d"
  cp -R "$SRC/$d" "$DEST/$d"
done
# AGENTS.md is referenced as a resource by the orchestrator, so ship it too.
cp "$REPO_ROOT/AGENTS.md" "$DEST/AGENTS.md"

# --- 2. install skills for global auto-discovery ---------------------------
# Prune skills a PREVIOUS install put in $SKILLS_DEST that are no longer in the
# repo (e.g. after a rename), using the manifest we write below. This only ever
# removes skills this installer created, never unrelated global skills.
MANIFEST="$DEST/.installed-skills"
current_skills=""
for skill_dir in "$SRC"/skills/*/; do
  current_skills="$current_skills $(basename "$skill_dir")"
done
if [ -f "$MANIFEST" ]; then
  while IFS= read -r prev; do
    [ -z "$prev" ] && continue
    case " $current_skills " in
      *" $prev "*) ;;  # still present — keep
      *) [ -d "$SKILLS_DEST/$prev" ] && rm -rf "${SKILLS_DEST:?}/$prev" && echo "==> Pruned removed skill: $prev" ;;
    esac
  done < "$MANIFEST"
fi

echo "==> Installing skills to $SKILLS_DEST"
mkdir -p "$SKILLS_DEST"
: > "$MANIFEST"
for skill_dir in "$SRC"/skills/*/; do
  name="$(basename "$skill_dir")"
  rm -rf "${SKILLS_DEST:?}/$name"
  cp -R "$skill_dir" "$SKILLS_DEST/$name"
  echo "$name" >> "$MANIFEST"
done

# --- 3. generate global agent configs with absolute paths ------------------
echo "==> Writing agent configs to $AGENTS_DEST"
mkdir -p "$AGENTS_DEST"

python3 - "$REPO_ROOT" "$DEST" "$AGENTS_DEST" <<'PY'
import json, os, sys

repo_root, dest, agents_dest = sys.argv[1], sys.argv[2], sys.argv[3]
src_agents = os.path.join(repo_root, ".kiro", "agents")

def rewrite(uri: str) -> str:
    # A resource URI is relative to the repo's .kiro/agents/ dir, e.g.
    #   file://../prompts/lead.md          -> .kiro/prompts/lead.md
    #   skill://../skills/x/SKILL.md       -> .kiro/skills/x/SKILL.md
    #   file://../../AGENTS.md             -> AGENTS.md (repo root)
    # We copy .kiro/{prompts,skills,templates} and AGENTS.md into sdlc-agent/,
    # so re-root each resolved path onto sdlc-agent/ by its basename layout.
    scheme, _, rel = uri.partition("://")
    resolved = os.path.normpath(os.path.join(src_agents, rel))
    kiro_rel = os.path.relpath(resolved, os.path.join(repo_root, ".kiro"))
    if kiro_rel.startswith(".."):
        # Outside .kiro/ (e.g. repo-root AGENTS.md) — map by basename into sdlc-agent/.
        target = os.path.join(dest, os.path.basename(resolved))
    else:
        target = os.path.join(dest, kiro_rel)  # e.g. sdlc-agent/prompts/lead.md
    return f"{scheme}://{target}"

count = 0
for fn in sorted(os.listdir(src_agents)):
    if not fn.endswith(".json"):
        continue
    cfg = json.load(open(os.path.join(src_agents, fn)))
    if isinstance(cfg.get("prompt"), str) and cfg["prompt"].startswith(("file://", "skill://")):
        cfg["prompt"] = rewrite(cfg["prompt"])
    if isinstance(cfg.get("resources"), list):
        cfg["resources"] = [
            rewrite(r) if isinstance(r, str) and r.startswith(("file://", "skill://")) else r
            for r in cfg["resources"]
        ]
    with open(os.path.join(agents_dest, fn), "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    count += 1
    print(f"    wrote {fn}")
print(f"    ({count} agents)")
PY

echo
echo "Done. The orchestrator + lead, researcher, developer, reviewer, janitor agents"
echo "are now available globally in Kiro (CLI and IDE)."
echo
echo "Run in ANY repository:"
echo "  cd /path/to/your-repo"
echo "  kiro-cli chat --agent orchestrator"
