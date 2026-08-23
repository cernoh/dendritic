---
name: act-workflow-testing
description: "Run GitHub Actions workflows locally with act, including tag events, runner images, release validation limits, and tag-release recovery"
---

# Act Workflow Testing

Use this procedure when validating a GitHub Actions workflow locally with `act`.

## Steps

1. Enter the exact repository checkout or Worktrunk worktree containing `.github/workflows`.
2. Confirm location and workflow discovery:
   ```sh
   pwd
   git branch --show-current
   act -l
   ```
   Completion criterion: the target workflow and job appear in `act -l`.
3. Create a realistic tag push payload:
   ```json
   {"ref":"refs/tags/v0.1.0-test","repository":{"full_name":"owner/repo"}}
   ```
4. Run a dry plan with a practical runner image:
   ```sh
   act push -n -W .github/workflows/release.yml \
     -P ubuntu-latest=catthehacker/ubuntu:act-latest \
     --eventpath /tmp/tag-event.json
   ```
   Completion criterion: the workflow parses and lists expected steps.
5. Run the workflow for real with the same event payload and image. Treat build, tests, type checks, and packaging as the local execution gate.
6. Keep publishing steps non-destructive. Never provide real GitHub credentials or publish a release from `act`; the final `gh release create` step may fail because `gh` is unavailable, credentials are fake, or the test tag is not remote.
7. Report exact commands, passed steps, and expected environment-limited failures. Do not weaken the workflow to make local publishing pass.

## Troubleshooting

- `stat .../.github/workflows: no such file or directory`: run `act` from the checkout/worktree containing `.github/workflows`.
- Interactive default-image prompt: pass `-P ubuntu-latest=catthehacker/ubuntu:act-latest`.
- Invalid event or tag-derived artifact names: use JSON with `ref: refs/tags/v...`; avoid `/dev/null`.
- Different host architecture: add `--container-architecture linux/amd64`.
- If a tag run uses a buggy workflow commit, fix and push the workflow branch, force-update the tag to the fixed SHA, then verify the new Actions run and release assets.
