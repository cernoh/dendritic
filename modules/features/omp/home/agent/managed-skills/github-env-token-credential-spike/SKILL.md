---
name: github-env-token-credential-spike
description: "Prove a GitHub token authenticates clone/push/delete against a repo without leaking it: env-var credential helper, disposable branch, API-side verification, remote left clean. Use when a test or CI job needs a credential route settled, or before storing a token as a CI secret."
---

# When to use

Settling "how does a credential reach this code, and does it actually work" for a private
GitHub repo: a network test's credential route, a CI secret, or before handing a token to
libgit2/git2-rs. The same recipe applies to any HTTPS git remote.

# Recipe

Keep the token in the environment only. Never in the URL (`https://x-access-token:$TOKEN@…`
leaks into `argv`, the process table, and `.git/config`), never `echo`ed.

```bash
set -euo pipefail
export VAULT_TOKEN="$(gh auth token)"           # local; CI uses a repo secret instead
cred='!f() { echo username=x-access-token; echo password=$VAULT_TOKEN; }; f'

git -c credential.helper="$cred" clone https://github.com/OWNER/REPO.git "$work/tv"
cd "$work/tv"
git config user.name spike; git config user.email spike@local
git commit --allow-empty -q -m "spike: credential probe"
BR="spike-$(date +%s)"
git -c credential.helper="$cred" push -q origin "HEAD:refs/heads/$BR"
```

Verify from the API, not from git's own output, then delete and prove the repo is back:

```bash
gh api repos/OWNER/REPO/branches/$BR --jq '.commit.sha[0:7]'
git -c credential.helper="$cred" push -q origin --delete "$BR"
gh api repos/OWNER/REPO/branches --jq '[.[].name] | join(",")'   # base branch only
```

Push proves write access; ref deletion proves it is not read-only, and leaves a scratch
remote as found. A disposable branch beats pushing the default branch: no fixture history
accumulates, and a failed run leaves at most one orphan branch the next run prunes.

# Traps

- `git push -c credential.helper=…` fails (`unknown switch 'c'`). `-c` goes **before** the
  subcommand: `git -c credential.helper="$cred" push …`.
- `clone` does not persist the helper; pass `-c` (or `GIT_ASKPASS`) to every later command.
- With `set -e`, an early failure skips later `echo "$BR" > /tmp/state` lines and the next
  invocation has no state to read. Write state before the risky step, or re-derive it.
- Scope check first: `gh auth status` prints token scopes. `repo` covers read **and** write
  on private repos.
- `gh auth token` (OAuth, account-wide `repo` scope) is fine for a workstation probe but
  cannot be the CI value. CI needs a dedicated fine-grained PAT (Repository access: one
  repo; Contents: Read and write) stored as a repository secret.
- `GITHUB_TOKEN`/`github.token` cannot reach another repo: GitHub documents its permissions
  as "limited to the repository that contains your workflow". Fork PRs get no secrets, so
  gate the network test on variable presence and **skip** rather than fail.
- For git2-rs the same token goes to
  `RemoteCallbacks::credentials(|_, _, _| Cred::userpass_plaintext("x-access-token", &token))`
  (HTTP Basic, the mechanism the git CLI just exercised). Record it as inference until a
  test exercises the libgit2 leg.
