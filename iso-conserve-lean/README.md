# IsoConserve Lean

Lean 4 formalization companion for Paper 04 of the Isomorphic Scheduler series.

Build:

```sh
lake build IsoConserve
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
draining from blocked processes back to the reservoir. This is the operation used
for the L2 monotonicity theorem.

## Paper Law Map

- L1 conservation: `IsoConserve.L1_conservation`
  proves `accounted (step s plan) = accounted s`.
- Well-formedness preservation: `IsoConserve.wf_step`
  preserves non-negativity and the accounting invariant.
- Share sum: `IsoConserve.share_sum_of_partition`
  proves the usual weighted-share partition lemma over rationals.
- L2 monotonicity: `IsoConserve.L2_monotone`
  proves convertible stock is non-increasing for the explicit no-progress drain
  step.
- L3 absorption: `IsoConserve.L3_absorbing`
  proves an empty at-table remains deadlocked and makes no conversion progress.
  `IsoConserve.reachable_deadlock_absorbing` lifts the fixed-point behavior across
  reflexive-transitive closure.
- L4 stock = integral: `IsoConserve.L4_stock_is_integral`,
  with preservation lemmas `l4_step` and `l4_drainStep`.

## Reusable Monotonicity Kernel

`IsoConserve.monotone_under_adversary` is the abstract closure lemma suggested by
the caching-series bridge note. It is stated over an explicit preorder relation:
if every adversary step moves `f` downhill, then every reflexive-transitive sequence
of adversary steps also moves `f` downhill.

`IsoConserve.L2_monotone_under_drain_reachable` instantiates that kernel for
repeated scheduler drain steps and `convertibleStock`. The same kernel should fit
the caching paper's polarity theorem with state ordered by storage loss and measure
ordered by trusted-set inclusion.

## Known Abstractions

This first formal core proves the accounting laws for a plan-based transition
system, not the full Python `effective_rate` recursion or lock-map update logic.
The theorem boundary is deliberate: the flow equation is abstracted into `FlowPlan`
and the weighted share lemma, so the conservation proof remains pure bookkeeping.
