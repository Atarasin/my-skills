---
name: audit-design-implementation
description: Audit a project's implementation against one or more design documents, record concrete noncompliance findings and proposed changes, apply the changes, and independently re-audit the modified project in fresh sessions for up to three sequential cycles before producing one final report. Use when a user asks to review, verify, inspect, or reconcile code against a design, specification, ADR, architecture document, interface contract, or implementation plan and wants the resulting fixes implemented rather than only reviewed.
---

# Audit Design Implementation

Run a bounded, evidence-based convergence loop. Keep every audit-and-fix cycle
in a new session so that later reviewers reconstruct the requirements and inspect
the modified implementation without inheriting earlier conclusions.

## Required Inputs

Resolve these inputs from the request and repository before starting:

- Project root. Default to the current workspace.
- Exact design document paths. Require at least one readable source document.
- Review scope, when the user limits modules or requirements.
- Final report path, when the user specifies one.

Read all applicable repository instructions, including `AGENTS.md`, before
delegating work. Treat the design documents as the requirements source and the
project instructions as execution constraints. Do not change a design document
unless the user explicitly asks for that.

If documents conflict or leave a behavior materially ambiguous, record the
conflict instead of inventing a requirement. Continue with unambiguous work.

## Preserve The Baseline

Capture `git status --short` and the relevant diff before cycle 1. Treat existing
changes as user-owned. Never revert or overwrite them. Tell every worker that
other edits may exist and must be preserved.

Do not assume that a dirty file was changed by this workflow. Attribute changes
by comparing the baseline, cycle results, and current diff.

## Enforce Fresh Sessions

Use the available multi-agent session tools. Discover them first when they are
not already loaded.

For every cycle:

1. Create a new worker with `fork_context: false`.
2. Give it the raw project path, design document paths, scope, cycle number, and
   the cycle protocol below.
3. Do not include findings, suggestions, summaries, or conclusions from earlier
   cycles.
4. Wait for it to finish, collect its structured cycle record, and confirm its
   edits are integrated into the coordinator workspace.
5. Close it, then create another new worker for the next cycle. Never reuse a
   worker with `send_input`, resume, or inherited conversation history.

Run workers sequentially because each cycle audits the implementation produced
by the previous cycle. Do not run cycles in parallel.

The coordinator may inspect diffs and run validation to integrate results, but
must not replace a required fresh review cycle with its own audit.

If no tool can create an independent session without inherited context, stop and
tell the user that the isolation requirement cannot be met. Do not simulate
multiple sessions in one context.

## Worker Cycle Protocol

Give each worker this responsibility and tell it to edit the current workspace
directly:

1. Read repository instructions and every supplied design document in full.
2. Reconstruct a requirement checklist with stable local IDs such as `REQ-001`.
3. Inspect the current implementation and relevant tests. Trace every material
   requirement to concrete code or identify missing evidence.
4. Classify findings as `critical`, `major`, or `minor`. For each finding, cite
   the requirement source and implementation evidence with file and line
   references.
5. Form a specific modification proposal for every actionable deviation before
   editing. State affected behavior, files, tests, and compatibility risks.
6. Apply the recorded proposals conservatively. Preserve unrelated and
   pre-existing changes. Update callers, tests, build files, and docs only when
   required by the implementation change.
7. Run the narrowest meaningful checks, then broader repository-required build,
   test, formatting, or static checks when feasible.
8. Reinspect the changed paths against the requirement checklist.
9. Return the structured cycle record below. Do not create a separate
   user-facing report.

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

Use `clean` only when there are no actionable deviations and relevant checks
pass. Use `modified` when code or tests changed, even if the worker believes the
result is now compliant. Use `blocked` when an unresolved document conflict,
missing dependency, unsafe ambiguity, or environment failure prevents
completion.

## Cycle Limit And Convergence

Run at most three cycles.

- Stop after a `clean` cycle.
- After a `modified` cycle, run another fresh cycle unless it was cycle 3.
- After a `blocked` cycle, continue while another independent review could still
  resolve or narrow the issue, but never exceed cycle 3.
- Stop immediately for destructive risk, missing required user authorization,
  or unavailable fresh-session tooling.

Do not claim compliance merely because three cycles were completed. Any
remaining deviation must appear in the final verdict and report.

## Final Verification

After the last cycle:

1. Inspect the cumulative diff against the original baseline.
2. Confirm that pre-existing changes were preserved.
3. Run the repository's required checks when feasible.
4. Reconcile disagreements between cycle records using current code and direct
   evidence. Preserve material disagreements in the report.
5. Use `assets/final-report-template.md` to create one final report.

Default the report path to:

```text
docs/reviews/<design-name>-implementation-audit-<YYYYMMDD-HHMMSS>.md
```

Create the parent directory when needed and never overwrite an existing report.
If the project has no documentation directory, place the report under
`review-reports/`.

Set the overall verdict to exactly one of:

- `Compliant`
- `Compliant with limitations`
- `Not compliant`

In the final response, give the verdict, number of cycles run, report path,
changed source areas, and validation status. Explicitly name checks that were
not run and why.
