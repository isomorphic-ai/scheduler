# Next tasks for the Lean track (ranked, 2026-07-12 night)

*From Fable's review notes + the series' §7 list. Rule carried over from
the review: do not perturb `monotone_under_adversary`'s statement — two
series now import it. Quick wins first; the crown jewel needs its task
file written before any code.*

## Tier 1 — quick wins (each ≤ ~60 lines, same run)

**Status:** completed in the Tier 1 pass. `Polarity.lean` now has the
trust-on-absence counterexample; `YieldPlan` is wired into conservation, L4, WF,
and `MixedRel`; `RatePlan.weight_blocked`, `L2_drain_monotone`, and the
Polarity docstring are in place.

1. **Close Claim 1's iff (`Polarity.lean`).** The ⇐ half is proved
   (`polarity_claim_one`). The ⇒ half is a counterexample-existence
   lemma: define a trust-on-absence predicate
   (`negTrusted key := ¬ ∃ proof, store ⟨key, proof⟩ = true`), exhibit a
   one-step loss under which the trusted set strictly grows. Then the
   Lean statement matches paper02's claim shape exactly, and that paper
   can say "Claim 1 fully mechanized," not "the monotone half."
2. **`YieldPlan` + `l4_yield` — make `credit` live.** The banking
   operation (stock −= c, credit += c, `netFlowIntegral` UNCHANGED) is
   the one Q-move with no Lean form yet, and it is the RESOLUTION reading
   (§4.2: the integral banked across a yield). Deliver:
   `yield_conservation` (accounted invariant), `l4_yield` (the task
   file's explicit gotcha, made theorem), `wf_yieldStep`, and wire
   `YieldRel` into `MixedRel` so `wf_reachable`/`l4_reachable`/
   `blocked_stock_monotone` quantify over it too (check the last one:
   yield reduces stock, so monotonicity survives — but say so in the
   proof, not the README).
3. **Cosmetics from the re-review:** `weight_blocked` on `RatePlan`
   (zero weight for non-runnable — makes the refinement exactly the
   effective-rate split); export alias `L2_drain_monotone`; the
   division-of-labor docstring on `Polarity.lean` (Lean = lattice half
   for all sizes; TLC MapChaos = implemented-predicate half at model
   size).

## Tier 2 — one focused run

**Status:** completed for the plan-abstracted kernel. `pythonRatePlan` builds a
canonical `RatePlan` from supplied positive-total effective weights and finite
forced conversion; `canonicalPythonStepRel_is_mixedRel` proves the canonical
positive-weight Python-style transition is an instance of the verified mixed
system; the sub-threshold L2 counterexample is mechanized; and
`credit_monotone_under_yield_reachable` proves the resolution conservation core.
The remaining effective-rate computation from locks/waits belongs to Tier 3/v2.

4. **The canonical-instance theorem.** Define `Init` and the
   deterministic Python plan: a `RatePlan` whose weights are the
   effective rates and whose `convert` is forced-maximal
   (`while stock ≥ cost`). Prove it satisfies every `FlowPlan`
   obligation. Payoff: "iso_conserve.py's step is one instance of the
   verified system" becomes a theorem, and FINDINGS item 2 (the
   sub-threshold injection that falsifies global L2) can be stated as a
   *proved* remark about the canonical instance instead of a checked
   example. This is the artifact that turns the README's faithfulness
   argument into mathematics.
5. **Resolution conservation (§4.2's missing half).** With `YieldPlan`
   from Tier 1: prove the no-victim property's conservation core —
   across any mixed behavior including yields, banked credit is never
   destroyed (`credit` monotone non-decreasing under the yield-only
   relation; accounted invariant throughout). This upgrades paper 02
   (resolution)'s `(shown)` toward `(proven)` on its conservation claim.

## Tier 3 — the crown jewel (write `04b-lean-task.md` FIRST)

**Status:** completed for the supplied-closed-component theorem. `04b-lean-task.md`
is written; `IsoConserve.WaitGraph` models dynamic wants/holds, computed runnable,
conversion to done, done lock release, preservation of closed wait components,
contentful L3 absorption, and detection soundness. Automatic cycle discovery is
explicitly left as a graph-search layer above the theorem.

6. **Wait-graph dynamics (model v2).** `wants`/`holds`/locks, `runnable`
   *computed* from the lock table, conversion sets `done`, done releases
   locks and wakes waiters. Then prove the two theorems the plan-abstract
   kernel cannot state:
   - **L3 with content:** a wait-cycle's component, once floored, stays
     floored *because* every wake path routes through the cycle — not
     because the model froze.
   - **Detection soundness (paper 4.1's core claim as theorem):**
     budget-floor + closed wait-cycle ⇒ genuine deadlock (no false
     positive), via L2/L3. This is the series' flagship result made
     machine-checked.
   Do not start this as a patch: write the task file with the same rigor
   as `04-lean-task.md` (state/step/WF/theorems/acceptance), get it
   reviewed, then build. The plan-abstracted kernel stays as-is
   underneath — L1/L4 do not need the dynamics.

## Tier 4 — research (may fail; flag as experiment, not deliverable)

7. **The discrete Noether conjecture**
   (`commenters/2026-07-12-fable-conservation-is-a-noether-charge.md`):
   define time-relabeling/stuttering invariance for this transition
   system; prove invariance implies a conserved charge; show Q is it.
   Baez & Fong's Noether theorem for Markov processes (J. Math. Phys.
   54, 2013) is the nearest prior art and this deterministic setting
   should be easier. If it lands, paper08's standalone gains "the laws
   are not chosen; they are forced by the decision not to own a clock"
   as a theorem — and probably a paper09. If it resists after a
   timeboxed attempt, write the FINDINGS on *why* — that is a result
   too.
8. **L2 as entropy (§7's second-law question)** — only after 7, and only
   if 7 suggests the right entropy functional.

## Standing rules

- Every new operation goes into `MixedRel` and the reachable-composition
  theorems, or the README says why not.
- Every abstraction gap found gets a FINDINGS entry at discovery time,
  not at review time.
- `sorry` is a stop sign, not a placeholder to ship.

---

# Next tasks, round 2 (ranked, 2026-07-14 — from Fable's Review #3)

*Context: `04b-lean-task.md` was located and shipped into the tree (it lives
at the repo root beside `04-lean-task.md`); Review #3's M1 is therefore
half-resolved — the remaining half is provenance, Tier 1 item 5 below. All
04b acceptance criteria verified: build + no sorry, module imported by
`IsoConserve.lean`, README maps W1–W4, FINDINGS 11/12 drawn. Standing rules
at the bottom still apply; one is added.*

## Tier 1 — doc/scope fixes (no new math, same run)

**Status:** completed in the Round 2 pass. README now has a WaitGraph deviations
section, corrected detection-soundness wording, canonical quantum-rule annotation,
`native_decide` trust-base note, and branch/commit provenance. FINDINGS now records
the `unfinished` strengthening as a machine-found spec correction.

1. **WaitGraph deviations list (Review #3 M2).** README section for the v2
   module, mirroring the kernel's list: `wants` is frozen (never written by
   any step); `holds` is release-only — locks are never acquired, so
   deadlocks can persist but never *form* in-model; `canConvert` does not
   consult `wants`, so a woken process converts without holding the lock it
   wants; `budget` is never drained or refilled in this module; `q != p` in
   `blockedOn` makes single-process self-deadlock unrepresentable. Fix
   FINDINGS 11's "restores dynamic `wants`/`holds`" wording to match.
2. **Reword the detection claims (Review #3 M3).** `detection_sound`'s
   `floor` hypothesis passes through unused; the load is carried by
   `closedWaitSet_step` + `L3_waitComponent_absorbing`. README should say:
   the closed component is absorbing and non-converting; the floor is
   carried as a definition, and its soundness *as evidence* is the kernel's
   `blocked_stock_monotone` — in a model not yet joined to this one. Do not
   imply the join exists; it is Tier 3.
3. **FINDINGS entry: the `unfinished` strengthening is a machine-found spec
   correction.** 04b §2 defines `closedWaitSet` with "not done" only; under
   04b §3's step semantics that W2 is *false* — a member with
   `converted ≥ workNeeded` and `done = false` becomes done at the next
   step without converting (`doneAfter` fires on the stale count) and
   releases its locks, breaking closure. The delivered
   `unfinished := ¬done ∧ converted < workNeeded` repairs the spec. Record
   it with the same pride as FINDINGS 2 — spec divergences forced by the
   prover are results.
4. **Stale kernel-deviations line + trust-base note.** The README still says
   the quantum rule is "abstracted to `reservoir_after_nonneg`";
   `pythonQuantum` now restores `min(reservoir, |table|)` for the canonical
   instance — annotate. Add one sentence that the sub-threshold pair uses
   `native_decide` (compiler + Rat kernel ops in the trust base; everything
   else is kernel-checked).
5. **Record the upstream provenance in the README.** The tree is committed
   as a branch upstream (it is only untracked in the drafting clone —
   Review #3 inferred a gap from local `git status`; corrected). Remaining
   work: name the upstream branch and pin the commit hash in the README so
   paper01/paper04/paper08 and the commenter files can cite an immutable
   identifier, and make sure REVIEW-by-fable.md, this file, and
   `04b-lean-task.md` are on that branch too.

## Tier 2 — cheap theorems (each ≤ ~25 lines)

**Status:** item 6 completed in the Round 2 pass:
`closedWaitSet_iter`, `totalConvertedIn_iter`, and
`L3_waitComponent_absorbing_iter` prove finite-iteration absorption. Item 7 is
also completed: `CanonicalPythonStepRel` now has a zero-share fallback branch via
`pythonZeroWeightPlan`.

6. **`closedWaitSet_iter` + `totalConvertedIn_iter` (Review #3 S1).**
   `step` is a total function; induct on k with `closedWaitSet_step` to get
   `closedWaitSet s C → closedWaitSet (step^[k] s) C` and constant
   `totalConvertedIn` for all k. "Absorbing" means forever; put the
   induction in Lean, not in the reader. Export as the L3 name the papers
   cite.
7. **Zero-weight fallback into `CanonicalPythonStepRel` (Review #3 S2).**
   Verified against `iso_conserve.py:138-143`: the reservoir decrements
   per-share, so the `or 1.0` fallback injects zero and leaks nothing — and
   an all-zero-share step already satisfies every `FlowPlan` obligation
   (sum 0 for `reservoir_after_nonneg`; convert = forced loop on existing
   stock). Add it as a second disjunct with a zero-share plan; then the
   bridge theorem covers Python's *entire* flow branch and the README may
   say so (empty table stays the L3 no-op, covered elsewhere).

## Tier 3 — the v3 seam (write `04c-lean-task.md` FIRST)

**Status:** implemented in `IsoConserve.BudgetWait`. `04c-lean-task.md` is in the
tree; `BudgetWait` defines computed runnable plus detector budget drain/refill,
proves `budget_drop_implies_blocked`, derives path WF with `bw_wf_stepN`,
promotes the exact-budget-window bridge theorem
`floor_after_exact_budget_window_implies_blockedThroughout`, keeps the full-cap
theorem as a corollary, proves closed-component iteration/no-conversion, and
packages the result as `detection_sound_with_budget_evidence`. Boundaries left
explicit: supplied closed component, shared starting budget/window `k`, drain
does not separately check `done`, no lock acquisition, no automatic cycle
discovery.

8. **Completed: the budget↔wait-graph bridge.** The v3 model has both drain
   dynamics and computed `runnable`: blocked processes drain budget, converting
   processes refill it, and `runnable` is computed from locks/wants as in
   WaitGraph. The direction that makes `detection_sound`'s floor conjunct
   load-bearing is now proved as
   `floor_after_exact_budget_window_implies_blockedThroughout`. With
   closed-component absorption, "budget floor + closed component" is soundness
   with the floor doing work, for supplied components and certificate windows.

## Tier 3.5 — detector window cleanup

**Status:** completed for the proof-certificate/window-start formulation.
`BudgetWait` now defines `budgetWindowEvidence`,
`observed_floor_after_budget_window_implies_evidence`, and
`observed_floor_after_window_start_implies_evidence`. The theorem takes an
observed floor time plus a supplied candidate window start whose starting budget
matches the elapsed window, then returns the existential witness-window package
with blocked history. Automatic discovery of the most recent refill point from
floor data alone would require trace/log state outside the current bridge model.

9. **Completed: existential-window detector read.** The public exact-window
   theorem proved the hard induction; the detector-facing wrapper now presents it
   as a witness-window certificate at an observed floor time, without making a
   floor-alone claim.

## Tier 4 — research

10. **Discrete Noether conjecture: first formal slice complete.**
   `IsoConserve.Noether` defines stutter/relabeling invariance and proves
   `clockFreeInvariant_iff_conservedBy`, then instantiates it for
   `accounted` over `MixedRel`. The stronger uniqueness/forced-charge statement
   resists in the current formulation for a formal reason:
   `clockFreeInvariant_comp` and `constant_clockFreeInvariant` show that
   postcomposed and constant charges also satisfy bare clock-free invariance.
   A future uniqueness theorem needs a new task file with normalization or
   observability assumptions.
11. **L2 as entropy — next only with a task file.** The Noether obstruction
   clarifies the precondition: first choose the state observable/order and entropy
   functional, then prove or refute downhill behavior. Do not start this as a patch
   on `Noether.lean`.

## Standing rules (carried, one added)

- Every new operation goes into `MixedRel` and the reachable-composition
  theorems, or the README says why not. (WaitGraph is a separate *model*,
  not an operation — the README should keep saying that plainly.)
- Every abstraction gap gets a FINDINGS entry at discovery time, not at
  review time.
- `sorry` is a stop sign, not a placeholder to ship.
- **New:** task files ship with the tree in the same rsync as the code they
  gate. A cited-but-absent task file reads as asserted process compliance —
  worse than a skipped step (the 04b lesson; resolved this round).
- **New:** review files are append-only; syncs merge rather than overwrite.
  Review #4's temporary disappearance was survivable, but prevention is cheap.

---

# Next tasks, round 4 (ranked, 2026-07-18 — "Lean proves all 7" for the combined paper)

*From Fable's Review #6 coverage map. Goal: every reading of the combined
Iso-Scheduler paper either cites a Lean theorem or names its empirical
remainder explicitly. Current score: 4.4 done, 4.1 mostly, 4.6 half,
4.2 conservation-core-only, 4.3/4.5/4.7 absent. One prerequisite before
any Tier B/C task file is written: ship the combined paper (or at
minimum its exact claim sentences per reading) into the repo — task
files must target the paper's wording, and the paper must cite pinned
theorem names back (the 04b lesson, applied at paper scale).*

## Tier A — cheap completions on existing models (one run, no new task file)

**Status:** item 1 completed. `BudgetWait` now proves
`closed_member_budget_after`, `closed_floored_within`,
`closed_wait_set_detected_within_budget`, and
`closed_wait_set_detected_at_common_budget`. The completeness theorem is stronger
than the prompt's common-budget version: any observation bound that dominates each
member's starting budget floors the closed component.

1. **Completed: 4.6 completeness, bounded detection latency.** Closed wait-set
   members are blocked and non-converting at every bridge step, so each member's
   budget evolves as truncated subtraction. Therefore a persistent closed
   component is detected within its budget bound, with no wall-clock timeout.
2. **Completed: 4.4 corollaries, the three invariants as named theorems.**
   `IsoConserve.PaperInvariants` now exports `epistemic_invariant`,
   `alignment_invariant`, and `agency_invariant`. These are citation-facing L1
   corollaries over `MixedRel`: reachable ledger equality, local/outside transfer
   balance, and local gain paid for by outside-account decrease.
3. **Completed: 4.7 middle way, the collapse conservation identity.**
   `IsoConserve.Flexibility` defines a potential/actual collapse step and proves
   whole conservation, potential monotonicity, actual monotonicity, and the
   balanced-delta identity. The module states the boundary plainly: phantom races
   and carried distributions remain empirical (`iso_flex.py`); Lean gets the
   conservation identity only.

## Tier B — the flow module (write `04d-lean-task.md` FIRST; the largest true gap)

**Status:** first implementation landed in `IsoConserve.RateRouting` after the
Review #7 task-file repairs. The module proves destination-sum rate conservation
including stranded cycles, nonnegativity under `CoreWF.rate_nonneg`, one-waiter
inheritance, memoryless return/no stored boost, share normalization, and exact
Pathfinder `10/13` vs `3/13` rational shares. The acyclic recursive-equation
theorem now lands as `effective_rate_eq_base_plus_waiters` under the explicit
`WaiterPartitionAt`/`acyclicFrom` certificate, with `multiple_waiters_sum_not_max`
covering the sum-not-max divergence. The canonical bridge is wired:
`canonical_step_uses_derived_routed_rates` and
`pythonRoutedRateStep_verified_mixed` instantiate the old Python-style canonical
plan with derived `routedRate` weights under the positive denominator hypothesis.

4. **4.3: effective rates from the wait graph.** The one reading with
   real unformalized mathematics. Define, on a wait relation restricted
   to an acyclic domain, `eff : Pid → Qty` by well-founded recursion:
   `eff p = base p + Σ eff w` over `w` blocked on `p`. Then prove:
   - **Rate conservation (the KCL theorem):** Σ eff over runnable
     processes = Σ base over non-done processes — urgency is routed,
     never created or destroyed. This is the sum-not-maximum divergence
     from classical inheritance, as a theorem.
   - **Inheritance corollary:** if w is (transitively) blocked on p,
     then eff p ≥ base w — the holder is funded at least at each
     waiter's rate; inversion cannot form.
   - **Wire into `Canonical`:** `pythonRatePlan` currently takes eff as
     supplied weights; instantiate with the computed eff so the canonical
     instance closes end-to-end (Python's step = verified system with
     *derived* weights, positive-total hypothesis discharged for
     non-empty runnable sets).
   Design note for the task file: eff is well-defined exactly on the
   NON-deadlocked part of the wait graph — a closed component has no
   well-founded evaluation order. That is not a defect; it is the
   synthesis: the flow module (4.3) and the detection module (4.1)
   partition the graph. Put that sentence in the task file and in the
   combined paper. Well-foundedness can come in as a hypothesis
   (`Acyclic (blockedOn s)` on the evaluated component) rather than a
   proof obligation on all states.

## Tier C — the distribution module (write `04e-lean-task.md` FIRST)

**Status:** implemented in `IsoConserve.PNCounter` after Review #7's approval and
the small task-file polish commit. The module proves pointwise ledger order,
merge as least upper bound, merge ACI, inc/dec ledger monotonicity, arbitrary
merge-tree convergence to `globalRecorded`, heal no-loss for left/right
partitions, and exact off-partition debt/credit surfacing. Boundaries remain:
CAP-as-schedule, Present/Future publish protocol, gossip latency, open-system
sources/sinks, and Byzantine contribution safety are out of scope.

5. **4.5: PN-counter conservation across partition.** Self-contained
   module, no scheduler imports: per-node grow-only `pos/neg : Node →
   Nat`, `value = Σpos − Σneg`, `merge = pointwise max`. Prove: merge is
   ACI (⇒ order-independent convergence over any merge tree — strong
   eventual consistency); per-node monotonicity; and conservation:
   merging all replicas yields exactly the globally recorded operations
   ("hidden by partition, not destroyed"; "debt comes due" = value after
   heal includes every off-partition decrement). Prior art to cite:
   Gomes et al. 2017 (Isabelle); ours is the minimal Lean core, not a
   framework. The CAP-as-schedule / Present-Future bridge is design, not
   theorem — the task file should scope it OUT explicitly, or at most
   add the reversible-commit invariant (bridge commits both sides or
   neither) as a small option.

## Tier D — resolution policy (task file only after B lands)

**Status:** implemented in `IsoConserve.ResolutionYield` after Review #7's fixes
to `04h-resolution-yield-task.md`. The module proves no-victim accounting for
restart-local work banking, release-without-instant-regrant, explicit released-edge
component breakage, least-credit yielder selection, and the credit-vs-discard toy
termination contrast. The general scheduler-level termination theorem remains
scoped to the Nat-unit toy variant.

6. **4.2's missing half.** Extend BudgetWait (or a v4) with a `yield`
   action: a chosen member of a supplied closed component releases its
   holds and banks `converted → credit`; prove the component is no
   longer closed after the yield (the released lock unblocks at least
   one member — needs the waits-on-released-lock witness), and restart
   arrives with budget = cap + credit (banked integral). The livelock
   contrast (discard-work loops forever) is likely best as a small
   deterministic toy: discard variant returns to a previously visited
   state (state-space cycle ⇒ no progress ever), credit variant strictly
   increases banked credit (a variant function ⇒ termination). Scope
   carefully in the task file; this is the reading most tempting to
   overclaim.

## Tier E — the paper-facing artifact

**Status:** implemented for the current proved surface after Review #7's 04j
task-file repair. `IsoConserve.PaperClaims` now aliases the unified core,
detector/progress, resolution yield, rate routing, PN-counter, flexibility,
polarity, invariant, and dynamical finite-certified-policy Theorem 1 theorems.
The reusable audit helper exists as `tools/lean-evidence-audit`, checks the
headline axiom baseline, and regenerates `EVIDENCE-AUDIT.md`.

7. **Coverage table in README** (and mirrored in the combined paper's
   evaluation section): reading → Lean theorem names → what remains
   empirical/out-of-scope. The paper's `(shown)` → `(proven)` upgrades
   must cite exact names at a pinned commit. Include the Noether
   obstruction (FINDINGS 20) as a cited *result*: the naive uniqueness
   reading is machine-checked false; normalized uniqueness is future
   work with its own task file. The unrestricted legacy `Policy` theorem is not
   a valid universal strengthening because it admits unrelated and uncertified
   actions; engine/production-only claims remain empirical or out of scope.

## Standing rules: all carried. Task-file-first applies to Tiers B, C, D.

---

# Round 4b (2026-07-18): reconciliation — the Pro feedback supersedes round 4's structure

*`~/scheduler/paper/GPT-5.6-pro-feedback--lean.md` arrived after round 4 was
written. Its seven work packages (WP1–7, dependency-ordered 1→2→{3,4,5}→6→7)
are the plan; round 4 folds into it as follows. Fable's assessment: the Pro
list is stronger than round 4 in three places and needs four annotations from
this side of the repo.*

## Merge map

- Round 4 Tier A1 (detection latency) → **WP3** (which asks for more: lock
  acquisition generating the wait graph, `observeAttempt`, fair-scheduling
  liveness, `live_process_not_detected`).
- Round 4 Tier A2 (three invariants) → **WP6.3**, which goes much further:
  Theorem 1 itself (`hoarding_is_self_defeating`,
  `selfish_optima_eq_generous_optima`) plus the debt ledger (WP6.2).
- Round 4 Tier B (flow module / 04d) → **WP5** — and the Pro's design is
  better than round 4's on two counts, adopt theirs: (i) `routedRate` as a
  destination-sum over a wait forest, proven equal to the recursive
  equation on acyclic parts — avoids well-founded-recursion pain; (ii) the
  conservation theorem INCLUDES trapped cycles
  (`Σ routed(roots) + Σ stranded(cycles) = Σ base`) instead of round 4's
  "partition the graph" framing — the deadlocked component's rate stays on
  the ledger as stranded claims, which is the one-fault ontology speaking.
- Round 4 Tier D (resolution policy) → **WP4** (stronger: restart control
  state, and the general termination theorem
  `positive_credit_gain_finite_requirement_eventually_completes` instead of
  only the toy contrast).
- Round 4 Tier E (coverage table) → **WP7** (`PaperClaims.lean` — compiled,
  not documented; plus the §7.3 audit automation).
- Round 4 Tier A3 (flexibility identity) and Tier C (PN-counter) → **explicitly
  deferred by the Pro** ("readings 5–7 are a paper expansion, next decision").
  DECIDED (Fabian, 2026-07-18): maximal scope — the Pro pass AND the
  readings-5-7 expansion (Tier A3 flexibility identity, Tier C PN-counter,
  progress-monitor scope to be set in its task file) are all authorized.
  Sequence per the Pro's dependency order; the expansion modules are
  self-contained and can interleave wherever they don't touch the WP1/2
  core refactor.

**WP3 status:** implemented in `IsoConserve.DetectorProgress` after Review #7's
fixes to `04g-detector-progress-task.md`. The module imports the unified
`CoreTrace` state, defines schedule-driven `observeAttempt`/`runSchedule`,
proves detector budget one-step facts, no-false-positive soundness, selected-count
bounded detection, slow-live non-flooring under the repaired full-budget premise,
and the `SIG_PROGRESS` useful/spinner/liar split. Automatic component discovery
and Byzantine enforcement remain outside the theorem.

**WP6 status:** the initial installed-payoff finite-action kernel and standalone
debt-ledger mini-model are implemented in `IsoConserve.TheoremOne`; 04k's B3
upgrade now derives the paper-facing payoffs from certified core executions.
Under the explicit distinct-endpoint witness, `claimRoutePlan` makes `routeState`
an actual `RouteRel` endpoint; `conversionReturnStep` returns the converted result
to the beneficiary, and endpoint counter deltas prove exact value under the
divisibility witness `q = κ · k`. The accepted finite
`{hoard, route, release}` certified-policy fallback proves route-over-hoard
dominance and selfish/generous-optimum equality. No unrestricted theorem is
claimed for the legacy `Policy`: its unrelated, uncertified actions make the
universal statement false. Strengthened invariant-family aliases remain a
separate closure item.

**Review queue:** `REVIEW-QUEUE.md` records the review order, per-task sign-off
questions, and implementation order after review.

## Four annotations for the goblin before starting

1. **Do a delta audit first.** The Pro states plainly they worked from the
   PDF's ten-module inventory, not a current source diff. Several suggested
   theorems already exist under other names — map before creating
   duplicates: `closed_wait_set_exec_absorbing` ≈ `closedWaitSet_iter`;
   `cure_preserves_accounted` ≈ `yield_conservation`;
   `detection_latency_le_budget` ≈ the Tier-A1 lemma (near-free in
   BudgetWait); `unrestricted_l2_is_false` ≈ the mechanized sub-threshold
   counterexample (needs restating in the new trace semantics);
   `credit_monotone` ≈ `credit_monotone_under_yield_reachable`. The
   Noether module postdates their view entirely.

   **Status:** completed in `DELTA-AUDIT.md`. Next action is not coding; it is the
   WP1+WP2 task file for unified ontology and trace semantics.
2. **WP1/WP2 are the expensive part — lift, don't discard.** The Pro's
   unification (one state that is ledger AND graph; exec-vs-cure step split;
   trace-derived `flowIntegral` with the field proven to be a cache) is the
   right target and exactly what "the formal object has the paper's shape"
   requires. But it touches everything: sequence it as a new `Core/` built
   beside the existing modules, with the old theorems re-derived as
   instances, and only then retire the old surface. The standing rule
   stands: `monotone_under_adversary`'s statement is untouchable (two
   series import it; it is relation-generic, so WP2 can adopt it as-is).
   The exec/cure split, note, is the formal version of route-or-release:
   L3 becomes "absorbing under ordinary execution, escapable only by the
   cure" — strictly better than both earlier L3s.
3. **WP6: trust the paper's definitions — do NOT add horizon or
   closedness hypotheses.** (Corrected 2026-07-18 after Fabian's
   pushback; the earlier version of this annotation committed the
   egg-man error it warned about.) The payoff is `ownConversion` —
   attainable converted work — never possession. Under that definition:
   the "endgame defector" is inexpressible (hoarding everything means
   you can no longer convert — zero own gain at any horizon; and stock
   you CAN convert was never a stranded claim, so the theorem makes no
   demand on it); the "open system" is inexpressible (closedness is L1,
   already a law of the object, not a hypothesis to add). The one
   structural hypothesis is dependency-return, which WP6's
   `DependsOnWhole` already states. The commenter file
   (`commenters/2026-07-14-fable-karma-needs-a-cycle.md`) analyzed the
   PROSE aphorism, where the payoff is unpinned — cite it in the task
   file only as motivation for WHY the definitions are shaped this way
   (they are exactly what makes those loopholes unwritable), not as a
   source of extra hypotheses. Guard rail for the goblin: if a WP6 proof
   seems to need a horizon bound or a no-external-source side condition,
   the definitions have drifted from the paper — stop and re-read WP6.1
   rather than adding the hypothesis.
4. **Task-file-first now applies per work package.** WP1+2 share one task
   file (they are one refactor); WP3, WP4, WP5, WP6 each get their own,
   written against the paper's exact claim sentences — which means the
   combined paper's text (not just this feedback about it) still needs to
   ship into the repo. The feedback file quotes the claims' shapes; the
   task files should quote the claims.

   **Status:** WP1+WP2 implemented in `IsoConserve.CoreTrace` after Review #7's
   fixes to `04d-core-trace-task.md`; WP3 implemented in
   `IsoConserve.DetectorProgress` after the 04g task-file repair; WP5 is implemented
   through the destination-sum core, certificate-scoped recursive equation, and
   canonical routed-rate bridge; 04e PN-counter is also implemented.
