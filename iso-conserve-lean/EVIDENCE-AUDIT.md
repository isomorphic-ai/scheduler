# Lean Evidence Audit

- Git HEAD: `8a1f610`
- Worktree dirty at audit run: `no`
- Build: `PASS`
- Sorry/admit/axiom scan: `PASS`
- Headline `#print axioms`: `PASS`
- Lean modules: `15`
- Source lines under `IsoConserve/`: `2672`
- Syntactic theorem/lemma declarations: `180`

## Build Log

```text
Build completed successfully (18 jobs).
```

## Sorry Admit Axiom Scan

No matches under `IsoConserve/`.

## Headline Axioms

```text
'IsoConserve.L1_conservation' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.L2_monotone' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.L2_drain_monotone' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.blocked_stock_monotone' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.L3_absorbing' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.reachable_deadlock_absorbing' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.L4_stock_is_integral' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.yield_conservation' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.wf_reachable' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.l4_reachable' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.polarity_claim_one' does not depend on any axioms
'IsoConserve.trust_on_absence_loss_counterexample' depends on axioms: [propext]
'IsoConserve.pythonRatePlan_conservation' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.canonicalPythonStepRel_is_mixedRel' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.credit_monotone_under_yield_reachable' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.WaitGraph.L3_waitComponent_absorbing_iter' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.WaitGraph.detection_sound' depends on axioms: [propext, Quot.sound]
'IsoConserve.BudgetWait.detection_sound_with_budget_evidence' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.BudgetWait.closed_wait_set_detected_within_budget' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
'IsoConserve.Noether.mixedRel_accounted_clockFree' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.epistemic_invariant' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.alignment_invariant' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.agency_invariant' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.Flexibility.collapse_whole_invariant' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.L1_conservation' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.L2_monotonicity' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.L3_absorption' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.L4_stock_integral' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.detection_complete_bounded' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.resolution_credit_core' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.canonical_python_step_verified' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.positive_trust_survives_loss' does not depend on any axioms
'IsoConserve.PaperClaims.epistemic_invariant' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.alignment_invariant' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.agency_invariant' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.PaperClaims.flexibility_collapse_whole_invariant' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
```

## Module Inventory

```text
IsoConserve/Basic.lean
IsoConserve/BudgetWait.lean
IsoConserve/Canonical.lean
IsoConserve/Flexibility.lean
IsoConserve/L1Conservation.lean
IsoConserve/L2Monotone.lean
IsoConserve/L3Absorbing.lean
IsoConserve/L4Integral.lean
IsoConserve/Noether.lean
IsoConserve/PaperClaims.lean
IsoConserve/PaperInvariants.lean
IsoConserve/Polarity.lean
IsoConserve/Reachable.lean
IsoConserve/ShareSum.lean
IsoConserve/WaitGraph.lean
```

## Current Paper-To-Lean Matrix

| Paper claim | Current Lean evidence | Status | Boundary |
|---|---|---|---|
| L1 conservation | `IsoConserve.L1_conservation`, reachable accounting corollaries | proved | plan-abstracted kernel |
| L2 monotonicity | `IsoConserve.blocked_stock_monotone`, `IsoConserve.L2_drain_monotone` | proved | repaired blocked/drain scope |
| L3 absorption | `IsoConserve.L3_absorbing`, `IsoConserve.WaitGraph.L3_waitComponent_absorbing_iter` | proved | old kernel plus supplied closed wait component |
| L4 stock/integral | `IsoConserve.L4_stock_is_integral`, `IsoConserve.l4_reachable` | proved | cached field, not yet trace-derived |
| Detection bounded completeness | `IsoConserve.BudgetWait.closed_wait_set_detected_within_budget` | proved | supplied closed component/window evidence |
| Detection soundness with evidence | `IsoConserve.BudgetWait.detection_sound_with_budget_evidence` | proved | supplied closed component |
| Resolution credit core | `IsoConserve.credit_monotone_under_yield_reachable` | proved | stock-to-credit core, not full restart yield |
| Caching polarity | `IsoConserve.polarity_claim_one` and counterexample | proved | positive-trust lattice theorem |
| Canonical Python flow step | `IsoConserve.canonicalPythonStepRel_is_mixedRel` | proved | supplied effective weights |
| Paper invariants | `epistemic_invariant`, `alignment_invariant`, `agency_invariant` | proved | ledger-level corollaries |
| Flexibility collapse | `IsoConserve.Flexibility.collapse_whole_invariant` | proved | conservation identity only |
| Noether slice | `IsoConserve.Noether.mixedRel_accounted_clockFree` | proved | uniqueness obstructed |
| PaperClaims current surface | `IsoConserve.PaperClaims.*` current aliases | proved | future claims omitted until source modules land |
| Unified core trace | `04d-core-trace-task.md` | review-gated | not implemented |
| Rate routing | `04f-rate-routing-task.md` | review-gated | not implemented |
| PN-counter distribution | `04e-lean-task.md` | review-gated | not implemented |
| Detector/progress signal | `04g-detector-progress-task.md` | review-gated | not implemented |
| Resolution yield | `04h-resolution-yield-task.md` | review-gated | not implemented |
| Theorem 1 | `04i-theorem1-task.md` | review-gated | not implemented |
| PaperClaims final closure | `04j-paper-claims-task.md` | review-gated | waits for future modules before final aliases |
