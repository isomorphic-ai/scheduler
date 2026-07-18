# Lean Delta Audit

Date: 2026-07-18

Purpose: map the current Lean source tree against `REVIEW-by-fable.md` Review #6
and `GPT-5.6-pro-feedback--lean.md` before writing the next task file. The Pro
feedback explicitly worked from a PDF/module inventory rather than a current source
diff, so this audit prevents duplicate theorem names and false gaps.

## Current Source Surface

Imported modules:

- `Basic`
- `ShareSum`
- `L1Conservation`
- `L2Monotone`
- `L3Absorbing`
- `L4Integral`
- `Reachable`
- `Polarity`
- `Canonical`
- `WaitGraph`
- `BudgetWait`
- `Noether`
- `PaperInvariants`
- `Flexibility`

Build status before this audit: `lake build` passes with 17 jobs, and the
`sorry`/`admit`/`axiom` scan is clean.

## Already Present Under Existing Names

### Core conservation and reachability

- `L1_conservation`, `drain_conservation`, `yield_conservation`
- `wf_step`, `wf_drainStep`, `wf_yieldStep`
- `wf_reachable`
- `l4_step`, `l4_drainStep`, `l4_yieldStep`, `l4_reachable`
- `mixed_step_accounted_eq`, `mixed_reachable_accounted_eq`
- `mixed_step_totalQ_eq`, `mixed_reachable_totalQ_eq`

### L2/detector stock monotonicity

- `convertibleStock_drainStep_le`
- `L2_drain_monotone`
- `L2_monotone_under_drain_reachable`
- `blocked_stock_monotone_restricted`
- `blocked_stock_monotone`
- `subthreshold_python_noProgress`
- `subthreshold_python_convertibleStock_increases`

The old unrestricted L2 reading is already refuted by the canonical
sub-threshold counterexample, but it is not yet restated in the future unified
trace semantics.

### Wait graph and detector evidence

- `WaitGraph.closedWaitSet_step`
- `WaitGraph.closedWaitSet_iter`
- `WaitGraph.totalConvertedIn_iter`
- `WaitGraph.L3_waitComponent_absorbing_iter`
- `WaitGraph.detection_sound`
- `BudgetWait.floor_after_exact_budget_window_implies_blockedThroughout`
- `BudgetWait.budgetWindowEvidence`
- `BudgetWait.observed_floor_after_window_start_implies_evidence`
- `BudgetWait.closed_member_budget_after`
- `BudgetWait.closed_floored_within`
- `BudgetWait.closed_wait_set_detected_within_budget`
- `BudgetWait.closed_wait_set_detected_at_common_budget`

These cover the current supplied-component detector soundness and bounded logical
latency result. They do not yet cover lock acquisition, automatic cycle discovery,
fair-scheduler liveness, or `live_process_not_detected`.

### Resolution/yield conservation core

- `YieldPlan`
- `yield_conservation`
- `l4_yield`
- `l4_yieldStep`
- `credit_monotone_under_yield_reachable`

This is the conservation core only. It does not yet model resolution as a control
restart, lock release that breaks a closed component, or the discard-vs-credit
livelock contrast.

### Canonical Python bridge

- `Init`, `Init_WF`, `Init_L4Invariant`
- `pythonQuantum`
- `forcedConvert`
- `pythonRatePlan`
- `pythonZeroWeightPlan`
- `CanonicalPythonStepRel`
- `canonicalPythonStepRel_is_mixedRel`
- `pythonConvert_forced_maximal`

The canonical bridge still takes effective weights as supplied data. The rate
routing module must compute them from the wait graph before the bridge is
end-to-end for scheduling.

### Paper-facing corollaries

- `epistemic_invariant`
- `alignment_invariant`
- `agency_invariant`
- `Noether.clockFreeInvariant_iff_conservedBy`
- `Noether.mixedRel_accounted_clockFree`
- `Noether.clockFreeInvariant_comp`
- `Noether.constant_clockFreeInvariant`
- `Flexibility.collapse_whole_invariant`
- `Flexibility.collapse_delta_balance`

The named invariants are L1 corollaries. They are not yet Theorem 1
(`hoarding_is_self_defeating`) or the dependency-return/private-gain theorem.

## Pro Work-Package Mapping

### WP1 + WP2: unified ontology and trace semantics

Status: open; must be task-file-first.

Current substrate exists in separate modules:

- ledger-only system: `Basic.Sys`
- wait graph: `WaitGraph.WGState`
- bridge model: `BudgetWait.BWState`
- relation wrappers: `StepRel`, `DrainRel`, `YieldRel`, `MixedRel`

Gap:

- no single state that is simultaneously ledger and dependency graph;
- no `WFState` wrapper where well-formedness is part of the state type;
- no `ExecStep` vs `CureStep` split;
- no trace-derived `flowIntegral`;
- `netFlowIntegral` is still a state field whose update law is proven, not yet a
  value derived from the trace and then cached.

Next file: write a WP1+WP2 task file before coding. Recommended name:
`04d-core-trace-task.md`.

### WP3: detector end-to-end

Status: partially present.

Already covered:

- supplied closed component absorption;
- floor evidence is load-bearing for a supplied exact/window-start certificate;
- bounded logical latency for a persistent supplied closed component.

Still missing:

- lock acquisition generating wait edges;
- `observeAttempt`;
- detector cycle/component discovery;
- fair-scheduler liveness;
- slow-but-live safety (`live_process_not_detected`).

This should wait until WP1+WP2 decide the unified step/event vocabulary.

### WP4: resolution policy

Status: conservation core only.

Already covered:

- generic stock-to-credit yield preserves accounting;
- total credit is monotone over yield-only reachability.

Still missing:

- yield as deadlock resolution in the wait graph;
- release of a held lock breaking a supplied closed component;
- restart/control-state model;
- discard-work cycle vs credit-progress termination theorem.

This should be task-file-first after WP1+WP2, and probably after the WP3 state
surface is known.

### WP5: rate routing

Status: open; largest true mathematical gap.

Already covered:

- `ShareSum` divides a supplied weight vector exactly;
- `Canonical` consumes supplied effective weights.

Still missing:

- `waitsOn`/destination forest;
- `routedRate` destination-sum definition;
- recursive-equation equivalence on acyclic parts;
- conservation including stranded cycles;
- inheritance and priority-inversion exclusion corollaries;
- canonical bridge using derived weights.

The Pro destination-sum design supersedes the older well-founded-recursion-first
plan.

### WP6: Theorem 1 and debt ledger

Status: open except for conservative L1 corollaries.

Already covered:

- `epistemic_invariant`, `alignment_invariant`, `agency_invariant` as L1
  corollaries;
- positive/negative trust polarity theorem.

Still missing:

- `ownConversion`;
- dependency-return semantics;
- `route_stranded_claim_strictly_dominates_hoard`;
- `selfish_optima_eq_generous_optima`;
- explicit debt ledger distinguishing taking budget from taking work.

Guard rail from Review #6: do not add horizon or closedness hypotheses if the
proof gets hard; revisit the definitions.

### WP7: paper-facing closure layer

Status: open.

Already covered:

- README theorem-name map exists, but it is prose.

Still missing:

- compiled `PaperClaims.lean`;
- automated theorem inventory / theorem-to-paper matrix;
- `#print axioms` audit for headline theorem names.

## Sequencing Decision

Do not write new operational Lean code for WP3/WP4/WP5/WP6 before WP1+WP2's task
file exists. The next substantive artifact should be the WP1+WP2 task file,
anchored to exact claim sentences from `paper08-expanded.md` or the combined paper
once it is shipped.

Self-contained expansion modules may interleave only when they do not touch the
future unified core. Tier A flexibility already landed under this exception.
