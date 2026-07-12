# IsoConserve Lean

Lean 4 formalization companion for Paper 04 of the Isomorphic Scheduler series.

Build:

```sh
lake build
```

The package is pinned to Lean `v4.30.0` and intentionally uses only Lean/Std so it
can build offline in this workspace.

## Model

The model uses a finite indexed process set, `Fin n -> Proc`, to avoid structural
process aliasing. A `FlowPlan` supplies the already-computed per-process injection
shares and conversion amounts for one step. This matches the conservation proof
strategy in `04-lean-task.md`: L1 depends on the fact that shares sum back to the
injected quantum, not on the details of the effective-rate recursion.

For the blocked/no-progress detector regime, a separate `DrainPlan` models stock
draining from blocked processes back to the reservoir. `DrainPlan.drain_blocked`
requires runnable processes to drain zero.

`RatePlan` is an optional refinement of `FlowPlan` whose shares are explicitly the
weighted partition `quantum * weight / totalWeight`; `ratePlan_share_sum` wires that
refinement to `share_sum_of_partition`. Plain `FlowPlan`s remain deliberately
unconstrained so L1/L4 apply to any accounting-balanced allocation.

## Paper Law Map

- L1 conservation: `IsoConserve.L1_conservation`
  proves `accounted (step s plan) = accounted s`.
- Well-formedness preservation: `IsoConserve.wf_step`
  preserves non-negativity and the accounting invariant.
- Share sum: `IsoConserve.share_sum_of_partition`
  proves the usual weighted-share partition lemma over rationals.
- L2 monotonicity: `IsoConserve.L2_monotone`
  proves convertible stock is non-increasing for the explicit no-progress drain
  step. `IsoConserve.blocked_stock_monotone` proves the stronger detector lemma:
  a process that starts blocked has non-increasing stock across any mixed sequence
  of flow and drain steps.
- L3 absorption: `IsoConserve.L3_absorbing`
  proves an empty at-table remains deadlocked and makes no conversion progress.
  `IsoConserve.reachable_deadlock_absorbing` lifts the fixed-point behavior across
  reflexive-transitive closure.
- L4 stock = integral: `IsoConserve.L4_stock_is_integral`,
  with preservation lemmas `l4_step` and `l4_drainStep`.
- Reachable invariants: `IsoConserve.wf_reachable` and `IsoConserve.l4_reachable`
  lift WF and L4 over mixed flow/drain reachability.

## Reusable Monotonicity Kernel

`IsoConserve.monotone_under_adversary` is the abstract closure lemma suggested by
the caching-series bridge note. It is stated over an explicit preorder relation:
if every adversary step moves `f` downhill, then every reflexive-transitive sequence
of adversary steps also moves `f` downhill.

`IsoConserve.L2_monotone_under_drain_reachable` instantiates that kernel for
repeated scheduler drain steps and `convertibleStock`. The same kernel should fit
the caching paper's polarity theorem with state ordered by storage loss and measure
ordered by trusted-set inclusion.

`IsoConserve.blocked_stock_monotone_restricted` is the scheduler-side blocked-stock
instance using the same generic kernel.

## What The Plan Abstraction Covers

The abstraction proves L1/L4 for a superset of the Python transition's accounting
behaviors: any plan whose reservoir and stock postconditions are well-formed, not
only the deterministic effective-rate split. This is useful for the keystone laws
because it isolates the bookkeeping from the scheduler mechanics.

The canonical weighted split is represented by `RatePlan`, but ordinary `FlowPlan`
does not require its shares to come from effective rates. Conversion is also
plan-supplied rather than forced maximal as in Python's `while stock >= cost` loop.
The quantum rule `min(reservoir, |at_table|)` is abstracted to
`reservoir_after_nonneg`.

## Deliberate Deviations From `iso_conserve.py`

This first formal core proves the accounting laws for a plan-based transition
system, not the full Python lock/wait dynamics.

- No lock table, `wants`, or `holds`.
- `runnable` is an explicit frozen field, not recomputed from locks.
- `done` is frozen; no step marks a process done, releases locks, or wakes waiters.
- `FlowPlan` conversion is optional rather than Python's forced-maximal conversion.
- The effective-rate recursion is not formalized; `RatePlan` covers the weighted
  partition once weights are supplied.
- Credit is accounted and preserved by L4, but stock-to-credit yield/banking is not
  modeled in this pass.

The L3 theorem is faithful to Python's empty-table branch, which is a no-op. In this
model the `done` component is frozen everywhere, so the `not allDone` preservation is
true for a model-wide reason rather than because lock-release dynamics were analyzed.
