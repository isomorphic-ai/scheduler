# 04b — Lean 4 Formalization Task: Wait-Graph Dynamics

**Series:** Isomorphic Scheduler · Paper 04 / Paper 01 companion  
**Depends on:** `iso-conserve-lean` plan-abstracted conservation kernel  
**Goal:** add a second Lean model with real wait-graph dynamics so the deadlock
and detection theorems have content, while leaving the existing L1/L4 accounting
kernel intact.

> **TruthSeed (task):** `iso-sched-04b-waitgraph-deadlock-sound`
> The plan abstraction proves conservation once a step's accounting plan is
> supplied. This task proves why a blocked wait component stays blocked: runnable
> is computed from locks and wants; conversion sets `done`; done processes release
> locks; and a closed wait component has no wake path. Detection soundness then
> follows: a floored, closed wait-cycle is a genuine deadlock, not a slow live set.

---

## 0. Non-negotiable boundary

Do **not** rewrite the existing plan kernel (`IsoConserve.Basic`,
`L1Conservation`, `L4Integral`, `Reachable`, `Canonical`). Keep it as the
accounting layer. Add wait-graph dynamics as a separate module that can import the
kernel where useful.

The new model's job is not to re-prove L1. Its job is to prove the dynamic facts
the plan abstraction could not state:

1. runnable is computed from locks/wants, not frozen;
2. done processes release locks;
3. closed wait components remain blocked because every wanted lock is held inside
   the component; and
4. budget-floor plus closed wait component is a sound deadlock signal.

---

## 1. State

Use finite indexed identities:

```lean
abbrev Pid (n : Nat) := Fin n
abbrev Lid (m : Nat) := Fin m

structure WGProc (m : Nat) where
  workNeeded : Nat
  converted : Nat
  stock : Qty
  budget : Qty
  wants : Option (Lid m)
  done : Bool

structure WGState (n m : Nat) where
  procs : Pid n -> WGProc m
  holds : Pid n -> Lid m -> Bool
```

`holds p l = true` means process `p` currently holds lock `l`. The holder of a
wanted lock is derived from `holds`, not stored separately.

---

## 2. Computed wait predicates

Define:

```lean
heldBy s l p       := s.holds p l = true
heldIn s C l       := ∃ p, C p ∧ heldBy s l p
blockedOn s p q    := ∃ l, wants p = some l ∧ holds q l = true ∧ q ≠ p
blocked s p        := ∃ q, blockedOn s p q
runnable s p       := p not done ∧ not blocked s p
atTableEmpty s     := ∀ p, ¬ runnable s p
closedWaitSet s C  := ∀ p, C p -> p not done ∧ ∃ q, C q ∧ blockedOn s p q
```

The key closure condition is not just "there is a cycle"; it is "every process in
the component wants a lock held by another process in the component." That is the
finite, proof-friendly form of a closed wait-cycle.

---

## 3. Step semantics

Keep step simple and deterministic enough to prove:

1. If a process is not runnable, it cannot convert.
2. If a process is runnable and has enough stock to pay `convertCost`, it converts
   one unit.
3. If its converted count reaches `workNeeded`, it becomes done.
4. Done processes hold no locks in the next state.
5. Non-done processes keep their holds in this v2 core.

This is enough to model wake-up: a waiter wakes only if an external holder becomes
done and releases a lock. A closed wait set has no runnable member, so no member
can become done, so no internal lock is released.

Define:

```lean
canConvert s p := runnable s p ∧ s.convertCost ≤ (s.procs p).stock
convertedAfter s p := if canConvert s p then p.converted + 1 else p.converted
doneAfter s p := p.done ∨ convertedAfter s p ≥ p.workNeeded
holdsAfter s p l := if doneAfter s p then false else s.holds p l
step s := ...
```

No flow injection is required in this v2 module. Flow/accounting already lives in
the plan kernel. This module is about wait-graph causality and detection.

---

## 4. Theorems

### W1 — Closed wait component has no runnable member

```lean
theorem closedWaitSet_not_runnable
    (hC : closedWaitSet s C) (hp : C p) :
    ¬ runnable s p
```

Reason: `hC hp` gives a holder `q` in the component with `blockedOn s p q`.

### W2 — Closed wait component is preserved by step

```lean
theorem closedWaitSet_step
    (hC : closedWaitSet s C) :
    closedWaitSet (step s) C
```

Reason: by W1, no `p ∈ C` is runnable, so no `p ∈ C` converts or becomes done.
Therefore every internal holder in `C` keeps its lock, so every internal wait edge
continues to exist.

### W3 — L3 with content

```lean
theorem L3_waitComponent_absorbing
    (hC : closedWaitSet s C) (nonempty : ∃ p, C p) :
    (∀ p, C p -> ¬ runnable (step s) p)
      ∧ totalConvertedIn C (step s) = totalConvertedIn C s
```

This is the contentful replacement for the plan model's frozen-field L3: the
component stays blocked because all wake paths route through the component.

### W4 — Detection soundness

```lean
def floored s C := ∀ p, C p -> s.procs p.budget = 0

theorem detection_sound
    (hC : closedWaitSet s C) (hf : floored s C) (nonempty : ∃ p, C p) :
    genuineDeadlock s C
```

where `genuineDeadlock s C` states:

- `C` is nonempty;
- every `p ∈ C` is not done;
- every `p ∈ C` is blocked on a holder in `C`; and
- no member of `C` is runnable.

Budget floor alone is not enough. The theorem intentionally requires the closed
wait component; this is the no-false-positive condition.

---

## 5. Acceptance

1. `lake build` succeeds.
2. No `sorry` or `admit` in `IsoConserve/`.
3. New module is imported by `IsoConserve.lean`.
4. README maps the v2 theorem names to the Paper 01 / Paper 04 claims.
5. FINDINGS notes any remaining abstraction gap, especially that this v2 model
   proves wait-graph causality but still delegates Q accounting to the plan
   kernel.

---

## 6. Out of scope

- Effective-rate recursion.
- Conservation accounting for flow/conversion. Use the existing plan kernel.
- Victim selection or resolution policy.
- Proving every arbitrary wait graph has a cycle. This task proves soundness once
  a closed wait component is supplied.
