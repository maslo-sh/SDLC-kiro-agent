# Scripts

Helpers for installing the SDLC orchestrator and its sub-agents into Kiro's user directory so they
are available as **global** agents in every workspace.

## `install-global.sh`

```
./scripts/install-global.sh
```

The pipeline definition lives under the repo's `.kiro/` directory (`.kiro/agents/`,
`.kiro/prompts/`, `.kiro/skills/`, `.kiro/templates/`) plus `AGENTS.md` at the repo root.

Installs into `~/.kiro` (override with `KIRO_HOME=/path/to/.kiro`). It:

1. Copies `.kiro/prompts/`, `.kiro/skills/`, `.kiro/templates/`, and `AGENTS.md` to
   `~/.kiro/sdlc-agent/`.
2. Copies each skill to `~/.kiro/skills/<name>/` so Kiro auto-discovers them globally.
3. Writes every agent config in `.kiro/agents/` (`orchestrator`, `lead`, `researcher`, `developer`,
   `reviewer`, `janitor`) to `~/.kiro/agents/`, rewriting each config's `prompt` and `resources`
   from the repo-relative `file://…` / `skill://…` paths to **absolute** paths under
   `~/.kiro/sdlc-agent/`.

Because the global configs use absolute paths into `~/.kiro/sdlc-agent/` (a copy — not this repo),
the agents keep working no matter which workspace you open. Re-run the script after editing any
prompt or skill in this repo to refresh the installed copy.

The pipeline needs **no seed data**: tickets come from what you describe at invocation (or Jira via
the `jira-query` skill), knowledge comes from the target workspace's own docs, and the hand-off
artifacts are written to a temporary `.sdlc/<TICKET-ID>/` directory inside whatever repo you run it
in.

### Using it

In any trusted workspace, pick the **orchestrator** agent as your session agent and name a ticket
(e.g. `Run PROJ-123 through the pipeline`). The Developer writes code into that workspace; the
scratch artifacts land in `.sdlc/<TICKET-ID>/` (add `.sdlc/` to that repo's `.gitignore` if you
don't want them committed).

## `uninstall-global.sh`

```
./scripts/uninstall-global.sh
```

Removes exactly what the installer added — the agent configs, the installed skills, and the
`~/.kiro/sdlc-agent/` payload — and leaves the rest of `~/.kiro` untouched.

## Requirements

`bash` and `python3` (used to transform the agent JSON). Both are standard on macOS and Linux.
