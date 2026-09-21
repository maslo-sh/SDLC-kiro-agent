# SDLC Agent Orchestration Tool

A reusable, importable definition of a software-development-lifecycle team: an **Orchestrator**
coordinating four **worker sub-agents**. It is plain Markdown plus Kiro agent configs, so you can
clone it into any project and run it in Kiro (or read it from Claude Code / Cursor) without extra
tooling.

## The model

Five roles — an **Orchestrator** and four workers it dispatches:

- **Orchestrator** — the primary agent. It accepts the operator's choice of sourcing path (pick a
  Jira ticket or deduce one from the code), dispatches each stage in order, consumes each worker's
  returned artifact and supplies it to the next stage, and runs the bounded Developer↔Reviewer review loop.
- **Lead** — sources, validates, and frames one ticket — either picked from Jira (list → choose →
  read) or deduced from the code — and returns a single framed ticket.
- **Researcher** — gathers best-practice guidance for the framed ticket from a knowledge source.
- **Developer** — implements the ticket, writing code and Implementation Notes, and revises on review
  feedback.
- **Reviewer** — reviews the code against a Definition-of-Done quality gate and returns an outcome of
  Approved or Changes Requested.

The workers do not hand off peer-to-peer. Every artifact a worker produces is returned to the
Orchestrator, which sequences the stages Lead → Researcher → Developer → Reviewer and runs the review
loop. The full workflow lives in [`AGENTS.md`](AGENTS.md).

## Install globally (use it in any repo)

Install the agents into your Kiro user directory so they're available in **every** workspace:

```
./scripts/install-global.sh
```

This copies the prompts, skills, and templates to `~/.kiro/sdlc-agent/`, installs the skills to
`~/.kiro/skills/`, and writes the five agent configs to `~/.kiro/agents/` with absolute paths. Re-run
it after editing prompts or skills to refresh. See [`scripts/README.md`](scripts/README.md) for
details and uninstall.

## Run with Kiro CLI

After `install-global.sh`, the five agents are available globally to `kiro-cli`. This is the most
reliable way to launch the pipeline.

**1. Confirm the agents are installed.** From any directory:

```
kiro-cli agent list
```

You should see `orchestrator`, `lead`, `researcher`, `developer`, and `reviewer` listed as `Global`.
(If you run this from inside this repo, they show as `Workspace` with an "Agent conflict … Using
workspace version" warning — that's expected, because this repo also defines them under
`.kiro/agents/`. It's harmless: the workspace copy simply wins here.)

**2. Launch the orchestrator.** `cd` into the project you want the pipeline to work on, then:

```
kiro-cli chat --agent orchestrator
```

**3. Name or describe a ticket** at the prompt, for example:

```
Run PROJ-123 through the pipeline.
```

or paste the ticket text directly if it isn't in a tracker.

The Orchestrator frames the ticket via the Lead, then dispatches the Researcher, Developer, and
Reviewer, running the review loop until the ticket is approved or the review cap (default 3) is
reached. The Developer writes code into the current workspace; the pipeline's hand-off artifacts go
to a temporary `.sdlc/<TICKET-ID>/` directory in that workspace (disposable — add `.sdlc/` to the
repo's `.gitignore` if you don't want it committed).

### Handy CLI commands

```
kiro-cli agent list                                  # see all agents and their scope
kiro-cli agent validate --path ~/.kiro/agents/orchestrator.json   # check a config parses
kiro-cli agent set-default orchestrator              # make it the default agent for `kiro-cli chat`
```

You can also run any worker directly for debugging, e.g. `kiro-cli chat --agent lead`.

## Run in the Kiro IDE

Select the **orchestrator** agent as the session agent from the agent picker, then name a ticket as
above.

If newly installed global agents don't appear in the picker, the IDE list is stale — Kiro scans
`~/.kiro/agents/` on startup and does not always live-reload. Run **Developer: Reload Window** from
the Command Palette (`Cmd+Shift+P`), or fully restart Kiro. Note also that if the workspace you're in
defines an agent of the same name under its own `.kiro/agents/`, that workspace version is shown
instead of the global one (workspace overrides global). If the IDE still doesn't show them after a
restart, use the Kiro CLI path above, which reads the same global configs.

## Handoff workflow

| Stage | Worker | Orchestrator supplies | Worker returns | Artifact |
|-------|--------|-----------------------|----------------|----------|
| 1. Frame | Lead | Sourcing path (pick a Jira ticket, or deduce from code) | Framed ticket | (in conversation) |
| 2. Research | Researcher | Framed ticket | Research Brief | `research-brief.md` |
| 3. Implement | Developer | Research Brief + framed ticket | Implementation Notes + code | `implementation-notes.md` |
| 4. Review (loop) | Reviewer | Implementation Notes + code | Review Report | `review-report-<n>.md` |

**Review loop.** After the initial implementation, the Orchestrator runs a bounded
Developer↔Reviewer loop. On **Changes Requested** while under the review cap, it supplies the Review
Report back to the Developer, who returns a revised implementation for another review. The loop ends
on **Approved** or when the cap is reached with an outstanding Changes Requested. The full workflow
is in [`AGENTS.md`](AGENTS.md).

## Layout

| Path | What it is |
|------|------------|
| [`.kiro/agents/`](.kiro/agents/) | The five Kiro agent configs (orchestrator + four workers) |
| [`.kiro/prompts/`](.kiro/prompts/) | The role prompt bodies each agent uses as its system prompt |
| [`.kiro/skills/`](.kiro/skills/) | The Ticket Management, Knowledge Source, and Quality Gate skills |
| [`.kiro/templates/`](.kiro/templates/) | Blank templates for the Research Brief, Implementation Notes, and Review Report |
| [`scripts/`](scripts/) | `install-global.sh` (and uninstall) to install the agents into `~/.kiro/` |

## Configuring the sources

The council reaches its tickets and knowledge through skills, each a documented operation
contract. The Lead sources a ticket one of two ways:

- **Jira Ticket Selection** (quicker) —
  [`.kiro/skills/jira-ticket-selection/SKILL.md`](.kiro/skills/jira-ticket-selection/SKILL.md)
  (`list_tickets`, `select_ticket`). Lists the open Jira tickets and lets the operator pick one,
  then hands the chosen key to Jira Ticket Management's `read`. Same Jira credentials as below.
- **Task Framing — Codebase Investigation** (longer) —
  [`.kiro/skills/task-framing-codebase-investigation/SKILL.md`](.kiro/skills/task-framing-codebase-investigation/SKILL.md).
  Investigates the repository, deduces the single highest-value piece of work, and proposes one task
  frame. Read-only; needs no external credentials.
- **Jira Ticket Management** —
  [`.kiro/skills/jira-ticket-management/SKILL.md`](.kiro/skills/jira-ticket-management/SKILL.md)
  (`read`, `change_ticket_status`, `comment`). Talks to the Jira Cloud REST API with `curl`, using
  `JIRA_BASE_URL` / `JIRA_EMAIL` / `JIRA_API_TOKEN` from the environment or a `.env` file in the repo
  the agent runs in.
- **Knowledge Source** —
  [`.kiro/skills/knowledge-source/SKILL.md`](.kiro/skills/knowledge-source/SKILL.md)
  (`search`, `read`). Default: the current workspace's own docs (READMEs, `docs/`, ADRs). Can point
  at a wiki or search index instead.

Both defaults need no configuration and no seed content — the pipeline works against whatever repo
you run it in. To use a different source, fulfill the same operation contract against it and give the
relevant agent (the Lead for tickets, the Researcher for knowledge) the tools it needs — for example
an MCP server — in that agent's config. Each skill's `SKILL.md` documents the mapping.

## Cross-machine reuse

Every reference — from `AGENTS.md`, the agent configs, and this README — is a **repo-relative path**.
No absolute or machine-specific paths appear anywhere, so a fresh clone works unchanged on any
machine.
