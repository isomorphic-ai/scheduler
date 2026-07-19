# Findings

1. L1 and L4 factor cleanly through finite indexed accounting.

   The formalization confirms the task note's main proof strategy: conservation
   does not need the values of `effective_rate`. Once a step is represented by
   per-process shares and conversions, each process account changes by exactly its
   injected share, and the reservoir changes by the negative sum of those shares.

2. L2 needs the blocked/drain regime stated explicitly.

   The paper text says "no progress implies convertible stock non-increasing." As
   a global statement over arbitrary injection steps, that is too strong: a step
   can inject stock without crossing the conversion threshold, leaving total
   converted unchanged while increasing stock. The theorem is true for the
   detector's blocked/no-progress drain step, where stock returns to the reservoir,
   and for per-blocked-process stock across mixed flow/drain behavior. The Lean file
   therefore proves `L2_monotone` for `DrainPlan` and
   `blocked_stock_monotone` for a process that starts blocked.

3. Deadlock absorption is strongest when the at-table is empty.

   With `atTableEmpty`, every active share and conversion is zero, so the abstract
   `step` is literally a fixed point. The one-step L3 theorem and the reachable
   closure theorem both use this fact. The `not allDone` part is preserved because
   this first model freezes `done`; restoring lock release and wake-up dynamics is a
   v2 task.

4. The reusable adversary monotonicity lemma is independent of rationals.

   `monotone_under_adversary` does not mention `Qty` or scheduler state. It takes
   an arbitrary state type, an explicit order relation with reflexivity and
   transitivity, an adversary relation, and a measure. This should be importable by
   the caching/polarity proof track.

5. The caching/polarity paper matches the abstraction.

   Reading `loss-is-invalidation.tex` confirmed that Claim 1 has the same closure
   shape: each storage-loss step moves the trusted set downhill, and any sequence
   of such steps remains downhill. `L2_monotone_under_drain_reachable` is the
   scheduler-side instance of that shared theorem, and `polarity_claim_one` is the
   caching-side monotone instance. The negative half is also represented by
   `trust_on_absence_loss_counterexample`: a trust-on-absence predicate grows under
   one storage-loss step.

6. The proof is plan-abstracted, not a full lock-system formalization.

   There are no locks, `wants`, or `holds`; `runnable` and `done` are frozen; and
   conversion is plan-supplied rather than forced-maximal. Plain `FlowPlan` still
   abstracts the quantum rule, while the canonical instance restores
   `min(reservoir, |table|)` for the positive-total-weight Python branch. Credit
   banking is now modeled by `YieldPlan`, but the full victimless-resolution policy
   is not. These deviations are acceptable for the L1/L4 accounting kernel because
   the theorems quantify over a superset of accounting-balanced Python behaviors,
   but L2/L3 should be revisited with real wait-graph dynamics in a v2
   formalization.

7. Yield makes the credit field live.

   `YieldPlan` moves stock into credit and leaves `netFlowIntegral` unchanged.
   `yield_conservation`, `wf_yieldStep`, and `l4_yield` prove the banking
   operation preserves accounted Q, well-formedness, and stock-plus-credit equals
   the external-flow integral. `MixedRel` includes yield, so reachable WF/L4
   invariants quantify over it.

8. The canonical Python-style step is now a theorem, modulo supplied weights.

   `pythonRatePlan` constructs a `RatePlan` using `pythonQuantum`, supplied
   effective weights, and `forcedConvert`, a finite model of Python's conversion
   loop bounded by remaining work. `CanonicalPythonStepRel` packages both the
   well-formed positive-weight canonical transition and Python's all-zero-weight
   fallback. The fallback is not a weighted partition because the shares sum to
   zero rather than the quantum, so Lean represents it as `pythonZeroWeightPlan`, a
   zero-share `FlowPlan` that still runs the forced conversion loop on already-held
   stock. `canonicalPythonStepRel_is_mixedRel` proves both branches are steps of
   the verified mixed system.

9. The global L2 counterexample is mechanized.

   `subthreshold_python_noProgress` and
   `subthreshold_python_convertibleStock_increases` prove the threshold case
   against the canonical plan: with cost `1`, reservoir/share `1/2`, and one unit
   of remaining work, no conversion occurs but convertible stock increases.

10. Resolution's conservation core is proved.

   `credit_monotone_under_yield_reachable` proves total banked credit is
   non-decreasing over yield-only reachability. Together with `yield_conservation`,
   this is the conservation core of the no-victim resolution reading, distinct
   from the full deadlock-resolution policy.

11. Wait-graph L3 is now contentful for supplied closed components.

   `IsoConserve.WaitGraph` adds a separate lock/wait state with computed runnable,
   conversion to `done`, and release-only lock updates by done processes. It does
   not model dynamic `wants`, lock acquisition, or budget drain/refill. The proof
   of `closedWaitSet_step` shows the relevant causality for supplied closed
   components: no member is runnable, so no member converts or becomes done, so the
   internal locks that block the component are not released.

12. Detection soundness is proved after the closed component is supplied.

   The v2 theorem intentionally does not prove that every arbitrary wait graph
   contains or finds such a component. `detection_sound` packages a supplied
   nonempty floored closed component as a `genuineDeadlock`; the floor hypothesis is
   carried as data, while the load-bearing dynamics are `closedWaitSet_step` and
   `L3_waitComponent_absorbing_iter`. The evidential link from budget floor to
   "blocked throughout" lives in the accounting kernel's drain model today; joining
   that evidence to computed runnable is the v3 bridge task.

13. Closed wait sets require `unfinished`, not merely `not done`.

   The 04b task sketch said a closed wait set needs members to be not done. The
   proof found a stronger necessary condition: a member with `done = false` but
   `converted >= workNeeded` would become done on the next step without converting,
   release its locks, and break closure. The delivered predicate therefore uses
   `unfinished := done = false ∧ converted < workNeeded`. This is a machine-found
   correction to the v2 spec, not just proof convenience.

14. Wait-graph absorption is now stated for all finite iterations.

   `closedWaitSet_iter`, `totalConvertedIn_iter`, and
   `L3_waitComponent_absorbing_iter` lift the one-step closed-component theorem to
   any finite number of `WaitGraph.step`s, so the L3 "absorbing" wording no longer
   relies on the reader to infer the induction.

15. The budget floor becomes load-bearing only with an exact drain window.

   `IsoConserve.BudgetWait` joins computed wait-graph blocking with detector budget
   drain/refill. The one-step theorem `budget_drop_implies_blocked` proves that a
   strict budget decrease can only occur in the blocked branch. The finite-window
   theorem `floor_after_exact_budget_window_implies_blockedThroughout` proves the
   important direction: if a process starts a witness interval with budget `k` and
   reaches zero after exactly `k` steps, then it was blocked at every step in that
   window. Final floor alone is intentionally not claimed.

16. End-to-end detector evidence is now packaged, with explicit v3 boundaries.

   `detection_sound_with_budget_evidence` combines a supplied closed wait component,
   final floor, the exact-window budget theorem, and no-conversion absorption into
   an `evidencedDeadlock` certificate. The component theorem now assumes only a
   common starting budget/window `k`; the earlier positivity and common-`budgetCap`
   assumptions were removed after the prover exposed the stronger budget-value
   induction. `BudgetWait` still omits lock acquisition and automatic cycle
   discovery. These are documented boundaries, not hidden proof assumptions.

17. `BudgetWait` derives path well-formedness internally.

   Review #5 pointed out that the main bridge theorem should not ask callers for a
   path invariant that follows from `bw_wf_step`. The theorem `bw_wf_stepN` now
   derives `BWWF (stepN k s)` from `BWWF s`, and the public exact-window and
   detector-certificate theorems take initial `BWWF` only.

18. Observed floors now produce explicit witness-window evidence, not floor-alone
    conclusions.

   `budgetWindowEvidence` packages the existential detector read: a start time,
   window length, observed end time, matching starting budget, final floor, and
   blocked history. `observed_floor_after_window_start_implies_evidence` proves
   this from a supplied candidate window start and an observed floor. The theorem
   deliberately does not infer the most recent refill point from floor data alone;
   that would require trace/log state outside `BudgetWait`.

19. The Noether experiment has a formal first slice, but not uniqueness.

   `IsoConserve.Noether.clockFreeInvariant_iff_conservedBy` proves the discrete
   stutter/relabeling equivalence: a charge is invariant over every finite
   stuttering path exactly when every real step conserves it. The scheduler
   instance `mixedRel_accounted_clockFree` shows that `accounted` is such a charge
   for mixed flow/drain/yield behavior, and
   `mixedRel_accounted_eq_totalQ_under_clockFree` ties it to the initial `totalQ`
   under WF. This is the clock-free conservation kernel; it does not yet prove
   that Q is the unique or forced charge.

20. Bare clock-free invariance cannot force a unique charge.

   `clockFreeInvariant_comp` proves that any postcomposition of a clock-free charge
   is clock-free, and `constant_clockFreeInvariant` proves that constant charges
   are clock-free for any relation. The scheduler instances
   `mixedRel_accounted_postcompose_clockFree` and `mixedRel_constant_clockFree`
   make the obstruction concrete for `MixedRel`. Therefore the strong "Q is the
   unique forced charge" reading is false without additional normalization or
   observability assumptions.

21. Closed wait components now have bounded detector completeness.

   `closed_member_budget_after` proves that a member of a closed wait component
   drains exactly one Nat budget unit per bridge step:
   `budget_after_k = budget_start - k`. `closed_floored_within` lifts this to the
   component: if the observation bound is at least every member's starting budget,
   the component is floored. `closed_wait_set_detected_within_budget` packages the
   completeness certificate directly as an `evidencedDeadlock`, using closed-set
   absorption for blocked history and no-conversion. This is logical-attempt
   latency, not elapsed time.

22. The paper's epistemic/alignment/agency invariants are now named L1 corollaries.

   `IsoConserve.PaperInvariants` adds the citation-facing wrappers:
   `epistemic_invariant` states that every mixed-reachable state from an initial WF
   state has ledger `accounted = initial totalQ`; `alignment_invariant` states that
   any local account decrease is exactly balanced by the outside account increase;
   and `agency_invariant` states that a local account increase implies the outside
   account strictly decreased. These are conservation corollaries, not yet the full
   dependency-utility theorem about hoarding.

23. The flexibility/middle-way reading now has its conservation identity.

   `IsoConserve.Flexibility` models a collapse from `potential` to `actual` and
   proves whole conservation, potential monotonicity, actual monotonicity, and the
   balanced delta identity. This mechanizes the conserved core of reading 4.7 while
   leaving phantom races and carried distributions as empirical engine evidence.

24. The unified core/trace surface now exists beside the older models.

   `IsoConserve.CoreTrace` defines one `CoreState` carrying both the Q ledger and
   the wait graph: stock, credit, base rate, detector budget, restart-local
   converted work, wants, holds, reserve, and total Q. The public relations are
   `ExecRel`, `CureRel`, and `CoreRel` over `WFState`. L1 is proved as
   `core_step_conserves_accounted` and `core_reachable_conserves_accounted`; L4 is
   trace-derived by `stock_credit_eq_initial_add_integral` and
   `L4_stock_is_trace_integral`, with `flowIntegral` computed from `StepEvent`
   history rather than read from a state cache.

25. Review #7's L2/L3 repairs are encoded in the unified core.

   The old unrestricted L2 reading is restated as
   `CoreTrace.unrestricted_l2_is_false` on the new state. The positive monotonicity
   theorem is deliberately restricted: `no_progress_convertible_stock_monotone`
   covers detector no-progress drain/yield traces, and
   `blocked_stock_monotone` ranges over `BlockedPreservingRel` so lock release
   cannot silently turn a blocked process into a runnable one mid-proof. L3 is
   global (`Deadlocked = atTableEmpty ∧ ¬ allDone`) and ordinary-execution-only:
   `deadlock_exec_fixed` proves absorption for `ExecRel`, while
   `cure_can_break_absorption` gives a checked release-claim witness showing the
   cure can intentionally leave the absorbing state.

26. CoreTrace is a shared surface, not the finished downstream modules.

   The old-to-new compatibility items are documented as comments, not theorem
   declarations: old L1 conservation, old blocked-stock monotonicity, old
   BudgetWait detection, and old yield conservation still describe what a full
   old-to-new simulation would owe. WP3, WP4, and WP5 now import `CoreTrace` for
   their first theorem surfaces, but the compatibility notes still do not prove a
   full old-to-new simulation. Remaining downstream work should keep using the
   shared record rather than reviving draft-local state sketches.

27. Detector/progress is now lifted onto the unified core state.

   `IsoConserve.DetectorProgress` imports `CoreTrace` and uses the shared
   `CoreState` budget, wait, stock, and conversion fields. The one-attempt lemmas
   `conversion_refills_budget`, `blocked_nonconversion_drains_budget`,
   `budget_drop_implies_blocked`, and `budget_after_ge_pred` are the core-state
   versions of the BudgetWait bridge. `detector_sound` proves no false positive
   for a supplied nonempty closed floored component; `closed_deadlock_eventually_floors`
   and `deadlock_eventually_detected` prove bounded completeness by selected
   attempts; `periodic_conversion_never_floors` and `live_process_not_detected`
   prove the slow-live safety side under the repaired full-budget initial
   hypothesis. `SIG_PROGRESS` is modeled as an honest in-loop signal plus a
   separate reputation check: a liar can survive the detector by reporting progress,
   but fails `reputationConsistent` when reported progress exceeds delivered
   progress.

28. The first repaired latency-prefix statement was still too strong.

   Review #7 required making `detection_latency_le_budget` concrete. The initial
   repair tried to demand a detecting prefix where every component member had been
   selected at most `k` times. That is false for unfairly ordered but ultimately
   sufficient schedules: one member may be oversampled before the last member
   reaches its budget bound. The committed theorem now states the sound bound as
   prefix existence under the per-member lower-bound hypothesis; the selected-count
   budget bound is carried by the schedule evidence, not by an unnecessary
   per-member upper bound on the detecting prefix.

29. Resolution yield now proves no-victim accounting and explicit component breakage.

   `IsoConserve.ResolutionYield` banks restart-local converted work into credit,
   resets the restart-local counter, releases held locks, and proves
   `resolution_yield_conserves` plus `resolution_yield_loses_no_accounted_work`.
   Component breakage is witness-based: `yield_releases_wait_edge` removes the
   concrete waiter/yielder/lock edge, and `yield_breaks_closed_component` requires
   the reviewed `honly` premise saying that edge was the waiter's only internal
   blocker. The general rational positive-gain termination theorem is intentionally
   not stated; the landed theorem
   `positive_credit_gain_finite_requirement_eventually_completes` is the Nat-unit
   toy variant, avoiding the Zeno-false formulation from Review #7.

30. The deployed phase-2 detector matches the checked BudgetWait semantics.

   Review #7's cross-track note reports that the Grok deadlock sidecar implements
   the same three-way budget transition as `BudgetWait.budgetAfter`: drain only
   when a transaction is in the wait set, refill on forward-progress counters, and
   otherwise leave the budget unchanged. The empirical arm and formal arm therefore
   agree at the transition-semantics level. This belongs in the 04j/PaperClaims
   coverage table as implementation alignment for reading 4.1, not as a new Lean
   theorem.

31. Rate routing's conserved core is destination-sum first; recursion is certificate-scoped.

   `IsoConserve.RateRouting` proves the Review #7-repaired KCL theorem
   `routed_rate_conserved`: every unfinished process's nonnegative `baseRate` is
   counted exactly once, either at a runnable routed destination or in
   `strandedRate` when the wait-chain does not reach one. The module also proves
   exact Pathfinder shares (`10/13` for low, `3/13` for medium), memoryless return
   (`remove_wait_edge_restores_base_rate`, `no_stored_boost_state`), share
   normalization (`shares_sum_quantum`), one-edge transitive routing
   (`transitive_rate_routing`), and the sum-not-max corollary
   (`multiple_waiters_sum_not_max`). The paper's recursive equation is now proved
   as `effective_rate_eq_base_plus_waiters` under an explicit
   `WaiterPartitionAt`/`acyclicFrom` certificate: the evaluated upstream region is
   a disjoint finite waiter tree, and the process itself is live. That certificate
   is the formal repair for the acyclic/fuel/live-intermediate premises; cyclic or
   over-fuel parts belong to `strandedRate`. The canonical bridge now exists as
   `canonical_step_uses_derived_routed_rates` and
   `pythonRoutedRateStep_verified_mixed`: a unified `CoreState` is viewed through
   `coreAsSys`, `routedWeights` is exactly `RateRouting.routedRate`, and the old
   Python-style plan is verified under the positive routed-weight denominator
   required by the share split.

32. PN-counter distribution conserves per-node ledgers by max, not replica values by sum.

   `IsoConserve.PNCounter` mechanizes the 04e CRDT kernel. `merge` is a least
   upper bound under componentwise ledger order and satisfies `merge_idem`,
   `merge_comm`, and `merge_assoc`; `eval_eq_globalRecorded` proves merge-tree
   convergence to the same pointwise recorded ledger. The no-loss theorems
   `replica_le_globalRecorded`, `partition_left_le_heal`,
   `partition_right_le_heal`, `off_partition_decrement_surfaces`, and
   `off_partition_increment_surfaces` make the paper's "hidden by partition, not
   destroyed" claim precise. The sharpening is explicit: conservation is of
   honest per-node grow-only evidence by `max`; summing replica-local `value`s
   would double-count shared observations and is intentionally not a theorem.

33. Theorem 1 landed at the finite-action-set level.

   `IsoConserve.TheoremOne.route_stranded_claim_strictly_dominates_hoard` proves
   the local strict theorem with the reviewed definitions: payoff is
   `ownConversion`, a stranded claim is held stock the holder cannot convert, and
   `DependencyReturn` is directed (`blockedOn`), not undirected connectivity. The
   committed policy theorem is the fallback promised in `04i-theorem1-task.md`:
   `selfish_optima_eq_generous_optima` proves route is both selfishly and
   generously optimal inside `{hoard, route, release}` for the supplied claim.
   The full unrestricted policy theorem remains review-gated rather than hidden
   behind a broad quantifier. `DebtLedger` is a standalone mini-model with debt
   conservation and return lemmas; it is not yet wired as a `CoreState` field.

34. PaperClaims now closes over the current proved module surface.

   `IsoConserve.PaperClaims` has been reconciled with the post-Review #7 modules
   instead of treated as a fresh file: its aliases now cover unified core trace,
   repaired L2, detector/progress, resolution yield, rate routing, PN-counter
   distribution, flexibility collapse, polarity, invariants, and the finite-action
   Theorem 1 surface. The headline `L2_monotonicity` is deliberately restricted to
   blockedness-preserving core traces, while `unrestricted_l2_is_false` remains a
   theorem-level warning against the old global reading. The audit helper now
   checks the headline `#print axioms` output against the exact allowed baseline
   `[propext, Classical.choice, Quot.sound]` and regenerates the coverage matrix
   from a single command.

35. Detector slow-live safety now uses a real selected-attempt window.

   `DetectorProgress.selectionWindowSafe` is the invariant-form repair selected
   for 04k WP-B2. A conversion resets the remaining allowance to `window`; only
   selections of that process consume the allowance; and a non-converting
   selection is rejected when it would consume the last slot. Thus
   `convertsWithinEverySelectionWindow` has a load-bearing `window` argument.
   `once_per_selection_window_never_floors` checks the positive direction on a
   two-selection window with exactly one conversion and also proves that the old
   every-selection predicate is false. `missed_selection_window_floors` checks
   the negative direction on the closed cycle: one missed size-one window drains
   the member's budget to zero. The old stronger result remains only under the
   explicit `*_every_selection` theorem names.

   The witness also exposes the current schedule model's boundary:
   `blockedOn_observeAttempt_iff` makes the wait graph invariant under
   `observeAttempt`. A process that misses because it is blocked cannot later
   unblock and convert in the same schedule semantics. The positive gate is
   therefore a finite genuine window whose later non-converting runnable attempt
   does not drain; repeated block/unblock/reconvert examples belong to the
   CoreRel-to-trace bridge rather than being implied here.

36. Core reachability and trace-derived L4 now form an exact commuting square.

   `CoreTrace.EventRel` has one constructor for each of the three `ExecRel` and
   four `CureRel` arms. Work, drain, yield, and route events are projected from
   their dependent plans; acquire and normal release retain their runnable/free
   evidence; claim release mirrors the current unguarded relation exactly.
   `core_step_iff_has_event` and `core_reachable_iff_has_typed_trace` prove that
   certified events and `TypedRun`s neither widen nor narrow `CoreRel`.

   The old `applyEvent`/`runState` path updated only stock and credit from arbitrary
   deltas, so it could not witness an actual work step's counters/budget/done
   updates or an acquire/release step's graph updates. It has been removed.
   `Run` now aliases `TypedRun`; `eventRel_stockCredit` proves the one-step
   projection from each full transition; and `L4_for_core_reachable` constructs a
   certified trace whose `flowIntegral` equals every process's final-minus-initial
   stock plus credit. `L4_zero_initial_for_core_reachable` is the PDF's
   `S_i + C_i = I_i` form for zero-initial ledgers.

   04k asked B1 to delete the final compatibility-obligations comment, but that
   comment names old-L1, old-blocked-stock, old-BudgetWait, and old-yield
   simulations into the unified model. Those are distinct cross-model theorems,
   not consequences of the CoreRel↔TypedRun bridge. The comment remains, with its
   separate scope made explicit; deleting it would falsely report four additional
   obligations as discharged.

37. Admissible core transitions now construct well-formed endpoints.

   Merely quantifying `CoreRel` over `WFState` had hidden a construction gap: a
   caller could supply the target proof, but the raw step and its plan did not
   derive it. The genuine obstruction was `workStep`, which leaves `holds`
   unchanged while `doneAfterWork` can mark a process done. The strengthened
   `WorkPlan.completion_holds_nothing` requires precisely the missing fact on the
   false-to-true completion branch; it does not weaken `CoreWF` or silently release
   locks. This intentionally narrows `WorkRel`, and external plan constructors now
   owe the new proof. There were no in-tree `CoreTrace.WorkPlan` record literals to
   migrate, and the B1 event equivalence remains exact because work events carry
   the strengthened plan.

   `wf_workStep`, `wf_drainStep`, `wf_yieldStep`, `wf_routeStep`,
   `wf_acquireStep`, and `wf_releaseStep` cover every field of `CoreWF`; the last
   theorem applies to both normal and claim release. Acquire preservation needs
   the existing `runnable` premise because acquiring sets a hold and runnable
   entails `done = false`; its lock-free guard remains operational evidence rather
   than a `CoreWF` premise. Seven `*StepOfWF` constructors and their relation
   witnesses now produce the certified endpoints for all seven `CoreRel` arms.
   `ResolutionYield.resolution_yield_preserves_coreWF` separately covers the
   restart operation, including nonnegative banked credit, equal expanded budget
   and cap, reset restart progress, cleared locks, and conserved accounting;
   `resolutionYieldWFState` packages that endpoint.
