# IsoConserve Lean

Lean 4 formalization companion for Paper 04 of the Isomorphic Scheduler series.

Build:

```sh
lake build
```

Evidence audit:

```sh
../tools/lean-evidence-audit
```

Use `../tools/lean-evidence-audit --write` from `iso-conserve-lean/` to generate
`EVIDENCE-AUDIT.md` for a release or paper-pinning pass.

The package is pinned to Lean `v4.30.0` and intentionally uses only Lean/Std so it
can build offline in this workspace.

Review #8 independently reproduced the build on a second machine with a fresh
Lean `v4.30.0` toolchain after moving the synced `.olean` cache aside: 24 jobs
rebuilt from source, the sorry/admit/axiom scan stayed clean, and the theorem
statements matched the recorded FINDINGS.

## Provenance

The reviewed Lean branch is `iso-conserve-lean` in
`git@github.com:isomorphic-ai/scheduler.git`, with local base commit
`e77bd5c8fbef3b07d52afe26c9e6261dee6fd181` (`Finish theorem 4`). When publishing
follow-up proof/doc changes, keep `04b-lean-task.md`, `NEXT-TASKS.md`, and
`REVIEW-by-fable.md` in the same committed tree so paper references have a single
immutable target.

## Model

The model uses a finite indexed process set, `Fin n -> Proc`, to avoid structural
process aliasing. A `FlowPlan` supplies the already-computed per-process injection
shares and conversion amounts for one step. This matches the conservation proof
strategy in `04-lean-task.md`: L1 depends on the fact that shares sum back to the
injected quantum, not on the details of the effective-rate recursion.

For the blocked/no-progress detector regime, a separate `DrainPlan` models stock
draining from blocked processes back to the reservoir. `DrainPlan.drain_blocked`
requires runnable processes to drain zero.

For the resolution/banking reading, `YieldPlan` moves stock into credit while
leaving `netFlowIntegral` unchanged. This is the Lean form of the task file's
"banking must not touch the external-flow integral" gotcha.

`RatePlan` is an optional refinement of `FlowPlan` whose shares are explicitly the
weighted partition `quantum * weight / totalWeight`; `ratePlan_share_sum` wires that
refinement to `share_sum_of_partition`. `RatePlan.weight_blocked` records that
non-runnable processes have zero weight in the canonical split. Plain `FlowPlan`s
remain deliberately unconstrained so L1/L4 apply to any accounting-balanced
allocation.

`IsoConserve.CoreTrace` is the unified WP1/WP2 core. Its `CoreState` is both a
ledger and a dependency graph: process stock, credit, base rate, detector budget,
restart-local progress, `wants`, and `holds` live in one record. Public transitions
use `WFState`, with ordinary execution separated from cure steps as `ExecRel`,
`CureRel`, and `CoreRel`. `ExecRel` covers work, acquire, and normal release;
`CureRel` covers drain, yield, route, and claim release. The work step does not
implicitly release locks; release is an explicit event, which keeps the L3
ordinary-execution/cure distinction visible.

## Paper Law Map

- L1 conservation: `IsoConserve.L1_conservation`
  proves `accounted (step s plan) = accounted s`.
- Well-formedness preservation: `IsoConserve.wf_step`
  preserves non-negativity and the accounting invariant.
- Share sum: `IsoConserve.share_sum_of_partition`
  proves the usual weighted-share partition lemma over rationals.
- L2 monotonicity: `IsoConserve.L2_monotone`
  proves convertible stock is non-increasing for the explicit no-progress drain
  step. `IsoConserve.L2_drain_monotone` is the scope-explicit export alias.
  `IsoConserve.blocked_stock_monotone` proves the stronger detector lemma: a
  process that starts blocked has non-increasing stock across any mixed sequence
  of flow, drain, and yield steps.
- L3 absorption: `IsoConserve.L3_absorbing`
  proves an empty at-table remains deadlocked and makes no conversion progress.
  `IsoConserve.reachable_deadlock_absorbing` lifts the fixed-point behavior across
  reflexive-transitive closure.
- L4 stock = integral: `IsoConserve.L4_stock_is_integral`,
  with preservation lemmas `l4_step`, `l4_drainStep`, and `l4_yield`.
- Yield conservation: `IsoConserve.yield_conservation` and
  `IsoConserve.wf_yieldStep` prove that stock-to-credit banking preserves
  accounting and well-formedness.
- Reachable invariants: `IsoConserve.wf_reachable` and `IsoConserve.l4_reachable`
  lift WF and L4 over mixed flow/drain/yield reachability.
- Canonical plan instance: `IsoConserve.pythonRatePlan` constructs a `RatePlan`
  using Python-style quantum, supplied effective weights, and a finite forced
  conversion loop bounded by remaining work. `IsoConserve.pythonRatePlan_conservation`
  instantiates L1 on that plan. `IsoConserve.canonicalPythonStepRel_is_mixedRel`
  is the bridge theorem: every well-formed canonical Python-style flow step
  (positive effective weight or all-zero-weight fallback) is a verified
  mixed-system step. `IsoConserve.coreAsSys`, `routedWeights`,
  `canonical_step_uses_derived_routed_rates`, and
  `pythonRoutedRateStep_verified_mixed` bridge the unified `CoreState` routing
  model back into that old `Sys` API: with a positive routed-weight denominator,
  the canonical Python-style step uses derived `RateRouting.routedRate` weights.
- Resolution credit core: `IsoConserve.credit_monotone_under_yield_reachable`
  proves banked credit is non-decreasing over yield-only reachability.
- Resolution yield WP4:
  `IsoConserve.ResolutionYield.resolution_yield_conserves` and
  `resolution_yield_loses_no_accounted_work` prove that restart-local converted
  work is banked into credit without losing accounted progress.
  `restart_has_base_plus_credit`, `resolution_yield_releases_held_locks`,
  `yield_releases_wait_edge`, and `yield_breaks_closed_component` prove the
  release/restart surface with an explicit released-lock witness.
  `least_credit_choice_spreads_burden` captures the least-credit yielder policy.
  The credit-vs-discard comparison is theorem-level via
  `canonical_credit_policy_completes_in_two_yields`,
  `canonical_discard_policy_livelocks_for_all_n`, and
  `positive_credit_gain_finite_requirement_eventually_completes`.
- Wait-graph L3/detection v2:
  `IsoConserve.WaitGraph.closedWaitSet_step`,
  `IsoConserve.WaitGraph.closedWaitSet_iter`,
  `IsoConserve.WaitGraph.totalConvertedIn_iter`, and
  `IsoConserve.WaitGraph.L3_waitComponent_absorbing_iter` prove closed-component
  absorption and no conversion progress for any finite number of wait-graph steps.
  `IsoConserve.WaitGraph.detection_sound` packages the supplied floor and closed
  component facts as a `genuineDeadlock`.
- Budget/wait bridge v3:
  `IsoConserve.BudgetWait.budget_drop_implies_blocked` proves that a one-step
  budget decrease can only come from computed blocking.
  `IsoConserve.BudgetWait.floor_after_exact_budget_window_implies_blockedThroughout`
  proves that draining from any starting budget `k` to zero over exactly `k`
  steps implies the process was blocked throughout.
  `IsoConserve.BudgetWait.observed_floor_after_window_start_implies_evidence`
  turns an observed floor time plus a supplied window start into an existential
  `budgetWindowEvidence` certificate.
  `IsoConserve.BudgetWait.closed_wait_set_detected_within_budget` proves bounded
  detection completeness: a closed component floors within any observation bound
  at least as large as each member's starting budget. The paper-facing soundness
  theorem `IsoConserve.BudgetWait.detection_sound_with_budget_evidence` combines
  exact-window budget history with closed-component absorption.
- Unified core/trace WP1-WP2:
  `IsoConserve.CoreTrace.core_step_conserves_accounted` and
  `IsoConserve.CoreTrace.core_reachable_conserves_accounted` prove L1 over the
  unified `CoreRel`; `core_step_preserves_totalQ` and
  `core_reachable_preserves_totalQ` carry the declared total.
  `CoreTrace.no_progress_convertible_stock_monotone` proves the repaired L2 over
  explicit detector no-progress drain/yield steps, while
  `CoreTrace.blocked_stock_monotone` uses the blocked-preserving relation required
  by Review #7. `CoreTrace.unrestricted_l2_is_false` restates the sub-threshold
  counterexample on the unified state.
  `CoreTrace.deadlock_exec_fixed` proves global deadlock is fixed under ordinary
  `ExecRel` reachability, and `CoreTrace.cure_can_break_absorption` gives a
  concrete release-claim witness showing cure can intentionally escape absorption.
  `CoreTrace.stock_credit_eq_initial_add_integral`,
  `CoreTrace.L4_stock_is_trace_integral`, and
  `CoreTrace.cached_integral_eq_trace_integral` provide the trace-derived L4
  surface via `flowIntegral`.
- Unified detector/progress WP3:
  `IsoConserve.DetectorProgress.conversion_refills_budget`,
  `blocked_nonconversion_drains_budget`, `budget_drop_implies_blocked`, and
  `budget_after_ge_pred` lift the one-attempt detector budget facts to the
  shared `CoreState`.
  `IsoConserve.DetectorProgress.detector_sound` proves a supplied nonempty
  closed and floored component is a genuine deadlock witness.
  `periodic_conversion_never_floors` and `live_process_not_detected` prove the
  slow-live safety direction for schedule prefixes when the process starts at
  full budget and converts on each selected attempt.
  `closed_deadlock_eventually_floors`, `deadlock_eventually_detected`, and
  `detection_latency_le_budget` prove bounded detection by per-member selection
  counts. The `SIG_PROGRESS` submodel is covered by
  `useful_reporter_never_reclaimed`, `spinner_eventually_reclaimed`,
  `liar_survives_in_loop_if_it_reports_progress`, and
  `liar_fails_reputation_check`.
- Rate routing WP5:
  `IsoConserve.RateRouting.routed_rate_conserved` proves the KCL law for
  priority flow: every unfinished process's base rate is either routed to a
  runnable destination or remains accounted as `strandedRate` when the wait-chain
  does not reach a runnable root. `routedRate_nonneg` and `strandedRate_nonneg`
  require `CoreWF.rate_nonneg`, matching Review #7's repair for rational rates.
  `blocked_rate_reaches_holder`, `blocked_rate_reaches_root`,
  `base_rate_goes_to_destination`, and `trapped_rate_goes_to_stranded` are the
  current inheritance/downstream accounting lemmas.
  `effective_rate_eq_base_plus_waiters` proves the paper's recursive equation
  under the explicit `acyclicFrom`/`WaiterPartitionAt` certificate: the upstream
  waiters form a disjoint finite tree rooted at the evaluated process. That
  certificate is the fuel-bounded acyclic premise; cyclic/over-fuel claims remain
  in `strandedRate` under the KCL theorem. `transitive_rate_routing` proves the
  one-edge destination-following step, and `multiple_waiters_sum_not_max` proves
  that two distinct live waiters contribute the sum of their base rates, not the
  maximum.
  `remove_wait_edge_restores_base_rate` and `no_stored_boost_state` prove the
  memoryless-return surface: rates are derived from the current graph, not stored
  as boost state. `shares_sum_quantum` proves runnable shares sum back to the
  quantum when the routed-rate denominator is positive. The canonical Pathfinder
  witness is exact over rationals: `pathfinder_low_share_eq_ten_thirteenths`,
  `pathfinder_medium_share_eq_three_thirteenths`, and
  `canonical_priority_inversion_cannot_form`. `canonical_step_uses_derived_routed_rates`
  wires these derived routed weights into the old `Canonical.pythonRatePlan` API
  under the positive routed-weight denominator required by the canonical share
  split.
- PN-counter distribution 04e:
  `IsoConserve.PNCounter.merge_idem`, `merge_comm`, and `merge_assoc` prove the
  merge ACI surface for the pointwise-max ledger join, with `le_merge_left`,
  `le_merge_right`, and `merge_least` exposing merge as the least upper bound.
  `eval_eq_globalRecorded` proves merge-tree convergence to the pointwise global
  record, independent of tree shape. `replica_le_globalRecorded`,
  `partition_left_le_heal`, `partition_right_le_heal`,
  `off_partition_decrement_surfaces`, and
  `off_partition_increment_surfaces` prove the no-loss/heal surface: recorded
  off-partition debt and credit appear in the healed ledger.
- Theorem 1 finite-action core:
  `IsoConserve.TheoremOne.route_stranded_claim_strictly_dominates_hoard` proves
  that, for a stranded claim, routing to a converter on a dependency-return edge
  strictly beats hoarding for the holder's `ownConversion`. The implemented
  optimality theorem is the reviewed fallback:
  `TheoremOne.selfish_optima_eq_generous_optima` proves route is both selfishly and
  generously optimal inside the finite `{hoard, route, release}` action set.
  `selfish_optimum_contains_no_stranded_claim` and
  `generous_optimum_contains_no_stranded_claim` rule out hoard as an optimum in
  that set. The debt mini-model is covered by
  `budget_transfer_creates_equal_debit`, `global_debt_sums_to_zero`,
  `stolen_budget_is_not_net_progress`, and
  `dependency_makes_debt_return_to_debtor`.

## Paper Claims Surface

`IsoConserve.PaperClaims` is the compiled paper-facing alias layer for the current
proved surface. It contains only aliases or thin corollaries whose source theorems
already exist. The current surface includes the core aliases
`PaperClaims.core_conservation`, repaired `PaperClaims.L2_monotonicity`,
`PaperClaims.core_deadlock_exec_fixed`, and `PaperClaims.core_trace_integral`;
detector/progress aliases such as `PaperClaims.detector_sound`,
`PaperClaims.detection_latency_le_budget`, `PaperClaims.live_process_not_detected`,
`PaperClaims.progress_signal_useful_kept`, and
`PaperClaims.progress_signal_spinner_reclaimed`; resolution/routing/distribution
aliases such as `PaperClaims.resolution_yield_loses_no_work`,
`PaperClaims.routed_rate_conserved`, `PaperClaims.priority_inversion_cannot_form`,
`PaperClaims.effective_rate_eq_base_plus_waiters`,
`PaperClaims.multiple_waiters_sum_not_max`, `PaperClaims.pn_counter_merge_converges`,
and `PaperClaims.pn_counter_debt_surfaces`;
plus the finite-action Theorem 1 aliases
`PaperClaims.hoarding_is_self_defeating` and
`PaperClaims.selfish_optima_eq_generous_optima`. The canonical bridge aliases
`PaperClaims.canonical_step_uses_derived_routed_rates` and
`PaperClaims.python_routed_rate_step_verified` expose the derived-routed-rate
Python-step instance.

`PaperClaims.L2_monotonicity` is explicitly the repaired/restricted reading over
blockedness-preserving core traces. The known-false unrestricted reading is exposed
separately as `PaperClaims.unrestricted_l2_is_false`.

The evidence audit prints `#print axioms` for the headline set and treats the
axiom surface as clean only when every theorem uses a subset of
`[propext, Classical.choice, Quot.sound]`. Review-gated future claims should be
added to `PaperClaims` only after their proof modules land; missing or partial
claims are tracked in `NEXT-TASKS.md` and `REVIEW-QUEUE.md`, not represented by
placeholders.

## Reusable Monotonicity Kernel

`IsoConserve.monotone_under_adversary` is the abstract closure lemma suggested by
the caching-series bridge note. It is stated over an explicit preorder relation:
if every adversary step moves `f` downhill, then every reflexive-transitive sequence
of adversary steps also moves `f` downhill.

`IsoConserve.L2_monotone_under_drain_reachable` instantiates that kernel for
repeated scheduler drain steps and `convertibleStock`. The same kernel should fit
the caching paper's polarity theorem with state ordered by storage loss and measure
ordered by trusted-set inclusion.

`IsoConserve.blocked_stock_monotone_restricted` is the scheduler-side blocked-stock
instance using the same generic kernel.

## Caching Polarity Instance

`IsoConserve.Polarity` contains the second instance of the shared kernel. It models
a cache store as a characteristic set of `(key, proof)` records, defines storage
loss as subset while authority is unchanged, and defines positive trust as
presence-and-match against authority.

`IsoConserve.polarity_claim_one` proves paper02's polarity claim: across any
reflexive-transitive sequence of storage-loss steps, the trusted set can only
shrink. This is the formal bridge between scheduler L2's downhill direction and
the caching series' "loss is invalidation" theorem.

`IsoConserve.trust_on_absence_loss_counterexample` proves the negative-polarity
half: a trust-on-absence predicate strictly grows after a one-step loss in a
one-key, one-proof cache. Together these are the mechanized shape of Claim 1.

## Paper Invariants

`IsoConserve.PaperInvariants` packages three combined-paper corollaries of L1
under the names the paper can cite:

- `epistemic_invariant`: from initial WF and mixed reachability, every reachable
  state's ledger equals the initial declared `totalQ`.
- `alignment_invariant`: for any mixed step, a local account's decrease is exactly
  the matching increase in the outside account.
- `agency_invariant`: if a local account increases in a mixed step, the outside
  account strictly decreases; private gain is paid for inside the conserved ledger.

## Flexibility Collapse

`IsoConserve.Flexibility` formalizes the conservation identity for the paper's
middle-way reading. A `collapse` step moves a non-negative amount from `potential`
to `actual`, with these named theorems:

- `collapse_whole_invariant`: potential plus actual is conserved.
- `collapse_potential_monotone`: potential does not increase.
- `collapse_actual_monotone`: actual does not decrease.
- `collapse_actual_gain_eq_potential_loss` and `collapse_delta_balance`: the two
  apparent changes are the same event viewed from opposite sides.

This module deliberately covers only the conservation identity. The phantom-race
and carried-distribution demonstrations remain empirical engine results.

## PN-Counter Distribution

`IsoConserve.PNCounter` is the standalone 04e module for the paper's distribution
reading. It imports only `Std` and models a PN-counter as per-node grow-only
positive and negative ledgers. `merge` is componentwise `max`, not addition; this
is the key conservation correction that prevents double-counting contributions
already seen by both replicas.

The semilattice surface is `merge_idem`, `merge_comm`, `merge_assoc`,
`le_merge_left`, `le_merge_right`, and `merge_least`. `MergeTree.eval` evaluates
arbitrary binary merge orders, and `eval_eq_globalRecorded` proves every merge
tree yields the same pointwise `globalRecorded` ledger over its leaves.

The no-loss surface is `replica_le_globalRecorded`,
`partition_left_le_heal`, `partition_right_le_heal`,
`off_partition_decrement_surfaces`, and `off_partition_increment_surfaces`.
These are the checked form of "hidden by partition, not destroyed." The module
does not prove CAP-as-schedule, the Present/Future publish protocol, gossip
latency bounds, open-system sources/sinks, or Byzantine contribution safety.

## Theorem 1

`IsoConserve.TheoremOne` is the 04i finite-action formalization of the paper's
hoarding theorem. The payoff definition is `ownConversion`: converted benefit
available to the actor, not nominal possession of unusable stock. A
`StrandedClaim` is held stock that the holder cannot convert, and
`DependencyReturn` is a directed dependency-return edge, currently the core
`blockedOn` relation rather than undirected graph adjacency.

The local strict theorem is `route_stranded_claim_strictly_dominates_hoard`.
Given a positive stranded claim held by `i`, a converter `j`, and
`DependencyReturn s i j`, routing strictly improves `i`'s own attainable
conversion over hoarding. `hoarding_is_self_defeating` exports the same core under
the paper-facing name.

The policy lift landed at the finite-action-set level:
`selfish_optima_eq_generous_optima` proves that `route` is both selfishly and
generously optimal among `{hoard, route, release}` for the supplied claim.
The unrestricted full-policy theorem remains future work; the task file now records
that this fallback is the committed level.

The standalone `DebtLedger` mini-model distinguishes taking budget from taking
work. `budget_transfer_creates_equal_debit` and `stolen_budget_is_not_net_progress`
show that budget capture is paired with debt, `global_debt_sums_to_zero` shows
debits and receivables are the same global matrix viewed from opposite sides, and
`dependency_makes_debt_return_to_debtor` pins the dependency-return reading. The
ledger is not a new `CoreState` field in this pass.

## Noether Slice

`IsoConserve.Noether` contains the first formal slice of the discrete Noether
experiment. It defines `StutterRel`, `ConservedBy`, and `ClockFreeInvariant`, then
proves `clockFreeInvariant_iff_conservedBy`: a quantity is invariant over all
finite stutter/relabeling paths exactly when it is conserved by each real step.

`IsoConserve.Noether.mixedRel_accounted_clockFree` instantiates this theorem for
the scheduler's mixed flow/drain/yield relation and the charge
`fun s => accounted s`. `mixedRel_accounted_eq_totalQ_under_clockFree` connects
that charge back to `totalQ` for a well-formed starting state.

The module also records the uniqueness obstruction:
`clockFreeInvariant_comp`, `constant_clockFreeInvariant`,
`mixedRel_accounted_postcompose_clockFree`, and `mixedRel_constant_clockFree`
show that postcompositions of a conserved charge and constant charges are
clock-free too. Bare stutter invariance therefore cannot prove Q unique; a future
uniqueness theorem would need extra normalization or observability assumptions.

## Canonical Python-Plan Instance

`IsoConserve.Canonical` defines `Init`, `pythonQuantum`, `forcedConvert`,
`pythonRatePlan`, and the well-formed canonical step relation
`CanonicalPythonStepRel`. The conversion loop is finite because it is bounded by
`remainingWork`; `pythonConvert_forced_maximal` proves that if the loop stops before
exhausting remaining work, the residual stock is below `convertCost`.

The canonical plan is parameterized by supplied effective weights. This keeps the
wait-graph/effective-rate computation outside the accounting kernel while proving
that, once those weights are available and have positive total weight, the
Python-style plan is a verified `RatePlan`. `IsoConserve.RateRouting` now proves
the finite destination-sum conservation law for deriving routed rates from the
current wait graph, and `canonical_step_uses_derived_routed_rates` wires those
derived rates into the old canonical plan under the positive denominator
hypothesis. The named bridge theorem `canonicalPythonStepRel_is_mixedRel` proves
that the canonical Python-style transition is an instance of the verified
transition system. The all-zero-weight Python fallback is represented by
`pythonZeroWeightPlan`: it injects no stock from the reservoir and still runs the
forced conversion loop on stock already held by runnable processes.
`wf_pythonStepOfWF`, `wf_pythonZeroWeightStepOfWF`,
`l4_pythonStepOfWF`, and `l4_pythonZeroWeightStepOfWF` inherit the existing
reachable WF/L4 preservation theorems for those concrete steps.

`IsoConserve.subthreshold_python_noProgress` and
`IsoConserve.subthreshold_python_convertibleStock_increases` mechanize the L2
threshold finding: a canonical one-process step can make no conversion progress
while increasing convertible stock. These two closed examples use `native_decide`,
so they include Lean's compiler/evaluator and rational kernel operations in the
trust base; the general theorems above are ordinary kernel-checked proofs.

## Wait-Graph Dynamics V2

`IsoConserve.WaitGraph` is the separate v2 module requested by
`04b-lean-task.md`. It models finite process and lock identities, a `wants` field,
a `holds` table, computed `runnable`, conversion to `done`, and lock release by
done processes.

The key predicate is `closedWaitSet s C`: every process in the component `C` is
unfinished and blocked on a lock held by another process in `C`. From that:

- `closedWaitSet_not_runnable` proves no member is runnable.
- `done_releases_locks` proves done processes hold no locks after the step.
- `closedWaitSet_step` proves the closed component is preserved by one step.
- `closedWaitSet_iter` proves the closed component is preserved for any finite
  number of steps.
- `totalConvertedIn_iter` proves converted progress inside `C` is unchanged for
  any finite number of steps.
- `L3_waitComponent_absorbing_iter` is the paper-facing forever-absorption theorem.
- `detection_sound` records that a supplied nonempty floored closed component has
  the fields of `genuineDeadlock`; the floor evidence is carried, not derived here.

This module proves soundness once a closed wait component is supplied. It does not
try to discover cycles automatically; that remains a graph-search layer above the
theorem.

## Wait-Graph Deviations

`IsoConserve.WaitGraph` is a separate v2 model for closed-component absorption, not
the full Python lock protocol.

- `wants` is copied unchanged by `step`; no step changes which lock a process wants.
- `holds` is release-only; done processes release locks, but no process acquires
  new locks.
- Deadlocks can persist in-model, but new deadlocks do not form through acquisition.
- `canConvert` uses computed `runnable` and stock; it does not model acquiring the
  wanted lock before conversion.
- `budget` is stored and used by `floored`, but this module does not drain or refill
  budgets.
- `blockedOn` requires `q != p`, so single-process self-deadlock is intentionally
  outside this closed-component theorem.
- `genuineDeadlock.not_runnable` is derivable from `internally_blocked`; it is kept
  as a detector-facing convenience field.

The budget-floor evidence and the wait-graph closure evidence currently live in
different Lean models. The accounting kernel proves blocked stock monotonicity under
drain dynamics; `WaitGraph` proves closed components are absorbing and
non-converting. `IsoConserve.BudgetWait` is the separate v3 bridge model that joins
computed blocking with detector budget drain/refill.

## Budget/Wait Bridge V3

`IsoConserve.BudgetWait` is the `04c-lean-task.md` bridge model. It keeps the
finite lock/wait structure, computes `runnable` from `wants`/`holds`, and adds
detector budget dynamics:

- converting processes refill `budget` to `budgetCap`;
- blocked non-converting processes drain one budget unit;
- unblocked non-converting processes leave budget unchanged;
- done processes release locks.
- the drain branch does not separately check `done`, so a done process that still
  wants a held lock can keep draining; this is harmless for the B1-B4 bridge
  theorems and kept explicit as a v3 deviation.

The main evidence theorem is
`floor_after_exact_budget_window_implies_blockedThroughout`: if a process starts a
witness interval with budget `k` and reaches zero after exactly `k` steps, then it
was blocked at every step in that interval. This is the theorem that makes the
floor evidence load-bearing. The full-cap version
`floor_after_full_drain_window_implies_blockedThroughout` is a corollary.

`budgetWindowEvidence` is the detector-facing existential package: it records the
window start, window length, ending observation time, starting budget, observed
floor, and blocked history. `observed_floor_after_window_start_implies_evidence`
proves this package from an observed floor at time `observedAt` plus a supplied
candidate window start whose budget equals `observedAt - start`. This is not a
floor-alone theorem; automatic discovery of the most recent refill point would
require trace/log state outside this bridge model.

`detection_sound_with_budget_evidence` packages the end-to-end certificate for a
supplied closed component whose members share a starting budget/window `k`: the
component remains closed, is floored at the end, every member was blocked
throughout the window, and converted progress inside the component is unchanged.

`closed_member_budget_after` proves the matching completeness direction for closed
components: every member's budget after `k` bridge steps is exactly its starting
budget minus `k` (Nat truncated subtraction). Consequently
`closed_floored_within` floors a closed component once the observation bound is at
least every member's starting budget, and
`closed_wait_set_detected_within_budget` packages the resulting
`evidencedDeadlock`. This is the bounded logical-latency theorem; it is measured
in bridge steps, not wall-clock time.

Review #7's cross-track note reports that the deployed phase-2 deadlock sidecar
uses the same detector transition shape as `BudgetWait.budgetAfter`: drain only
while the transaction is in the wait set, refill on forward progress counters, and
otherwise leave the budget unchanged. That makes the empirical detector an
implementation-level instance of the checked semantics, not merely a matching
outcome.

V3 still deliberately omits lock acquisition and automatic cycle discovery.

## Detector/Progress WP3

`IsoConserve.DetectorProgress` is the 04g lift of the detector bridge to the
unified `CoreTrace.CoreState`. A scheduled attempt observes one process: conversion
spends one unit of stock and refills its Nat detector budget to `budgetCap`;
blocked non-conversion drains the budget by one with truncated subtraction; and an
unblocked non-converting attempt leaves the budget unchanged. `runSchedule` is the
only driver used by the headline theorems.

The no-false-positive theorem is `detector_sound`: a supplied candidate component
that is closed in the current lock graph, floored, and nonempty packages as
`GenuineDeadlock`. The floor is detector evidence, but closure is the structural
reason the component is genuinely blocked; the budget-window theorems are what make
the floor evidence meaningful across a schedule.

Bounded completeness is stated in selected attempts. If every member of a closed
component is selected at least `k` times and every member starts with budget at most
`k`, then `closed_deadlock_eventually_floors` and
`deadlock_eventually_detected` show the component is caught after that schedule.
`detection_latency_le_budget` exposes the same result as a prefix-existence
statement. It does not claim automatic cycle discovery.

Slow-live safety is stated over a genuine selected-attempt window.
`selectionWindowSafe` carries a remaining-selection allowance: conversion resets
it to the window size, other processes' selections leave it alone, and a selected
non-conversion may not consume its final slot. With initial
`budget = budgetCap` and positive cap, `periodic_conversion_never_floors` proves
the budget is nonzero on every prefix, and `live_process_not_detected` shows any
component containing that process cannot fire. The theorem-level witnesses
`once_per_selection_window_never_floors` and `missed_selection_window_floors`
make the window bite in both directions; the former also refutes the old
every-selection premise on its concrete schedule. Because `observeAttempt`
preserves the wait graph, repeated block/unblock/reconvert histories remain a
typed-core-trace concern rather than a claim of this schedule-only model.

The progress signal is an honest self-reporting channel, not Byzantine enforcement.
A rising report refills budget and is trusted by the in-loop detector
(`liar_survives_in_loop_if_it_reports_progress`); the separate reputation predicate
catches reported progress that exceeds delivered progress
(`liar_fails_reputation_check`).

## Resolution Yield WP4

`IsoConserve.ResolutionYield` is the 04h restart/yield model over the shared
`CoreTrace.CoreState`. `resolutionYield s y` banks
`s.convertCost * convertedSinceRestart y` into `credit y`, resets
`convertedSinceRestart`, clears `wants`, rewinds `pc`, releases every lock held by
`y`, and expands the restart budget cap to the old base cap plus the banked Nat
progress units.

The accounting theorems are `resolution_yield_conserves` for the whole state and
`resolution_yield_loses_no_accounted_work` /
`no_victim_accounted_progress_preserved` for the yielder's local account.
`accounted_includes_banked_work` names the credit transfer, and `credit_monotone`
states the monotonicity side under the explicit premise that the banked Q value is
nonnegative.

Component breakage is not inferred from yield alone. A `ReleaseWitness` identifies
the yielder, waiter, and lock edge being released. `yield_releases_wait_edge` proves
that edge is gone after the yield, and `yield_breaks_closed_component` proves the
supplied component is no longer closed when that edge was the waiter's only
internal blocker. The cure step releases without instant regrant; later lock
acquisition remains a separate ordinary execution step.

The livelock contrast is a small deterministic model. The credit policy completes
the canonical two-unit case, while the discard policy is a fixed point for all
iterations. `positive_credit_gain_finite_requirement_eventually_completes` is the
Nat-unit finite-requirement toy theorem; it deliberately avoids the Zeno-false
arbitrary-positive-rational statement rejected in Review #7.

## What The Plan Abstraction Covers

The abstraction proves L1/L4 for a superset of the Python transition's accounting
behaviors: any plan whose reservoir and stock postconditions are well-formed, not
only the deterministic effective-rate split. This is useful for the keystone laws
because it isolates the bookkeeping from the scheduler mechanics.

The canonical weighted split is represented by `RatePlan`, but ordinary `FlowPlan`
does not require its shares to come from effective rates. Conversion is also
plan-supplied rather than forced maximal as in Python's `while stock >= cost` loop;
the canonical `pythonRatePlan` restores forced-maximal conversion for the
positive-total-weight Python branch, and `pythonZeroWeightPlan` restores the
all-zero-effective-weight fallback. Plain `FlowPlan` abstracts the quantum rule to
`reservoir_after_nonneg`; the canonical `pythonQuantum` restores
`min(reservoir, |at_table|)` for the positive-weight branch.

## Deliberate Deviations From `iso_conserve.py`

This first formal core proves the accounting laws for a plan-based transition
system, not the full Python lock/wait dynamics.

- No lock table, `wants`, or `holds`.
- `runnable` is an explicit frozen field, not recomputed from locks.
- `done` is frozen; no step marks a process done, releases locks, or wakes waiters.
- `FlowPlan` conversion is optional rather than Python's forced-maximal conversion.
- `RatePlan` covers the weighted partition once weights are supplied, and
  `pythonRatePlan` is the canonical positive-total-weight instance over supplied
  weights. `IsoConserve.RateRouting` now formalizes the destination-sum routing
  law, certificate-scoped recursive acyclic equation, exact Pathfinder shares, and
  canonical `pythonRatePlan` wiring to derived routed rates.
- Python's all-zero-effective-weight fallback is included as a zero-share
  `FlowPlan`, not as a `RatePlan`.
- Credit is accounted, and stock-to-credit yield/banking is modeled as `YieldPlan`;
  full victimless-resolution behavior remains outside this pass.

The original plan-kernel L3 theorem is faithful to Python's empty-table branch,
which is a no-op. In that model the `done` component is frozen everywhere, so the
`not allDone` preservation is true for a model-wide reason rather than because
lock-release dynamics were analyzed. `IsoConserve.WaitGraph` supplies the separate
contentful wait-graph proof.
