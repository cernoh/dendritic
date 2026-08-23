---
name: fix-fork-release-workflow
description: "Fix a GitHub Actions release workflow when forking an Android project — replace hardcoded upstream URLs, handle no-prior-release, make secret-dependent steps conditional with proper env indirection"
---

# Fix GitHub Actions Release Workflow for Fork

When forking an Android project with a release workflow that triggers on tags, the workflow needs several fixes to work in the fork:

## 1. Replace hardcoded upstream repo references

Search for the original repo name (e.g., `komikku-app/komikku`) in:
- API compare URLs
- Badge URLs  
- Changelog links

Replace with `${{ github.repository }}` to make it dynamic.

## 2. Handle no-prior-release case

If the fork has no releases yet, `get-latest-release` actions fail. Replace with git-based approach:

```yaml
- name: Get previous release
  id: last_release
  run: |
    prev_tag=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
    echo "PREV_TAG_NAME=$prev_tag"
    echo "PREV_TAG_NAME=$prev_tag" >> $GITHUB_OUTPUT
```

In subsequent steps, handle empty `PREV_TAG_NAME`:
```yaml
if [ -n "$prev_tag" ]; then
  # use prev_tag for comparison
else
  # fall back to root commit: git rev-list --max-parents=0 HEAD
fi
```

## 3. Make secret-dependent steps conditional

For steps that require secrets (signing keys, google-services.json, etc.):

**Wrong** (step-level env not visible in step's own `if:`):
```yaml
- name: Sign APK
  if: ${{ env.SIGNING_KEY != '' }}
  env:
    SIGNING_KEY: ${{ secrets.SIGNING_KEY }}
```

**Right** (job-level env visible in step `if:`):
```yaml
jobs:
  release-app:
    env:
      SIGNING_KEY: ${{ secrets.SIGNING_KEY }}
    steps:
      - name: Sign APK
        if: ${{ env.SIGNING_KEY != '' }}
```

## 4. Handle both signed and unsigned APKs

When signing is optional, the rename step must handle both cases:

```yaml
if [ -f "$DIR/app-universal-release-unsigned-signed.apk" ]; then
  SUFFIX="-unsigned-signed"
else
  SUFFIX="-unsigned"
fi
mv "$DIR/app-universal-release${SUFFIX}.apk" "Komikku-${TAG}.apk"
```

## 5. Add workflow_dispatch for manual triggers

```yaml
on:
  push:
    tags:
      - v*
  workflow_dispatch:
```

This allows `gh workflow run "Release Builder" --ref v1.14.0` when tag push doesn't trigger automatically.

## 6. Remove telemetry flags if google-services.json missing

If `GOOGLE_SERVICES_JSON` secret isn't set, remove `-Pinclude-telemetry` from Gradle commands — the Firebase plugin won't initialize without the config file.
