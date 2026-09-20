---
name: jj-libgit2-transport-verification
description: "Verify a libgit2 (git2-rs) push/fetch plus jj CLI reconciliation cycle against a real GitHub remote: the colocated-repo mechanics, the untracked-remote-bookmark immutability trap, ref/bookmark coupling, and the measurement and scripting traps that silently falsify results."
---

# Verifying a libgit2 + jj transport cycle

Use when proving or debugging a design where **libgit2 (git2-rs)** does the network
and a pinned **jj CLI** does every jj operation in the same colocated repo — e.g. a
mobile client that cannot ship a `git` binary. Worked example: jjSync
(`cernoh/jjsync`, ticket 6), jj 0.45.1, git2 0.20.4, Rust 1.97.1.

## The cycle that works

1. libgit2 clone with a token, then `cd <dir> && jj git init --colocate`.
2. `remote.fetch("+refs/heads/*:refs/remotes/<remote>/*", FetchPrune::On, None)`.
3. If `<bookmark>@<remote>` exists and is not an ancestor of `@`:
   `jj rebase -s @ -o <bookmark>@<remote>`. Conflicts do not fail the command — check
   `conflicts()` / `jj resolve --list` (exit 0 = conflicts listed, exit 2 = none).
4. If `@` is not empty: `jj describe -m <msg>`, `jj bookmark set <bookmark> -r @`
   (jj exports `refs/heads/<bookmark>`), then
   `remote.push(&["refs/heads/<b>:refs/heads/<b>"], ..)`.
5. Fresh change: `jj new` **only if `@` still holds the pushed commit** (see trap 2).

No hand-written remote-tracking ref and no explicit `jj git import` are needed:
`jj git import` in a colocated repo prints `No import needed in colocated
workspaces.` and jj auto-imports git refs before every command.

## Traps that cost real time

1. **libgit2 writes `refs/remotes/<remote>/<branch>` on push *conditionally*.**
   libgit2 maps the pushed ref through the remote's **fetch** refspec
   (`push.c` update-tips / `git_remote__matching_refspec`). A clone sets
   `+refs/heads/*:refs/remotes/origin/*`, so it works there — but the
   **adopt-in-place** path, where the app adds the remote itself, may have no fetch
   refspec and jj would then be blind to the push. Record the ref write as a
   *conditional safety net*, not dead code.
2. **An untracked remote bookmark is an immutable head.**
   `builtin_immutable_heads() = trunk() | tags() | untracked_remote_bookmarks()`.
   After a push to a bookmark the app created, the pushed commit goes immutable and
   jj warns `The working-copy commit became immutable; a new commit has been created
   on top of it` — it *already* made the fresh change. An unconditional `jj new`
   then stacks a second empty commit, and junk grows per cycle. Ask
   "did the push move `@`?" before running `jj new`.
3. **`jj bookmark track <b>@<remote>` is not a free fix.** It stops trap 2 for
   non-default bookmarks, but a *tracked* bookmark **follows the remote**: on import
   it fast-forwards, and on divergence it becomes **conflicted** (multiple targets),
   after which any revset read of it fails (`jj log -r <b>` → error). That kills
   push-only mode (the bookmark is already at the remote tip, so the push is a
   permanent no-op). Whether tracking still leaves trap 2 open when the bookmark *is*
   the remote default branch (`trunk()`) was **not settled** — measure it.
4. **Deleting `refs/remotes/<remote>/<branch>` deletes the local bookmark too.**
   In a colocated repo the local bookmark lives in `refs/heads/<b>` and jj derives it
   from the git ref; restoring the remote ref does not bring the local bookmark back.
   Never hand-write that ref to a wrong value.
5. **First cycle: `<bookmark>@<remote>` does not exist yet.**
   `jj log -r "<bm>@origin & ::@"` **errors** rather than returning empty, so an
   ancestor test reads false and the rebase runs against a nonexistent revision
   (`Revision ... doesn't exist`). Guard the rebase on the remote bookmark existing —
   read it from `jj bookmark list --all-remotes -T 'json(self)'` (the `target` array;
   multiple entries mean conflicted).
6. **jj writes status text to stderr.** `jj bookmark create/describe/rebase/import/track`
   all report there. A helper that returns stdout only will see empty strings and
   assertions that grep for `Rebased`, `nothing to commit` or `Started tracking` will
   silently misreport. Merge stdout + stderr.
7. **`-T commit_id` needs an explicit newline.** `-T commit_id` emits every id on one
   line, so `splitlines()` returns 1 for any non-empty revset. This bug appeared in
   three separate probes in one session and corrupted a load-bearing count. Always
   `-T 'commit_id ++ "\n"'`, or count with a template that ends in a newline. Sanity
   check every counter against a printed list.
8. **`jj -R <dir> git init --colocate` does not work.** `cd` into the directory.
9. **`jj rebase --abort` does not exist** — jj records conflicts in commits. To clear
   one, use `jj undo`, or abandon/restore the conflicted commit.

## Measurement recipe

- Drive the real remote with a throwaway Rust spike exposing one subcommand per step,
  plus a Python assertion harness that prints `PASS`/`FAIL` with the observed value.
  Never assert on a label you have not seen printed.
- Before a slow external leg, assert the harness itself: run each check against a
  known state and confirm a deliberate failure is caught.
- Count commits with the `all()` revset, not a hand-built chain revset — `mutable()`
  and `immutable()` exclude exactly the commits you are looking for.
- Distinguish a *harness* defect from a *design* defect every time a check fails; the
  majority of failures in the worked example were harness bugs (missing fetch, wrong
  sequencer order, broken counters).
- **Vault discipline:** push only to fresh throwaway branches
  (`<prefix>-<unix-ts>`), never the default branch, and delete every branch at the
  end; verify with `gh api repos/<o>/<r>/branches --jq '.[].name'` and a commit count
  on the default branch.

## Environment notes

- Enter the project shell first (`nix develop`); `cargo build` for git2 also needs
  `cmake`, `pkg-config`, `openssl`, `perl` in the shell for the vendored libgit2.
- No `python3` in the dev shell: run harnesses with
  `nix shell nixpkgs#python3 --command python3 <script>`.
- Token callback that works: `Cred::userpass_plaintext("x-access-token", &token)`;
  libgit2 offers `CredentialType::USER_PASS_PLAINTEXT`. A rejected push surfaces as
  `Err` with `ErrorCode::NotFastForward`.
