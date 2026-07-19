# Lean Evidence Audit

- Git HEAD: `819bd20`
- Report note: this records the tree at the Git HEAD above; rerun `tools/lean-evidence-audit` for the current HEAD.
- Worktree dirty at audit run: `yes`
- Build: `PASS`
- Sorry/admit/axiom scan: `PASS`
- Headline `#print axioms`: `PASS`
- Lean modules: `19`
- Source lines under `IsoConserve/`: `5619`
- Syntactic theorem/lemma declarations: `344`

## Build Log

```text
Build completed successfully (22 jobs).
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
'IsoConserve.CoreTrace.core_step_conserves_accounted' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.core_reachable_conserves_accounted' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.no_progress_convertible_stock_monotone' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
'IsoConserve.CoreTrace.blocked_stock_monotone' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.deadlock_exec_fixed' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.closed_wait_set_exec_absorbing' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.closed_wait_set_converted_total_fixed' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.cure_preserves_accounted' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.cure_can_break_absorption' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.stock_credit_eq_initial_add_integral' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.L4_stock_is_trace_integral' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.CoreTrace.unrestricted_l2_is_false' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.DetectorProgress.detector_sound' does not depend on any axioms
'IsoConserve.DetectorProgress.periodic_conversion_never_floors' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
'IsoConserve.DetectorProgress.live_process_not_detected' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.DetectorProgress.closed_deadlock_eventually_floors' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
'IsoConserve.DetectorProgress.deadlock_eventually_detected' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.DetectorProgress.detection_latency_le_budget' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.DetectorProgress.useful_reporter_never_reclaimed' depends on axioms: [propext]
'IsoConserve.DetectorProgress.spinner_eventually_reclaimed' depends on axioms: [propext, Quot.sound]
'IsoConserve.DetectorProgress.liar_survives_in_loop_if_it_reports_progress' depends on axioms: [propext]
'IsoConserve.DetectorProgress.liar_fails_reputation_check' depends on axioms: [propext, Quot.sound]
'IsoConserve.ResolutionYield.resolution_yield_conserves' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.ResolutionYield.resolution_yield_loses_no_accounted_work' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
'IsoConserve.ResolutionYield.no_victim_accounted_progress_preserved' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
'IsoConserve.ResolutionYield.accounted_includes_banked_work' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.ResolutionYield.credit_monotone' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.ResolutionYield.restart_has_base_plus_credit' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.ResolutionYield.resolution_yield_releases_held_locks' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
'IsoConserve.ResolutionYield.yield_releases_wait_edge' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.ResolutionYield.yield_breaks_closed_component' depends on axioms: [propext, Classical.choice, Quot.sound]
'IsoConserve.ResolutionYield.least_credit_choice_spreads_burden' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
'IsoConserve.ResolutionYield.canonical_credit_policy_completes_in_two_yields' depends on axioms: [propext]
'IsoConserve.ResolutionYield.canonical_discard_policy_livelocks_for_all_n' depends on axioms: [propext]
'IsoConserve.ResolutionYield.positive_credit_gain_finite_requirement_eventually_completes' depends on axioms: [propext]
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
IsoConserve/CoreTrace.lean
IsoConserve/DetectorProgress.lean
IsoConserve/Flexibility.lean
IsoConserve/L1Conservation.lean
IsoConserve/L2Monotone.lean
IsoConserve/L3Absorbing.lean
IsoConserve/L4Integral.lean
IsoConserve/Noether.lean
IsoConserve/PaperClaims.lean
IsoConserve/PaperInvariants.lean
IsoConserve/Polarity.lean
IsoConserve/RateRouting.lean
IsoConserve/Reachable.lean
IsoConserve/ResolutionYield.lean
IsoConserve/ShareSum.lean
IsoConserve/WaitGraph.lean
```

## Current Paper-To-Lean Matrix

| Paper claim | Current Lean evidence | Status | Boundary |
|---|---|---|---|
| L1 conservation | `IsoConserve.L1_conservation`, reachable accounting corollaries | proved | plan-abstracted kernel |
| L2 monotonicity | `IsoConserve.blocked_stock_monotone`, `IsoConserve.L2_drain_monotone` | proved | repaired blocked/drain scope |
| L3 absorption | `IsoConserve.L3_absorbing`, `IsoConserve.WaitGraph.L3_waitComponent_absorbing_iter` | proved | old kernel plus supplied closed wait component |
| L4 stock/integral | `IsoConserve.L4_stock_is_integral`, `IsoConserve.l4_reachable`, `IsoConserve.CoreTrace.L4_stock_is_trace_integral` | proved | old kernel uses cached field; CoreTrace is trace-derived |
| Detection bounded completeness | `IsoConserve.BudgetWait.closed_wait_set_detected_within_budget` | proved | supplied closed component/window evidence |
| Detection soundness with evidence | `IsoConserve.BudgetWait.detection_sound_with_budget_evidence` | proved | supplied closed component |
| Resolution credit core | `IsoConserve.credit_monotone_under_yield_reachable` | proved | stock-to-credit core, not full restart yield |
| Caching polarity | `IsoConserve.polarity_claim_one` and counterexample | proved | positive-trust lattice theorem |
| Canonical Python flow step | `IsoConserve.canonicalPythonStepRel_is_mixedRel` | proved | supplied effective weights |
| Paper invariants | `epistemic_invariant`, `alignment_invariant`, `agency_invariant` | proved | ledger-level corollaries |
| Flexibility collapse | `IsoConserve.Flexibility.collapse_whole_invariant` | proved | conservation identity only |
| Noether slice | `IsoConserve.Noether.mixedRel_accounted_clockFree` | proved | uniqueness obstructed |
| PaperClaims current surface | `IsoConserve.PaperClaims.*` current aliases | proved | future claims omitted until source modules land |
| Unified core trace | `IsoConserve.CoreTrace.core_reachable_conserves_accounted`, `IsoConserve.CoreTrace.deadlock_exec_fixed`, `IsoConserve.CoreTrace.L4_stock_is_trace_integral` | proved | shared surface; full old-to-new simulation not proved |
| Rate routing | `IsoConserve.RateRouting.routed_rate_conserved`, `IsoConserve.RateRouting.pathfinder_low_share_eq_ten_thirteenths`, `IsoConserve.RateRouting.no_stored_boost_state` | partial | destination-sum KCL, exact shares, and memoryless return proved; recursive equation/canonical wiring remain |
| PN-counter distribution | `04e-lean-task.md` | review-gated | not implemented |
| Detector/progress signal | `IsoConserve.DetectorProgress.detector_sound`, `IsoConserve.DetectorProgress.detection_latency_le_budget`, `IsoConserve.DetectorProgress.live_process_not_detected`, `IsoConserve.DetectorProgress.liar_fails_reputation_check` | proved | supplied component; selected-attempt schedule; honest signal plus reputation |
| Resolution yield | `IsoConserve.ResolutionYield.resolution_yield_conserves`, `IsoConserve.ResolutionYield.yield_breaks_closed_component`, `IsoConserve.ResolutionYield.positive_credit_gain_finite_requirement_eventually_completes` | proved | supplied released-edge witness; Nat-unit toy termination |
| Theorem 1 | `04i-theorem1-task.md` | review-gated | not implemented |
| PaperClaims final closure | `04j-paper-claims-task.md` | review-gated | waits for future modules before final aliases |
