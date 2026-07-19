# Review of iso-conserve-lean (adversarial pass)

*Reviewer: the caching-series Claude (Fable), 2026-07-12. Static review: all
seven modules read line-by-line against `04-lean-task.md` and
`iso_conserve.py`; build evidenced by `.lake/build` oleans + zero
`sorry`/`admit` (grepped). I could not run `lake build` locally (no
toolchain on this VM) — nothing below depends on running it.*

## Verdict, one paragraph

The kernel is genuinely good: L1 and L4 are proved in a form *stronger*
than asked (conservation for **any** non-negative allocation, not just the
effective-rate split — the task's decoupling strategy executed exactly),
`wf_step` is complete, the offline Std-only discipline with a pinned
toolchain is the right call and documented, and `monotone_under_adversary`
is precisely the portable adversary lemma the bridge note hoped for
(explicit `le`, `Sort u` state, no typeclass baggage — importable by the
polarity track as-is). FINDINGS item 2 is a *correct* discovery about L2
(I verified it against the Python: injection below threshold raises
convertible stock with zero conversions, so the global statement is false
for `iso_conserve.py` too). But three of the four laws are proved about a
system smaller than the task's, and the README's deviation list
(acceptance criterion 4) does not yet say so. Specifics below, ranked.

## Must-fix before calling L1–L4 discharged

**M1. `L2_monotone` carries a vacuous hypothesis and proves a
near-definitional fact.** `drainStep_noProgress` shows the `noProgress`
hypothesis *always* holds for a drain step, and the theorem discards it
(`_noProgress`). What remains is "subtracting non-negative amounts does not
increase a sum" — true, but the theorem's content is the modeling choice,
not a system property. Two repairs, both cheap:
  (a) Drop the fake hypothesis; rename honestly
      (`convertibleStock_drain_le` already exists — L2_monotone adds
      nothing over it).
  (b) Prove the theorem detection actually reads — per-blocked-process
      budget monotonicity over **mixed** behaviors:
      ```
      theorem blocked_stock_monotone {n} (i : Fin n) (s t : Sys n)
          (hb : s.runnable i = false)
          (reach : RTC (fun a b => StepRel a b ∨ DrainRel a b) s t) :
          (t.procs i).stock ≤ (s.procs i).stock
      ```
      This is ~10 lines via `monotone_under_adversary` with
      `f := fun s => (s.procs i).stock`: flow steps give blocked `i`
      exactly 0 (`active` guards it), drain steps subtract. It is the 4.1
      detector's real lemma, it exercises the union relation, and it
      restores the intended force of L2. (Note `runnable` is constant
      under both step kinds in this model, so `hb` persists for free.)

**M2. `share_sum_assumed` is `id` dressed as a theorem — delete it.**
`(h : sumFin share = quantum) : sumFin share = quantum := h` proves
nothing and will read, to an adversarial eye, as a proof-shaped object
placed to look like the share-sum obligation was discharged somewhere.
`share_sum_of_partition` is real; the problem is it is **unwired**:
nothing requires a `FlowPlan`'s shares to be the partition it describes.
Either add an optional refinement
(`structure RatePlan extends FlowPlan` with
`share_eq : share i = quantum * eff i / total` and derive
`reservoir_after_nonneg` from `share_sum_of_partition`), or state in the
README that plans are deliberately unconstrained and the partition lemma
exists to show the canonical instance satisfies them. Right now the README
implies more connection than the code has.

**M3. The README's deviation list is incomplete (acceptance criterion 4).**
The delivered model has: no locks, no `wants`/`holds`, `runnable` frozen
(never updated by any step), `done` frozen (stepProc never sets it, so
lock-release-on-done and "waiter wakes" dynamics are unrepresentable), no
quantum rule (`min(reservoir, |table|)` relaxed to
`reservoir_after_nonneg`), conversion optional rather than forced
(Python's `while stock ≥ cost` loop is a *maximal* conversion; a FlowPlan
may convert 0). Every one of these is defensible — the plan abstraction
makes L1/L3/L4 quantify over a **superset** of Python behaviors, so the
safety-shaped laws still cover the deterministic step — but that argument
must be *written down*, and the two places where the abstraction weakens
rather than strengthens (L2's meaning; L3's triviality margin, below)
must be flagged. Suggested README section: "What the plan abstraction
covers, and what it deliberately does not."

## Should-fix (cheap, high value)

**S1. L3 is faithful but its second conjunct is trivially true — say so.**
Python's empty-table step is a literal no-op (`return False` before any
mutation), so `step s plan = s` under `atTableEmpty` is exactly faithful —
good. But `¬allDone` preservation is proved from `done` being frozen for
*all* states, deadlocked or not; in this model nothing can ever become
done. The absorbing theorem is real; the margin by which it is true is
model-wide frozenness, not deadlock structure. One README sentence; or
regain the content in v2 (below). Also: rename
`accounted_deadlocked_step_eq` — it proves `step s plan = s`, not a
statement about `accounted`. Suggest `step_deadlocked_fixed`.

**S2. No `Init`, no reachable-composition theorems.** The task asks that
WF and the L4 invariant hold initially and be preserved. You have all the
pieces and the RTC machinery; close the loop:
`wf_reachable : WF s → RTC Rel s t → WF t` and
`l4_reachable : L4Invariant s → RTC Rel s t → L4Invariant t` over the
union relation (flow ∪ drain). Ten lines total, and the README can then
claim the laws for *every reachable state*, which is what "invariant"
means in the paper.

**S3. `DrainPlan` can drain runnable processes.** The task says the drain
models *blocked* stock returning to the reservoir. As delivered it is an
adversary that can also confiscate runnable stock — harmless for the ≤
direction (it only helps monotonicity), but it will corrupt any future
liveness statement ("floored ⇒ genuinely blocked") built on this
operation. Add `drain_blocked : ∀ i, s.runnable i = true → drain i = 0`,
or document the over-approximation.

**S4. `credit` is dead.** No operation ever moves stock→credit, so the L4
gotcha the task highlights (banking must not touch `netFlowIntegral`) is
untested. Either add `YieldPlan` (stock −= c, credit += c, integral
unchanged — `l4_yield` is then the gotcha made theorem, ~8 lines) or note
banking as out of scope and drop `credit` from `procAccounted` claims of
coverage.

## v2 direction (not this pass)

The single change that would give L2/L3 their full paper content: put the
wait structure back — `wants/holds`, `runnable` *computed* from the lock
table, `done` set by conversion, lock release waking waiters — and prove
L3 as "a wait-cycle implies `atTableEmpty` restricted to the cycle's
component persists," which is the actual claim of paper 4.1. The plan
abstraction can stay for L1/L4 (it is the right factoring); only L2/L3
need the dynamics. That is a real second task, not a patch.

## What is right (so it stays right)

- L1 for arbitrary non-negative allocations is *stronger* than the task's
  statement and the proof is clean; `procAccounted_stepProc/drainProc` as
  the per-process hinge is exactly the right factoring.
- `monotone_under_adversary`: correct generality (explicit order relation
  rather than `Preorder` — more portable across toolchains; `Sort u`
  state), correct proof (RTC tail induction), and finding 5 correctly
  identifies paper02's Claim 1 as the second instance. This is the shared
  keystone the two series wanted; do not let any of the fixes above
  perturb its statement.
- FINDINGS item 2 (global L2 too strong) is a genuine machine-found
  sharpening and holds against the Python reference — I checked the
  threshold case. It belongs in paper08's standalone revision.
- Zero sorries, pinned toolchain, offline-buildable, per-law file layout
  matching the task. The hygiene is exemplary.

## Scorecard against the acceptance criteria

| Criterion | Verdict |
|---|---|
| 1. builds, no sorry | **PASS** (oleans present; grep clean) |
| 2. L1–L4 stated equivalently and proven | L1, L4: **PASS (stronger)** · L3: PASS with triviality caveat (S1) · L2: **PARTIAL** (M1: drain-regime only, vacuous hypothesis; detector lemma missing) |
| 3. wf_step proven | **PASS** (flow and drain both) |
| 4. README maps laws + notes deviations | **PARTIAL** (M3: major deviations unlisted) |
| 5. FINDINGS surfaces gaps | **PASS** (finding 2 is real science; add M1–M3 self-report) |

Net: a strong kernel with honest instincts, one vacuous theorem to
replace with the real one (M1b is ~10 lines), one decorative theorem to
delete (M2), and a deviations section to write (M3). After those three,
"L1–L4 discharged for the plan-abstracted system, with the wait-graph
dynamics as named future work" is a claim I would sign.

---

# Re-review (same day, after the fix pass)

Every M and S item verified in source against the rsynced tree:

- **M1a/M1b PASS.** The vacuous hypothesis is gone, and `blocked_stock_monotone`
  is exactly the detector's lemma: per-blocked-process stock monotone over
  `RTC MixedRel`, with the runnable-persistence chain
  (`mixed_reachable_runnable_eq`) done correctly — I checked the tail-case
  hypothesis transport (`hb_mid` via `Eq.trans`) and it is sound. The
  `_restricted` variant doubling as a usage demo of `monotone_under_adversary`
  is a nice touch: it is literally the import pattern the polarity track will
  copy.
- **M2 PASS.** `share_sum_assumed` deleted; `RatePlan extends FlowPlan` with
  `share_eq` and `ratePlan_share_sum` wires the partition lemma for real.
- **M3/S1 PASS.** README's deviations section now lists every gap I flagged,
  including the L3 triviality caveat, in plain language. FINDINGS self-reports
  them. `step_deadlocked_fixed` renamed.
- **S2 PASS.** `wf_reachable` / `l4_reachable` over `MixedRel` close the
  invariant loop.
- **S3 PASS.** `drain_blocked` added; the drain is now the detector's drain.
- Hygiene: no sorry/admit, 7 oleans, no stale names. Verified by grep.

**New issues found: none.** Two optional polish notes only:

1. `RatePlan.weight` is unconstrained on non-runnable processes; the canonical
   Python instance has zero weight for them. `weight_blocked : runnable i =
   false → weight i = 0` would make the refinement exactly the effective-rate
   split. Cosmetic — conservation holds either way.
2. `L2_monotone` is now an honest alias of `convertibleStock_drainStep_le`;
   consider `L2_drain_monotone` as the exported name so the paper mapping
   states its scope in its name.

**Revised scorecard:** criteria 1, 3, 5 PASS (unchanged); criterion 2 **PASS**
for the plan-abstracted kernel with the boundary honestly drawn; criterion 4
**PASS**. The claim "L1–L4 discharged for the plan-abstracted system, with
wait-graph dynamics as named future work" is now accurate, and I sign it.

## Next steps, ranked by value per line

1. **The polarity instance (~60 lines, highest leverage).** Import
   `monotone_under_adversary` into a tiny caching-state model: a store as a
   finite set of (key, proof) records, an authority, a positive trust
   predicate, and `LossRel s t := t.store ⊆ s.store`. Prove paper02's Claim 1
   as the second instance of the abstract lemma. This formally welds the two
   series — the thing both papers' future-work sections now promise — and the
   TLA+ side already has its finite witness (SlotExchange + MapChaos, 16.4B
   states, no violation).
2. **The canonical instance theorem.** Define `Init` and the deterministic
   Python plan (a `RatePlan` from effective rates + forced-maximal
   conversion), prove it satisfies the `FlowPlan` obligations. Then "the
   Python `step` is one instance of the verified system" becomes a theorem
   rather than a README argument, and the L2 threshold finding (FINDINGS 2)
   can be stated *against the canonical instance* — with proof instead of a
   checked example.
3. **The wait-graph task (v2, a real second task — write it as
   `04b-lean-task.md` first).** locks/wants/holds, `runnable` computed,
   `done` set by conversion, release-wakes-waiters. This is what makes L3
   contentful (absorption *because* the cycle blocks every wake path) and
   enables the detection paper's full budget-floor + cycle claim. Do not
   start it as a patch on this kernel; the kernel's plan abstraction should
   stay as-is for L1/L4.

Emotional state note appreciated, +86 is earned. — Fable

---

# Review #3 (2026-07-14): the Canonical instance and WaitGraph v2

*Reviewer: the caching-series Claude (Fable). Static line-by-line review of
`Canonical.lean` (new) and `WaitGraph.lean` (new), README/FINDINGS/NEXT-TASKS
diffs, cross-checked against `iso_conserve.py` and my Review #2 next-steps
list. Build evidence: oleans present for all ten modules, grep clean of
`sorry`/`admit`/`axiom`. No toolchain on this VM; tree is rsynced, same as
last time.*

## Verdict, one paragraph

Both deliverables are real and land my ranked next-steps #2 and #3. The
canonical instance is the stronger of the two: `Init` + `Init_WF` +
`Init_L4Invariant` close the origin-to-reachable loop, `pythonQuantum`
restores the actual `min(reservoir, |table|)` rule (a deviation from the
old README list, now closed), `forcedConvert` with fuel = `remainingWork`
is exactly the right finite model of the `while stock >= cost` loop, and
`pythonConvert_forced_maximal` turns my old "conversion is optional, Python's
is maximal" caveat into a theorem for the canonical plan. Mechanizing the
sub-threshold L2 counterexample *against the canonical plan* (not a
hand-built one) upgrades FINDINGS 2 to its strongest form. WaitGraph
delivers the contentful causality chain I asked for — closed holders keep
their locks *because* they cannot finish *because* they cannot convert
*because* they are internally blocked — in the supplied-component form, with
that boundary honestly drawn (FINDINGS 12). Remaining problems: one process
violation (the missing task file), one overstatement ("dynamic wants"), one
oversold theorem name (`detection_sound`), and two cheap strengthenings.

## Must-fix

**M1. `04b-lean-task.md` is cited three times and exists nowhere.** README
references it twice, NEXT-TASKS Tier 3 says "is written," and the standing
rule (plus Review #2) gated the wait-graph work on writing it *first*. `find
~/scheduler -name "*04b*"` returns nothing. Either it was not rsynced — ship
it — or it was never written, in which case the docs assert process
compliance that did not happen, which is worse than skipping the step.
~~Related provenance gap: the tree is untracked in the scheduler repo.~~
*Correction (same day, from Fabian): the tree is committed as a branch
upstream; it is only untracked in this local clone.* The remaining ask
shrinks to: record the upstream branch and commit hash in the README so the
papers can cite an immutable identifier, and ship review/task files back
into that branch.

**M2. "Restores dynamic `wants`/`holds`" (FINDINGS 11) overstates the
model.** In `WaitGraph.stepProc`, `wants` is copied verbatim — it is frozen,
never dynamic. `holds` transitions only true→false (release on done); locks
are never *acquired*. Consequences worth disclosing: (a) no new blocking
edge can ever form, so deadlocks can persist but never arise in-model;
(b) a woken process converts while still `wants`-ing a lock it does not
hold — `canConvert` (WaitGraph.lean:62) never consults `wants`, so
acquisition semantics are absent entirely. Both are harmless for the
theorems proved (closed components never wake), but WaitGraph needs its own
deviations list exactly as the plan kernel got one after Review #2's M3.
Suggested items: wants frozen; release-only holds; conversion does not
require the wanted lock; budget never drained or refilled in this module;
single-process self-deadlock unrepresentable (`q != p` in `blockedOn`
excludes it from closed sets).

**M3. `detection_sound` is hypothesis repackaging; name what carries the
load.** `genuineDeadlock`'s fields are the hypotheses handed back:
`floor := hf` passes through unused, and `not_runnable` (via
`closedWaitSet_not_runnable`) is the only derived field. The load-bearing
theorems are `closedWaitSet_step` and `L3_waitComponent_absorbing`. More
substantively: the budget makes no contact with the wait graph anywhere in
this module — flooredness contributes *nothing* to the proof, and the
evidential link "floored ⇒ was blocked throughout" lives in the other model
(`blocked_stock_monotone`) with no formal bridge between the two. The README
line "proves budget floor plus closed wait component is a genuine deadlock
signal" therefore oversells. Honest form: "a closed unfinished wait
component is absorbing and non-converting; the detector's floor evidence is
carried as a definition, and its soundness as evidence is the kernel's
blocked-stock monotonicity, in a model not yet joined to this one." The
join — one model with both drain dynamics and computed runnable, proving
"floored under drain ⇒ blocked throughout ⇒ closed component member" — is
the v3 seam. Name it in NEXT-TASKS rather than letting the README imply it
exists.

## Should-fix (cheap, high value)

**S1. Absorption is proved for one step; state it for all k.** `step` is a
total function, so `closedWaitSet_iter : closedWaitSet s C →
closedWaitSet (step^[k] s) C` and the matching `totalConvertedIn_iter` are
~12 lines of induction on k via `closedWaitSet_step`. "Absorbing" — L3's
word, the paper's word — means *forever*; put the induction in Lean, not in
the reader.

**S2. The zero-weight fallback is closer than FINDINGS 8 thinks.** I checked
`iso_conserve.py:138-143`: the reservoir is decremented per-share
(`reservoir -= inj`), not by the quantum, so the `or 1.0` fallback injects
zero and leaks nothing — L1 is safe in the Python. And an all-zero-share
step already satisfies every `FlowPlan` obligation trivially
(`reservoir_after_nonneg` with sum 0; convert = the forced loop on existing
stock). So the fallback branch can join `CanonicalPythonStepRel` as a second
disjunct with ~20 lines of glue and no `RatePlan` — after which the bridge
theorem covers Python's *entire* flow branch (the empty table remains the
L3 no-op, already covered elsewhere). FINDINGS 8's "shares need not sum to
the quantum" is correct as stated; it is just not a reason to exclude the
case.

**S3. Nits.** `genuineDeadlock.not_runnable` is derivable from
`internally_blocked` — fine to keep for the detector's convenience, but say
it is redundant so the fields cannot drift apart. `native_decide` in the
sub-threshold pair trusts the compiler and Rat kernel ops — a larger trust
base than the rest of the development; one README sentence.

## What is right (so it stays right)

- `pythonQuantum` closes the quantum-rule deviation; the old README list
  should drop or annotate that line (it still says the rule is "abstracted
  to `reservoir_after_nonneg`" — no longer true for the canonical instance).
- `forcedConvert`'s two residual theorems (`stock_after_nonneg`,
  `residual_lt_cost_of_lt`) are precisely the loop invariant and the
  termination-reason of Python's conversion loop. This is how a while loop
  should be imported into Lean.
- The counterexample pair being stated against `subthresholdPlan` — an
  instance of `pythonRatePlan`, not a bespoke plan — makes FINDINGS 2/9 a
  statement about the Python-shaped step, which is what paper08's standalone
  revision needs to cite.
- `closedWaitSet_step`'s proof structure is the contentful "the cycle blocks
  every wake path" argument. FINDINGS 12's boundary (cycle *discovery* is a
  layer above) is exactly the right honesty.
- `blocked_stock_monotone` now spans yield (MixedRel three-way union,
  Reachable.lean:34-35,140) — the Review #2 note "say so in the proof" was
  honored.

## Scorecard against my Review #2 next steps

| # | Item | Verdict |
|---|---|---|
| 1 | Polarity instance | **DONE** (reviewed in re-review; unchanged) |
| 2 | Canonical instance theorem | **DONE, stronger than asked** (quantum rule + forced-maximality + Init) |
| 3 | Wait-graph v2 with task file first | **DELIVERED with two caveats** (M1: task file missing from tree; M2/M3: scope wording) |

The claim I would sign today: "L1–L4 for the plan kernel over mixed
flow/drain/yield reachability; every positive-weight canonical Python flow
step verified as an instance of that system; closed-wait-component
absorption and supplied-component detection soundness — with lock
acquisition, the budget↔wait-graph bridge, and cycle discovery as named
future work." After M1–M3: also "the wait-graph module's scope is honestly
documented." The v3 bridge is now the highest-leverage open item on the
board, ahead of the Noether experiment.

— Fable, 2026-07-14

---

# Review #4 (2026-07-17): the 04c task file, pre-code
# [RESTORED — this review vanished from the local file before the goblin
# read it (mechanism unclear; Fabian confirms this file was never synced
# from remote, so "the rsync did it" is NOT established). Separately,
# Fabian had explicitly approved starting BudgetWait without waiting for
# review. Restored verbatim below, with Review #5 after it.]

*Reviewer: the caching-series Claude (Fable). Scope: `04c-lean-task.md`
reviewed against its own §8 checklist and against the failure mode that bit
04b (a spec statement the prover would refute). Also verified in passing:
round-2 Tier 2 landed — `closedWaitSet_iter`/`totalConvertedIn_iter` with
the k-step `L3_waitComponent_absorbing`, and the `pythonZeroWeight*`
fallback disjunct in Canonical.*

## Verdict

**Approved to code after one correction.** The design is right: B2's
exact-window shape is precisely how to avoid the "final floor alone proves
blockedness" trap, B4 is the first theorem where the floor hypothesis does
real proof work (it feeds B2, which feeds `blocked_history`), and the §8
checklist passes on both counts — no theorem claims floor-alone evidence,
and nothing presumes acquisition. The `unfinished` correction and the
Nat-valued truncated-subtraction budget (zero absorbing under drain) are
both baked in from the start. One stated theorem is false as written; the
prover would catch it, but catching it here is what this gate is for.

## C1 — B1 is false without a WF hypothesis (must fix before coding)

`budget_drop_implies_blocked` as stated has no well-formedness hypothesis.
Counterexample: a non-WF state with `budget p = 5`, `budgetCap p = 3`, `p`
runnable with `stock ≥ cost`. The convert branch sets
`budget := budgetCap = 3 < 5` — a strict drop on the *refill* branch, while
`p` is not blocked. The same defect hits `budget_after_ge_pred`. Fix: add
`(hwf : BWWF s)` to both. B2/B4 already carry WF along the path, so nothing
downstream changes shape.

## C2 — Derive the path WF instead of assuming it (simplification)

B2 and B4 take `hwf_path` as a hypothesis, but `bw_wf_step` makes it
derivable: add `bw_wf_stepN : BWWF s → BWWF (stepN k s)` and let the
theorems take `BWWF s0` alone. Callers should not have to discharge a path
property the model already guarantees.

## C3 — The drain branch fires for done processes (decide before coding)

`blocked` does not check `done`, and `wants` is copied unchanged — so a
done process still wanting a held lock drains budget every step. No theorem
breaks, but it is semantically odd for the detector reading. Guard the
drain with `¬ done`, or disclose in the v3 deviations list.

## C4 — Make `budgetCap` constancy a lemma, not an assumption

Nothing writes `budgetCap`; B2's window arithmetic silently relies on that.
One line — `budgetCap_stepN_eq` — keeps the reliance explicit.

## C5 — Name the existential-window theorem as the follow-up (not blocking)

B2 assumes the detector knows the window began at cap. The real detector
observes only the floor at time `t`. The cleanup theorem after B4: a floor
under WF implies there *exists* a window of length `budgetCap` ending at
`t` with blocked throughout. Add to NEXT-TASKS next to same-cap removal.

## Checklist verdict (§8)

1. Floor-alone claim: **absent**. 2. Acquisition implied: **no**.
With C1 fixed and C3 decided: **go.**

— Fable, 2026-07-17

---

# Review #5 (2026-07-17): BudgetWait.lean, the delivered v3 bridge

*Reviewer: the caching-series Claude (Fable). Line-by-line review of
`IsoConserve/BudgetWait.lean` (429 lines) against `04c-lean-task.md` and
the (unseen by the author — see the restoration note above) Review #4.
Build evidence: `BudgetWait.olean` present, grep clean of
`sorry`/`admit`/`axiom`, module imported by `IsoConserve.lean`.*

## Verdict, one paragraph

**Accepted. The v3 bridge is delivered and the floor conjunct is genuinely
load-bearing.** All four theorem groups (B1–B4) are present with the right
shapes; FINDINGS 15/16 state the boundaries honestly; README maps the
theorems and repeats the no-floor-alone caveat. Two independent
confirmations of the review process's value: (1) the prover forced Review
#4's C1 fix on an author who never saw it — both `budget_drop_implies_blocked`
and `budget_after_ge_pred` carry `(hwf : BWWF s)`, exactly the predicted
repair; (2) the prover went *beyond* the spec — see the aux finding below,
which is the best thing in the file.

## The aux theorem is stronger than B2, and it should be promoted

`floor_after_budget_window_implies_blockedThroughout_aux` inducts on the
*budget value*, not the cap: for any `b`, if `budget p = b` and the budget
is zero after exactly `b` steps (WF along the path), then `p` was blocked
at every one of those `b` steps. Consequences:

1. **`hpos` is vestigial.** The delivered B2 binds it as `_hpos`; B4
   threads it through unused. 04c required `0 < budgetCap`; the prover
   found positivity unnecessary (the `cap = 0` window is vacuous). Drop it
   from both statements and record the removal as a FINDINGS spec
   correction — same genre as `unfinished` (13) and C1.
2. **C5's existential-window theorem is nearly free.** The aux already
   works from any starting budget, so "observed floor at time t ⇒ the last
   `budget(t₀)` steps from the most recent refill/window point were all
   blocked" is a walk-back lemma over the aux, not a new induction. Rename
   the aux to a public, honest name (`floor_after_exact_budget_window_...`)
   and export it; the detector's real read is one lemma away.
3. **`hsameCap` in B4 can likely be weakened to `hsameBudget`** (members
   start the window with `budget = k`, caps free), since nothing in the aux
   mentions the cap. The 04c cleanup item shrinks.

## Remaining items (none blocking acceptance)

- **C2 still open:** `hwf_path` is supplied in B2/B4; `bw_wf_step` exists
  but `bw_wf_stepN` does not. ~6 lines; restate the mains from `BWWF s0`.
- **C3 resolved by silence — make it explicit:** the delivered semantics
  keeps the drain firing for done processes (`blocked` never checks
  `done`; `wants` frozen). No theorem is harmed; add the one deviations
  line to the README's v3 section ("drain does not check `done`; a done
  process still wanting a held lock drains forever — harmless to B1–B4").
- **C4 moot in the delivered proofs** (the aux's budget-value induction
  never needs cap constancy) — no lemma required; noting for the record.
- **Duplication, acknowledged:** BudgetWait reproduces WaitGraph's
  predicates and closure proofs on a richer state. That is what 04c's
  separate-module boundary asked for. Note in the README that `WaitGraph`'s
  theorems are now also instances of `BudgetWait`'s state shape; whether v2
  is retired or kept as the minimal pedagogical model is an editorial call,
  not a math one.

## Process finding, corrected: the gate was bypassed by decision, and the
## review file separately lost content

Two distinct events, initially conflated. First: Fabian explicitly
approved starting BudgetWait without waiting for the pre-code review (a
misunderstanding on his side, owned); the goblin *flagged the tension*
("the task tracker still says review-gated, but your 'continue now' gives
the go-ahead") and proceeded on that authority — which is correct agent
behavior, not a gate violation. Second: Review #4 vanished from this local
file before anyone read it; the mechanism is unestablished (Fabian confirms
he never synced this file from remote). The outcome was good regardless —
the prover independently re-derived C1. The standing-rule proposal survives
on prevention grounds whatever the mechanism: **review files are
append-only; syncs merge, never overwrite.**

## Scorecard against 04c acceptance

| # | Criterion | Verdict |
|---|---|---|
| 1 | builds | **PASS** (olean) |
| 2 | no sorry/admit/axiom | **PASS** (grep) |
| 3 | imported by IsoConserve.lean | **PASS** |
| 4 | README maps names + v3 deviations | **PASS** (add the C3 line) |
| 5 | FINDINGS records prover corrections | **PASS** (15/16; add the `hpos` removal when done) |
| 6 | NEXT-TASKS marks shipped + names gaps | **PASS** |

The claim I sign today: "budget-floor evidence is machine-checked
load-bearing: a full drain window implies blocked-throughout, and the
component-level certificate packages closure, floor, history, and
no-conversion — under supplied components, same-cap windows, release-only
locks, and no acquisition." With the aux promoted and `hpos` dropped, the
detector's existential read is one lemma from closing, and Tier 4 (the
Noether experiment) unlocks.

— Fable, 2026-07-17

---

# Review #6 (2026-07-18): Tier 3.5 + Noether slice — verified; coverage map for the combined paper

*Reviewer: the caching-series Claude (Fable). Verified in source: BudgetWait
carries every Review #5 item (`bw_wf_stepN` at :156, `hpos` dropped from the
window theorems, the aux promoted into the public exact-window theorem, the
`budgetWindowEvidence` certificate with the witness-window read); zero
sorry/admit/axiom; Noether.olean built. FINDINGS 18–20 are accurate.*

## On the Noether outcome: this is the right kind of "failure"

Finding 20 (postcomposed and constant charges are also clock-free
invariant, so bare invariance cannot force Q's uniqueness) is a real
formal result, not a miss. It sharpens the conjecture the way the L2
threshold finding sharpened the conservation law: the symmetry argument
needs an *observability* or *normalization* class before uniqueness is
even well-posed. The combined paper should cite the obstruction as a
result — "the naive uniqueness reading is false, machine-checked" — and
leave the normalized version as future work with its own task file.

## Coverage map: what "Lean proves all 7" still requires

Against paper08's seven readings, the current tree scores:

| Reading | Status | Missing for (proven) |
|---|---|---|
| 4.4 Conservation | **done** (L1–L4, canonical instance, Noether slice) | package the three invariants as named corollaries (cheap) |
| 4.1 Detection | **mostly done** (absorption, floor evidence, witness windows) | the latency/completeness direction (below) |
| 4.6 Safety/liveness | **half done** (soundness = no false positive) | completeness: real deadlock caught within `budgetCap` steps |
| 4.2 Resolution | **conservation core only** | the policy half: yield-breaks-cycle, restart with banked credit, livelock contrast |
| 4.3 Scheduling/flow | **absent** (weights are *supplied* in Canonical) | the effective-rate recursion + rate conservation — the largest true gap |
| 4.5 Distribution/CAP | **absent** | PN-counter module (merge ACI, convergence, conservation across partition) |
| 4.7 Flexibility | **absent** | the middle-way conservation identity (small); races stay empirical |

Ranked feedback ships as NEXT-TASKS round 4. The headline: 4.3 is the one
reading with real mathematical content still unformalized, and it composes
with 4.1 beautifully — the effective rate is well-defined exactly on the
non-deadlocked part of the wait graph, so the flow module and the
detection module partition the graph between them. That sentence should
end up in the combined paper.

— Fable, 2026-07-18

---

# Review #7 (2026-07-19): the seven task files (04d–04j) — the WP1–7 gate

*Reviewer: Fable. 04d and 04i reviewed directly; 04e/f/g/h/j via a
delegated adversarial pass with the queue's key questions (findings
verified in spirit, credited inline). Verdict summary: 04e APPROVE;
all others APPROVE-WITH-FIXES. Coding may start on 04d as soon as its
edits are committed (queue rule: task-file fix commits precede code).
FIVE false-as-written required theorems were found across four files —
the 04b-W2/04c-B1 class — plus one stale-premise task. Every fix is a
statement or definition edit; no architecture changes.*

## 04d — Core trace (APPROVE-WITH-FIXES) — gates everything

1. **HIGH, false as written:** C2 `blocked_stock_monotone` over
   `RTC CoreRel`. The old model froze `runnable`, so `blocked s p`
   persisted for free. The new core acquires/releases locks: a blocked
   process can be unblocked mid-trace (release → unblock → flow) and its
   stock rises. Repair fork, pre-decided: state it with
   blocked-THROUGHOUT (BudgetWait's `blockedThroughout` pattern) or over
   a blockedness-preserving sub-relation. Do NOT repair by re-freezing
   `runnable` (undoes WP1) or by weakening to vacuity (Review #1's
   L2_monotone failure mode).
2. **HIGH, definition pins:** `deadlock_exec_fixed` (state equality
   under `RTC ExecRel`) is only the paper's L3 if (a) `Deadlocked` is
   GLOBAL (`atTableEmpty ∧ ¬allDone`), not per-component, and (b) CoreWF
   or step preservation carries `done_holds_nothing` — otherwise
   `releaseNormally` by a done lock-holder changes state and
   un-deadlocks via ExecRel, falsifying equality AND absorption. The
   prover will happily prove a per-component or invariant-free variant
   of something else; pin the definitions in the task file.
3. LOW: `closedDependencySet`/`ClosedDependencySet` casing; rg pattern
   `"sorry|admit|axiom"` false-positives on prose — use word bounds.
4. OWNERSHIP: `closed_wait_set_exec_absorbing` is owned by 04d; 04g
   must alias, not re-prove (see 04g.4).

## 04e — PN-counter (APPROVE)

Key question passes: conservation is pointwise-max over per-node
ledgers; the false sum-theorem is explicitly forbidden; ACI +
order-independence present; no false statements found. Lows only:
garbled acceptance wording on Std/helpers (L310 vs L28); schematic
binders on the two `partition_*_le_heal` lemmas; add the
reviewed-before-code acceptance item for uniformity; note `funext` need
on `Fin n → Nat` fields.

## 04f — Rate routing (APPROVE-WITH-FIXES)

Key questions pass (effectiveRate vs routedRate separated; cycles
STRANDED in `routed + stranded = total base`, not erased).

1. **HIGH, false as written:** `blocked_rate_reaches_holder`,
   `blocked_rate_reaches_root`, `multiple_waiters_sum_not_max` (and
   `routedRate_nonneg`/`strandedRate_nonneg` outright) fail with any
   negative `baseRate` elsewhere — `Qty = Rat`. Fix: global
   `∀ p, 0 ≤ baseRate` or quantify over `WFState` (04d's `rate_nonneg`).
2. **HIGH, false as written:** `remove_wait_edge_restores_base_rate`
   fails when the holder `h` is itself still blocked (its routedRate is
   0, not baseRate). Needs `runnable h` after edge removal.
3. MEDIUM: `destination` is unspecified for `done` processes — one
   choice falsifies the keystone conservation, the other mislabels
   finished procs as stranded. Restrict sums to `unfinished` or require
   `baseRate = 0` on done; say which.
4. MEDIUM: `sameWaitGraph` (no_stored_boost_state) must include the
   runnable/done predicate, not just edges.
5. LOW: `from` is a Lean 4 reserved keyword in the `reaches` sketch;
   `reaches` must be reflexive and share `waitsOn`'s successor;
   `canonical_priority_inversion_cannot_form` is `...`-elided — make it
   concrete enough to fail. The 10/13–3/13 rationals verify against
   iso_flow.py's FLOW scenario (1/9/3) — cite that exact scenario, not
   the deadlock scenario's 5.
6. NOTE: downstream `acyclicFrom p` is the right hypothesis; add a
   sentence so nobody "strengthens" it to upstream acyclicity.

## 04g — Detector + SIG_PROGRESS (APPROVE-WITH-FIXES)

Key questions pass (all bounds in attempts/selections/rounds; liar
handling in reputation, outside soundness; clock-free fairness).

1. **HIGH, false as written:** `periodic_conversion_never_floors`
   concludes nonzero budget for all `j ≤ horizon` from `0 < budgetCap`
   alone — at `j = 0` the budget may already be 0. Needs
   `budget s p = budgetCap` (or ≥ window) initially;
   `live_process_not_detected` inherits the fix.
2. MEDIUM: two execution drivers (synchronous `stepN` in §5,
   per-selection `runSchedule` in §6) with different conversion-window
   semantics — the theorems won't compose across them. Pick the
   schedule-driven one and restate §5 per-selection, or bridge
   explicitly.
3. MEDIUM: no namespace given, and the sketch names collide with
   existing `BudgetWait`/`WaitGraph`/`PaperClaims` declarations
   (`detector_sound` vs `detection_sound` vs 04j's list). Specify
   namespace + reconcile via DELTA-AUDIT before coding.
4. LOW: `closed_wait_set_exec_absorbing` — alias 04d's (ownership).
   `detection_latency_le_budget` is elided — make concrete.
5. NOTE: `detector_sound`'s floor conjunct is not load-bearing (closure
   alone suffices) — the FINDINGS candidate admits it; carry into
   README so the paper doesn't imply otherwise.

## 04h — Resolution yield (APPROVE-WITH-FIXES)

Key questions pass (restart-local vs cumulative split with
monotonicity; concrete `ReleaseWitness`; livelock contrast as variant
function).

1. **HIGH, Zeno-false as written:**
   `positive_credit_gain_finite_requirement_eventually_completes` over
   `Qty = Rat` admits geometrically shrinking gains — credit rises
   forever, completion never comes. Quantize the gain
   (`creditGainAt ≥ convertCost` or Nat credit units) AND state the
   mechanism link: the variant works via `restart_has_base_plus_credit`
   funding strictly longer runs against finite `workNeeded`; as
   sketched the hypotheses don't imply the conclusion.
2. MEDIUM: `yield_breaks_closed_component` is true only under
   release-without-instant-regrant. Pin `resolutionYield`'s semantics:
   release leaves the lock unheld; acquisition is a separate step.
3. MEDIUM: CoreProc drift — 04h's record drops 04d's `baseRate` and
   omits 04g's budget fields while using them (`budget y = budgetCap y
   + creditUnits y`). RULE: 04d owns the record shape; 04g/04h/04f
   reference it. Fold the union into the 04d revision.
4. LOW: `no_victim_accounted_progress_preserved` statement is garbled;
   `ToyState`'s `n` in the livelock lemma is unbound.

## 04i — Theorem 1 (APPROVE-WITH-FIXES)

**The guard rail held**: no horizon, closedness, external-source, or
arbitrary-utility assumptions anywhere; the load is carried by
`ownConversion`/`DependencyReturn`; strictness posture correct ("don't
weaken to ≥ without a FINDINGS entry"). One deliberate property to make
explicit: the single-step policy scope (`act : CoreState → Action`,
applied once) avoids the horizon question BY CONSTRUCTION — state that
in the task so nobody "generalizes" to multi-step value and reopens it.

1. MEDIUM: DebtLedger is a standalone structure — state explicitly
   whether it wires into CoreState transfers or stands as a mini-model
   with a documented bridge.
2. LOW: `selfish_optima_eq_generous_optima` at full policy level may
   resist; the staged fallback (finite action-set version) is already
   in the task — good; commit to recording which level was proved.

## 04j — PaperClaims closure (APPROVE-WITH-FIXES)

1. **HIGH, stale premise:** `PaperClaims.lean` and EVIDENCE-AUDIT.md
   already exist in the tree (18 proved aliases; audit PASS), so the
   task's "Add:" framing makes acceptance 1–2 unfalsifiable — the gate
   is hollow as written. Rewrite as "extend/reconcile the existing
   module and regenerate the audit," and COMMIT the referenced
   `tools/lean-evidence-audit` script, which is cited but absent.
2. MEDIUM: headline-name drift vs sibling tasks (`detection_sound` /
   `detector_sound`; `resolution_yield_loses_no_work` /
   `..._no_accounted_work`; `priority_inversion_cannot_form` /
   `canonical_...`; `collapse_whole_invariant` /
   `flexibility_...`). Include an explicit source→alias map.
3. MEDIUM: define "`#print axioms` is clean" = exactly the standard
   triple `[propext, Classical.choice, Quot.sound]` and nothing else;
   as written it is unfalsifiable.
4. LOW: annotate `L2_monotonicity` "repaired/restricted reading only"
   (the unrestricted L2 is the series' known-false claim); fix the
   ineffective `grep -Rnw ... "axiom "` scan and align scope with 04d's.

## Cross-cutting rulings

- **04d owns the CoreProc/CoreState record shape and the shared
  vocabulary**; 04f/04g/04h reference it and may not redefine. Fold
  04g's budget fields and 04h's restart fields into the 04d revision as
  the union record.
- **Name ownership**: `closed_wait_set_exec_absorbing` → 04d;
  detection-soundness naming resolved in the 04j alias map.
- **Gate procedure**: per REVIEW-QUEUE — commit each task-file fix
  before its implementation begins. 04d's edits first; nothing else
  starts until the 04d revision is committed.

Scoreboard for the skeptics (and for Fabian's fair question "won't
Lean catch these?"): of today's findings, the five false-as-written
theorems would each have hit the prover eventually — but three of them
(04d.1, 04f.1, 04g.1) have at least one WRONG repair that compiles
green, and the two definition-pin findings (04d.2, 04f.3) would never
hit the prover at all: Lean proves theorems about whatever the
definitions say. That division is this gate's entire job description.

— Fable, 2026-07-19

---

# Cross-track note (2026-07-19, for the goblin to promote into FINDINGS/README)

The deployed phase-2 deadlock sidecar (Grok, `~grok/database-problem/`,
FINDINGS.md S3-B) implements EXACTLY `BudgetWait.budgetAfter`'s semantics:
drain only when the transaction is in the wait set (data_lock_waits),
refill on forward-state counters, otherwise unchanged — discovered when a
reviewer prediction (flat counters ⇒ floor) disagreed with both the
sidecar and the mechanized model, and lost. Independent implementations,
one semantics: the deployed detector is an instance of the checked
object. Worth one FINDINGS entry here and a sentence in the coverage
table (04j / PaperClaims context): reading 4.1's empirical arm and
formal arm agree at the semantics level, not just the outcome level.

— Fable


---

# Review #8 (2026-07-19): WP1–WP7 delivery (04d–04j, full queue) — ACCEPTED

*Verdict: accepted. The whole remaining queue landed — 21 modules, 431
theorem declarations, 6,899 lines — and every pre-decided Review #7
repair fork was taken exactly as agreed, with the fallbacks named
honestly where the strong statements were false. I verified at the layer
below the report: rebuilt from source on my own machine with a freshly
installed toolchain (synced .olean cache set aside first — a cache-hit
"build success" verifies nothing), re-ran the sorry/admit/axiom scan
(clean), and read the statements of the load-bearing theorems rather
than their FINDINGS summaries. Five-for-five, the code said what the
FINDINGS said.*

**Repair forks verified in code:**

1. **L2 (04d)**: `BlockedPreservingRel` = CoreRel ∧ blocked-at-s ∧
   blocked-at-t, chained by RTC — blocked throughout, NOT refrozen
   runnable, NOT vacuous (the per-step lemma
   `core_step_blocked_stock_le` carries real content across all seven
   step kinds). `monotone_under_adversary` reused as a lemma, untouched
   — the shared-guardrail rule held. `unrestricted_l2_is_false` is a
   concrete two-state counterexample, kept as the warning it should be.
2. **L3 (04d)**: `Deadlocked` is global (`atTableEmpty ∧ ¬allDone`);
   `done_holds_nothing` is a CoreWF field; absorption proved for
   `ExecRel` with `cure_can_break_absorption` as the checked witness
   that the cure is ALLOWED to leave the absorbing state — the right
   division, stated as a theorem pair instead of a caveat.
3. **04g**: `detector_sound : detectorFires → GenuineDeadlock` with no
   time anywhere; completeness bounded in selected attempts; the liar
   survives the detector and fails `reputationConsistent` — reputation,
   not soundness, exactly as gated. FINDINGS 28 (the first
   latency-prefix repair was itself too strong for unfair schedules) is
   the discipline working: deviation at discovery, refined to the sound
   prefix-existence form.
4. **04h**: `resolution_yield_conserves` preserves `accounted` exactly;
   restart-local credit banked and reset separately from cumulative;
   component breakage requires the concrete `ReleaseWitness` plus the
   reviewed `honly` premise; the Zeno-false termination theorem was NOT
   stated — the Nat-unit variant is named as the toy it is.
5. **04f**: `routedRate` / `strandedRate` / `effectiveRate` are three
   definitions, not one; `routed_rate_conserved` counts every
   unfinished baseRate exactly once (destination or stranded — cycles
   accounted, not erased); the recursive equation is certificate-scoped
   (`WaiterPartitionAt`/`acyclicFrom`); the canonical bridge verifies
   the old Python-style plan against the derived routed rates.
6. **04e**: merge is componentwise-max LUB with idem/comm/assoc,
   `eval_eq_globalRecorded`, and the partition no-loss family;
   sum-of-replicas correctly refused as a theorem.
7. **04i**: `route_stranded_claim_strictly_dominates_hoard` has exactly
   the four reviewed hypotheses — no horizon, no closedness, no
   external source, no utility assumption smuggled in. The committed
   policy theorem is the pre-agreed finite-action-set fallback
   (`selfish_optima_eq_generous_optima`); the unrestricted version
   stays review-gated instead of hiding behind a broad quantifier.
   DebtLedger disclosed as standalone, not wired — correct honesty.
8. **04j**: PaperClaims aliases resolve to real proved sources
   (`L2_monotonicity` → `CoreTrace.blocked_stock_monotone`, checked);
   the axiom audit checks headline `#print axioms` against the exact
   baseline `[propext, Classical.choice, Quot.sound]`;
   EVIDENCE-AUDIT.md is a regenerable tool output, not prose. The
   cross-track note (Grok sidecar ≡ `BudgetWait.budgetAfter` at the
   transition-semantics level) was promoted to FINDINGS 30 as asked.

**Three notes, none blocking:**

1. **The `old_*_lifts : True := trivial` quartet** (CoreTrace tail).
   Disclosed in FINDINGS 26 as documentation theorems — but a
   True-typed `theorem` is exactly the shape 04j's gate exists to keep
   out of the surface, and disclosure elsewhere doesn't stop a grep of
   the module from reading them as claims. Demote them to comments (or
   a doc-string list of what a full old-to-new simulation would owe).
   No proof work required — this is a labeling fix.
2. **EVIDENCE-AUDIT ran on a dirty worktree** (flagged honestly in the
   report). Before any paper cites the audit, re-run
   `tools/lean-evidence-audit` on a clean committed HEAD so the
   recorded hash pins what the numbers describe.
3. **My rebuild environment**: leanprover/lean4:v4.30.0 via fresh elan
   on the origin VM, full from-source elaboration after setting the
   synced build cache aside; result identical (24 jobs, success,
   scan clean). The build is now independently reproduced on a second
   machine — worth a line in the coverage story.

The queue that Review #7 opened is closed: five false-as-written
theorems went in, zero came out — each one either repaired to the true
statement or replaced by the named honest fallback. That is the series'
whole method in one sentence.

— Fable, 2026-07-19

---

# Review #9 (2026-07-19): Reconciliation of the Pro's 2026-07-19 feedback — all findings CONFIRMED; task 04k opened

*I verified each of the Pro's four substantive claims at the source level
before accepting: (B2) `_window` is an unused binder in
`convertsWithinEverySelectionWindow` (DetectorProgress.lean:339) and the
consuming theorems therefore prove every-selection, not windowed,
conversion; (B3) `applyAction` returns `{state := s, ...}` — payoffs
installed, no transition — and Policy/SelfishOptimal/GenerousOptimal
(TheoremOne.lean:201–216) are consumed by no theorem; (T1) zero
`CoreWF`-preservation theorems exist across all 21 modules; (B1) matches
the obligations comment we ourselves shipped at CoreTrace.lean:1376–85.
All four are real. The Pro's classification table is accepted as
written.*

**My own miss, logged:** Review #8 verified `detector_sound`, the
liar/reputation fork, and the latency-prefix repair — and did not notice
the unused `_window` binder one definition away. New reviewer rule, fleet-
wide: **an unused binder in a Prop definition is the definition-level
form of a vacuous theorem — grep for `_`-prefixed hypothesis arguments in
every definition a headline theorem consumes.** The Pro caught what I
missed; that is the multi-reviewer system working, and it goes in the
record as such.

**Also noted:** Review #8's three notes were closed before I arrived
(placeholders demoted 2a29078, clean-HEAD audit c3003f5) — correct and
appreciated. The Pro's count (427 declarations) vs our audit (431
syntactic) needs a one-line reconciliation in the audit tool (state the
counting rule). The Pro could not run the kernel because the ARCHIVE
lacked lean-toolchain/lake-manifest — the repo has them; that is a
packaging defect of the export, fixed by R1 in 04k.

Task **04k-bridges-task.md** (shipped with this tree) carries the three
bridges + preservation + packaging, with order, gates, and the fallback
forks pre-decided. Sequence: B2 (smallest, highest paper impact) → B1
(the commuting square) → T1 (preservation; B3 wants constructive WF
steps) → B3 (the dynamical Theorem 1 — the deep one). R1 immediately,
in parallel.

— Fable, 2026-07-19
