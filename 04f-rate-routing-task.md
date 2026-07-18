# 04f - Lean 4 Formalization Task: Conserved Rate Routing

**Series:** Isomorphic Scheduler - combined paper / Paper 08 §4.3
**Depends on:** `04d-core-trace-task.md`, `paper08-expanded.md` §4.3,
`iso-conserve-lean/NEXT-TASKS.md` Round 4b WP5, and
`GPT-5.6-pro-feedback--lean.md` §5
**Goal:** prove that effective scheduling rates are conserved flow routed along the
current wait graph, not supplied weights or cached priority boosts.

> **TruthSeed (task):** `iso-sched-04f-rate-routing`
> A blocked process's urgency is Q as a derivative: it flows along the wait-edge
> into the holder that can release it. The holder receives the sum of all routed
> waiter rates, closed cycles retain stranded rate on the ledger, and when the
> wait-edge disappears there is no boost to unwind.

---

## 0. Non-Negotiable Boundaries

Do **not** start this implementation until `04d-core-trace-task.md` has been
reviewed and the core state/event vocabulary has landed. This task is drafted now
so the target is explicit; its Lean module should be built against the new core,
not against the old split `Basic`/`WaitGraph` surface.

Tentative module path after the core lands:

```text
iso-conserve-lean/IsoConserve/RateRouting.lean
```

or, if `04d` creates a `Core/` folder:

```text
iso-conserve-lean/IsoConserve/Core/RateRouting.lean
```

Do **not** perturb `monotone_under_adversary`.

Do **not** reintroduce a stateful "boost" field. Effective rate is a derived
observable of the current graph. The memoryless-return theorem depends on this.

Do **not** silently discard deadlocked cycles to make routing acyclic. The central
conservation theorem must account for rate trapped in cycles as stranded rate.

Do **not** claim CFS/EEVDF production-kernel results. This module proves the finite
rate-routing mathematics and a canonical rational example; kernel integration
remains engineering work.

---

## 1. Paper Claims This Task Targets

From `paper08-expanded.md` §4.3:

> Reading of Q: **flow**. Priority is a rate -- a stream filling each process's
> bucket -- not a stored claim. At each instant the available capacity is divided
> among the runnable processes in proportion to their *effective* rates, where a
> blocked process's rate flows down its wait-edge into the holder it is blocked on:

> `eff(p) = base(p) + Σ eff(w)` over every process `w` currently blocked on `p`,
> transitively along the chain of wait-edges.

> The cure is to *route* that urgency -- the flow -- into the holder the task
> depends on, exactly the node whose progress will release it.

> The instant the lock releases, the wait-edge vanishes, the flow reverts, and the
> high task resumes at full rate -- memoryless, with no boost to restore.

> Result: priority inheritance falls out as a structural consequence of
> conservation rather than as a protocol; the bottleneck is funded in exact
> proportion to the urgency waiting on it; inversion cannot form.

> The divergence from classical inheritance is the *sum* (the holder catches the
> total of its waiters' rates, not the maximum), which is what conservation
> requires.

From the Pro feedback §5:

> The missing result is that the **effective weights themselves** are produced by
> conservation along wait edges.

> The central conservation theorem should include trapped cycles rather than
> silently deleting them.

---

## 2. Inputs From The Unified Core

This module should import the `04d` core and use its finite process identity:

```lean
abbrev ProcId (n : Nat) := Fin n
```

Use these core observables, whether as definitions imported from the core or as
thin aliases in this module:

```lean
baseRate  : CoreState n m -> ProcId n -> Qty
blockedOn : CoreState n m -> ProcId n -> ProcId n -> Prop
runnable  : CoreState n m -> ProcId n -> Prop
unfinished : CoreState n m -> ProcId n -> Prop
```

The rate-routing layer may use a simpler single-successor view when the lock model
has unique holders:

```lean
def waitsOn (s : CoreState n m) (p : ProcId n) : Option (ProcId n) := ...
```

If multiple holders are possible, either prove this task for a `UniqueHolder`
well-formed subcase, or generalize `waitsOn` to a finite predecessor relation. Do
not fake uniqueness if the core state does not provide it.

---

## 3. Destination, Routed Rate, And Stranded Rate

The Pro feedback's key design is to define routing as a destination sum first, not
as unconstrained recursion:

```lean
def destination (s : CoreState n m) (fuel : Nat)
    (p : ProcId n) : Option (ProcId n) := ...
```

Intended behavior:

- if `p` is runnable, `destination s fuel p = some p`;
- if `p` is blocked on `q`, destination follows `q`;
- if the search exhausts `fuel`, destination returns `none`;
- use `fuel = n` (or a proved sufficient bound) for public definitions.

Then define the final destination and final root share:

```lean
def routesTo (s : CoreState n m) (p r : ProcId n) : Prop :=
  destination s n p = some r

def trapped (s : CoreState n m) (p : ProcId n) : Prop :=
  destination s n p = none

def routedRate (s : CoreState n m) (r : ProcId n) : Qty :=
  sumFin (fun p => if destination s n p = some r then baseRate s p else 0)

def strandedRate (s : CoreState n m) : Qty :=
  sumFin (fun p => if trapped s p then baseRate s p else 0)
```

This representation handles both ordinary roots and cycles: acyclic wait chains
end at `some r`; cycles or over-fuel paths become `none` and remain accounted as
stranded rate.

Also define the intermediate accumulation relation used by the paper's recursive
equation:

```lean
def reaches (s : CoreState n m) (from to : ProcId n) : Prop := ...

def effectiveRate (s : CoreState n m) (p : ProcId n) : Qty :=
  sumFin (fun w => if reaches s w p then baseRate s w else 0)
```

`effectiveRate s p` is the rate accumulated at node `p` before it is forwarded
again. `routedRate s r` is the final rate delivered to runnable root `r`. For a
runnable root, they should coincide:

```lean
theorem routedRate_eq_effectiveRate_of_runnable
    (hr : runnable s r) :
    routedRate s r = effectiveRate s r
```

If the proof is cleaner with an explicit certificate instead of executable
`destination`, use:

```lean
structure RoutingCertificate (s : CoreState n m) where
  destination : ProcId n -> Option (ProcId n)
  destination_correct : ...
```

but the public theorem names should still be about `routedRate` and
`strandedRate`, not about the certificate.

---

## 4. Conservation Of Rate

Required theorem:

```lean
theorem routed_rate_conserved
    (s : CoreState n m) :
    sumFin (fun r =>
      if runnable s r then routedRate s r else 0) + strandedRate s =
    sumFin (fun p => baseRate s p)
```

This is the finite KCL theorem for priority flow: urgency is routed or stranded,
never created or destroyed.

Useful supporting lemmas:

```lean
theorem routedRate_nonneg
theorem strandedRate_nonneg
theorem base_rate_goes_to_destination
theorem trapped_rate_goes_to_stranded
```

Do not require the whole graph to be acyclic for conservation. A cycle is exactly
where the rate is stranded, so the theorem must still balance.

---

## 5. Acyclic Equation Equals The Paper's Recursive Formula

On a no-cycle component, prove that the destination-sum definition agrees with the
paper equation:

```lean
def immediateWaiter (s : CoreState n m) (w p : ProcId n) : Prop :=
  waitsOn s w = some p

def acyclicFrom (s : CoreState n m) (p : ProcId n) : Prop := ...
```

Required theorem:

```lean
theorem effective_rate_eq_base_plus_waiters
    (hacyclic : acyclicFrom s p) :
    effectiveRate s p =
      baseRate s p +
      sumFin (fun w =>
        if immediateWaiter s w p then effectiveRate s w else 0)
```

If the exact theorem needs a subtree-specific helper in addition to
`effectiveRate`, add it, then make `effective_rate_eq_base_plus_waiters` the
paper-facing corollary.

Also prove transitive routing:

```lean
theorem transitive_rate_routing
    (hpath : waitsTransitivelyOn s w p)
    (hdest : destination s n p = some r) :
    destination s n w = some r
```

---

## 6. Sum-Not-Max And Inheritance Corollaries

The divergence from classical priority inheritance must be explicit:

```lean
theorem blocked_rate_reaches_holder
    (hwait : waitsOn s w = some h)
    (hbase_nonneg : 0 <= baseRate s w) :
    baseRate s w <= effectiveRate s h

theorem blocked_rate_reaches_root
    (hwait : waitsOn s w = some h)
    (hdest : destination s n h = some r)
    (hbase_nonneg : 0 <= baseRate s w) :
    baseRate s w <= routedRate s r

theorem multiple_waiters_sum_not_max
    (hw1 : waitsOn s w1 = some h)
    (hw2 : waitsOn s w2 = some h)
    (hne : w1 != w2)
    (h1 : 0 <= baseRate s w1)
    (h2 : 0 <= baseRate s w2) :
    baseRate s w1 + baseRate s w2 <= effectiveRate s h
```

If useful, strengthen the second theorem to equality under a closed three-process
scenario with no other routed contributors.

Then state inversion exclusion at the share level:

```lean
def share (s : CoreState n m) (quantum : Qty) (p : ProcId n) : Qty :=
  quantum * routedRate s p /
    sumFin (fun r => if runnable s r then routedRate s r else 0)

theorem canonical_priority_inversion_cannot_form :
  ...
```

The theorem should capture the Mars-Pathfinder shape:

- `high` waits on `low`;
- `low` and `medium` are runnable;
- `baseRate high > baseRate medium`;
- `baseRate medium > baseRate low`;
- `low` receives at least as much share as `medium` once `high` is waiting on
  `low`.

For the canonical numbers from `iso_flow.py`, prove the exact rational shares:

```lean
theorem pathfinder_low_share_eq_ten_thirteenths :
    share pathfinderState 1 low = (10 : Qty) / 13

theorem pathfinder_medium_share_eq_three_thirteenths :
    share pathfinderState 1 medium = (3 : Qty) / 13

theorem pathfinder_low_share_gt_medium :
    share pathfinderState 1 low > share pathfinderState 1 medium
```

These are the Lean form of the paper's displayed "0.77 vs 0.23" engine result.

---

## 7. Memoryless Return

Because effective rate is derived from `blockedOn`/`waitsOn`, removing a wait-edge
must immediately remove the routed contribution:

```lean
def removeWaitEdge (s : CoreState n m) (w h : ProcId n) : CoreState n m := ...
```

Required theorems:

```lean
theorem remove_wait_edge_restores_base_rate
    (honly : noOtherWaiters s h)
    (hwait : waitsOn s w = some h) :
    routedRate (removeWaitEdge s w h) h = baseRate s h

theorem no_stored_boost_state
    (hgraph_eq : sameWaitGraph s t)
    (hrate_eq : forall p, baseRate s p = baseRate t p) :
    forall p, routedRate s p = routedRate t p
```

The second theorem is the stronger statement: rate has no history. If the graph and
base rates match, effective rates match.

---

## 8. Wire To Shares And The Canonical Step

After `RateRouting` is proved, connect it to the existing share machinery lifted
into the unified core:

```lean
theorem shares_sum_quantum
    (hpos : 0 < sumFin (fun r =>
      if runnable s r then routedRate s r else 0)) :
    sumFin (fun r => if runnable s r then share s quantum r else 0) = quantum
```

Then instantiate the canonical Python-style plan with `routedRate` rather than
supplied effective weights:

```lean
theorem routedRatePlan_is_FlowPlan
theorem canonical_step_uses_derived_routed_rates
```

The existing `Canonical` module already proves "supplied weights imply verified
step." This task closes the remaining gap: the supplied weights are computed from
the current wait graph by conservation.

---

## 9. README And FINDINGS Updates

Update `iso-conserve-lean/README.md` with a §4.3 coverage row:

- `routed_rate_conserved`;
- `effective_rate_eq_base_plus_waiters`;
- `multiple_waiters_sum_not_max`;
- `canonical_priority_inversion_cannot_form`;
- the exact `10/13` and `3/13` share theorems;
- `no_stored_boost_state`.

Document boundaries:

- finite model, not production CFS/EEVDF integration;
- unique-holder or relation-general assumption, whichever the proof uses;
- cycles are accounted as stranded rate, not evaluated by recursive effective
  rate;
- canonical bridge to Python depends on the unified core from `04d`.

Update `FINDINGS.md` if Lean forces a sharper statement. The likely sharpening is
that the recursive equation is only meaningful on acyclic components; the global
law is the destination/stranded conservation theorem.

---

## 10. Acceptance

1. The task file is reviewed before code starts.
2. `lake build` succeeds after implementation.
3. No `sorry`, `admit`, or new `axiom` appears in `IsoConserve/`.
4. The new module imports the unified core and is imported by `IsoConserve.lean`.
5. README and FINDINGS name theorem-level coverage and boundaries.
6. The canonical `10/13` vs `3/13` example is a theorem over rationals, not a
   floating-point check.

---

## 11. Suggested Work Order

1. Implement `destination`, `routedRate`, and `strandedRate`.
2. Prove `routed_rate_conserved`; this is the keystone.
3. Prove the acyclic recursive-equation corollary.
4. Prove sum-not-max, inheritance, and memoryless return.
5. Add the canonical three-process rational example.
6. Wire routed rates into the canonical share plan.

If step 3 fights, keep step 2 and the canonical example. Conservation plus
sum-not-max already proves the paper's main routing claim; the recursive equation
can be tightened in a follow-up.
