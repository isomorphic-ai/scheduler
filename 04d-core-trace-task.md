# 04d — Lean 4 Formalization Task: Unified Core and Trace Semantics

**Series:** Isomorphic Scheduler · combined paper / Paper 04 companion
**Depends on:** `iso-conserve-lean`, `DELTA-AUDIT.md`, `paper08-expanded.md`,
`GPT-5.6-pro-feedback--lean.md`, and Review #6 in `REVIEW-by-fable.md`
**Goal:** build the next core beside the existing modules: one state that is both a
conserved ledger and a dependency graph, with explicit trace/event semantics and a
trace-derived stock/flow integral. Existing proofs are substrate; this task lifts
them into the paper's actual ontology.

> **TruthSeed (task):** `iso-sched-04d-core-trace`
> The current Lean tree proves many readings in separate small models. The combined
> paper's primitive object is one conserved dependency system. This task creates that
> object and re-expresses L1-L4 over one event/trace semantics, separating ordinary
> execution from route-or-release cure steps.

---

## 0. Non-Negotiable Boundaries

Do **not** perturb `monotone_under_adversary`'s statement. It is intentionally
relation-generic and is imported by both the scheduler and caching tracks.

Do **not** rewrite or delete the existing modules in this task. Add the new core
beside them, tentatively:

```text
iso-conserve-lean/IsoConserve/CoreTrace.lean
```

When a theorem already exists in the old surface, rederive or alias it from the new
surface only after the new theorem is proved. See `DELTA-AUDIT.md` before creating a
new name.

Do **not** code WP3/WP4/WP5/WP6 against the old split state. Those task files depend
on this task's state and event vocabulary.

---

## 1. Paper Claims This Task Targets

From `paper08-expanded.md` §4:

> Each node `p` holds a stock `S_p ≥ 0` of Q; the system holds an unallocated
> reserve `R`; converted progress `W_p` counts units of work done, each costing
> `κ > 0` of Q.

> Q enters a node as a **flow** at the node's rate; Q leaves a node only by
> **conversion** (turning `κ` of stock into one unit of work) or by **movement** to
> another node (routing along an edge, or banking across a yield).

> The three readings are calculus: the flow is `dQ/dt`, the stock is `∫` of net
> flow, and banked stock is that integral carried across a discontinuity.

From §4.4:

> **L1 (conservation).** At every step, `R + Σ_p S_p + κ·Σ_p W_p` is invariant.
> Flow moves Q from the reserve to a stock; conversion moves `κ` from a stock to
> converted work; routing and yielding move Q between stocks. No operation creates
> or destroys Q.

> **L2 (monotonicity).** In any interval with no progress, convertible stock is
> monotone non-increasing — the signal detection reads.

> **L3 (absorbing fixed point).** A deadlock is the absorbing state in which flow
> can convert to progress nowhere; once entered it is never left.

> **L4 (stock = integral of flow).** Each node's held stock equals the running
> integral of its net flow, exactly. Rate is the derivative of this stock; credit is
> this integral banked across a yield.

From the Pro feedback, §2.1, refining L3:

> A deadlock is absorbing under ordinary execution. It can be left only by the
> theory's cure: route the claim or release it.

This refinement is required so cure steps do not falsify the ordinary-execution
absorption theorem.

---

## 2. State

Use finite process and lock identities, as in `WaitGraph` and `BudgetWait`.

The state must be both ledger and dependency graph:

```lean
abbrev ProcId (n : Nat) := Fin n
abbrev LockId (m : Nat) := Fin m

structure CoreProc (m : Nat) where
  baseRate : Qty
  stock : Qty
  credit : Qty
  converted : Nat
  workNeeded : Nat
  wants : Option (LockId m)
  done : Bool

structure CoreState (n m : Nat) where
  procs : ProcId n -> CoreProc m
  holds : ProcId n -> LockId m -> Bool
  reserve : Qty
  convertCost : Qty
  totalQ : Qty
```

Definitions required on the state:

```lean
accounted
heldBy
blockedOn
blocked
canConvert
runnable
unfinished
closedDependencySet
strandedClaim
```

The important semantic choice from the Pro feedback: `DependencyConnected` or
`DependsOnWhole` must express dependency return, not ordinary undirected graph
adjacency. Nodes independent of the dependency whole are outside Theorem 1 later;
do not bake a too-weak graph predicate into this core task.

---

## 3. Well-Formed State As A Type

Create a wrapper so well-formedness is part of the transition surface:

```lean
structure CoreWF (s : CoreState n m) : Prop where
  cost_pos : 0 < s.convertCost
  reserve_nonneg : 0 <= s.reserve
  stock_nonneg : forall p, 0 <= (s.procs p).stock
  credit_nonneg : forall p, 0 <= (s.procs p).credit
  rate_nonneg : forall p, 0 <= (s.procs p).baseRate
  accounted_eq_total : accounted s = s.totalQ

structure WFState (n m : Nat) where
  state : CoreState n m
  wf : CoreWF state
```

Transitions may either return `WFState n m` directly, or return a state together
with a preservation theorem that immediately constructs `WFState`. The public step
relation should quantify over well-formed states, not arbitrary raw states.

---

## 4. Event And Trace Semantics

Define an explicit event layer. The exact constructors may change during coding, but
the split is required:

```lean
inductive ExecEvent
  | flow
  | convert
  | acquire
  | releaseNormally

inductive CureEvent
  | route
  | drain
  | yield
  | releaseClaim

inductive StepEvent
  | exec : ExecEvent -> StepEvent
  | cure : CureEvent -> StepEvent
```

Define:

```lean
def netFlow (e : StepEvent) (p : ProcId n) : Qty := ...
def Trace := List StepEvent
def flowIntegral (trace : Trace) (p : ProcId n) : Qty :=
  trace.foldl (fun acc e => acc + netFlow e p) 0
```

If a cached per-process integral field is introduced for executability, prove it is
equal to `flowIntegral`. The trace is the evidence; the field is a cache.

Required trace lemmas:

```lean
flowIntegral_nil
flowIntegral_snoc
integral_discrete_derivative
yield_preserves_integral
```

---

## 5. Operational Relations

Define ordinary execution and cure as separate relations:

```lean
def ExecRel (s t : WFState n m) : Prop := ...
def CureRel (s t : WFState n m) : Prop := ...
def CoreRel (s t : WFState n m) : Prop := ExecRel s t \/ CureRel s t
```

`ExecRel` is for the system's ordinary dynamics. `CureRel` is route-or-release:
the mechanism that can intentionally break a deadlock while preserving Q.

Every operation must prove:

```lean
accounted t.state = accounted s.state
t.state.totalQ = s.state.totalQ
```

Then lift to `RTC CoreRel`.

---

## 6. Required Theorems

### C1 — L1 over the unified relation

```lean
theorem core_step_conserves_accounted :
  CoreRel s t -> accounted t.state = accounted s.state

theorem core_reachable_conserves_accounted :
  RTC CoreRel s t -> accounted t.state = accounted s.state
```

### C2 — L2 in the repaired form

Retain the corrected readings:

```lean
theorem no_progress_convertible_stock_monotone :
  RTC NoProgressRel s t -> convertibleStock t.state <= convertibleStock s.state

theorem blocked_stock_monotone :
  blocked s.state p -> RTC CoreRel s t ->
    (t.state.procs p).stock <= (s.state.procs p).stock

theorem flow_leaves_blocked_stock_unchanged :
  blocked s.state p -> ExecFlowRel s t ->
    (t.state.procs p).stock = (s.state.procs p).stock
```

Also restate the old false reading as a checked counterexample in the new semantics:

```lean
theorem unrestricted_l2_is_false : ...
```

This should reuse the canonical sub-threshold witness if possible.

### C3 — L3 with ordinary execution vs cure

```lean
theorem deadlock_exec_fixed :
  Deadlocked s.state -> RTC ExecRel s t -> t.state = s.state

theorem closed_wait_set_exec_absorbing :
  ClosedDependencySet s.state C -> RTC ExecRel s t ->
    ClosedDependencySet t.state C

theorem closed_wait_set_converted_total_fixed :
  ClosedDependencySet s.state C -> RTC ExecRel s t ->
    totalConvertedIn C t.state = totalConvertedIn C s.state

theorem cure_preserves_accounted :
  CureRel s t -> accounted t.state = accounted s.state

theorem cure_can_break_absorption :
  exists s t C, ClosedDependencySet s.state C /\ CureRel s t /\
    not (ClosedDependencySet t.state C)
```

The last theorem may be a concrete witness. It is important because it prevents the
wrong reading "deadlock can never be intentionally resolved."

### C4 — L4 as trace-derived integral

Primary theorem shape:

```lean
theorem stock_credit_eq_initial_add_integral :
  Run initial trace final ->
    (final.state.procs p).stock + (final.state.procs p).credit =
      (initial.state.procs p).stock + (initial.state.procs p).credit +
        flowIntegral trace p
```

With zero initial stock and credit, derive the paper-facing corollary:

```lean
theorem L4_stock_is_trace_integral : ...
```

If a cached integral is used:

```lean
theorem cached_integral_eq_trace_integral : ...
```

---

## 7. Lifting Existing Theorems

At minimum, expose compatibility theorem names that show old modules are instances
or predecessors of the new core:

```lean
old_L1_conservation_lifts
old_blocked_stock_monotone_lifts
old_budget_wait_detection_lifts
old_yield_conservation_lifts
```

These may initially be documentation theorems or exact aliases if the state
translation is straightforward. Do not duplicate old proofs under new names without
connecting them to the old surface.

---

## 8. README/FINDINGS Requirements

Update `README.md` with:

- the new core module and relation names;
- a sentence that `ExecRel` is ordinary execution and `CureRel` is the
  route-or-release mechanism;
- the trace-derived L4 theorem name;
- any remaining gap where the old and new surfaces are not yet connected.

Update `FINDINGS.md` if the prover forces a spec correction, especially around:

- `done` semantics;
- dependency-return definitions;
- trace-derived integral signs;
- the old unrestricted L2 counterexample.

---

## 9. Acceptance Criteria

1. `lake build` succeeds.
2. `rg -n "sorry|admit|axiom" IsoConserve IsoConserve.lean lakefile.lean`
   returns no matches.
3. New module is imported by `IsoConserve.lean`.
4. Public relation names include `ExecRel`, `CureRel`, and `CoreRel`.
5. L1-L4 are stated over the unified core surface.
6. L3 distinguishes ordinary execution absorption from cure-step escape.
7. L4's public theorem uses `flowIntegral` derived from a trace, not only a cached
   state field.
8. README and FINDINGS describe all remaining abstraction gaps.
9. Commit the task file before any implementation commit.
