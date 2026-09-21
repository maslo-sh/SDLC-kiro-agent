---
name: gitlab-push-commit
description: Commit local changes and push them to a branch on a self-hosted GitLab over HTTPS using a user-provided access token. Use to publish the Developer's work to a remote branch.
version: "1.0"
---

# GitLab Push Commit Skill

The GitLab Push Commit skill publishes local work by committing it and pushing to a branch on a
**self-hosted GitLab** instance over HTTPS, authenticating with the user's own access token. It
drives the local `git` client (not the REST API), so it pushes the actual working-tree commits.

## Credentials

Authenticate with a self-hosted GitLab access token read from the environment. The repository the
agent runs in is assumed to provide these **either as already-exported environment variables** (e.g.
from the launch/scheduler environment or your shell profile) **or in a `.env` file** at the repo
root:

| Variable | Meaning |
|----------|---------|
| `GITLAB_HOST` | Self-hosted GitLab host, e.g. `gitlab.your-company.com` |
| `GITLAB_TOKEN` | Personal/project access token with `write_repository` (or `api`) scope |

Load them with this preamble before any call — it prefers already-exported vars and falls back to a
local `.env`:

```bash
# Prefer already-exported env vars (e.g. from scheduler env); fall back to .env file
if [ -z "$GITLAB_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi
```

Never print the token, the push URL containing it, or any `Authorization`/`PRIVATE-TOKEN` header.
Never ask the operator to paste a token into chat. Keep the token out of `git remote -v` output by
using it only in an ephemeral push URL as shown below, never by baking it into the saved remote.

## Operation

| Operation | Input | Output | Meaning |
|-----------|-------|--------|---------|
| `push_commit(branch, message)` | target branch name + commit message | the pushed branch and commit sha | Stage tracked changes, commit them, and push the branch to the remote |

### `push_commit(branch, message)`

Stage the working-tree changes, create a commit, and push the branch to the self-hosted remote using
a token-authenticated HTTPS URL. The token is passed only in the ephemeral push URL for a single
`git push`, so it never persists in the repo's remote configuration.

```bash
if [ -z "$GITLAB_TOKEN" ] && [ -f .env ]; then set -a; source .env; set +a; fi

# Derive the "group/project" path from the existing origin remote so the push URL
# targets the same repository without hardcoding it.
REPO_PATH=$(git config --get remote.origin.url | sed -E 's#^.*[:/]([^/]+/[^/]+?)(\.git)?$#\1#')

git checkout -B "<BRANCH>"
git add -A
git commit -m "<MESSAGE>"

# Push using an ephemeral token URL (oauth2:<token>). Do not echo this URL.
git push "https://oauth2:$GITLAB_TOKEN@$GITLAB_HOST/$REPO_PATH.git" "<BRANCH>"
```

If there is nothing to commit, do not create an empty commit — report that the working tree is clean
instead. If the push is rejected (non-fast-forward, protected branch), do not force-push; report the
rejection so the operator can decide.

## Notes

- This operation uses the local `git` client, so the agent needs the `shell` tool.
- Quote interpolated values (`<BRANCH>`, `<MESSAGE>`) to avoid shell-injection when building commands.
- `push_commit` never force-pushes and never rewrites history; those are destructive and out of scope.
