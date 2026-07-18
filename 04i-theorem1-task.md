# 04i - Lean 4 Formalization Task: Theorem 1 And Dependency Return

**Series:** Isomorphic Scheduler - combined paper / Paper 08 §3 and §4.4
**Depends on:** `04d-core-trace-task.md`, `04f-rate-routing-task.md`,
`04h-resolution-yield-task.md`, `paper08-expanded.md` §§3/4.4,
`iso-conserve-lean/NEXT-TASKS.md` Round 4b WP6, and
`GPT-5.6-pro-feedback--lean.md` §6
**Goal:** prove the paper's central theorem at the definition level: a stranded
claim held where it cannot convert is worse for its holder than routing it to a
converter on its dependency-return path. Then derive the debt-ledger and invariant
corollaries without adding horizon, closedness, or arbitrary-utility assumptions.

> **TruthSeed (task):** `iso-sched-04i-theorem1-dependency-return`
> The payoff is own attainable conversion, not nominal possession. If a node keeps
> Q it cannot convert, and its own progress runs through a node that can convert
> that Q, hoarding reduces its own attainable conversion. Routing is both selfishly
> and globally optimal because the dependency graph returns the conservation law to
> the holder.

---

## 0. Non-Negotiable Boundaries

Do **not** implement this before the unified core from `04d` and the routing/yield
vocabulary from `04f`/`04h` have been reviewed. This theorem is about the paper's
whole object, not the old plan-abstracted kernel alone.

Do **not** introduce a horizon bound, endgame exception, external-source condition,
or extra closedness hypothesis. The closed law is L1, already part of the object.
The payoff is `ownConversion`, so hoarded unconvertible possession is not gain.

Do **not** use an arbitrary utility function. A utility that rewards possession of
unusable stock redefines a stranded claim as benefit and recreates the error the
theorem rules out.

Do **not** define dependency as ordinary undirected adjacency. The structural
hypothesis is dependency-return: the holder's attainable conversion runs through the
converter or the dependency whole containing it.

If a proof seems to require one of the forbidden assumptions, stop and repair the
definitions rather than adding the assumption.

---

## 1. Paper Claims This Task Targets

From `paper08-expanded.md` §3:

> **Theorem (hoarding is self-defeating).** In a connected dependency graph, a node
> that hoards the conserved quantity -- that holds a claim it cannot itself convert
> rather than routing or releasing it -- starves the nodes it depends on, which hold
> the resources it needs, and therefore deadlocks *itself*. Consequently the selfish
> optimum and the generous optimum coincide: routing Q to where it converts is at
> once the best move for the whole and the best move for the part.

From §4.4:

> Because Q moved from one part to another is conserved -- one part's decrease is
> exactly another's increase -- a part's success runs through the whole's.

> Because conservation forbids the private creation of Q, no action can produce a
> private gain at the whole's expense: every gain is a transfer, and the only net
> loss from held stock is conversion to progress, which advances the whole.

From the Pro feedback §6:

> Private gain is **converted benefit available to the node through its
> dependencies**. It is not nominal possession of unconvertible Q.

---

## 2. Definitions

Define outcomes and policies over the unified core:

```lean
structure Outcome (n m : Nat) where
  state : CoreState n m

inductive Action (n m : Nat) where
  | hoard : ProcId n -> Qty -> Action n m
  | route : ProcId n -> ProcId n -> Qty -> Action n m
  | release : ProcId n -> Qty -> Action n m

def applyAction : CoreState n m -> Action n m -> Outcome n m := ...
```

Define private gain as attainable converted work:

```lean
def ownConversion
    (i : ProcId n) (o : Outcome n m) : Qty := ...

def wholeConversion (o : Outcome n m) : Qty := ...
```

This definition is the core of the theorem. It must count conversion that is
available to `i` through its dependency-return path. It must not count inert stock
that `i` cannot convert.

Define stranded claims:

```lean
def HoldsClaim (s : CoreState n m) (i : ProcId n) (q : Qty) : Prop := ...
def CanConvertQty (s : CoreState n m) (i : ProcId n) (q : Qty) : Prop := ...

def StrandedClaim (s : CoreState n m) (i : ProcId n) (q : Qty) : Prop :=
  0 < q /\ HoldsClaim s i q /\ not (CanConvertQty s i q)
```

Define dependency-return, not mere connectivity:

```lean
def DependencyReturn
    (s : CoreState n m) (i j : ProcId n) : Prop := ...

def DependsOnWhole
    (s : CoreState n m) (i : ProcId n) : Prop := ...
```

`DependencyReturn s i j` should mean that conversion at `j`, or in the dependency
whole containing `j`, contributes to or is required for `i`'s own attainable
conversion.

---

## 3. Local Dominance Theorem

The first theorem is local and strict:

```lean
theorem route_stranded_claim_strictly_dominates_hoard
    (hq : 0 < q)
    (hstranded : StrandedClaim s i q)
    (hcan : CanConvertQty s j q)
    (hreturn : DependencyReturn s i j) :
    ownConversion i (applyAction s (Action.route i j q)) >
      ownConversion i (applyAction s (Action.hoard i q))
```

This is the formal egg-man correction: if `i` cannot convert the claim, possession
is not private gain. Routing to a converter on the dependency-return path improves
`i`'s own attainable conversion.

Also prove the non-strict release alternative if it falls out naturally:

```lean
theorem release_weakly_dominates_hoard_for_stranded_claim
```

Do not weaken the route theorem to `>=` unless the definitions prove that strictness
is impossible; if that happens, record the reason in `FINDINGS.md`.

---

## 4. Policy-Level Lift

After the local theorem, define optimality over policies without arbitrary utility:

```lean
structure Policy (n m : Nat) where
  act : CoreState n m -> Action n m

def SelfishOptimal (P : Policy n m) (i : ProcId n) (s : CoreState n m) : Prop :=
  forall P', ownConversion i (applyPolicy P s) >=
    ownConversion i (applyPolicy P' s)

def GenerousOptimal (P : Policy n m) (s : CoreState n m) : Prop :=
  forall P', wholeConversion (applyPolicy P s) >=
    wholeConversion (applyPolicy P' s)
```

Required theorems:

```lean
theorem selfish_optimum_contains_no_stranded_claim
theorem generous_optimum_contains_no_stranded_claim
theorem selfish_optima_eq_generous_optima
theorem hoarding_is_self_defeating
```

If full policy optimality is too broad, first prove the finite action-set version:
for a given stranded claim, the action set `{hoard, route, release}` has no
selfish optimum at `hoard`, and `route` is optimal for both `ownConversion i` and
`wholeConversion`.

---

## 5. Debt Ledger

Formalize the distinction between taking budget and taking work.

Suggested state:

```lean
structure DebtLedger (n : Nat) where
  asset : ProcId n -> Qty
  debt : ProcId n -> ProcId n -> Qty

def netPosition (d : DebtLedger n) (i : ProcId n) : Qty := ...
def globalNetDebt (d : DebtLedger n) : Qty := ...
```

Taking budget creates an equal debit:

```lean
theorem budget_transfer_creates_equal_debit
theorem global_debt_sums_to_zero
theorem stolen_budget_is_not_net_progress
theorem dependency_makes_debt_return_to_debtor
```

Taking work is different because whole conversion increases:

```lean
theorem taking_work_increases_shared_conversion
theorem taking_work_reduces_other_burden
theorem taking_work_is_generous
```

The debt-return theorem should use `DependencyReturn`. If `H` deprives `L` of
conversion capacity and later depends on `L`, the apparent gain returns as reduced
own conversion for `H`.

---

## 6. Corollaries As Theorem Names

Some weaker versions already exist in `IsoConserve.PaperInvariants`; this task
should either strengthen them over the unified core or provide paper-facing aliases
only after the stronger definitions exist.

### Epistemic

```lean
theorem local_increase_has_accounted_source
theorem no_quantity_can_be_asserted_ex_nihilo
theorem recorded_presence_survives_loss
theorem absence_is_not_evidence
```

The last two should connect to `Polarity.lean`: positive recorded evidence survives
loss; trust-on-absence has the known counterexample shape.

### Alignment

```lean
theorem dependency_success_runs_through_whole
theorem critical_path_funding_is_routing_not_sacrifice
theorem merge_union_preserves_contributions
```

Use `RateRouting` for critical-path funding and `PNCounter` for merge preservation
after those modules land.

### Agency

```lean
theorem private_transfer_cannot_increase_whole
theorem no_private_net_gain_at_whole_expense
theorem only_conversion_is_net_productive_gain
```

The third theorem must distinguish local balance increase from shared converted
progress. A transfer can improve a node's local position; only conversion increases
whole progress.

---

## 7. README And FINDINGS Updates

Update `iso-conserve-lean/README.md` with §3/§4.4 theorem coverage:

- `route_stranded_claim_strictly_dominates_hoard`;
- `selfish_optimum_contains_no_stranded_claim`;
- `generous_optimum_contains_no_stranded_claim`;
- `selfish_optima_eq_generous_optima`;
- `hoarding_is_self_defeating`;
- debt-ledger theorem names;
- strengthened epistemic/alignment/agency theorem names.

Document boundaries:

- payoff is `ownConversion`, not possession;
- dependency-return is the structural hypothesis;
- no horizon or closedness side condition;
- no arbitrary utility function;
- policy optimality may first be finite-action-set optimality if the general policy
  quantifier is too broad.

Update `FINDINGS.md` if Lean forces a sharpening. Likely candidates:

- strict route dominance depends on how `ownConversion` credits dependency-return;
- debt return is not the same theorem as budget transfer conservation;
- existing invariant corollaries were ledger-level shadows of the stronger theorem.

---

## 8. Acceptance

1. The task file is reviewed before code starts.
2. `lake build` succeeds after implementation.
3. No `sorry`, `admit`, or new `axiom` appears in `IsoConserve/`.
4. The theorem module imports the unified core and whichever of `RateRouting`,
   `PNCounter`, and `Polarity` are needed for corollaries.
5. README and FINDINGS cite exact theorem names and boundaries.
6. No theorem adds horizon, closedness, or arbitrary-utility assumptions to Theorem
   1.

---

## 9. Suggested Work Order

1. Define `ownConversion`, `StrandedClaim`, and `DependencyReturn`.
2. Prove `route_stranded_claim_strictly_dominates_hoard`.
3. Add finite action-set optimality before general policies.
4. Add the debt ledger distinction.
5. Strengthen/alias the three invariant corollary families.
6. Update README/FINDINGS.

Stop after step 1 if `ownConversion` cannot be made precise without extra
hypotheses. That is the theorem's load-bearing definition, not a detail.
