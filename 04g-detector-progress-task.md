# 04g - Lean 4 Formalization Task: Detector And Progress Signal

**Series:** Isomorphic Scheduler - combined paper / Paper 08 §4.1 and §4.6
**Depends on:** `04d-core-trace-task.md`, `04c-lean-task.md`,
`paper08-expanded.md` §§4.1/4.6, `iso-conserve-lean/NEXT-TASKS.md` Round 4b WP3,
and `GPT-5.6-pro-feedback--lean.md` §3
**Goal:** close the detector theorem in one model: lock ownership and requested
locks generate the wait graph; conversion refills detector stock; non-conversion
drains it; floor plus a closed wait component is sound; persistent closed
non-conversion is detected within a budget bound; and `SIG_PROGRESS` handles the
100%-CPU useful/spinner distinction without a wall clock.

> **TruthSeed (task):** `iso-sched-04g-detector-progress`
> The detector does not measure duration. It measures conversion. A live process
> that keeps converting refills its budget and is never declared dead; a closed
> non-converting component drains to the floor and is caught; a process whose
> progress is internally invisible gets an honest channel to report a monotone
> counter.

---

## 0. Non-Negotiable Boundaries

Do **not** implement this before `04d-core-trace-task.md` has been reviewed and the
unified core state/event vocabulary has landed. This task lifts the existing
`BudgetWait` bridge into the core; it should not become a third parallel detector
state.

Implement the Lean surface in:

```lean
namespace IsoConserve.DetectorProgress
```

Names already exported by `IsoConserve.CoreTrace`, `IsoConserve.BudgetWait`, or
`IsoConserve.PaperClaims` must be imported or aliased rather than redefined under
the same unqualified name. In particular, `closed_wait_set_exec_absorbing` is
owned by 04d/CoreTrace; this task may export a detector-facing alias, but it must
not re-prove or fork the theorem.

Do **not** use wall-clock time, elapsed time, sleeps, timestamps, or timeout
constants. Bounds are in scheduled attempts, conversion opportunities, or per-member
selection counts.

Do **not** require Lean to discover cycles automatically. It is enough for
`detectorFires s C` to take a supplied finite candidate `C` and verify, from the
state's current `wants`/`holds`, that `C` is closed and floored. Graph search can
remain an executable layer above the theorem.

Do **not** claim Byzantine honesty. `SIG_PROGRESS` provides an honest channel. A
lying process is outside the detector's in-loop safety claim and belongs to an
out-of-band reputation predicate.

---

## 1. Paper Claims This Task Targets

From `paper08-expanded.md` §4.1:

> Give each process a budget -- its stock of the conserved quantity -- initialised
> to `k`. A step that converts (makes forward progress) resets the budget to `k`;
> a step that fails to progress (a blocked acquire) decrements it.

> The stranded claim is Q held in a cycle that cannot convert; the cure is to
> recognise it from the budget reaching its floor (the integral hitting zero)
> *together with* a closed wait-cycle among the floored processes.

> This is not a timer: a slow process that keeps converting keeps resetting its
> budget and never floors, so it is never mistaken for stuck. Only genuine
> non-conversion drains the budget to the floor.

> Result: timer-free deadlock detection with no false positives, localising the
> cause (the cycle) distinctly from the symptom (who is floored), with detection
> latency bounded by the budget size.

From §4.6:

> The budget of §4.1 measures conversion, not duration.

> Safety follows from L2: a live process converts, refills its budget, never
> floors, is never falsely flagged. Liveness follows from L3: a dead set converts
> nowhere, drains to the floor in bounded steps, is caught.

> The cure is to stop inferring and **ask**: a progress signal (`SIG_PROGRESS`) to
> which a process replies with a monotone counter. A rising counter refills the
> budget (the useful process is spared -- the case external inference could not
> save); a flat counter drains it (the spinner is reclaimed, no clock).

From the Pro feedback §3, the required theorem families are detector safety,
slow-but-live safety, deadlock liveness, and an exact budget bound.

---

## 2. Inputs From The Unified Core

The unified 04d core owns the process record shape. It already carries the
detector view explicitly:

```lean
budget : Nat
budgetCap : Nat
```

Do not add a separate detector-only process record outside the core. The detector
must read the same process/lock state that execution mutates.

Required core observables:

```lean
blockedOn   : CoreState n m -> ProcId n -> ProcId n -> Prop
blocked     : CoreState n m -> ProcId n -> Prop
runnable    : CoreState n m -> ProcId n -> Prop
canConvert  : CoreState n m -> ProcId n -> Prop
unfinished  : CoreState n m -> ProcId n -> Prop
converted   : CoreState n m -> ProcId n -> Nat
budget      : CoreState n m -> ProcId n -> Nat
budgetCap   : CoreState n m -> ProcId n -> Nat
```

Do not represent the detector budget by `stock` in this task; `stock` remains the
Q ledger quantity, while `budget : Nat` is the detector counter.

---

## 3. Detector Step Semantics

Define a scheduled attempt as a core transition, and use schedules as the only
execution driver for this module:

```lean
def observeAttempt (s : CoreState n m) (p : ProcId n) : CoreState n m := ...
def runSchedule : List (ProcId n) -> CoreState n m -> CoreState n m := ...
```

Required behavior:

1. If `canConvert s p`, process `p` converts one unit and its budget refills to
   `budgetCap s p`.
2. Else if `blocked s p`, process `p` does not convert and its budget drains by
   one with truncated subtraction.
3. Else the process neither converts nor drains.
4. Lock acquisition/release and `done` updates come from the unified core, not from
   a detector-only copy.

Do not introduce a second synchronous `stepN` semantics for the headline theorems.
If iteration helpers are useful, define them as wrappers around schedule prefixes
so every budget-window statement talks about selected attempts for the process in
question.

Required one-step facts:

```lean
theorem conversion_refills_budget
theorem blocked_nonconversion_drains_budget
theorem budget_drop_implies_blocked
theorem budget_after_ge_pred
```

These are the core-lifted versions of the existing `BudgetWait` bridge lemmas.

---

## 4. Closed Components And Detector Firing

Define closed wait sets from the actual lock graph:

```lean
def closedWaitSet (s : CoreState n m) (C : ProcId n -> Bool) : Prop :=
  forall p, C p = true ->
    unfinished s p /\ exists q, C q = true /\ blockedOn s p q

def floored (s : CoreState n m) (C : ProcId n -> Bool) : Prop :=
  forall p, C p = true -> budget s p = 0

structure GenuineDeadlock (s : CoreState n m) (C : ProcId n -> Bool) : Prop where
  nonempty : exists p, C p = true
  unfinished_all : forall p, C p = true -> unfinished s p
  internally_blocked : forall p, C p = true ->
    exists q, C q = true /\ blockedOn s p q
  not_runnable : forall p, C p = true -> not (runnable s p)

def detectorFires (s : CoreState n m) (C : ProcId n -> Bool) : Prop :=
  closedWaitSet s C /\ floored s C /\ exists p, C p = true
```

Required safety theorem:

```lean
theorem detector_sound :
    detectorFires s C -> GenuineDeadlock s C
```

This is the no-false-positive theorem. The component `C` is supplied, but the
closure evidence is checked against the current state.

---

## 5. Slow-But-Live Safety

State liveness of an individual process in conversion units and selected attempts,
not time. The budget can be nonzero forever only if the observation starts from a
full enough budget; Review #7 found that the old statement was false at `j = 0`
when `budget s p = 0`.

```lean
def selectedCount
    (schedule : List (ProcId n)) (p : ProcId n) : Nat := ...

def convertsWithinEverySelectionWindow
    (s0 : CoreState n m) (schedule : List (ProcId n))
    (p : ProcId n) (window : Nat) : Prop := ...
```

Required theorems:

```lean
theorem periodic_conversion_never_floors
    (hcap_pos : 0 < budgetCap s p)
    (hbudget0 : budget s p = budgetCap s p)
    (hlive : convertsWithinEverySelectionWindow s schedule p (budgetCap s p)) :
    forall prefix,
      prefix <:+ schedule ->
      budget (runSchedule prefix s) p != 0

theorem live_process_not_detected
    (hcap_pos : 0 < budgetCap s p)
    (hbudget0 : budget s p = budgetCap s p)
    (hlive : convertsWithinEverySelectionWindow s schedule p (budgetCap s p))
    (hp : C p = true) :
    forall prefix,
      prefix <:+ schedule ->
      not (detectorFires (runSchedule prefix s) C)
```

If `live_process_not_detected` needs the stronger assumption that `p` is the
member whose floor would be necessary for `C`, state that explicitly. Do not turn
the theorem into a wall-clock statement.

---

## 6. Deadlock Liveness And Exact Bound

Closed components should remain closed and non-converting under ordinary execution:

```lean
theorem closed_wait_set_exec_absorbing :=
  CoreTrace.closed_wait_set_exec_absorbing

theorem closed_wait_set_no_conversion :=
  CoreTrace.closed_wait_set_converted_total_fixed
```

Then prove bounded detection under fair scheduling. Use selection counts, not time:

```lean
def memberSelectedAtLeast
    (schedule : List (ProcId n)) (C : ProcId n -> Bool) (k : Nat) : Prop :=
  forall p, C p = true -> k <= selectedCount schedule p
```

Required theorems:

```lean
theorem closed_deadlock_eventually_floors
    (hC : closedWaitSet s C)
    (hfair : memberSelectedAtLeast schedule C k)
    (hcap : forall p, C p = true -> budget s p <= k) :
    floored (runSchedule schedule s) C

theorem deadlock_eventually_detected
    (hC : closedWaitSet s C)
    (hnonempty : exists p, C p = true)
    (hfair : memberSelectedAtLeast schedule C k)
    (hcap : forall p, C p = true -> budget s p <= k) :
    detectorFires (runSchedule schedule s) C

theorem detection_latency_le_budget
    (hC : closedWaitSet s C)
    (hnonempty : exists p, C p = true)
    (hfair : memberSelectedAtLeast schedule C k)
    (hcap : forall p, C p = true -> budget s p <= k) :
    exists prefix,
      prefix <:+ schedule /\
      detectorFires (runSchedule prefix s) C /\
      forall p, C p = true -> selectedCount prefix p <= k
```

For a round-robin schedule, add a corollary translating the bound to rounds if it
is cheap. The headline theorem remains the selection-count bound.

---

## 7. Progress Signal

Add the `SIG_PROGRESS` self-reporting channel as a small submodel or as core events:

```lean
structure ProgressProc where
  budget : Nat
  budgetCap : Nat
  reported : Nat
  delivered : Nat
  reclaimed : Bool

def sigProgressStep (p : ProgressProc) (reply : Nat) : ProgressProc := ...
def honest (p : ProgressProc) : Prop := p.reported = p.delivered
```

Required behavior:

- if `reply > p.reported`, budget refills;
- if `reply <= p.reported`, budget drains;
- `reported` is monotone non-decreasing;
- reputation compares reported progress to delivered progress out of band.

Required theorems:

```lean
theorem rising_progress_refills_budget
theorem flat_progress_drains_budget
theorem reported_counter_monotone
theorem useful_reporter_never_reclaimed
theorem spinner_eventually_reclaimed
theorem liar_survives_in_loop_if_it_reports_progress
theorem liar_fails_reputation_check
```

The liar theorem must be worded carefully: the detector accepts a rising report at
face value; the reputation checker catches mismatch between reported and delivered
progress. Do not state that the detector itself detects lies.

---

## 8. README And FINDINGS Updates

Update `iso-conserve-lean/README.md` with §4.1 and §4.6 theorem coverage:

- `detector_sound`;
- `periodic_conversion_never_floors`;
- `live_process_not_detected`;
- `closed_deadlock_eventually_floors`;
- `deadlock_eventually_detected`;
- `detection_latency_le_budget`;
- progress-signal theorem names for useful/spinner/liar.

Document boundaries:

- finite model;
- supplied candidate component, checked by predicate rather than discovered by
  graph search;
- no wall-clock time;
- honest channel, not Byzantine enforcement;
- the floor conjunct in `detector_sound` is carried as detector evidence, but
  closure is the load-bearing structural proof of genuine deadlock; budget-window
  theorems are what make the floor evidence meaningful over a trace.

Update `FINDINGS.md` if Lean forces a sharper claim. Likely candidates:

- floor alone is never enough; closure carries the structural deadlock evidence;
- final floor alone is weaker than a budget-window certificate unless the trace
  records enough attempt history;
- liar handling is reputation, not detector soundness.

---

## 9. Acceptance

1. The task file is reviewed before code starts.
2. `lake build` succeeds after implementation.
3. No `sorry`, `admit`, or new `axiom` appears in `IsoConserve/`.
4. The new detector/progress module imports the unified core and is imported by
   `IsoConserve.lean`.
5. README and FINDINGS cite exact theorem names and boundaries.
6. A no-time audit on the new Lean module finds no clock/timeout vocabulary except
   comments explaining the exclusion.
7. The Review #7 repair commit for this task file precedes the implementation
   commit.

---

## 10. Suggested Work Order

1. Lift `BudgetWait` one-step budget facts into the unified core.
2. Define `detectorFires` and prove `detector_sound`.
3. Prove slow-but-live non-flooring.
4. Prove closed-deadlock bounded detection via selected-count fairness.
5. Add the `SIG_PROGRESS` submodel and useful/spinner/liar theorems.
6. Update README/FINDINGS.

Stop after step 2 if the core lift reveals a state-shape mismatch. That mismatch is
itself a finding; do not paper over it with a parallel detector model.
