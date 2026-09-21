---
name: jira-ticket-selection
description: The Lead's "pick a ticket from Jira" path — list the open Jira tickets, present them to the operator to choose one, and return the chosen issue key for framing. Read-only; writes no files.
version: "1.0"
---

# Jira Ticket Selection Skill

The Jira Ticket Selection skill is the **quicker** of the Lead's two ways of sourcing work: instead
of deducing a task from the code (see the `task-framing-codebase-investigation` skill), it lists the
open tickets already in **Jira**, lets the operator choose one, and returns that issue key. Framing
the chosen ticket's detail is then done through the `jira-ticket-management` skill's `read` operation
— this skill only lists and selects.

It talks to the **Jira Cloud REST API** (v3) with `curl`, using the **same credentials** as the
`jira-ticket-management` skill.

## Credentials

All operations authenticate with a Jira account email + API token against a Jira base URL, read from
the environment. The repository the agent runs in is assumed to provide these **either as already-
exported environment variables** (e.g. from the launch/scheduler environment or your shell profile)
**or in a `.env` file** at the repo root:

| Variable | Meaning |
|----------|---------|
| `JIRA_BASE_URL` | Jira Cloud base URL, e.g. `https://your-org.atlassian.net` |
| `JIRA_EMAIL` | Atlassian account email used for basic auth |
| `JIRA_API_TOKEN` | Atlassian API token for that account |

Load them with this preamble before any call — it prefers already-exported vars and falls back to a
local `.env`:

```bash
# Prefer already-exported env vars (e.g. from scheduler env); fall back to .env file
if [ -z "$JIRA_API_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi
```

Never print the token, the `Authorization` header, or full raw responses containing credentials.
Never ask the operator to paste a token into chat.

## Operations

| Operation | Input | Output | Meaning |
|-----------|-------|--------|---------|
| `list_tickets(project, jql?)` | a project key + optional JQL filter | the open tickets as `{ key, summary, status }` rows | List the tickets the operator could pick from |
| `select_ticket(tickets)` | the listed tickets | the single issue key the operator chose | Present the list and capture the operator's choice |

After `select_ticket` returns an issue key, load that ticket's full detail with the
**`jira-ticket-management` skill's `read(ticket_id)`** operation — this skill does not re-fetch it.

### `list_tickets(project, jql?)`

Search the project for open, actionable issues. Default to issues that are not done; the operator may
supply their own JQL to narrow it (for example, by assignee, label, or sprint).

```bash
if [ -z "$JIRA_API_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi

# Default JQL lists open issues in the project, newest first. Override <JQL> to narrow.
curl -sS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Accept: application/json" \
  --get "$JIRA_BASE_URL/rest/api/3/search" \
  --data-urlencode "jql=project = <PROJECT> AND statusCategory != Done ORDER BY updated DESC" \
  --data-urlencode "fields=summary,status" \
  --data-urlencode "maxResults=50"
```

Map each returned issue to a `{ key, summary, status }` row, using `key`, `fields.summary`, and
`fields.status.name`. If the search returns no issues, report that the project has no open tickets
rather than inventing candidates.

### `select_ticket(tickets)`

Present the listed tickets to the operator as a short, numbered list (key — summary — status) and ask
which one to work on. Return the **single issue key** the operator picks. Do not choose on the
operator's behalf; if they decline to pick, report that no ticket was selected. The chosen key is the
input to the `jira-ticket-management` `read(ticket_id)` operation.

## Notes

- These operations use `curl`, so the Lead agent needs the `shell` tool.
- Quote interpolated values to avoid shell-injection when building the commands.
- This skill is **read-only**: it lists and selects, and writes no files and changes no ticket state.
  Recording progress on the chosen ticket (status changes, comments) is the `jira-ticket-management`
  skill's job.
