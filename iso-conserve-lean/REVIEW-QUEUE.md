# Lean Review Queue

This file is the handoff for the review-gated task files in the combined
Iso-Scheduler Lean pass. It exists so implementation resumes in dependency order,
with the reviewer checking the semantic choices before code is written.

## Current Gate

Do not start the remaining implementation packages until their task files are
reviewed. The current build is clean for the existing modules; the remaining work is
new-core alignment and expansion modules, not a patch on the old surface.

Verified before this queue was written:

- `lake build` succeeds in `iso-conserve-lean/`.
- `rg "\bsorry\b|\badmit\b|axiom " IsoConserve` returns no matches.
- the git worktree was clean.

## Review Order

1. `04d-core-trace-task.md`
   - WP1/WP2: unified ledger + dependency graph, exec/cure split, trace-derived
     integral.
   - This is the gate for every core-dependent implementation.
   - Key review question: does `CoreState` have the paper's ontology, and does
     `DependencyReturn` mean dependency-return rather than graph adjacency?

2. `04g-detector-progress-task.md`
   - WP3: end-to-end detector and `SIG_PROGRESS`.
   - Depends on the `04d` state/event vocabulary.
   - Key review question: are bounds stated in scheduled attempts/selection counts,
     not time, and is liar handling explicitly reputation rather than detector
     soundness?

3. `04h-resolution-yield-task.md`
   - WP4: work-conserving resolution yield.
   - Depends on `04d` and the detector/wait surface from `04g`.
   - Key review question: does the task distinguish restart-local converted work
     from cumulative delivered work, and does component breakage require a concrete
     released wait-edge witness?

4. `04f-rate-routing-task.md`
   - WP5: conserved rate routing.
   - Depends on `04d`.
   - Key review question: does the task keep intermediate `effectiveRate` separate
     from final runnable-root `routedRate`, and are cycles accounted as stranded
     rate rather than erased?

5. `04e-lean-task.md`
   - Expansion: PN-counter distribution.
   - Self-contained; can be reviewed or implemented independently once signed off.
   - Key review question: does conservation mean global recorded per-node ledgers
     by `max`, not summing replica-local values?

6. `04i-theorem1-task.md`
   - WP6: Theorem 1, dependency-return, debt ledger, strengthened invariants.
   - Depends on `04d`, and uses `04f`/`04h`; some corollaries may use `04e`.
   - Key review question: are `ownConversion` and `DependencyReturn` strong enough
     that no horizon, closedness, external-source, or arbitrary-utility assumption
     is introduced?

7. `04j-paper-claims-task.md`
   - WP7: compiled `PaperClaims.lean` surface and evidence audit.
   - Last step. It may alias only proved theorem sources.
   - Key review question: does the closure layer preserve the engine/Lean division
     honestly and avoid theorem-shaped placeholders?

## Implementation Order After Review

The safe coding order is:

1. `04d` core trace.
2. `04g` detector/progress.
3. `04h` resolution yield and `04f` rate routing, in either order after their
   dependencies are met.
4. `04e` PN-counter, any time after its review because it is self-contained.
5. `04i` Theorem 1/dependency-return.
6. `04j` PaperClaims/evidence audit.

If review changes a task file, update the task file first and commit that review
resolution before writing Lean code.

## Standing Guardrails

- Do not perturb `monotone_under_adversary`; the scheduler and caching tracks share
  it.
- Every abstraction gap gets a FINDINGS entry when found.
- No `sorry`, `admit`, or new `axiom`.
- Use `/usr/local/bin/codex-git-commit` for coherent commits with explicit file
  pathspecs.
- Keep task files and implementation in the same branch history so paper citations
  can point to pinned commits.
