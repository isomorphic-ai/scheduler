# 04c — Lean 4 Formalization Task: Budget/Wait-Graph Bridge

**Series:** Isomorphic Scheduler · Paper 04 / Paper 01 companion  
**Depends on:** `iso-conserve-lean` accounting kernel and `04b` WaitGraph v2  
**Goal:** join the detector budget evidence with computed wait-graph blocking, so
the floor conjunct in deadlock detection becomes load-bearing rather than carried
as unused data.

> **TruthSeed (task):** `iso-sched-04c-budget-wait-bridge`
> The accounting kernel proves that blocked stock drains monotonically; WaitGraph
> proves that a closed wait component is absorbing and non-converting. This task
> proves the missing evidential link in one finite model: when a process reaches
> the budget floor through the detector's drain dynamics, every drain in the
> witness interval happened because the process was blocked. Therefore a floored
> closed wait component is not only structurally deadlocked; the floor is real
> evidence of sustained non-conversion.

---

## 0. Non-Negotiable Boundary

Do **not** fold this into the plan kernel or rewrite `IsoConserve.WaitGraph`.
Add a separate v3 bridge module, tentatively:

```text
iso-conserve-lean/IsoConserve/BudgetWait.lean
```

This module may reuse names and proof ideas from `WaitGraph`, but its job is
different:

- WaitGraph v2 proves closed components stay closed.
- The plan kernel proves blocked stock/budget moves downhill in a plan model.
- BudgetWait v3 proves the detector budget floor is evidence of blockedness in a
  model where `runnable` is computed from locks/wants.

This is a bridge model, not the full Python scheduler.

---

## 1. State

Use finite indexed identities, as in WaitGraph:

```lean
abbrev Pid (n : Nat) := Fin n
abbrev Lid (m : Nat) := Fin m

structure BWProc (m : Nat) where
  workNeeded : Nat
  converted : Nat
  stock : Qty
  budget : Nat
  budgetCap : Nat
  wants : Option (Lid m)
  done : Bool

structure BWState (n m : Nat) where
  procs : Pid n -> BWProc m
  holds : Pid n -> Lid m -> Bool
  convertCost : Qty
```

`budget` is natural-valued because detector floors are discrete. Draining uses
truncated subtraction: `budget - 1`, so zero is absorbing under further drain.

`budgetCap` is per-process to avoid a global side condition. The main window theorem
will assume a process starts the witness interval at its cap and reaches zero after
exactly `budgetCap` steps.

---

## 2. Computed Wait Predicates

Define the same computed wait predicates as v2, with the v2 prover correction
included from the start:

```lean
unfinished s p := (s.procs p).done = false
  /\ (s.procs p).converted < (s.procs p).workNeeded

blockedOn s p q := ∃ l,
  (s.procs p).wants = some l /\ s.holds q l = true /\ q != p

blocked s p := ∃ q, blockedOn s p q
runnable s p := (s.procs p).done = false /\ ¬ blocked s p
closedWaitSet s C := ∀ p, C p = true ->
  unfinished s p /\ ∃ q, C q = true /\ blockedOn s p q
floored s C := ∀ p, C p = true -> (s.procs p).budget = 0
```

Do **not** weaken `closedWaitSet` to merely `done = false`. Review #3 found that
W2 is false under the step semantics if a process is not done but has already
converted all required work.

---

## 3. Step Semantics

Keep the step deterministic and minimal:

1. `canConvert s p := runnable s p ∧ s.convertCost ≤ (s.procs p).stock`.
2. If `canConvert s p`, process `p` converts one unit:
   - `converted += 1`;
   - `stock -= convertCost`;
   - `budget := budgetCap`.
3. Else if `blocked s p`, process `p` drains one budget unit:
   - `budget := budget - 1`;
   - no conversion.
4. Else process `p` neither converts nor drains:
   - `budget` unchanged.
5. If the post-conversion count reaches `workNeeded`, `done := true`.
6. Done processes release locks in the next state.
7. Non-done processes keep their existing holds.
8. `wants` is copied unchanged.

This v3 bridge may keep lock acquisition out of scope. It needs release dynamics
for closed-component preservation, but not acquisition dynamics. If acquisition is
omitted, README/FINDINGS must say so explicitly.

Sketch:

```lean
convertedAfter s p :=
  if canConvert s p then (s.procs p).converted + 1
  else (s.procs p).converted

budgetAfter s p :=
  if canConvert s p then (s.procs p).budgetCap
  else if blocked s p then (s.procs p).budget - 1
  else (s.procs p).budget

doneAfter s p :=
  if (s.procs p).done then true
  else if (s.procs p).workNeeded <= convertedAfter s p then true
  else false

holdsAfter s p l :=
  if doneAfter s p then false else s.holds p l
```

---

## 4. Well-Formedness

Define a lightweight bridge WF:

```lean
structure BWWF (s : BWState n m) : Prop where
  cost_pos : 0 < s.convertCost
  stock_nonneg : ∀ p, 0 <= (s.procs p).stock
  budget_le_cap : ∀ p, (s.procs p).budget <= (s.procs p).budgetCap
```

Prove preservation:

```lean
theorem bw_wf_step : BWWF s -> BWWF (step s)
```

The stock proof is the usual forced-conversion residual proof for the converting
case, and equality/non-change for non-converting cases.

---

## 5. Theorems

### B1 — Budget Drop Implies Blocked

The one-step detector fact:

```lean
theorem budget_drop_implies_blocked
    (hdrop : ((step s).procs p).budget < (s.procs p).budget) :
    blocked s p
```

Reason: the only branch that strictly decreases budget is the `blocked s p` branch.
Conversion refills to cap; runnable non-conversion leaves budget unchanged.

Also useful:

```lean
theorem budget_after_ge_pred
    ((step s).procs p).budget >= (s.procs p).budget - 1
```

This prevents a final floor from being explained by a multi-unit hidden drop.

### B2 — Full Drain Window Implies Blocked Throughout

Define finite iteration:

```lean
def stepN : Nat -> BWState n m -> BWState n m
```

Define the history predicate:

```lean
def blockedThroughout (s : BWState n m) (k : Nat) (p : Pid n) : Prop :=
  ∀ j, j < k -> blocked (stepN j s) p
```

The main evidential theorem should avoid the false statement "final floor alone is
enough." Use a full-budget exact window:

```lean
theorem floor_after_full_drain_window_implies_blockedThroughout
    (hcap : (s.procs p).budget = (s.procs p).budgetCap)
    (hpos : 0 < (s.procs p).budgetCap)
    (hfloor : ((stepN (s.procs p).budgetCap s).procs p).budget = 0)
    (hwf_path : ∀ j, j <= (s.procs p).budgetCap -> BWWF (stepN j s)) :
    blockedThroughout s (s.procs p).budgetCap p
```

Why this shape: from cap to zero in exactly `cap` steps, with each step able to
drop at most one budget unit, every step must be a strict drop. By B1, every such
step occurred while blocked.

If this theorem fights Lean, keep the same concept but split it into two lemmas:

```lean
full_window_floor_implies_strict_drop_each_step
strict_drop_each_step_implies_blockedThroughout
```

The split is acceptable and probably clearer.

### B3 — Closed Wait Component Still Absorbs

Port the v2 closed-component result to the bridge state:

```lean
theorem closedWaitSet_step
    (hC : closedWaitSet s C) :
    closedWaitSet (step s) C

theorem closedWaitSet_iter
    (k : Nat) (hC : closedWaitSet s C) :
    closedWaitSet (stepN k s) C

theorem totalConvertedIn_iter
    (k : Nat) (hC : closedWaitSet s C) :
    totalConvertedIn C (stepN k s) = totalConvertedIn C s
```

This should follow the v2 proof structure: closed members are blocked, therefore
not runnable, therefore cannot convert or become done, therefore internal holders
do not release locks.

### B4 — Budget Floor + Closed Component, With Floor Doing Work

Define an evidence-carrying deadlock certificate:

```lean
structure evidencedDeadlock (s0 : BWState n m) (k : Nat)
    (C : Pid n -> Bool) : Prop where
  nonempty : ∃ p, C p = true
  closed_final : closedWaitSet (stepN k s0) C
  floored_final : floored (stepN k s0) C
  blocked_history : ∀ p, C p = true -> blockedThroughout s0 k p
  no_conversion : totalConvertedIn C (stepN k s0) = totalConvertedIn C s0
```

Main theorem:

```lean
theorem detection_sound_with_budget_evidence
    (hC0 : closedWaitSet s0 C)
    (hfull : ∀ p, C p = true ->
      (s0.procs p).budget = (s0.procs p).budgetCap)
    (hpos : ∀ p, C p = true -> 0 < (s0.procs p).budgetCap)
    (hsameCap : ∀ p, C p = true -> (s0.procs p).budgetCap = k)
    (hfloor : floored (stepN k s0) C)
    (hwf_path : ∀ j, j <= k -> BWWF (stepN j s0))
    (nonempty : ∃ p, C p = true) :
    evidencedDeadlock s0 k C
```

The same-cap hypothesis is deliberate. It avoids dependent per-process window
lengths in the first bridge theorem. A later refinement may remove it.

The proof obligations:

- `closed_final` from `closedWaitSet_iter`;
- `floored_final` from `hfloor`;
- `blocked_history` from B2 per member, using `hsameCap`;
- `no_conversion` from `totalConvertedIn_iter`.

This is the first theorem where the floor conjunct does real proof work.

---

## 6. Acceptance

1. `lake build` succeeds.
2. No `sorry`, `admit`, or `axiom` in `IsoConserve/`.
3. New module is imported by `IsoConserve.lean`.
4. README maps `BudgetWait` theorem names to the Paper 01 / Paper 04 detector
   claim and states the v3 deviations.
5. FINDINGS records any further spec correction surfaced by the prover.
6. `NEXT-TASKS.md` marks the task file as shipped and names any theorem not yet
   implemented.

---

## 7. Out Of Scope

- Effective-rate recursion.
- Flow-share conservation; use the existing plan kernel for L1/L4.
- Lock acquisition. Release-on-done is enough for the bridge theorem; acquisition
  can remain out of scope if documented.
- Victim selection or resolution policy.
- Automatic cycle discovery. The bridge starts from a supplied closed component.
- Removing the same-`budgetCap` hypothesis from B4. That is a cleanup theorem after
  the first bridge lands.

---

## 8. Review Checklist

Before coding, review this file for two failure modes:

1. Does any theorem accidentally claim that final floor alone proves blockedness?
   It should not.
2. Does any theorem imply the lock-acquisition protocol exists? It should not.

Only after those are clean should `IsoConserve/BudgetWait.lean` be written.
