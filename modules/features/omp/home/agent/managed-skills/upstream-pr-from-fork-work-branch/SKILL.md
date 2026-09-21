---
name: upstream-pr-from-fork-work-branch
description: "Propose one concern as a PR to the upstream repo you forked when your fork's work branch carries unrelated commits (dependency fixes, host tooling): cut a fresh branch from the shared base, cherry-pick only the concern, verify without polluting, prove purity, and open a cross-repo PR with the real CI state."
---

# Upstream PR from a fork's work branch

Use when you must send one concern to the upstream project, but your fork's work branch
carries commits that do not belong in that PR: an unrelated dependency fix, a host-specific
dev shell, a revert of someone else's experiment.

The goal is a branch whose diff is exactly the concern, plus an honest statement of what was
left out and why.

## 1. Confirm the base

```bash
git rev-parse --short master                       # fork's base
gh api repos/<upstream>/commits/<default> --jq '.sha[0:9]'
```

When the two match, cherry-picks from the work branch apply cleanly. When they differ,
cherry-pick and expect conflicts in files the upstream moved.

## 2. Cut from the base, never from the work branch

```bash
git checkout -b m3e-expressive master
```

A branch cut from the work branch drags its extra commits into the PR diff. `--head`
for a cross-repo PR must be `<fork-owner>:<branch>`; using the fork's work branch is the
mistake this skill exists to prevent.

## 3. Cherry-pick only the concern

List the commits and pick by sha, excluding host tooling and unrelated fixes:

```bash
git log --oneline <fix-base>..<work-head>
for c in <sha1> <sha2> ...; do
  if git cherry-pick "$c" >/tmp/cp.log 2>&1; then echo "picked $c"; else sed -n '1,12p' /tmp/cp.log; break; fi
done
git log --oneline master..HEAD        # must equal the intended set and count
```

Trap that cost a cycle: `git cherry-pick -q` is not a valid flag. Git prints usage, the loop's
`||` branch fires, and a bare `break` leaves the branch empty while the log looks like nothing
happened. Drop `-q` and check the resulting log against the intended count.

## 4. Verify when the base cannot build

A base that cannot resolve a dependency (a dead JitPack coordinate, a yanked artifact) fails
every `:app` task before it reaches your code. Verify the concern alone by applying the fix as
an **uncommitted** edit, building, then reverting it:

```bash
# edit the catalog line by hand; then
./gradlew :app:compileDebugKotlin
git checkout -- gradle/libs.versions.toml
```

If the dev shell exists only on the work branch, restore it untracked for the build and delete
it before pushing:

```bash
git show <work-branch>:shell.nix | tee shell.nix >/dev/null
rm -f shell.nix
```

Cherry-picks of commits whose identical trees already passed the full gate on the work branch
do not need a second full gate. Say in the PR body which command proved what, not more.

## 5. Prove the branch is pure before every push

```bash
git diff --stat master..<branch> -- gradle/libs.versions.toml shell.nix   # expect no output
```

An uncommitted temporary edit is invisible here, so a later `git add -A` or `git commit -a`
slips it into the branch. Revert first, then check, then push.

## 6. Open the cross-repo PR

```bash
gh pr create --repo <upstream> --base <default> --head <fork-owner>:<branch> \
  --title "..." --body-file /tmp/pr-body.md
```

Fill the upstream PR template from the repository, not from memory: fetch
`.github/PULL_REQUEST_TEMPLATE.md` (it may 404 on `master`; then use the template the user
supplies).

## 7. Report the real CI state

```bash
gh run list --repo <upstream> --limit 4 --json name,status,conclusion,headBranch,event
gh pr checks <n> --repo <upstream>
```

A first-time contributor's `pull_request` run shows `action_required`: GitHub holds the
workflow until a maintainer approves it. `gh pr checks` can list passing third-party apps
(CodeFactor, Sourcery) while **no build has run**. Never report CI as green in that state, and
warn that a known base problem (a dead dependency coordinate) will fail the run once approved.

## 8. Say what was left out

The diff cannot show an excluded commit. Name each one in the body, with its reason, and state
the verification that was done instead. If a reviewer may read a dependency pin as new, check
first whether the base already resolves that version transitively, and say so.

Corollary: review apps may append to the PR description after creation. Read the current body
(`gh pr view <n> --json body`) before editing it from a file, or the appended text is lost.
