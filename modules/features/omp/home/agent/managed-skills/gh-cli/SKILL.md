---
name: gh-cli
description: "Use when running gh CLI commands — covers pr, issue, release, run, api, secret, search, repo, project, gist, discussion, workflow, auth, formatting, and common idioms. Pull this skill before any gh invocation you're not 100% sure of."
---

# gh CLI Reference

`gh` is the GitHub CLI. Authenticated wrapper around GitHub's REST (v3) and GraphQL (v4) APIs. Use it instead of curl + manual auth for anything GitHub-shaped.

## I want to… (task → command)

| I want to… | Do this |
|---|---|
| Open the current repo in a browser | `gh browse` |
| Open a specific PR/issue/file+line | `gh browse 123` or `gh browse src/foo.kt:42` |
| See my PRs awaiting review | `gh pr status` |
| See CI for current branch | `gh pr checks --watch` |
| Get logs of a failing CI run | `gh run view --log-failed` |
| Get latest release tag as a shell var | `latest=$(gh release view --json tagName --jq .tagName)` |
| Trigger a workflow_dispatch | `gh workflow run build.yml -f param=value` |
| Set a secret from an env var | `gh secret set FOO --body "$FOO"` |
| Bulk-set secrets from a dotenv file | `gh secret set -f .env` |
| Find my open PRs not yet approved | `gh pr list --author @me --json number,title,reviewDecision --jq '.[] \| select(.reviewDecision != "APPROVED")'` |
| Mirror all issues to JSON | `gh api repos/{owner}/{repo}/issues --paginate --slurp > issues.json` |
| Clone a repo at shallow depth | `gh repo clone o/r -- --depth 1` |
| Fork a repo I don't own | `gh repo fork o/r` |
| Create a signed release with assets | `gh release create v1.0.0 ./dist/*.apk --generate-notes` |
| Anything the subcommands don't cover | `gh api <endpoint>` (REST) or `gh api graphql -f query=…` (v4) |

## Common `--json` fields

Run `gh <cmd> --json` (no value) to see valid fields for a specific command. Commonly useful ones:

**`gh pr list` / `gh pr view`**: `number`, `title`, `body`, `state`, `author`, `headRefName`, `baseRefName`, `headRepository`, `isDraft`, `reviewDecision`, `mergeStateStatus`, `statusCheckRollup`, `labels`, `assignees`, `reviewers`, `milestone`, `url`, `createdAt`, `updatedAt`, `mergedAt`, `closedAt`, `additions`, `deletions`, `changedFiles`, `commits`

**`gh issue list` / `gh issue view`**: `number`, `title`, `body`, `state`, `author`, `assignees`, `labels`, `milestone`, `projectCards`, `isPinned`, `url`, `createdAt`, `updatedAt`, `closedAt`, `comments`

**`gh release list` / `gh release view`**: `tagName`, `name`, `isDraft`, `isPrerelease`, `isLatest`, `createdAt`, `publishedAt`, `author`, `url`, `assets` (each: `name`, `size`, `downloadCount`, `contentType`, `url`)

**`gh run list` / `gh run view`**: `databaseId` (the run id), `name`, `workflowName`, `status`, `conclusion`, `event`, `branch`, `headBranch`, `headSha`, `createdAt`, `updatedAt`, `jobs`, `url`

**`gh repo list`**: `name`, `nameWithOwner`, `description`, `isPrivate`, `isFork`, `isArchived`, `primaryLanguage`, `stargazerCount`, `updatedAt`, `url`

**`gh search repos`**: `name`, `fullName`, `description`, `owner`, `language`, `license`, `stargazersCount`, `forksCount`, `openIssuesCount`, `updatedAt`, `url`, `isPrivate`, `isArchived`, `isFork`

## Filter/transform patterns with `--jq`

```bash
# PRs with failing required checks
gh pr list --json number,title,statusCheckRollup \
  --jq '.[] | select(.statusCheckRollup[]? | .conclusion == "FAILURE") | .number'

# Latest release tag (shell assignment)
latest=$(gh release view --json tagName --jq .tagName)

# All asset URLs from a release
gh release view v1.0.0 --json assets --jq '.assets[].url'

# Format a table: #number  title  author
gh pr list --json number,title,author \
  --template '{{range .}}{{printf "#%v" .number}}  {{.title}}  {{.author.login}}{{"\n"}}{{end}}'

# Clickable hyperlinks
gh issue list --json title,url --template '{{range .}}{{hyperlink .url .title}}{{"\n"}}{{end}}'
```


## Auth & Scope

```bash
gh auth login                          # interactive; picks github.com or GHE host
gh auth login --hostname git.corp.com  # Enterprise
gh auth status                         # who am I, what scopes
gh auth refresh -s project,workflow    # add missing OAuth scopes
gh auth token                          # print current token (for scripting)
gh auth setup-git                      # wire gh as git credential helper
```

Precedence for token: `GH_TOKEN` > `GITHUB_TOKEN` > stored credentials. Enterprise: `GH_ENTERPRISE_TOKEN`.

## Global Flags (every command)

| Flag | Purpose |
|---|---|
| `-R owner/repo` | Target a repo other than the cwd's |
| `--json fields` | Emit JSON; fields are comma-separated. Run `cmd --json` with no value to list valid fields |
| `-q/--jq expr` | Filter JSON output (jq syntax, built-in — no jq binary needed) |
| `-t/--template` | Go-template output; helpers: `color`, `autocolor`, `join`, `pluck`, `tablerow`, `tablerender`, `timeago`, `timefmt`, `truncate`, `hyperlink`, `contains`, `hasPrefix`, `hasSuffix`, `regexMatch` |

## Pull Requests (`gh pr`)

```bash
gh pr list                                             # open PRs
gh pr list --state merged --author @me --limit 50      # my merged PRs
gh pr list --label bug --assignee alice --json number,title,headRefName
gh pr view 123                                         # by number; also: URL, branch name
gh pr view --web                                       # open in browser
gh pr checkout 123                                     # also: branch, URL
gh pr checkout 123 --detach                            # detached HEAD
gh pr create                                           # interactive
gh pr create --title T --body B --base main --head feat --reviewer alice --label bug --draft
gh pr create --fill                                    # title+body from commits
gh pr create --fill-first                              # from first commit only
gh pr create --web                                     # open browser form
gh pr diff                                             # current branch's PR
gh pr diff 123 > patch.diff
gh pr merge 123 --merge                                # --squash, --rebase, --delete-branch
gh pr merge 123 --admin                                # bypass branch protection
gh pr checks                                           # CI status for current PR
gh pr checks --watch                                   # block until done
gh pr review 123 --approve --body "LGTM"
gh pr review 123 --request-changes --body "Fix X"
gh pr close 123 --delete-branch
gh pr reopen 123
gh pr ready 123                                        # mark as ready (draft → ready)
gh pr edit 123 --add-label bug --add-reviewer alice
gh pr status                                           # yours + review-requested + current
gh pr update-branch                                    # merge/push base into head
gh pr revert 123                                       # create revert PR
gh pr lock / unlock 123
```

### PR selectors
Any PR subcommand accepts: number (`123`), branch name, PR URL, or `@me`-style filters. Last two forms of `pr list` output are interchangeable.

## Issues (`gh issue`)

```bash
gh issue list                                          # open issues
gh issue list --state closed --label bug --assignee @me
gh issue list --search "is:open label:bug sort:reactions"
gh issue create --title T --body B --label bug --assignee alice
gh issue create --web
gh issue view 42 --comments                            # include comments
gh issue view 42 --web
gh issue close 42 --reason "not planned"               # or "completed"
gh issue reopen 42
gh issue comment 42 --body "Fixed in abc123"
gh issue edit 42 --add-label regression
gh issue delete 42 --yes
gh issue transfer 42 other/repo
gh issue pin / unpin 42
gh issue lock / unlock 42 --reason "off-topic"         # reasons: off-topic, too heated, resolved, spam
gh issue develop 42                                    # create branch from issue
gh issue status                                        # assigned/mentioned/created by you
```

## Releases (`gh release`)

```bash
gh release list --limit 10
gh release view v1.0.0
gh release view v1.0.0 --web
gh release create v1.0.0                               # interactive
gh release create v1.0.0 --title "Release 1.0" --notes "changelog…"
gh release create v1.0.0 --generate-notes              # auto notes via GitHub API
gh release create v1.0.0 --generate-notes --notes-start-tag v0.9
gh release create v1.0.0 -F changelog.md               # notes from file
gh release create v1.0.0 --notes-from-tag              # from annotated tag message
gh release create v1.0.0 --draft                       # save as draft
gh release create v1.0.0 --prerelease                  # mark pre-release
gh release create v1.0.0 --target develop              # tag non-default branch
gh release create v1.0.0 --verify-tag                  # fail if tag doesn't already exist
gh release create v1.0.0 --fail-on-no-commits          # fail if no commits since last release
gh release create v1.0.0 --latest=false                # explicitly not latest
gh release create v1.0.0 ./dist/*.apk ./dist/*.aab     # upload assets
gh release create v1.0.0 'file.zip#My Display Label'   # asset with label
gh release create v1.0.0 --discussion-category General # start discussion
gh release upload v1.0.0 ./dist/*.apk --clobber        # overwrite existing asset
gh release download v1.0.0 -p '*.apk'                  # download assets by pattern
gh release download --pattern '*.tar.gz' --dir ./out
gh release edit v1.0.0 --title "New Title" --notes "…"
gh release delete v1.0.0 --yes
gh release delete-asset v1.0.0 asset.apk --yes
```

If tag doesn't exist, `release create` makes it from default branch (or `--target`). To use an existing annotated tag: push it first, then run the command.

## Actions Runs (`gh run`)

```bash
gh run list --limit 10
gh run list --workflow build.yml --branch main
gh run view 12345
gh run view --log                                      # full logs
gh run view --log-failed                               # only failed step logs
gh run watch                                           # live-tail current/latest run
gh run watch <id> --compact                            # only failed/relevant steps
gh run watch --exit-status                             # non-zero exit on failure (for scripts)
gh run rerun 12345                                     # re-run failed run
gh run rerun 12345 --job 6789                          # re-run specific failed job
gh run cancel 12345
gh run delete 12345
gh run download 12345                                  # download artifacts to ./
gh run download 12345 -n artifact-name --dir ./out
```

## Workflows (`gh workflow`)

```bash
gh workflow list
gh workflow list --all                                 # include disabled
gh workflow view build.yml
gh workflow run build.yml                              # trigger workflow_dispatch
gh workflow run build.yml -f param1=value -f param2=value   # pass inputs
gh workflow run build.yml --ref feature-branch
gh workflow enable / disable build.yml
```

## Secrets & Variables

```bash
# Secrets (encrypted; values hidden after set)
gh secret list
gh secret list --app dependabot                        # scopes: actions|agents|codespaces|dependabot
gh secret set MY_SECRET                                # interactive prompt
gh secret set MY_SECRET --body "value"
echo "val" | gh secret set MY_SECRET                   # pipe from stdin
gh secret set MY_SECRET < file.txt
gh secret set -f .env                                  # bulk from dotenv file
gh secret set MY_SECRET --env production               # environment-scoped
gh secret set MY_SECRET --org myorg --visibility all   # org-level: all|private|selected
gh secret set MY_SECRET --org myorg --repos a,b,c      # selected repos
gh secret set MY_SECRET --user                         # user-level (Codespaces)
gh secret delete MY_SECRET

# Variables (plaintext; visible in logs)
gh variable list
gh variable set MY_VAR --body "value"
gh variable set MY_VAR --env staging
gh variable set MY_VAR --org myorg --visibility all
gh variable get MY_VAR
gh variable delete MY_VAR
```

## Repository (`gh repo`)

```bash
gh repo view                                           # current repo
gh repo view owner/repo --web
gh repo clone owner/repo
gh repo clone owner/repo -- --depth 1                  # extra args passed to git
gh repo fork                                           # fork cwd, prompt to add remote
gh repo fork owner/repo --clone=false
gh repo fork --remote=false                            # fork without wiring remote
gh repo create                                         # interactive
gh repo create my-repo --public --clone
gh repo create my-repo --private --source ./local --push --remote
gh repo create my-repo --template owner/template-repo
gh repo list owner --limit 50 --language kotlin
gh repo list owner --source --no-archived              # exclude forks
gh repo edit --description "New desc" --add-topic android
gh repo set-default owner/repo
gh repo rename new-name
gh repo archive / unarchive
gh repo delete owner/repo --yes
gh repo sync                                           # sync fork from upstream
gh repo sync dest-owner/dest-repo --source owner/repo
```

## Search (`gh search`)

```bash
gh search repos "vim plugin" --language go --sort stars --limit 20
gh search repos --owner microsoft --visibility public
gh search repos --topic unix,terminal --sort forks
gh search repos --good-first-issues ">=10"
gh search repos --archived=false
gh search repos --match name,description               # restrict to name|description|readme

gh search issues "memory leak" --repo owner/repo --state open --label bug
gh search issues --assignee @me --sort updated
gh search prs "fix ci" --state merged --merged ">2024-01-01"
gh search commits "fix typo" --repo owner/repo --author alice
gh search code "TODO" --repo owner/repo --match path   # code search
```

Use GitHub search qualifiers directly as args: `gh search repos 'stars:>1000' topic:cli`.

## API Escape Hatch (`gh api`)

For anything not covered by a built-in subcommand.

```bash
# GET with {owner}/{repo} placeholders auto-substituted
gh api repos/{owner}/{repo}/releases
gh api repos/{owner}/{repo}/issues/123/comments

# POST; adding -f/-F switches method from GET to POST
gh api repos/{owner}/{repo}/issues/123/comments -f body='comment body'

# Typed fields: -F auto-converts true/false/null/int
gh api repos/{owner}/{repo}/labels -F name=urgent -F color=d73a4a -F description="Critical"

# Read field value from file: -F 'key=@path' or stdin: -F 'key=@-'
gh api gists -F 'files[myfile.txt][content]=@myfile.txt'

# Nested params
gh api repos/{owner}/{repo}/labels -F 'name=urgent' -F 'color=d73a4a'
gh api /orgs/{org}/properties/schema -X PATCH \
  -F 'properties[][property_name]=env' \
  -F 'properties[][allowed_values][]=staging' \
  -F 'properties[][allowed_values][]=prod'

# JSON body from file (any method)
gh api repos/{owner}/{repo}/rulesets --input body.json
cat body.json | gh api repos/{owner}/{repo}/rulesets --input -

# GET with query string (override method)
gh api -X GET search/issues -f q='repo:cli/cli is:open label:bug'

# Custom header / preview
gh api -H 'Accept: application/vnd.github.v3.raw+json' repos/{owner}/{repo}/contents/README.md
gh api --preview baptiste,nebula /some/endpoint

# jq filter on response
gh api repos/{owner}/{repo}/issues --jq '.[].title'

# Pagination (auto-follows Link header or GraphQL cursor)
gh api repos/{owner}/{repo}/issues --paginate --jq '.[].title'
gh api repos/{owner}/{repo}/issues --paginate --slurp   # wrap all pages in outer array

# GraphQL
gh api graphql -f query='{ viewer { login } }'
gh api graphql -F owner='{owner}' -F name='{repo}' -f query='
  query($name: String!, $owner: String!) {
    repository(owner: $owner, name: $name) {
      releases(last: 3) { nodes { tagName } }
    }
  }
'
# GraphQL pagination: query must accept $endCursor and fetch pageInfo{hasNextPage,endCursor}
gh api graphql --paginate -f query='
  query($endCursor: String) {
    viewer { repositories(first: 100, after: $endCursor) {
      nodes { nameWithOwner }
      pageInfo { hasNextPage endCursor }
    }}
  }
'
```

### Field flags cheat-sheet
| Flag | Meaning |
|---|---|
| `-f key=value` | raw string param |
| `-F key=value` | typed: `true`/`false`/`null`/int auto-converted; `{owner}`/`{repo}`/`{branch}` expanded; `@file` reads file; `@-` reads stdin |
| `key[sub]=value` | nested object |
| `key[]=v1` `key[]=v2` | array |

## Caches (`gh cache`)

```bash
gh cache list
gh cache delete <id>
```

## Gists (`gh gist`)

```bash
gh gist list --public --limit 20
gh gist create file.txt --public --desc "my gist"
gh gist create *.txt -d "multi-file"
gh gist view <id>
gh gist view <id> --raw                                  # raw content, no filenames
gh gist view <id> --filename foo.txt                     # specific file
gh gist edit <id> [filename]
gh gist clone <id>
gh gist delete <id>
gh gist rename <id> old.txt new.txt
```

## Projects (v2) (`gh project`)

```bash
gh project list --owner @me
gh project list --owner myorg --format json
gh project view 1 --owner @me
gh project create --title "Sprint 42" --owner @me
gh project copy <number> --source-owner @me --title "Copy" --drafts
gh project delete <number> --owner @me
gh project edit <number> --title "New" --readme "Desc"
gh project field-create <number> --name "Priority" --datatype TEXT --owner @me
gh project field-list <number> --owner @me
gh project item-create <number> --owner @me --title "New item" --body "Desc"
gh project item-list <number> --owner @me --format json
gh project item-add <number> --owner @me --url https://github.com/.../issues/1
gh project item-edit --id <item-id> --field-id <field-id> --text "value"
gh project item-archive <number> --owner @me --id <item-id>
gh project item-delete <number> --owner @me --id <item-id>
gh project link <number> --owner @me                     # link to current repo
gh project unlink <number> --owner @me
gh project mark-template <number> --owner @me --template / --no-template
gh project close <number> --owner @me
```

## Labels (`gh label`)

```bash
gh label list --limit 100
gh label create urgent --color d73a4a --description "Critical"
gh label create "priority: high" --color "fbca04" -f      # --force: update if exists
gh label clone source-owner/source-repo                  # copy labels from another repo
gh label edit urgent --color 0075ca --new-name critical
gh label delete stale --yes
```

## Discussions (`gh discussion`)

```bash
gh discussion list --category "General" --repo owner/repo
gh discussion view <number> --repo owner/repo --comments
gh discussion create --category "Ideas" --title "T" --body "B"
gh discussion comment <number> --body "…"
gh discussion edit <number> --title "New"
```

## Browse, Config, Alias

```bash
gh browse                                              # open repo in browser
gh browse 123                                          # open issue/PR
gh browse path/to/file.go:42                           # open file at line
gh browse --settings                                   # repo settings page
gh browse --commit main path/to/file.go                # pin to branch/commit

gh config set editor code                              # editor for gh
gh config set editor code -h github.com                # per-host
gh config set git_protocol ssh
gh config list
gh config get editor

gh alias set bugs "issue list --label bug"
gh alias set --clobber bugs "issue list --label 'type: bug'"
gh alias list
gh alias delete bugs
gh alias import aliases.json
```

## Environment Variables Worth Knowing

| Var | Purpose |
|---|---|
| `GH_TOKEN` / `GITHUB_TOKEN` | Auth token (github.com / *.ghe.com) |
| `GH_ENTERPRISE_TOKEN` | Auth for GHES hosts |
| `GH_HOST` | Default hostname when not inferrable |
| `GH_REPO` | Default `[HOST/]OWNER/REPO` |
| `GH_DEBUG=1` | Verbose stderr; `GH_DEBUG=api` also logs HTTP |
| `GH_PAGER` | Pager (default less) |
| `NO_COLOR=1` | Disable ANSI colors |
| `GH_FORCE_TTY=1` or `GH_FORCE_TTY=80` or `GH_FORCE_TTY=50%` | Force TTY output / set columns |
| `GH_PROMPT_DISABLED=1` | Disable interactive prompts (CI) |
| `GH_NO_UPDATE_NOTIFIER=1` | Silence "new version" warnings |
| `GLAMOUR_STYLE` | Markdown rendering style |
| `GH_EDITOR` > `GIT_EDITOR` > `VISUAL` > `EDITOR` | Editor precedence |
| `GH_BROWSER` > `BROWSER` | Browser precedence |

## Idioms & Gotchas

1. **Auto-placeholders in `gh api`**: `{owner}`, `{repo}`, `{branch}` expand from cwd's git remote or `GH_REPO`.
2. **`--json` requires a field list** and the fields differ per command. Run `gh <cmd> --json` (no value) to see valid ones.
3. **Pagination**: `--paginate` for REST; for GraphQL your query must take `$endCursor: String` and return `pageInfo { hasNextPage endCursor }`. `--slurp` wraps pages into one array.
4. **`gh run watch`** does not accept fine-grained PATs (`checks:read` not grantable). Use classic token.
5. **`gh pr checkout`** fetches fork PRs automatically and names the local branch after the head branch.
6. **`gh pr create`** prompts for push destination if branch isn't fully pushed; use `--head` to skip.
7. **Fork flow**: `gh repo fork` creates the fork on your account, then asks whether to add the remote.
8. **`gh release create`** creates the tag if missing; use `--verify-tag` to refuse.
9. **Escape hyphens in search** with `--`: `gh search repos -- -topic:linux`.
10. **Secret values are locally encrypted** before upload; never echoed back.


