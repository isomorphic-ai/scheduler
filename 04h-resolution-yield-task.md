# 04h - Lean 4 Formalization Task: Resolution Yield And Banked Work

**Series:** Isomorphic Scheduler - combined paper / Paper 08 §4.2
**Depends on:** `04d-core-trace-task.md`, `04g-detector-progress-task.md`,
`paper08-expanded.md` §4.2, `iso-conserve-lean/NEXT-TASKS.md` Round 4b WP4, and
`GPT-5.6-pro-feedback--lean.md` §4
**Goal:** formalize resolution as a work-conserving yield: a process breaks a
closed wait component by releasing held locks and restarting, while banking its
converted-since-restart progress as credit instead of discarding it as victim loss.

> **TruthSeed (task):** `iso-sched-04h-resolution-yield`
> Deadlock resolution has no victim when the releaser's converted progress is
> conserved. Yield releases the claim that closes the cycle, transfers restart-local
> converted work into credit, and returns the process with base budget plus banked
> credit. Discarding that work returns to the same contention; banking it creates a
> monotone variant.

---

## 0. Non-Negotiable Boundaries

Do **not** implement this before the unified core from `04d` and the detector
surface from `04g` have been reviewed. This task needs the same lock/wait graph,
control state, budget, converted work, and credit ledger in one state.

Implement the Lean surface in:

```lean
namespace IsoConserve.ResolutionYield
```

The process and state records are owned by `IsoConserve.CoreTrace`. This task may
define aliases such as `creditUnits`, but it must not introduce a second
`CoreProc`/`CoreState` shape.

Do **not** present the existing `YieldPlan` theorem as the full §4.2 result.
`YieldPlan` proves the conservation core for stock-to-credit banking. This task
must additionally model restart-local converted work, lock release, restart control,
and the broken wait edge.

Do **not** call a process a victim if its accounted progress is preserved. The task
should reserve "discard" or "loss-abort" for the ablation that destroys converted
work.

Do **not** prove termination by a scheduler fairness hack or rotation counter. The
termination argument must use credit as the monotone variant.

---

## 1. Paper Claims This Task Targets

From `paper08-expanded.md` §4.2:

> Discarding the victim's work can livelock -- the restarted process re-enters the
> same contention and is aborted again.

> Reading of Q: **banked stock**. When a process yields to break the cycle, its
> converted progress is not discarded; it is *banked* as credit -- the integral
> carried across the restart discontinuity -- so the process returns with an
> expanded budget (base plus credit).

> The cure is for one process to release its claim -- but releasing while
> *conserving* the released work, so the release costs nothing in the long run.

> Because the yielder's integral is banked rather than destroyed, it converges
> instead of reliving the same fight.

> Result: deadlock resolution with no victim; the releaser loses nothing and the
> system makes progress.

From the Pro feedback §4, a resolution yield should:

1. value the process's retained progress in Q-units;
2. transfer that value into credit;
3. release held claims or locks;
4. restart the control path;
5. preserve the entire accounted ledger.

---

## 2. State Requirements

The unified core process must distinguish cumulative delivered work from
restart-local work. If `04d` still has only one `converted` field, revise the core
before this task lands rather than encoding restart semantics in theorem
hypotheses.

The shape is the one already supplied by 04d:

```lean
structure CoreProc (m : Nat) where
  baseRate : Qty
  stock : Qty
  credit : Qty
  convertedTotal : Nat
  convertedSinceRestart : Nat
  workNeeded : Nat
  pc : Nat
  wants : Option (LockId m)
  budget : Nat
  budgetCap : Nat
  done : Bool
```

Accounting can use either representation below, but it must be explicit:

1. `convertedSinceRestart` is restart-local and included in `accounted`; yield moves
   `convertCost * convertedSinceRestart` into `credit` and resets it to zero.
2. `convertedTotal` remains monotone, while `restartableProgress` is the bankable
   component; yield moves only the restartable component into `credit`.

In both designs, prove:

```lean
theorem converted_total_monotone_under_resolution
theorem accounted_includes_banked_work
```

Do not let "converted" mean both delivered permanent work and restart-local work.

---

## 3. Resolution Yield Step

Define the yield as a cure event over a chosen process:

```lean
def resolutionYield
    (s : CoreState n m) (y : ProcId n) : CoreState n m := ...
```

Required behavior:

- bank `convertCost * convertedSinceRestart y` into `credit y`;
- reset the restart-local progress/control path for `y`;
- release every lock held by `y`, leaving those locks unheld by `y` after this
  step;
- clear or rewind `wants y` according to the core's restart semantics;
- set `budget y = budgetCap y + creditUnits y`, where `creditUnits` is a Nat
  progress-unit view of banked restart work;
- leave unrelated processes' accounted values unchanged except for wake effects
  caused by released locks.

`resolutionYield` is release-without-instant-regrant. Lock acquisition after the
yield is a separate ordinary execution step; the cure step itself must not release
and reacquire the same lock in one transition.

Required one-step theorems:

```lean
theorem resolution_yield_conserves
theorem resolution_yield_loses_no_accounted_work
theorem credit_monotone
theorem restart_has_base_plus_credit
theorem resolution_yield_releases_held_locks
```

These lift the already-proved conservation core (`yield_conservation`,
`credit_monotone_under_yield_reachable`) to the real restart operation.

---

## 4. Yield Breaks The Closed Component

A yield breaks a particular closed wait component only when the yielder releases a
lock that some component member was waiting on. Make the witness explicit:

```lean
structure ReleaseWitness (s : CoreState n m) (C : ProcId n -> Bool)
    (y w : ProcId n) (l : LockId m) : Prop where
  y_in : C y = true
  w_in : C w = true
  y_holds : s.holds y l = true
  w_wants : (s.procs w).wants = some l
  w_ne_y : w ≠ y
```

Required theorem:

```lean
theorem yield_releases_wait_edge
    (hw : ReleaseWitness s C y w l) :
    not (blockedOn (resolutionYield s y) w y)

theorem yield_breaks_closed_component
    (hC : closedWaitSet s C)
    (hw : ReleaseWitness s C y w l)
    (honly : forall q, C q = true -> blockedOn s w q -> q = y) :
    not (closedWaitSet (resolutionYield s y) C)
```

The `honly` premise is deliberate. Releasing one edge proves the component broke only
when that edge was the member's internal blocker; otherwise Lean should not pretend
another internal wait edge is impossible.

---

## 5. Credit Policy And No-Victim Theorem

Model the paper's selection policy:

```lean
def yielderScore (s : CoreState n m) (p : ProcId n) : Qty :=
  credit s p

def choosesLeastCredit
    (s : CoreState n m) (C : ProcId n -> Bool) (y : ProcId n) : Prop := ...
```

The selection theorem should be modest:

```lean
theorem least_credit_choice_spreads_burden
    (hchoice : choosesLeastCredit s C y)
    (hyield : s' = resolutionYield s y) :
    forall z, C z = true -> z != y -> credit s y <= credit s z
```

The stronger "no victim" result is accounting, not psychology:

```lean
theorem no_victim_accounted_progress_preserved
    (hyield : s' = resolutionYield s y) :
    procAccounted s'.convertCost (s'.procs y) =
      procAccounted s.convertCost (s.procs y)
```

---

## 6. Credit Versus Discard Ablation

Define a small deterministic comparison model, not a full scheduler:

```lean
structure ToyState where
  remaining : Nat
  banked : Nat
  atContention : Bool

def creditPolicyStep : ToyState -> ToyState
def discardPolicyStep : ToyState -> ToyState
```

Required theorems:

```lean
theorem canonical_credit_policy_completes_in_two_yields
theorem canonical_discard_policy_returns_to_same_contention
theorem canonical_discard_policy_livelocks_for_all_n (n : Nat)
```

The discard theorem can be stated as a state-space cycle:

```lean
theorem discard_returns_to_previous_state :
    discardPolicyStep s = s
```

or as a periodicity theorem over `stepN`, whichever is cleaner.

The credit theorem should track banked work:

```lean
theorem credit_policy_banked_work_strictly_increases
```

---

## 7. General Termination Variant

Prove the general theorem if the toy comparison goes cleanly:

```lean
theorem positive_credit_gain_finite_requirement_eventually_completes
    (hgain : forall j, beforeComplete j -> 1 <= creditGainUnitsAt j)
    (hbound : finiteRemainingRequirement s0) :
    exists k, completes (stepN k s0)
```

This should be a variant-function argument over Nat progress units, not arbitrary
positive rationals. Review #7 found the rational version Zeno-false: geometrically
shrinking positive gains can increase credit forever without completing. The proof
must use the mechanism link supplied by `restart_has_base_plus_credit`: each
positive unit of banked restart work funds a strictly longer restart attempt
against finite `workNeeded`. If the exact scheduler semantics make this too broad,
keep the theorem in the toy model and document the boundary.

---

## 8. README And FINDINGS Updates

Update `iso-conserve-lean/README.md` with §4.2 theorem coverage:

- `resolution_yield_conserves`;
- `resolution_yield_loses_no_accounted_work`;
- `credit_monotone`;
- `restart_has_base_plus_credit`;
- `yield_releases_wait_edge`;
- the credit-vs-discard comparison theorem names;
- the general positive-credit termination theorem if proved.

Document boundaries:

- restart-local converted work versus cumulative delivered work;
- yield breaks a component only with a released-lock witness;
- no-victim means accounted progress is preserved;
- if the discard comparison is a toy model, say so.

Update `FINDINGS.md` for any sharpening. Likely candidates:

- the old generic `YieldPlan` was conservation-core-only, not full resolution;
- component breakage requires a concrete released wait edge;
- credit termination is a variant theorem only under finite requirement and
  positive gain.

---

## 9. Acceptance

1. The task file is reviewed before code starts.
2. `lake build` succeeds after implementation.
3. No `sorry`, `admit`, or new `axiom` appears in `IsoConserve/`.
4. The resolution module imports the unified core/detector surface and is imported
   by `IsoConserve.lean`.
5. README and FINDINGS cite exact theorem names and boundaries.
6. The credit-vs-discard comparison is theorem-level, not only an engine trace.
7. The Review #7 repair commit for this task file precedes the implementation
   commit.

---

## 10. Suggested Work Order

1. Refine the core state's converted-work split if necessary.
2. Define `resolutionYield` and prove accounting preservation.
3. Prove lock release and wait-edge breakage with an explicit witness.
4. Prove restart budget includes credit and credit is monotone.
5. Add the credit-vs-discard toy comparison.
6. Attempt the general positive-credit finite-requirement theorem.

Stop after step 2 if the converted-work meaning is ambiguous. That is a model bug,
not a proof inconvenience.
