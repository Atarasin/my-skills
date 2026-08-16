# Worktree Isolation And Git Integration Protocol

Mechanics for the coordinator. Read this before creating the first worktree.

The point of all of it: a reviewer who can see the previous reviewer's
conclusions will tend to ratify them, and a reviewer sharing a mutable checkout
can silently trample another's revision. Fresh session plus fresh worktree per
perspective is what makes four cycles produce four opinions instead of one
opinion repeated four times.

## Contents

- [Preflight](#preflight)
- [Local-Only Inputs](#local-only-inputs)
- [Per-Cycle Protocol](#per-cycle-protocol)
- [Report Worktree](#report-worktree)
- [Recovery](#recovery)

## Preflight

1. Confirm the project is a Git repository and the caller is on a named local
   branch, not detached HEAD.
2. Record `original_root`, `original_branch`, `original_head`, configured
   upstream, `git status --short`, and relevant staged and unstaged diffs.
3. Confirm no merge, rebase, cherry-pick, revert, or bisect is in progress.
4. Require the original worktree to be clean, including relevant untracked
   files. Design documents are frequently mid-edit, so check the documents under
   review specifically and name the dirty paths when refusing. Ask the user to
   commit or stash. With explicit user authorization, the coordinator may
   instead commit the staged set **verbatim** — no content changes — as the
   review baseline, recording that in the report's baseline-protection section.
   Never commit, stash, reset, or discard user-owned changes without that
   authorization — an uncommitted design edit is often the user's actual
   current thinking, and losing it is worse than any finding the review produces.
5. Create a unique `run_id` and a temporary parent:

   ```text
   ${TMPDIR:-/tmp}/review-design-proposal/<repo>-<run_id>/
   ```

6. Reserve unique temporary branches, named by perspective so the history stays
   readable months later:

   ```text
   design-review/<design-slug>/<run_id>/cycle-1-requirements
   design-review/<design-slug>/<run_id>/cycle-2-architecture
   design-review/<design-slug>/<run_id>/cycle-3-risk
   design-review/<design-slug>/<run_id>/cycle-4-consistency
   design-review/<design-slug>/<run_id>/report
   ```

7. Probe verification tooling once — `rg`, a Mermaid CLI (`mmdc`), PlantUML,
   `pandoc` — and record availability in the run metadata. Pass the list to
   every worker so a check whose tool is missing is recorded
   `n-a (tool unavailable, confirmed at preflight)` instead of being
   rediscovered per cycle.

Request authorization for `git worktree`, staging, commits, merges, branch
deletion, and cleanup before executing them. Never bypass repository hooks or
signing policy unless the user explicitly authorizes that exception.

## Local-Only Inputs

A linked worktree contains tracked files only. Design documents commonly
reference untracked companions: exported diagram sources, generated API
references, large asset directories, or requirement notes kept outside the
repository. A reviewer that cannot open the diagram will review the prose alone
and quietly miss half the design.

- Resolve every relative link and image path in the documents under review, and
  identify which targets are absent from a fresh worktree.
- Resolve every **upstream requirement source** against a fresh worktree as well
  (`git ls-files --error-unmatch`, or `test -f` in a scratch worktree). Sources
  that exist only through local symlinks or gitignored material (for example
  `.agents/skills/…` entries) are absent for the worker: pass the tracked
  equivalent path instead (for example `skills/<name>/SKILL.md`) and state the
  mapping explicitly in the worker prompt.
- Copy small, non-secret ignored files in only when the repository permits it.
  Record the source and verify they stay untracked.
- Link large asset directories read-only. Never redirect a worker's writes
  outside the cycle worktree.
- Do not copy secrets, private notes, or ambiguous local files without user
  authorization.
- Tell the worker which paths are context-only and must not be edited or staged.
- Before every cycle commit, verify no hydrated local-only file is staged.

If a required upstream requirement source cannot be made available safely,
record the affected coverage checks as blocked. Guessing at the requirement
produces a review of an imagined document.

## Per-Cycle Protocol

Cycles run sequentially. At the start of cycle `N`, the original branch must
contain all successfully merged revisions from cycles `1..N-1` — that is the
whole reason for merging between cycles rather than at the end.

### 1. Create the cycle worktree

Capture the current original-branch HEAD as `cycle_base`, then branch from that
exact commit:

```bash
git worktree add -b <cycle_branch> <cycle_worktree> <cycle_base>
```

Use a unique path below the run's temporary parent, such as `<run_root>/cycle-N`.
Hydrate only approved local-only inputs. Confirm the worktree is clean before
spawning the worker.

### 2. Spawn the worker

Create one worker with `fork_context: false`. See the SKILL.md section "Start A
Fresh Review Session" for exactly what to pass and what to withhold.

Wait for it to finish, collect its cycle record, and close it. Never reuse a
worker with `send_input`, resume, inherited history, or the same worktree.

If no tool can create an independent session without inherited context, stop and
tell the user the isolation requirement cannot be met. Do not simulate multiple
perspectives in one context.

### 3. Inspect and commit

Inspect `git status`, staged and unstaged diffs, untracked files, and
verification output. Reconcile the worker's verdict against actual state:
`clean` means no document changes and passing checks, `revised` means an actual
document change, `blocked` means a concrete unresolved blocker. If the record
says `clean` but files changed, or `revised` without a reviewable change,
resolve the mismatch before integrating.

The coordinator, not the worker, owns Git integration:

1. Review every changed path. Confirm each is an in-scope design document, and
   reject any change to source code, tests, build files, or configuration.
2. Read the full document diff. A design revision is prose, and prose is where a
   reviewer can quietly widen scope, delete a decision the user made, or invent
   a requirement — none of which show up as anything but ordinary-looking
   sentences. Reverse any such change and record it.
3. Re-run the document verification checks after the revision.
4. Stage only the reviewed cycle changes.
5. Verify hydrated local-only files and unrelated files are not staged.
6. Run staged diff checks and repository-required hooks.
7. For a `revised` cycle, create one descriptive commit naming the perspective.
   Do not amend or rewrite existing history.

### 4. Merge back

Before merging, confirm the original worktree is still clean, `original_branch`
is still checked out there, its HEAD still equals `cycle_base`, and no Git
operation is in progress.

If the original branch moved or went dirty, preserve the cycle branch and
worktree, stop, and ask the user how to reconcile. Design documents get edited
in parallel more often than code does; never overwrite that.

```bash
git merge --no-ff <cycle_branch> -m "merge(design-review): integrate cycle N (<perspective>)"
```

Non-fast-forward by default, so the perspective boundary stays visible in
history. Follow an established linear-history policy when the repository
explicitly requires one, using its approved procedure, and record that choice.

If a merge conflicts, resolve only when the correct integration is unambiguous.
Otherwise abort, keep the cycle worktree and branch, mark the cycle `blocked`,
and report the preserved recovery paths.

After a successful merge:

1. Re-run the document verification checks in the original worktree.
2. Confirm the cycle commit is an ancestor of `original_branch`.
3. Confirm the original worktree is clean.
4. Remove the cycle worktree normally, without `--force`.
5. Delete the merged branch with `git branch -d`.
6. Record worktree path, branch, cycle commit, merge commit, verification
   result, and cleanup result for the final report.

For a `clean` cycle there is nothing to merge. Confirm the branch has not
diverged, remove its clean worktree, delete the branch, record a no-op.

## Report Worktree

The final report is written through its own worktree so the coordinator never
edits the caller's checkout directly:

1. Create `<run_root>/report` and `<report_branch>` from the current integrated
   original-branch HEAD.
2. Write the report from `assets/final-report-template.md` under the
   project-root-relative `./docs/reviews/` directory.
3. Commit it on the report branch.
4. Recheck that the original branch is clean and unchanged since the report
   worktree was created.
5. Merge back with the same merge policy, re-run verification, remove the
   worktree, delete the branch.

## Recovery

Never remove a worktree containing uncommitted changes, and never delete an
unmerged branch. When integration is blocked, preserving both is what makes the
work recoverable — report the exact paths and branch names so the user can pick
up from there.
