# Branch and PR Workflow

Before making any code changes, check the current branch with `git branch --show-current`.

## Rule 1: Never edit on the default branch

If on the default branch (`main`, `master`, `develop`, `trunk`, or whatever `origin/HEAD` points to), create a feature branch first. Derive the name from the task (for example, `feat/add-auth` or `fix/null-pointer`). Do not ask; create it.

## Rule 2: Use issue-linked PRs for remote repositories

Before making changes, check whether the current Git repository has a remote:

```bash
git remote -v
```

If `git remote -v` reports at least one remote, treat the repository as a remote repository and follow this workflow for every requested change:

1. Create a GitHub issue before editing. The issue must describe the requested change, acceptance criteria, and the intended PR boundary.
2. Create a feature branch for that issue. Include the issue number in the branch name when practical (for example, `feat/123-add-auth`).
3. Make only the changes covered by that issue.
4. Open a pull request for the branch. The PR body MUST reference the issue with `Closes #<issue-number>` (or an equivalent GitHub closing keyword), and the PR title/body MUST identify the issue.
5. Do not make untracked or unrelated changes in the remote repository without first creating a corresponding issue.

If no remote exists, use the normal local-branch workflow and do not create GitHub issues or PRs.

## Rule 3: Stack changes requested in one message or context

When one user message or context window requests multiple independent changes in a remote repository, create one issue and one branch per change, then use stacked pull requests. Build each branch on the previous branch in dependency order, and create/update the stack with the `gh stack` command. Every PR in the stack MUST reference its own issue with `Closes #<issue-number>` (or an equivalent GitHub closing keyword).

Do not combine unrelated requested changes into one issue or PR merely to avoid stacking. If the changes cannot be meaningfully separated, use one issue and one PR instead.

## Rule 4: Ensure `gh stack` is installed

Before using stacked pull requests, check whether the GitHub CLI extension is installed:

```bash
gh extension list
```

If `gh stack` is absent, install it with:

```bash
gh extension install github/gh-stack
```

After installation, verify that `gh stack` is available before continuing.

## Rule 6: Tag every PR title with its number

Every pull request sent to the default branch MUST have its title end with the
pull-request tag `(#<number>)`, where `<number>` is the PR's own number — the
same tag GitHub appends to squashed merge commits (for example,
`feat(mango): move focused client to HUAWEI/AOC monitor (#115)`).

1. Create or update the PR as usual (`gh pr create` / `gh pr edit`).
2. Read the PR number from the returned URL, or with:
   ```bash
   gh pr view --json number --jq .number
   ```
3. Update the title to append the tag:
   ```bash
   gh pr edit <number> --title "<title> (#<number>)"
   ```
4. Apply the tag to every PR in a stack, each with its own number. Skip the
   edit only when the title already ends with `(#<number>)`.

## Rule 5: Clean up worktrees after use

When work in a worktree is complete, clean it up before finishing the task:

1. Confirm all required changes are committed, pushed, and represented by the issue-linked PR.
2. From a different worktree or the main checkout, remove the worktree with `git worktree remove <worktree-path>`.
3. Delete the local feature branch after its PR is merged with `git branch -d <branch-name>`. Do not force-delete a branch that contains unmerged work.
4. Verify the cleanup with `git worktree list` and `git branch --list <branch-name>`.

Never remove a worktree that contains uncommitted user changes. If cleanup is blocked by uncommitted changes or an unmerged branch, report the exact blocker and preserve the worktree.

## Working and finishing

1. Work on the issue's feature branch, or on the appropriate branch in the stack.
2. Run the relevant tests and checks.
3. Commit the change, push the branch, and open/update the issue-linked PR. Use the `ce-commit-push-pr` skill when the work is done, then tag the PR title with its number per Rule 6.
4. For stacked changes, preserve stack order and use `gh stack` for stack operations.
5. After the worktree's task is complete, perform the Rule 5 cleanup from another checkout.

If neither a remote nor a `.github` directory exists, work on a local branch in the main checkout with no issue or PR requirement.

## Structured command output

When a command is expected to return JSON, use Nushell to parse and inspect it. This includes commands such as `gh`, `git`, `curl`, `aws`, and `kubectl` when invoked with JSON output flags.

From the bash execution tool, invoke Nushell explicitly:

```bash
command ... | nu -c 'from json | where ...'
```

or:

```bash
nu -c '^command ... | from json | where ...'
```

Use Nushell for filtering, navigation, and exporting JSON. Do not use `jq`, Python, or ad-hoc text parsing for JSON unless Nushell cannot handle the format. Bash remains acceptable for invoking the producer and for non-structured output.

Examples:

```bash
gh api repos/OWNER/REPO/issues --paginate | nu -c 'from json | where pull_request? == null | select number title'
curl -fsSL https://example.com/data.json | nu -c 'from json | get results | first 10'
kubectl get pods -o json | nu -c 'from json | get items | select metadata.name status.phase'
```
