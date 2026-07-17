---
name: audit-design-implementation
description: Audit a project's implementation against design documents, fix concrete noncompliance, and independently re-audit for up to three sequential cycles. Use whenever a user asks to review, verify, inspect, reconcile, or complete code against a design, specification, ADR, architecture document, interface contract, or implementation plan and wants fixes applied. Every cycle runs in a fresh agent session and a new isolated Git worktree; successful cycle commits are merged back into the caller's original branch before the next cycle, followed by one Chinese final report.
---

# Audit Design Implementation

Run a bounded, evidence-based convergence loop. Isolate every audit-and-fix
cycle in both a fresh agent session and a new Git worktree. Merge a successful
cycle back into the caller's original branch before starting the next cycle, so
each later reviewer inspects the exact integrated implementation without
inheriting earlier conclusions or sharing a mutable checkout.

## Required Inputs

Resolve these inputs from the request and repository before starting:

- Project root. Default to the current workspace.
- Exact design document paths. Require at least one readable source document.
- Review scope, when the user limits modules or requirements.
- Final report filename, when the user specifies one. Resolve relative names
  under `<project-root>/docs/reviews/`; keep this directory fixed unless the
  user explicitly requests a different destination.

Read all applicable repository instructions, including `AGENTS.md`, before
creating a worktree or delegating work. Treat the design documents as the
requirements source and repository instructions as execution constraints. Do
not change a design document unless the user explicitly asks for that.

If documents conflict or leave a behavior materially ambiguous, record the
conflict instead of inventing a requirement. Continue with unambiguous work.

## Git And Worktree Preflight

This workflow integrates every modified cycle through Git, so the caller's
original worktree must provide a stable merge target.

1. Confirm the project is a Git repository and the caller is on a named local
   branch, not detached HEAD.
2. Record:
   - `original_root`
   - `original_branch`
   - `original_head`
   - configured upstream, if any
   - `git status --short`
   - relevant staged and unstaged diffs
3. Confirm no merge, rebase, cherry-pick, revert, or bisect is in progress.
4. Require the original worktree to be clean, including relevant untracked
   files. If it is dirty, stop and ask the user to commit or stash the changes.
   Do not commit, stash, reset, or discard user-owned changes on their behalf.
5. Create a unique `run_id` and a temporary parent such as:

   ```text
   ${TMPDIR:-/tmp}/audit-design-implementation/<repo>-<run_id>/
   ```

6. Reserve unique temporary branches:

   ```text
   audit/<design-slug>/<run_id>/cycle-1
   audit/<design-slug>/<run_id>/cycle-2
   audit/<design-slug>/<run_id>/cycle-3
   audit/<design-slug>/<run_id>/report
   ```

Request any required authorization for `git worktree`, staging, commits, merges,
branch deletion, or cleanup before executing them. Never bypass repository
hooks or signing policy unless the user explicitly authorizes that exception.

## Local-Only Worktree Inputs

A linked worktree contains tracked files only. Before delegation, inspect
repository instructions for required ignored or untracked local inputs such as
runtime configuration, fixtures, data mounts, credentials, or generated
artifacts.

- Prefer worktree-local configuration or explicit environment variables.
- Copy small, non-secret ignored configuration into the worktree only when the
  repository permits it. Record the source and verify it remains untracked.
- Use read-only links for large shared data only when consumers do not mutate
  it. Redirect writable outputs to the worktree or a worktree-local temporary
  directory.
- Do not copy secrets or ambiguous local files without user authorization.
- Tell the worker which local-only paths are context-only and must not be
  edited or staged.
- Before every cycle commit, verify no hydrated local-only file is staged.

If required local inputs cannot be made available safely, record the affected
checks as blocked rather than weakening isolation.

## Per-Cycle Worktree Protocol

Run cycles sequentially. At the start of cycle `N`, the original branch must
contain all successfully merged changes from cycles `1..N-1`.

### 1. Create The Cycle Worktree

Capture the current original-branch HEAD as `cycle_base`, then create a branch
and linked worktree from that exact commit:

```bash
git worktree add -b <cycle_branch> <cycle_worktree> <cycle_base>
```

Use a unique path below the run's temporary parent, for example
`<run_root>/cycle-N`. Hydrate only the approved local-only inputs described
above. Confirm the cycle worktree is clean before spawning the worker.

### 2. Start A Fresh Review Session

Use the available multi-agent session tools. Discover them first when they are
not already loaded.

Create one worker with `fork_context: false`. Give it only:

- the raw cycle worktree path as the project root;
- design document paths resolved inside that worktree;
- review scope;
- cycle number;
- repository instruction paths;
- the Worker Cycle Protocol and Cycle Record below.

Do not include findings, suggestions, summaries, or conclusions from earlier
cycles. Tell the worker:

- it owns edits only inside the cycle worktree;
- it must not run Git operations, create commits, merge branches, remove the
  worktree, or write the final report;
- hydrated local-only files are not implementation changes and must not be
  edited.

Wait for the worker to finish, collect its structured cycle record, and close
the worker. Never reuse a worker with `send_input`, resume, inherited history,
or the same worktree.

If no tool can create an independent session without inherited context, stop
and tell the user that the isolation requirement cannot be met. Do not simulate
multiple sessions in one context.

### 3. Inspect And Commit The Cycle

In the cycle worktree, inspect `git status`, staged and unstaged diffs, untracked
files, and validation output. Reconcile the worker verdict with actual state:

- `clean` requires no implementation changes and passing relevant checks.
- `modified` requires an implementation or test change.
- `blocked` requires a concrete unresolved blocker.

The coordinator, not the worker, owns Git integration:

1. Review every changed path and confirm it is workflow-owned and in scope.
2. Run the narrowest meaningful checks again when needed.
3. Stage only the reviewed cycle changes.
4. Verify hydrated local-only files and unrelated files are not staged.
5. Run staged diff checks and repository-required hooks.
6. For a `modified` cycle, create one descriptive cycle commit on the temporary
   branch. Do not amend or rewrite existing history.

If the cycle record says `clean` but files changed, or says `modified` without a
reviewable change, resolve the mismatch before integration.

### 4. Merge Back Into The Original Branch

Before merging, confirm:

- the original worktree is still clean;
- `original_branch` is still checked out there;
- its HEAD still equals `cycle_base`;
- no Git operation is in progress.

If the original branch moved or became dirty, preserve the cycle branch and
worktree, stop, and ask the user how to reconcile the concurrent change.

For a modified cycle, merge the cycle branch from `original_root`. Use a
non-fast-forward merge by default so the audit-cycle boundary remains visible:

```bash
git merge --no-ff <cycle_branch> -m "merge(audit): integrate cycle N"
```

Follow an established linear-history policy when the repository explicitly
requires one; in that case use the repository's approved fast-forward or
rebase-and-merge procedure and record it.

If a merge conflicts, resolve only when the correct integration is
unambiguous. Otherwise abort the merge, keep the cycle worktree and branch, mark
the cycle `blocked`, and report the preserved recovery paths.

After a successful merge:

1. Run the relevant post-merge checks in the original worktree.
2. Confirm the cycle commit is an ancestor of `original_branch`.
3. Confirm the original worktree is clean.
4. Remove the cycle worktree normally, without `--force`.
5. Delete the merged temporary branch with `git branch -d`.
6. Record the worktree path, temporary branch, cycle commit, merge commit,
   validation result, and cleanup result for the final report.

For a clean cycle, there is no commit to merge. Confirm the temporary branch has
not diverged, remove its clean worktree, delete the branch, and record the
integration as a no-op.

Never remove a worktree that contains uncommitted changes or delete an unmerged
branch. Preserve both when integration is blocked.

## Worker Cycle Protocol

Give each worker this responsibility and tell it to edit its assigned cycle
worktree directly:

1. Read repository instructions and every supplied design document in full.
2. Reconstruct a requirement checklist with stable local IDs such as `REQ-001`.
3. Inspect the current implementation and relevant tests. Trace every material
   requirement to concrete code or identify missing evidence.
4. Classify findings as `critical`, `major`, or `minor`. For each finding, cite
   the requirement source and implementation evidence with file and line
   references.
5. Form a specific modification proposal for every actionable deviation before
   editing. State affected behavior, files, tests, and compatibility risks.
6. Apply the recorded proposals conservatively. Update callers, tests, build
   files, and docs only when required by the implementation change.
7. Run the narrowest meaningful checks, then broader repository-required build,
   test, formatting, or static checks when feasible.
8. Reinspect the changed paths against the requirement checklist.
9. Return the structured cycle record below. Do not create a separate
   user-facing report and do not perform Git operations.

The worker must not merely list suggestions when an unambiguous, in-scope fix is
feasible. It must implement the fix and verify it. It must not make speculative
changes for contradictory or underspecified requirements.

## Cycle Record

Require every worker's final response to contain:

```markdown
## Cycle N

### Requirement Coverage
| ID | Requirement source | Implementation evidence | Status |

### Findings Before Changes
| Severity | Requirement ID | Evidence | Proposed change |

### Changes Applied
| File | Change | Requirement IDs |

### Verification
| Command or check | Result | Notes |

### Remaining Deviations
| Severity | Requirement ID | Reason | Recommended next action |

### Cycle Verdict
`clean`, `modified`, or `blocked`
```

Use `clean` only when there are no actionable deviations, no implementation
changes, and relevant checks pass. Use `modified` when code, tests, build files,
or implementation documentation changed, even if the worker believes the
result is now compliant. Use `blocked` when a document conflict, missing
dependency, unsafe ambiguity, environment failure, or integration failure
prevents completion.

## Cycle Limit And Convergence

Run at most three audit cycles.

- Stop after a successfully integrated `clean` cycle.
- After a successfully integrated `modified` cycle, create a new branch,
  worktree, and fresh session for the next cycle unless it was cycle 3.
- After a `blocked` cycle, continue only when another independent cycle could
  still resolve or narrow the issue and the blocked changes were safely
  integrated or discarded with explicit user authorization.
- Stop immediately for destructive risk, missing required authorization,
  unavailable fresh-session tooling, or unsafe worktree integration.

Do not claim compliance merely because three cycles were completed. Any
remaining deviation or unmerged cycle branch must appear in the final verdict
and report.

## Final Verification And Report Integration

After the last audit cycle:

1. Inspect the cumulative original-branch diff and history against
   `original_head`.
2. Confirm every modified cycle was merged and every successful temporary
   worktree/branch was cleaned up.
3. Confirm user-owned baseline state was preserved.
4. Run the repository's required checks from the integrated original branch.
5. Reconcile disagreements between cycle records using current code and direct
   evidence. Preserve material disagreements in the report.

Create the report through a separate finalization worktree so the coordinator
does not modify the caller's checkout directly:

1. Create `<run_root>/report` and `<report_branch>` from the current integrated
   original-branch HEAD.
2. Use `assets/final-report-template.md` to create one final report in Chinese.
3. Write it under the project-root-relative `./docs/reviews/` directory in the
   report worktree.
4. Commit the report on the report branch.
5. Recheck that the original branch is clean and unchanged since the report
   worktree was created.
6. Merge the report branch back into the original branch using the same merge
   policy, run final checks, then remove the worktree and delete the branch.

The default report path is:

```text
./docs/reviews/<design-name>-implementation-audit-<YYYYMMDD-HHMMSS>.md
```

Resolve `./docs/reviews/` from the audited project root. Create it when needed,
never overwrite an existing report, and do not fall back to another report
directory.

Set the overall verdict to exactly one of:

- `Compliant`
- `Compliant with limitations`
- `Not compliant`

The report must include the temporary branch, worktree, cycle commit, merge
result, post-merge validation, and cleanup status for every cycle. Any preserved
worktree or unmerged branch is a remaining operational risk.

In the final response, give the verdict, number of cycles run, report path,
changed source areas, validation status, original branch, merged commit(s), and
worktree cleanup status. Explicitly name checks that were not run and why.
