# SDLC Agent Orchestration Tool

This is the cross-tool entry point for the agentic SDLC flow — an importable repository that defines
a software-development-lifecycle team as one **Orchestrator** plus four **worker sub-agents**. It is
plain Markdown and Kiro agent configs: Kiro loads the agents in `.kiro/agents/`, Claude Code and
Cursor read this file to discover the model, and Claude Code can treat it as its entry point by
symlinking `CLAUDE.md → AGENTS.md`.

The **entry point** is one ticket **explicitly named by the operator** when the Orchestrator is
invoked. The Orchestrator dispatches that ticket id to the Lead, whose job is to load, validate, and
frame that specific ticket rather than choosing from a backlog.

## The Model — Orchestrator + Four Sub-agents

A primary **Orchestrator** coordinates four **worker sub-agents**: a **Lead** (loads, validates, and
frames one explicitly named ticket), a **Researcher** (gathers best-practice guidance), a
**Developer** (writes code), and a **Reviewer** (reviews against a Definition-of-Done).

Control is **centralized at the Orchestrator**. It is a coordinating layer *above* the four workers,
not a peer to them: it dispatches each stage to the responsible worker sub-agent,
consumes the artifact that worker returns, and supplies it as the next stage's input. The workers do
**not** hand off peer-to-peer; every artifact flows back to the Orchestrator, which sequences the
stages and runs the review loop.

```
                        ┌─────────────────────────────────────┐
                        │             ORCHESTRATOR            │
   operator names  ───► │  dispatches stages in order,        │
   a ticket id          │  consumes each returned artifact,   │
                        │  runs the bounded review loop       │
                        └─────────────────────────────────────┘
                           │  ▲     │  ▲      │  ▲      │  ▲
              named ticket │  │framed│  │brief │  │notes │  │review
                     id    ▼  │ticket▼  │      ▼  │+code ▼  │report
                        ┌──────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
                        │ Lead │  │Researcher│  │Developer │  │ Reviewer │
                        │frame │  │  brief   │  │implement │  │  review  │
                        └──────┘  └──────────┘  └──────────┘  └──────────┘

        (review loop: Reviewer → Orchestrator → Developer → Orchestrator → Reviewer …)
```

The Orchestrator tracks the current stage, the review count, and the artifact paths **in its own
conversation** — there is no shared state file. Each ticket's produced artifacts (the Research
Brief, Implementation Notes, and Review Reports) are hand-off/scratch files, written to a temporary
working directory **inside the workspace being worked on** at `.sdlc/<TICKET-ID>/`. They are
disposable — add `.sdlc/` to that repo's `.gitignore` if you don't want them committed. The actual
deliverable is the code the Developer writes.

## The Orchestrator

The Orchestrator (`.kiro/prompts/orchestrator.md`) is the primary agent you invoke to drive one named
ticket end to end. It:

- accepts the **explicitly named ticket id** the operator supplies at invocation,
- **dispatches each stage in order** — Lead frames → Researcher briefs → Developer implements →
  Reviewer reviews — to the responsible worker sub-agent,
- **consumes the artifact each worker returns** and supplies it as input to the next stage,
- runs and bounds the **Developer↔Reviewer review loop**, enforcing a maximum number of reviews
  (default **3**; the operator may override at invocation).

The Orchestrator performs no worker behavior; it delegates every stage to the worker sub-agents.

## Handoff Workflow

The four stages run in order. Stages 1–3 run once each; stage 4 is a bounded loop.

Every input is **supplied by the Orchestrator**; every artifact is **returned to the Orchestrator**.

| Stage | Worker | Orchestrator supplies | Worker returns | Artifact path |
|-------|--------|-----------------------|----------------|---------------|
| 1. Frame | Lead | Explicitly named ticket id | Framed ticket | (in conversation) |
| 2. Research | Researcher | Framed ticket | Research Brief | `.sdlc/<TICKET-ID>/research-brief.md` |
| 3. Implement | Developer | Research Brief + framed ticket | Implementation Notes + code | `.sdlc/<TICKET-ID>/implementation-notes.md` |
| 4. Review (loop) | Reviewer | Implementation Notes + code | Review Report (`Approved` / `Changes Requested`) | `.sdlc/<TICKET-ID>/review-report-<n>.md` |
| 4. Revise (loop) | Developer | Review Report feedback | Revised Implementation Notes + code | `implementation-notes-<n+1>.md` |

### Review loop

After the initial implementation the Orchestrator runs a bounded Developer↔Reviewer loop, counting
each review it dispatches:

1. **Reviewer** evaluates the Implementation Notes and code against the quality-gate skill and
   returns a Review Report with an outcome of `Approved` or `Changes Requested`.
2. On **`Approved`** — the loop ends; the ticket is approved (terminal).
3. On **`Changes Requested`** while reviews performed < the cap — the Orchestrator supplies the
   Review Report to the Developer, which returns a revised implementation, then the Reviewer runs
   again.
4. On **`Changes Requested`** when the cap is reached — the loop ends without approval (terminal),
   and the Orchestrator reports the outstanding changes.

The review cap defaults to **3** and can be overridden by the operator at invocation.

### Handoff relationships

There is no peer-to-peer handoff. Each relationship is a worker returning an artifact to the
Orchestrator, which then supplies it to the next stage:

1. **Operator → Orchestrator → Lead.** The operator names a ticket; the Orchestrator dispatches that
   ticket id to the Lead, which loads, validates, and frames it.
2. **Lead → Orchestrator → Researcher.** The Lead returns the framed ticket; the Orchestrator
   supplies it to the Researcher.
3. **Researcher → Orchestrator → Developer.** The Researcher returns the Research Brief; the
   Orchestrator supplies it to the Developer.
4. **Developer → Orchestrator → Reviewer.** The Developer returns the Implementation Notes and code;
   the Orchestrator supplies them to the Reviewer.

Within the review loop, the Reviewer returns the Review Report to the Orchestrator, which — on
`Changes Requested` under the cap — supplies it to the Developer for a revised implementation.

## Installing globally

To use the pipeline in **any** workspace, install the agents into your Kiro user directory
(`~/.kiro/`) by running the install script from this repo:

```
./scripts/install-global.sh
```

The script copies the prompts, skills, and templates to `~/.kiro/sdlc-agent/`, installs the three
skills to `~/.kiro/skills/` (so Kiro auto-discovers them everywhere), and writes the five agent
configs to `~/.kiro/agents/` with their `prompt`/`resources` rewritten to absolute paths under
`~/.kiro/sdlc-agent/`. Re-run it after editing any prompt or skill in this repo to refresh the global
copy. See [`scripts/README.md`](scripts/README.md) for details and uninstall.

## Launching (Kiro CLI or IDE)

Once installed globally, the five agents are available in every workspace.

**Kiro CLI (most reliable).** From any directory, confirm they installed with `kiro-cli agent list`
(look for `orchestrator`, `lead`, `researcher`, `developer`, `reviewer` as `Global`). Then `cd` into
the project you want to work on and launch:

```
kiro-cli chat --agent orchestrator
```

**Kiro IDE.** Select the **orchestrator** agent as the session agent from the agent picker. If newly
installed global agents don't appear, the picker is stale — run **Developer: Reload Window** or
restart Kiro (Kiro scans `~/.kiro/agents/` at startup and doesn't always live-reload). If a workspace
defines an agent of the same name, that workspace version is shown instead of the global one.

Then name or describe a ticket, for example:
- `Run PROJ-123 through the pipeline` (fetched from Jira via the jira-query skill), or
- `Take this ticket through the pipeline: <paste the ticket text>`.

The Orchestrator frames it via the Lead, then dispatches the Researcher, Developer, and Reviewer,
running the review loop until the ticket is approved or the review cap (default 3) is reached. The
Developer writes the code into the current workspace; the pipeline's hand-off artifacts go to a
temporary `.sdlc/<TICKET-ID>/` directory in that workspace.

You can also run the agents from this repo directly (without installing) by opening it as a trusted
workspace — the workspace configs in `.kiro/agents/` use repo-relative paths.

Other harnesses: Kiro and Claude Code auto-discover the three skills under
`.kiro/skills/<name>/SKILL.md`;
Cursor and other cross-tool agents read this file to discover the model and the repo-relative links
below.

## Links

### Role prompt bodies (`.kiro/prompts/`)

- [Orchestrator](.kiro/prompts/orchestrator.md)
- [Lead](.kiro/prompts/lead.md)
- [Researcher](.kiro/prompts/researcher.md)
- [Developer](.kiro/prompts/developer.md)
- [Reviewer](.kiro/prompts/reviewer.md)

### Kiro agent configs (`.kiro/agents/`)

- [orchestrator.json](.kiro/agents/orchestrator.json)
- [lead.json](.kiro/agents/lead.json)
- [researcher.json](.kiro/agents/researcher.json)
- [developer.json](.kiro/agents/developer.json)
- [reviewer.json](.kiro/agents/reviewer.json)

### Skills (`.kiro/skills/`)

- [Ticket Management](.kiro/skills/ticket-management/SKILL.md)
- [Knowledge Source](.kiro/skills/knowledge-source/SKILL.md)
- [Quality Gate](.kiro/skills/quality-gate/SKILL.md)

All links are repo-relative so they resolve on any machine after a clone.
