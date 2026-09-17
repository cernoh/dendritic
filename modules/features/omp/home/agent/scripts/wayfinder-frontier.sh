#!/usr/bin/env bash
# Print the wayfinder frontier: every open ticket that carries a wayfinder:<type>
# label, has no open blocker, and has no assignee. The map itself is excluded.
#
# Usage: wayfinder-frontier.sh [<owner>/<repo>]
# Without an argument, gh infers the repository from the current directory.

set -euo pipefail

repo=${1:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}

gh api "repos/$repo/issues?state=open&per_page=100" --paginate --jq '
  .[]
  | select(.pull_request == null)
  | .labels as $labels
  | ($labels | map(.name)) as $names
  | select($names | index("wayfinder:map") | not)
  | select($names | map(startswith("wayfinder:")) | any)
  | select(.issue_dependencies_summary.blocked_by == 0)
  | select((.assignees | length) == 0)
  | "#\(.number)\t\(.title)"
'
