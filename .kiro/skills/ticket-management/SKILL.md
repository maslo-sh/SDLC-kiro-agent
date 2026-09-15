---
name: ticket-management
description: Read a Jira ticket, change its status, and comment on it via the Jira Cloud REST API using curl. Use to load a named ticket and record its progress through the SDLC pipeline.
version: "2.0"
---

# Ticket Management Skill

The Ticket Management skill is the interface the **Lead** uses to load a ticket's detail and record
its progress as it moves through the pipeline. It talks to the **Jira Cloud REST API** (v3) with
`curl`.

The pipeline is entered by the **operator naming a ticket** when the Orchestrator is invoked; the
Orchestrator dispatches that ticket id (the Jira issue key, e.g. `OKAPI-1234`) to the Lead, which
uses `read` to load it. The three operations are `read`, `change_ticket_status`, and `comment`.

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
| `read(ticket_id)` | Jira issue key | the ticket's summary, status, and description | Load one ticket's full detail for the Lead to frame |
| `change_ticket_status(ticket_id, status)` | issue key + target status name | the applied transition | Move the ticket to a new workflow status |
| `comment(ticket_id, comment)` | issue key + comment text | the created comment | Add a comment to the ticket |

### `read(ticket_id)`

Fetch the issue and use its `fields.summary` as the title, `fields.status.name` as the status, and
`fields.description` as the body.

```bash
if [ -z "$JIRA_API_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi

curl -sS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Accept: application/json" \
  "$JIRA_BASE_URL/rest/api/3/issue/<TICKET_ID>?fields=summary,status,description"
```

### `change_ticket_status(ticket_id, status)`

Jira status changes are **workflow transitions**, and transition IDs are workflow/status-specific —
**never hardcode them**. Look up the available transitions, find the one whose target status matches
`status` (for example, status `Code review` via a transition named `Move to Code Review`), then POST
its id.

```bash
if [ -z "$JIRA_API_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi

# 1. Look up the available transitions for the ticket (IDs are workflow/status-specific)
curl -sS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Accept: application/json" \
  "$JIRA_BASE_URL/rest/api/3/issue/<TICKET_ID>/transitions"

# 2. Find the transition whose target status is the requested one (e.g. "Code review")
#    and POST its id:
curl -sS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Content-Type: application/json" \
  -X POST -d '{"transition":{"id":"<TRANSITION_ID>"}}' \
  "$JIRA_BASE_URL/rest/api/3/issue/<TICKET_ID>/transitions"
```

If no transition targets the requested status (the workflow does not allow that move from the current
status), do not force it — report the available transitions back to the Orchestrator instead.

### `comment(ticket_id, comment)`

Add a comment. The v3 API expects the body in Atlassian Document Format (ADF).

```bash
if [ -z "$JIRA_API_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi

curl -sS -u "$JIRA_EMAIL:$JIRA_API_TOKEN" -H "Content-Type: application/json" \
  -X POST "$JIRA_BASE_URL/rest/api/3/issue/<TICKET_ID>/comment" \
  -d '{
    "body": {
      "type": "doc",
      "version": 1,
      "content": [
        { "type": "paragraph", "content": [ { "type": "text", "text": "<COMMENT>" } ] }
      ]
    }
  }'
```

## Status mapping

Jira workflow/transition names are project-specific, so `change_ticket_status` resolves the
transition **by matching the target status name** against the list returned by the transitions
endpoint — it never assumes a fixed id. Typical council statuses and the transitions they map to:

| Council status | Typical Jira transition / target status |
|----------------|-----------------------------------------|
| `in-progress`  | *In Progress* / *Start Progress* |
| `in-review`    | *Code review* / *Move to Code Review* |
| `done`         | *Done* / *Close* |

## Notes

- `ticket_id` is the Jira issue key exactly as the operator names it at invocation (e.g. `OKAPI-1234`).
- These operations use `curl`, so the Lead agent needs the `shell` tool. Quote interpolated values to avoid shell-injection when building the commands.
