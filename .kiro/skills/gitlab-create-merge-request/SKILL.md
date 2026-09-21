---
name: gitlab-create-merge-request
description: Open a merge request on a self-hosted GitLab via the REST API (v4) using curl and a user-provided access token. Use to propose a pushed branch for review.
version: "1.0"
---

# GitLab Create Merge Request Skill

The GitLab Create Merge Request skill opens a merge request on a **self-hosted GitLab** instance
through the **GitLab REST API (v4)** with `curl`, authenticating with the user's own access token. It
proposes an already-pushed source branch for merge into a target branch.

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

## Operation

| Operation | Input | Output | Meaning |
|-----------|-------|--------|---------|
| `create_merge_request(source_branch, target_branch, title, description)` | source + target branch names, MR title, MR description | the created MR's iid and web url | Open a merge request from the source branch into the target branch |

### `create_merge_request(source_branch, target_branch, title, description)`

POST the MR to the project's merge_requests endpoint. Use `--data-urlencode` so the title and
description are encoded safely.

```bash
if [ -z "$GITLAB_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi

curl -sS --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -X POST "$GITLAB_BASE_URL/projects/$GITLAB_PROJECT_ID/merge_requests" \
  --data-urlencode "source_branch=<SOURCE_BRANCH>" \
  --data-urlencode "target_branch=<TARGET_BRANCH>" \
  --data-urlencode "title=<TITLE>" \
  --data-urlencode "description=<DESCRIPTION>"
```

Report the returned `iid` (the project-scoped MR number used by the review-comments skill) and
`web_url`. If a merge request already exists for the same source/target pair, GitLab returns an
error rather than a duplicate — surface that instead of retrying.

## Notes

- This operation uses `curl`, so the agent needs the `shell` tool.
- Quote interpolated values to avoid shell-injection when building the commands.
- The MR `iid` returned here is the input other GitLab skills (e.g. review comments) use to address
  this merge request.
