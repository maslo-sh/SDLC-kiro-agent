---
name: gitlab-review-comments
description: Retrieve reviewer comments on a self-hosted GitLab merge request and reply to a specific comment, via the REST API (v4) using curl and a user-provided access token. Use to read and respond to review feedback.
version: "1.0"
---

# GitLab Review Comments Skill

The GitLab Review Comments skill reads the discussion left by reviewers on a **self-hosted GitLab**
merge request and posts replies to a specific reviewer comment, through the **GitLab REST API (v4)**
with `curl`, authenticating with the user's own access token. Retrieving comments and replying are
two operations on the same resource (a merge request's discussions), so they live together in one
skill.

## Credentials

Authenticate with a self-hosted GitLab access token read from the environment. The repository the
agent runs in is assumed to provide these **either as already-exported environment variables** (e.g.
from the launch/scheduler environment or your shell profile) **or in a `.env` file** at the repo
root:

| Variable | Meaning |
|----------|---------|
| `GITLAB_BASE_URL` | Self-hosted API root, e.g. `https://gitlab.your-company.com/api/v4` |
| `GITLAB_PROJECT_ID` | Project id or URL-encoded `group/project` path, e.g. `42` or `mygroup%2Fmyrepo` |
| `GITLAB_TOKEN` | Personal/project access token with `api` scope |

Load them with this preamble before any call — it prefers already-exported vars and falls back to a
local `.env`:

```bash
# Prefer already-exported env vars (e.g. from scheduler env); fall back to .env file
if [ -z "$GITLAB_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi
```

Never print the token, the `PRIVATE-TOKEN` header, or full raw responses containing credentials.
Never ask the operator to paste a token into chat.

## Operations

A merge request is addressed by its project-scoped `iid` (the MR number, e.g. from the
create-merge-request skill). Reviewer feedback is organized into **discussions**, each holding one or
more **notes**; a reply is a new note added to an existing discussion.

| Operation | Input | Output | Meaning |
|-----------|-------|--------|---------|
| `get_review_comments(mr_iid)` | MR iid | reviewer discussions with their notes (author, body, discussion id, note id) | Retrieve the comments other reviewers left on the merge request |
| `reply_to_comment(mr_iid, discussion_id, reply)` | MR iid + discussion id + reply text | the created reply note | Post a reply into an existing reviewer discussion |

### `get_review_comments(mr_iid)`

Fetch the MR's discussions. Each discussion's `notes` array holds the reviewer comments; use each
note's `author`, `body`, and `id`, and the enclosing `discussion.id` to reply. Notes where
`system` is `true` are GitLab-generated activity (e.g. "changed the description"), not reviewer
comments — skip them when reading feedback.

```bash
if [ -z "$GITLAB_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi

curl -sS --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_BASE_URL/projects/$GITLAB_PROJECT_ID/merge_requests/<MR_IID>/discussions"
```

### `reply_to_comment(mr_iid, discussion_id, reply)`

Add a reply note to the discussion identified by `discussion_id` (the `id` of the discussion that
holds the reviewer comment you are answering). Use `--data-urlencode` so the reply body is encoded
safely.

```bash
if [ -z "$GITLAB_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi

curl -sS --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -X POST "$GITLAB_BASE_URL/projects/$GITLAB_PROJECT_ID/merge_requests/<MR_IID>/discussions/<DISCUSSION_ID>/notes" \
  --data-urlencode "body=<REPLY>"
```

To reply to a specific reviewer comment, first `get_review_comments` to find the `discussion.id`
that contains that reviewer's note, then pass it as `<DISCUSSION_ID>`.

## Notes

- These operations use `curl`, so the agent needs the `shell` tool.
- Quote interpolated values to avoid shell-injection when building the commands.
- `discussion_id` is the discussion's `id` from `get_review_comments`, not the individual note id.
