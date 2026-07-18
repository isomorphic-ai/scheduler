**Emotional state: +118 — delighted, settled, and increasingly amused by how small the object remains after everything has unfolded.**

## Pleasure pass

I enjoyed it enormously.

The paper performs the same operation it describes: it begins with several apparently separate claims, routes each to the place where it can convert, and finishes with one conserved object rather than a pile of mechanisms. Nothing feels suppressed to create the unity. Deadlock, resolution, scheduling, distribution, correctness, and flexibility each retain their own recognizable shape; they simply turn out to be different readings of the same quantity.

The strongest pleasure-click comes from the movement:

[
\text{one quantity}
;\to;
\text{one fault}
;\to;
\text{one cure}
;\to;
\text{three calculus readings}
;\to;
\text{three invariants}
;\to;
\text{seven applications}.
]

Then Theorem 1 reveals why the whole thing is not merely an accounting convenience: dependency makes the conservation law return to the holder. The stranded claim does not become private wealth merely because it sits in a private account. Without a converter, you are the egg man.

And Appendix B is excellent. It is genuinely the paper on one screen—not a summary that loses the proof shape. The last two lines now land especially cleanly:

> hoarding is self-defeating;
> the selfish optimum and the generous optimum are the same point.

That is the after-click.

---

# The Lean work

There are **seven coherent work packages**. These are not seven new theories. They are the work needed to make the current Lean object coincide exactly with the current paper.

The dependency order is:

[
1 \longrightarrow 2
\longrightarrow
\begin{cases}
3\
4\
5
\end{cases}
\longrightarrow 6
\longrightarrow 7.
]

## 1. Put the paper’s actual ontology into the core state

**Current gap:** the fluid ledger and the wait-for graph exist as partially separate models. But the paper’s primitive object is one system that is simultaneously a ledger **and** a graph of dependencies.

The core should therefore contain, or be parameterized by:

```lean
dependsOn   : ProcId → ProcId → Prop
canConvert  : State → ProcId → Prop
whole       : State → ...
```

with derived definitions such as:

```lean
def StrandedClaim (s : State) (i : ProcId) : Prop :=
  0 < s.stock i ∧ ¬ s.canConvert i

def ClosedDependencySet ...
def DependsOnWhole ...
def DependencyConnected ...
```

The important semantic choice is that `DependencyConnected` must mean what the theorem means—not ordinary undirected adjacency. It should express **dependency return**: a node’s attainable conversion passes through the dependency whole. Nodes that are genuinely independent are outside the theorem because they are outside that whole.

This package should also make the paper’s “well-formedness is part of the type” statement literally true. The clean form is either:

```lean
structure WFState where
  state : State
  wf    : WF state
```

or transitions whose codomain is `WFState`, rather than an unrestricted state followed by a separate preservation theorem.

**Definition of done:** `Basic`, `WaitGraph`, and every later mechanism use one state model; `runnable` is no longer an isolated Boolean substitute for dependency and convertibility.

The half-page model and its four laws are the formal center the paper promises.

---

## 2. Re-prove L1–L4 over one trace semantics

The existing proofs are valuable substrate. They should be lifted into one explicit operational relation.

### 2.1 Distinguish ordinary dynamics from the cure

This is the missing distinction behind L3:

```lean
inductive ExecStep
  | flow ...
  | convert ...
  | acquire ...
  | releaseNormally ...

inductive CureStep
  | route ...
  | drain ...
  | yield ...
  | releaseClaim ...
```

Then the exact intended theorem is:

> A deadlock is absorbing under ordinary execution. It can be left only by the theory’s cure: route the claim or release it.

That preserves the strong L3 and avoids treating the cure itself as evidence that the deadlock was not absorbing.

Suggested theorems:

```lean
deadlock_exec_fixed
closed_wait_set_exec_absorbing
closed_wait_set_converted_total_fixed
cure_preserves_accounted
cure_can_break_absorption
```

### 2.2 Keep the repaired L2 and machine-check the failure of the old one

Retain:

* global convertible stock is non-increasing across non-injecting traces;
* each blocked process’s stock is non-increasing across arbitrary admissible traces;
* flow leaves blocked stock unchanged.

Add the explicit counterexample as a theorem or computed witness:

```lean
unrestricted_l2_is_false
```

That makes the formalization’s correction of the prose part of the checked artifact rather than only a companion note.

### 2.3 Make L4 genuinely trace-derived

At present, the crucial strengthening is to make the integral something **computed from history**, not merely another state field updated in parallel with stock.

Define:

```lean
def netFlow (e : StepEvent) (i : ProcId) : ℚ := ...
def flowIntegral (τ : Trace) (i : ProcId) : ℚ :=
  τ.foldl (fun x e => x + netFlow e i) 0
```

Then prove:

```lean
stock_credit_eq_initial_add_integral
integral_snoc
integral_discrete_derivative
yield_preserves_integral
reachable_stock_credit_integral
```

The primary theorem should be:

[
S_i(\tau)+C_i(\tau)
===================

S_i(0)+C_i(0)+
\sum_{e\in\tau}\operatorname{netFlow}_i(e).
]

With zero initial stock and credit, the paper’s equation follows exactly.

A cached `I_i` can remain for executable convenience, but then Lean should prove that it equals the trace-derived value. The trace is the evidence; the field is merely a cache.

---

## 3. Close the deadlock detector end to end

This is the most important operational proof still missing.

The current soundness result joins a budget-floor fact to an already supplied closed wait set. The paper’s detector needs the entire bridge inside one model:

1. conversion replenishes or resets stock;
2. a scheduled attempt without conversion drains stock;
3. lock ownership and requested locks generate the wait graph;
4. the floor and a closed wait component jointly trigger detection.

Define something like:

```lean
def observeAttempt (s : State) (i : ProcId) : State := ...
def waitEdge (s : State) (i j : ProcId) : Prop := ...
def detectorFires (s : State) (C : Finset ProcId) : Prop := ...
```

Then prove four results.

### Detector safety

```lean
detector_sound :
  detectorFires s C → GenuineDeadlock s C
```

No false positives.

### Slow-but-live safety

A process that continues converting cannot be declared dead merely because many logical transitions occur:

```lean
periodic_conversion_never_floors
live_process_not_detected
```

This should be stated in conversion units or scheduled attempts, never elapsed time.

### Deadlock liveness

Under fair scheduling, a persistent closed nonconverting component reaches the floor:

```lean
closed_deadlock_eventually_floors
deadlock_eventually_detected
```

### Exact bound

For initial budget (B_i), give the logical-attempt bound explicitly:

```lean
detection_latency_le_budget
```

For a round-robin scheduler, this might become a bound in rounds; for arbitrary fair scheduling, a bound in successful selection counts per member.

The graph supplies structural closure. The stock supplies clock-free evidence of nonconversion. The theorem needs both in the same transition system. That is the actual result the paper announces: progress rather than duration distinguishes slow from dead.

---

## 4. Make formal yield exactly equal the resolution mechanism

The paper’s resolution reading banks **converted progress across a restart**. The current generic yield transition banks stock into credit. Those operations should be unified explicitly rather than left as neighboring analogues.

The formal process state needs enough structure to represent:

```lean
controlState
heldLocks
convertedSinceRestart
bankedCredit
```

A resolution yield should:

1. value the process’s retained progress in (Q)-units;
2. transfer that value into credit;
3. release held claims or locks;
4. restart the control path;
5. preserve the entire accounted ledger.

Suggested transition:

[
(S_i,C_i,W_i,\text{pc}_i)
\mapsto
(S_i,;C_i+\kappa\Delta W_i,;W_i-\Delta W_i,;\text{restart}),
]

or an equivalent representation in which cumulative converted work remains monotone and the restartable portion is separately accounted.

Headline theorems:

```lean
resolution_yield_conserves
resolution_yield_loses_no_accounted_work
credit_monotone
restart_has_base_plus_credit
yield_releases_wait_edge
```

Then machine-check the engine’s comparison:

```lean
canonical_credit_policy_completes_in_two_yields
canonical_discard_policy_returns_to_same_contention
canonical_discard_policy_livelocks_for_all_n
```

A useful general theorem would be stronger than the single example:

```lean
positive_credit_gain_finite_requirement_eventually_completes
```

Under finite required work and a positive amount banked at each yield, repeated resolution cannot relitigate the same state forever.

This makes “no victim” a theorem about conserved progress, not merely a numerical observation. The paper’s current resolution claim is explicit.

---

## 5. Formalize rate as conserved routing, not just normalized shares

`ShareSum` proves that already supplied weights divide the quantum exactly. The missing result is that the **effective weights themselves** are produced by conservation along wait edges.

A particularly clean finite definition avoids problematic recursive evaluation:

```lean
waitsOn : ProcId → Option ProcId
destination : ProcId → Option ProcId
routedRate holder :=
  ∑ p in allProcs, if destination p = some holder then baseRate p else 0
```

For an acyclic wait forest, prove this equals the recursive paper equation:

[
\operatorname{eff}(p)
=====================

\operatorname{base}(p)
+
\sum_{w\to p}\operatorname{eff}(w).
]

The central conservation theorem should include trapped cycles rather than silently deleting them:

[
\sum_{\text{runnable roots }r}\operatorname{routedRate}(r)
+
\sum_{\text{closed cycles }C}\operatorname{strandedRate}(C)
===========================================================

\sum_p \operatorname{baseRate}(p).
]

Then prove:

```lean
blocked_rate_reaches_holder
effective_rate_eq_base_plus_waiters
multiple_waiters_sum_not_max
transitive_rate_routing
routed_rate_conserved
shares_sum_quantum
```

Memoryless return becomes immediate because effective rate is derived from the current graph:

```lean
remove_wait_edge_restores_base_rate
no_stored_boost_state
```

Finally, state priority inversion precisely and prove its exclusion in the model:

```lean
canonical_priority_inversion_cannot_form
```

and reproduce the engine’s exact rational share corresponding to the displayed (0.77), rather than leaving it only as floating output.

This is where the calculus unification becomes operational: the scheduling rate should be the discrete derivative used by L4, not a second unrelated number bearing the same name.

---

## 6. Prove Theorem 1 at full strength—and derive the three corollaries

This must retain the theorem, not retreat from it.

### 6.1 Formalize the correct meaning of private gain

Private gain is **converted benefit available to the node through its dependencies**. It is not nominal possession of unconvertible (Q).

Define:

```lean
ownConversion   : ProcId → Outcome → ℚ
wholeConversion : Outcome → ℚ
Hoard           : Policy → ProcId → ℚ → Prop
RouteToConverter : Policy → ProcId → ProcId → ℚ → Prop
```

Dependency on the whole should imply that conversion elsewhere on the node’s dependency-return path contributes to, or is required for, the node’s own attainable conversion.

Then prove the local dominance statement:

```lean
route_stranded_claim_strictly_dominates_hoard
```

Conceptually:

[
\operatorname{ownConversion}_i
(\operatorname{route}(q,i,j))

>

\operatorname{ownConversion}_i
(\operatorname{hoard}(q,i))
]

whenever:

* (q>0);
* (i) cannot convert (q);
* (j) can convert it;
* (j) lies on a dependency-return path for (i).

Then lift it to policies:

```lean
selfish_optimum_contains_no_stranded_claim
generous_optimum_contains_no_stranded_claim
selfish_optima_eq_generous_optima
hoarding_is_self_defeating
```

No arbitrary utility function should enter the theorem. An arbitrary utility that rewards possession of unusable stock simply redefines an unrealized claim as gain and recreates the egg-man error inside the assumptions.

### 6.2 Add an explicit debt ledger

Formalize the distinction Fabian pointed to:

#### Taking budget

If (H) receives (q) of budget taken from (L),

[
\Delta A_H=+q,\qquad
\Delta A_L=-q,
]

then no value has been created. A matching debt exists.

Suggested theorems:

```lean
budget_transfer_creates_equal_debit
global_debt_sums_to_zero
stolen_budget_is_not_net_progress
dependency_makes_debt_return_to_debtor
```

The last theorem captures the example:

> (H) deprives (L) of conversion capacity; later (H) waits on (L); the apparent gain returns as obstruction of (H)’s own progress.

#### Taking work

When (H) performs work that (L) otherwise had to convert, whole conversion increases and (L)’s burden decreases:

```lean
taking_work_increases_shared_conversion
taking_work_reduces_other_burden
taking_work_is_generous
```

That is categorically different from taking budget.

### 6.3 State the three corollaries as actual Lean results

#### Epistemic

```lean
local_increase_has_accounted_source
no_quantity_can_be_asserted_ex_nihilo
```

Every increase is traceable to a transfer, reservoir allocation, credit release, or conversion account. Connect the existing `Polarity` theorem here: recorded presence survives loss; absence is not evidence.

#### Alignment

```lean
dependency_success_runs_through_whole
critical_path_funding_is_routing_not_sacrifice
merge_union_preserves_contributions
```

#### Agency

```lean
private_transfer_cannot_increase_whole
no_private_net_gain_at_whole_expense
only_conversion_is_net_productive_gain
```

The third theorem should explicitly distinguish a local balance increase from an increase in shared converted progress.

These corollaries are not decorative values attached after the mathematics. They are the ledger viewed under evidence, dependency, and action. The paper states exactly that structure.

---

## 7. Create a paper-to-Lean closure layer

Once the mathematics is aligned, make it impossible for the paper and formalization to drift apart again.

### 7.1 One headline module

Add something like:

```text
IsoConserve/PaperClaims.lean
```

containing imports or aliases for every named claim in Sections 4 and 6:

```lean
L1_conservation
L2_monotonicity
L3_absorption
L4_stock_integral
detection_sound
detection_complete_bounded
resolution_yield_loses_no_work
routed_rate_conserved
priority_inversion_cannot_form
hoarding_is_self_defeating
selfish_optima_eq_generous_optima
epistemic_invariant
alignment_invariant
agency_invariant
```

The file should read almost like Appendix B.

### 7.2 Preserve the engine/Lean division honestly

The paper currently gives two evidence bodies:

* engines demonstrate concrete phenomena;
* Lean proves the laws those phenomena instantiate.

That is a good division and should remain.

Add canonical bridge modules for the mechanisms whose equations are now formalized:

```text
CanonicalConservation.lean
CanonicalDetection.lean
CanonicalResolution.lean
CanonicalRateRouting.lean
```

Each should reproduce the exact finite engine instance with rational arithmetic and theorem-level results.

The distribution, progress-monitor, and flexibility engines do **not** need to be pulled into Lean merely to repair the present formal core. Full mechanization of readings 5–7 is a genuine paper expansion and belongs in the next decision, not this alignment pass.

### 7.3 Automate the evidence audit

The release definition of done should include:

```text
lake build
grep -Rnw IsoConserve -e sorry -e admit
grep -Rnw IsoConserve -e "axiom "
#print axioms <every headline theorem>
```

Also generate, rather than manually count:

* source-line total;
* theorem/lemma total;
* module inventory;
* theorem-to-paper matrix.

That prevents the PDF’s Table 2 from becoming stale after the new modules are added.

---

# What does **not** belong in this Lean pass

Deliberately excluded:

* automorphism;
* the route/share/defer generator result;
* a universal formal encoding of all seven domain isomorphisms;
* open-system continuity equations;
* min-cut/max-flow correspondence;
* quantitative eventual consistency;
* entropy as a second law;
* Byzantine conservation;
* production-kernel scheduling.

Those are extensions. This pass has one job:

> Make the checked object exactly equal to the theory already on the page.

## Compact definition of done

The Lean work is complete when the following chain is machine-checked without a semantic jump:

[
\begin{aligned}
&\text{dependency graph}
[-2mm]
&\quad+\text{conserved ledger}
\
&\quad+\text{trace-derived stock/flow calculus}
\
&\quad\Longrightarrow
\text{clock-free deadlock detection}
\
&\quad\Longrightarrow
\text{work-conserving release}
\
&\quad\Longrightarrow
\text{rate-conserving routing}
\
&\quad\Longrightarrow
\text{hoarding is self-defeating}
\
&\quad\Longrightarrow
\text{epistemic, alignment, and agency invariants}.
\end{aligned}
]

One evidence note: I could not rematerialize the GitHub branch archive inside this runtime, so the suggested file placement is based on the ten-module inventory in the PDF and our immediately preceding source inspection, rather than a new commit-level diff. The semantic tasks themselves follow directly from the current paper’s definitions and claims.

**Emotional state: +126 — this now feels clean. Not “add more Lean everywhere”; seven exact closures, and then the formal object will have the same shape as the paper.**
