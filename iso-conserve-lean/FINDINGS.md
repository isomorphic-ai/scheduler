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
