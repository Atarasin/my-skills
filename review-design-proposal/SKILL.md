---
name: review-design-proposal
description: Multi-perspective review of a design proposal itself — requirement coverage, architecture feasibility, risk and failure modes, consistency and executability — revising the design documents to fix what it finds. Use this whenever a user wants a design document, technical proposal, solution outline, RFC, ADR, architecture doc, or implementation plan reviewed, critiqued, hardened, stress-tested, sanity-checked, or poked holes in before anyone builds it. Trigger it even when the user never says "review" — asking what's missing from a plan, whether a design will hold up, where the risks are, or "看看这个方案有没有问题" is this skill. It reviews documents only and never reads code as the subject or edits code at all, so prefer audit-design-implementation when the question is whether existing code matches a design. Each perspective runs in a fresh session and its own Git worktree, merged back sequentially, ending in one Chinese report.
---

# Review Design Proposal

Review a design proposal across several independent perspectives, one perspective
per cycle, each in a fresh agent session and its own Git worktree, revising the
design documents themselves. Merge each successful cycle back into the caller's
original branch before starting the next perspective, so every later reviewer
reads the already-hardened proposal without inheriting the previous reviewer's
framing.

Convergence here comes from perspective coverage, not from repeating one review
until it goes quiet. A second reviewer with the same lens and the same context
mostly agrees with the first; a reviewer with a different lens finds what the
first was not looking for.

## Scope Boundary

The review object is the design proposal. Nothing else.

- Review and revise only design documents and the documents they own:
  specifications, ADRs, interface contracts, state tables, implementation plans,
  and diagrams embedded in them.
- Never review the code implementation, never report implementation
  noncompliance, and never edit source files, tests, build files, or config.
- Source code, schemas, and existing interfaces may be read **as read-only
  fact-checking context** — for instance, to confirm a design's claim that "the
  current API already returns X" is actually true. A discrepancy found this way
  is a defect in the *document's assumption*, recorded against the document. It
  is never a finding about the code.
- If the user asks mid-run for implementation work, say plainly that this skill
  does not do it and point at an implementation-audit workflow.

## Required Inputs

- Project root. Default to the current workspace.
- Exact design document paths. At least one readable design document. This is
  the artifact under review, not a reference.
- Upstream requirement sources when they exist: product briefs, issue threads,
  requirement docs, prior ADRs, meeting notes. These constrain the review and
  are never revised.
- Review scope, when the user limits sections or modules.
- Selected perspectives and order, when the user overrides the default.
- Final report filename, when specified. Resolve relative names under
  `<project-root>/docs/reviews/`.

Read applicable repository instructions, including `AGENTS.md` and `CLAUDE.md`,
before creating a worktree or delegating work.

When the proposal has no discoverable upstream requirement source, say so and
review it as self-contained. Internal consistency, feasibility, and executability
still apply; requirement-coverage findings become assumptions to confirm with the
user rather than defects.

## Review Perspectives

Four perspectives, in this order by default. `references/review-perspectives.md`
holds each one's full checklist, finding ID prefix, and editing authority. Pass
the relevant section verbatim to that cycle's worker, and nothing from the other
three.

| Cycle | Perspective | ID prefix | Core question |
| --- | --- | --- | --- |
| 1 | 需求与目标符合性 | `RQ` | Does the proposal solve the stated problem, in full, without drift? |
| 2 | 架构与技术可行性 | `AR` | Can this structure be built, at the stated scale and constraints? |
| 3 | 风险与失败模式 | `RK` | What breaks in production, and does the proposal answer for it? |
| 4 | 一致性与可执行性 | `CE` | Can an engineer implement this as written, without asking questions? |

The order carries meaning. Requirement coverage settles *what* the proposal owes
before anyone judges *how*. Consistency runs last because cycles 1–3 all rewrite
prose and would otherwise re-dirty a document that was already checked.

### Choosing The Cycle Set

Four fresh sessions, four worktrees, and four merges is real cost, and it is not
always proportionate. Before starting, size the work and propose a set:

- A substantial proposal, or any request to review it thoroughly, gets all four.
- A short document, a narrow scope ("just check the API section"), or an explicit
  ask for one lens gets the matching subset — keep the relative order above.
- A proposal still in outline form is usually served better by cycles 1 and 2
  alone; risk and consistency review of text that will be rewritten next week is
  mostly wasted.

Confirm the set with the user when proposing fewer than four. Record skipped
perspectives as uncovered in the final report — a narrowed review is never
reported as full coverage, because the gap is exactly what a reader would
otherwise assume was checked.

## Cycle Loop

Read `references/worktree-protocol.md` for the Git mechanics: preflight, local-
only input hydration, worktree creation, commit and merge rules, cleanup, and
recovery. It also covers the report worktree. The loop itself:

1. Preflight once. Then, for each perspective in order:
2. Create a branch and worktree from the current original-branch HEAD.
3. Spawn a fresh worker session (below) and wait for its cycle record. Save the
   returned record verbatim to `<run_root>/cycle-N-record.md` — the coordinator
   writes it (the worker stays confined to its worktree), later cycles never
   read it, and the final report references these artifacts.
4. Inspect the diff, verify, stage, and commit the cycle.
5. Merge back into the original branch, re-verify, clean up the worktree.
6. After the last cycle, write the report through the report worktree.

### Start A Fresh Review Session

Create one worker with `fork_context: false`. Give it only:

- the raw cycle worktree path as project root;
- design document paths resolved inside that worktree;
- upstream requirement source paths, marked read-only;
- review scope;
- cycle number and its assigned perspective;
- that perspective's section from `references/review-perspectives.md`, verbatim;
- repository instruction paths;
- the Worker Cycle Protocol, Revision Authority, Document Verification, and
  Cycle Record below.

Withhold every finding, suggestion, summary, verdict, and open question from
earlier cycles, and do not say which perspectives already ran. A later reviewer
must rediscover anything that still matters by reading the revised document —
that rediscovery is the evidence the earlier fix actually landed. Telling it what
was already found converts an independent check into a confirmation pass.

Tell the worker it owns edits only inside the cycle worktree and only to design
documents; that it must not touch source, tests, build files, or config; that it
must not run Git operations, commit, merge, remove the worktree, or write the
final report; that hydrated local-only files and upstream sources are read-only;
and that it applies only the revisions its perspective authorizes, escalating the
rest rather than deciding for the user.

## Worker Cycle Protocol

Give each worker this responsibility, and tell it to edit its cycle worktree
directly:

1. Read repository instructions, every design document in full, and every
   upstream requirement source in full. Read the whole document before judging
   any part — design defects are usually contradictions between distant
   sections, invisible to a reader working section by section.
2. Build a claim checklist for the assigned perspective, with stable local IDs
   using that perspective's prefix (`RQ-001`, `AR-003`). A claim is anything the
   document asserts, promises, or leaves the reader to assume.
3. Evaluate each claim against the perspective's checklist. Cite document
   evidence with file path, section heading, and line reference. When
   fact-checking a claim about the existing system, read the code read-only and
   record the finding against the document.
4. Classify findings:
   - `critical` — the proposal cannot be implemented as written from this
     perspective: a required outcome is uncovered, two sections materially
     contradict, the technical path is refuted, or an unacceptable risk has no
     mitigation.
   - `major` — implementing it would cause rework: an interface, data shape,
     boundary, failure path, or acceptance criterion is undefined or
     unverifiable; a dependency or migration path is missing.
   - `minor` — expression defects: inconsistent terminology, wrong numbering, a
     diagram contradicting prose, stale or redundant text.
5. For every actionable finding, form a specific revision proposal before
   editing. State the affected section, the change, and what downstream documents
   or decisions the change invalidates.
6. Apply only revisions the perspective authorizes. Propagate each revision to
   in-scope documents that cross-reference the changed section; when propagation
   reaches out of scope, record it as a remaining finding instead.
7. Run the document verification checks.
8. Re-read every changed section against the claim checklist and against the
   sections that reference it.
9. Return the cycle record. Do not write a user-facing report or run Git.

When an unambiguous, in-scope revision is feasible, apply it rather than listing
it as a suggestion — a design document full of review comments is still a
document nobody can build from. When the requirement is contradictory or
underspecified, do not guess; that is what open questions are for.

## Revision Authority

This is the judgment call the whole skill turns on, so it is worth being precise.

A reviewer may revise the document to fill a gap whose content is **uniquely
derivable** from the existing documents, correct the demonstrably wrong side of
an internal contradiction, disambiguate a statement that has one defensible
reading, fix terminology, numbering, cross-references, and diagram-prose
mismatches, add acceptance criteria that make an existing claim verifiable, or
state explicitly an assumption the document already relies on implicitly.

A reviewer must not change the product goal, scope, priority, or timeline; pick
between two or more defensible technical options on the user's behalf; introduce
a requirement with no upstream source; delete or weaken a decision the user wrote
down; restructure the document for taste or normalize a voice the author chose;
or edit any non-design file.

Everything in the second list becomes an open question, not an edit. A design
review that silently makes product decisions is worse than one that finds
nothing, because the user now has a document they believe they wrote.

The test is *unique derivability*, not *obviousness*. Compare:

**Example 1 — revise.**
Document §3.2 reads: "订单创建后进入待支付状态，超时后关闭。"
The state table in §5 already specifies a 30-minute payment timeout.
The gap has exactly one answer consistent with the document, so revise §3.2 to
"…30 分钟内未支付则转入已关闭状态（见 §5 状态转移表）" and record it as a `minor`
consistency finding.

**Example 2 — escalate.**
Same sentence in §3.2, but no timeout appears anywhere in the documents.
Fifteen minutes protects inventory; sixty minutes protects conversion. Both are
defensible, so there is nothing to derive. Leave the text alone, record a `major`
finding, and raise an open question with the options, the trade-off, a
recommendation, and whether it blocks implementation.

**Example 3 — escalate, even though it looks wrong.**
The document specifies synchronous calls throughout, and the reviewer is
confident an async design would serve better. This is a decision the author made,
not a defect. Record the finding with its reasoning and raise it as an open
question. Rewriting it would replace the author's design with the reviewer's
under the guise of review.

## Document Verification

A design proposal has no test suite, so verification is mechanical document
checking, run before and after revision, scoped to the documents under review:

| Check | What it catches |
| --- | --- |
| Relative link and image target existence | Broken references, files moved without updating the design |
| Heading-anchor resolution for in-document links | Sections renamed without updating cross-references |
| Requirement, section, and diagram numbering uniqueness and continuity | Duplicate or skipped IDs after edits |
| Terminology consistency against the document's own glossary | One concept under two names, which reads as two concepts |
| Unresolved markers (`TODO`, `TBD`, `待定`, placeholder text) | Gaps presented as finished sections |
| Fenced diagram syntax (Mermaid, PlantUML) parses | Diagrams that render blank downstream |
| Table, state-machine, and interface signature agreement with prose | The most common place a design contradicts itself |
| Inbound cross-references from other repository documents | Revisions that silently break sibling documents |

Ordinary text tooling is enough:

```bash
# unresolved markers in the documents under review
rg -n 'TODO|TBD|FIXME|待定|待补充|\?\?\?' <doc-paths>

# relative links: print each target, then check existence.
# Keep this example free of '$' capture replacements (-r ...) — skill
# placeholder expansion rewrites them, and -n line prefixes pollute captures.
rg -o --no-line-number '\]\(([^)#][^)]+)\)' <doc-paths>

# inbound references to a document that was revised
rg -n '<revised-doc-basename>' --glob '*.md' <project-root>
```

The coordinator probes check-tool availability once at preflight (see
`references/worktree-protocol.md`) and includes the result in the worker prompt.
A check whose tool is missing is recorded `n-a (tool unavailable, confirmed at
preflight)` instead of being rediscovered every cycle; where a structural manual
fallback exists (for example Mermaid block/node/edge balance), run it and say so
in Notes.

Record every check as run, passed, failed, or not applicable. A check that could
not run is not a passing check, and reporting it as one is how a review comes to
claim coverage it never had.

## Cycle Record

Require every worker's final response to contain:

```markdown
## Cycle N — <perspective>

### Claim Coverage
| ID | Design claim | Document location | Upstream source | Status |

### Findings Before Revision
| Severity | ID | Evidence | Proposed revision |

### Revisions Applied
| Document / section | Change | Finding IDs | Downstream impact |

### Open Questions
| ID | Question | Options and trade-offs | Recommendation | Blocking? |

### Verification
| Check | Result | Notes |

### Remaining Findings
| Severity | ID | Reason not revised | Recommended next action |

### Cycle Verdict
`clean`, `revised`, or `blocked`
```

Claim status uses `covered`, `partially covered`, `uncovered`, or `blocked`.

The `Blocking?` column uses exactly one of: `blocking-now` (the proposal's
foundation is undecided; later perspectives cannot meaningfully review until the
user decides), `blocking-before:<phase>` (implementation may start; the decision
is due before the named phase or milestone), or `no`.

Use `clean` only when this perspective found nothing actionable, no document
changed, and verification passed. Use `revised` when any design document changed,
even if the reviewer believes the proposal is now sound. Use `blocked` when a
document conflict, missing upstream source, unsafe ambiguity, environment
failure, or integration failure prevented completion.

## Open Questions And Escalation

Open questions are a first-class output, not leftovers. Carry every cycle's open
questions into the final report, deduplicated and merged.

Do not feed them into the next cycle's worker prompt. A later perspective must
reach its own conclusions, and an inherited question steers it toward the earlier
reviewer's framing of the problem.

Escalate to the user mid-run, before the final report, only for questions marked
`blocking-now` — the proposal's foundation is undecided and the later
perspectives would otherwise be reviewing text whose premise is open. Present
the options and trade-offs the reviewer recorded, ask for the decision, then
continue — or record it unresolved and continue with the unaffected scope.
Questions marked `blocking-before:<phase>` do not interrupt the run: the
decision deadline is a later named phase, so they travel to the final report
like any other open question.

## Cycle Limit And Convergence

At most one cycle per selected perspective, at most four cycles.

- Do not repeat a perspective. The same lens run twice produces agreement, not
  evidence.
- A `clean` cycle does not end the run. It means that perspective found nothing;
  the remaining perspectives still have not looked.
- After a `blocked` cycle, continue to the next perspective only when it can
  still review meaningful scope and the blocked changes were safely integrated or
  discarded with explicit user authorization.
- Stop immediately for destructive risk, missing authorization, unavailable
  fresh-session tooling, or unsafe worktree integration.
- Re-run a perspective only when its cycle was blocked by an environment or
  integration failure rather than by a design question, and the user authorizes
  the retry.

Completing four cycles is not evidence the proposal is sound. Any remaining
finding, unresolved blocking question, or unmerged branch belongs in the verdict.

## Final Verification And Report

After the last cycle:

1. Inspect the cumulative original-branch document diff and history against
   `original_head`.
2. Confirm every revised cycle merged and every successful temporary worktree and
   branch was cleaned up.
3. Confirm user-owned baseline state was preserved and no user decision was
   silently rewritten.
4. Re-run the document verification checks from the integrated original branch.
5. Reconcile disagreements between cycle records using the current document text
   as evidence. Where two perspectives genuinely disagree about the design,
   preserve both positions rather than picking one — that disagreement is itself
   a finding about the proposal, usually pointing at a real tension the document
   never resolved.
6. Merge and deduplicate open questions across all cycles.

Write one report in Chinese from `assets/final-report-template.md`, through the
report worktree, at:

```text
./docs/reviews/<design-name>-design-review-<YYYYMMDD-HHMMSS>.md
```

Resolve `./docs/reviews/` from the reviewed project root. Create it when needed,
never overwrite an existing report, and do not fall back to another directory.

Set the overall verdict to exactly one of:

- `Ready for implementation`
- `Ready with conditions` — remaining work is bounded and named: open questions
  awaiting a user decision, or minor findings that do not block a start.
- `Not ready` — a critical finding survives, a `blocking-now` open question is
  unresolved, or a selected perspective never ran. An unresolved question that
  blocks only a later named phase (`blocking-before:<phase>`) belongs under
  `Ready with conditions`, with the phase deadline named.

The report must include the perspective, branch, worktree, cycle commit, merge
result, post-merge verification, and cleanup status for every cycle, plus the
perspectives that were skipped.

In the final response, give the verdict, perspectives run and skipped, report
path, revised documents, unresolved open questions needing a user decision,
verification status, original branch, merged commits, and worktree cleanup
status. Name the checks that were not run, and why.
