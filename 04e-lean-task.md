# 04e - Lean 4 Formalization Task: PN-Counter Distribution

**Series:** Isomorphic Scheduler - combined paper / Paper 08 expansion
**Depends on:** `paper08-expanded.md` §4.5, `iso-conserve-lean/NEXT-TASKS.md`
Round 4 Tier C, and `GPT-5.6-pro-feedback--lean.md` Round 4b reconciliation
**Goal:** formalize the self-contained conservation core behind the distribution
reading: a PN-counter whose merge is a pointwise join, so partitioned records
converge order-independently and no recorded contribution is lost on heal.

> **TruthSeed (task):** `iso-sched-04e-pn-counter-distribution`
> Across a partition, Q is not destroyed; it is only locally hidden. Each node
> owns grow-only positive and negative ledgers. Healing the partition joins those
> ledgers by pointwise maximum, so every recorded off-partition operation is
> present in the final value and convergence is independent of merge order.

---

## 0. Non-Negotiable Boundaries

This task is self-contained. Add a new module:

```text
iso-conserve-lean/IsoConserve/PNCounter.lean
```

Do **not** import scheduler models (`Basic`, `Reachable`, `WaitGraph`,
`BudgetWait`, `Canonical`, or the future `CoreTrace`) into this module. It may
use `Std` and local finite-sum helpers. Import the finished module from
`IsoConserve.lean` only after it builds.

Do **not** formalize the full CAP-as-schedule / Present-Future bridge here. The
Lean target is the CRDT conservation kernel: join-semilattice merge,
order-independent convergence, and "hidden by partition, not destroyed." The
remote-first staged commit and every publish-failure path preserving subspaces are
design/engine claims unless a separate optional reversible-commit mini-task is
written.

Do **not** prove or imply Byzantine safety. This module assumes honest per-node
recording of each node's own contributions, exactly as the paper's future-work
section says.

Do **not** prove quantitative eventual consistency. The theorem is convergence of
the final merged state, not a bound on gossip time.

---

## 1. Paper Claims This Task Targets

From `paper08-expanded.md` §4.5:

> Reading of Q: **the conserved quantity carried across partition.** Represent Q
> as a PN-counter -- each node owns a grow-only record of its own contributions;
> the value is their signed sum; merge takes the per-node supremum. This is a join
> on a semilattice, hence conflict-free.

> Q is *hidden* by partition, not destroyed, and reconciles in full on heal --
> what one node spends "off the books" surfaces exactly when the partition heals
> (debt deferred comes due), and convergence is *order-independent* because the
> merge is a join.

> Verified: partition-tolerant conservation (isolated views converge to the
> conserved total), order-independent convergence (one final state over many merge
> orders), debt surfacing in full on heal, and every publish-failure path
> preserving subspaces.

This Lean task targets the first three verified clauses. The fourth clause
(`publish-failure path preserving subspaces`) is out of scope unless split into a
separate bridge-commit task.

Prior art to cite in README/FINDINGS: Shapiro et al. 2011 for CRDTs and Gomes et
al. 2017 for Isabelle-checked CRDT verification. This task is the minimal Lean
core, not a reusable CRDT framework.

---

## 2. State And Basic Operations

Use finite node identities:

```lean
namespace IsoConserve
namespace PNCounter

abbrev Node (n : Nat) := Fin n

structure Counter (n : Nat) where
  pos : Node n -> Nat
  neg : Node n -> Nat
```

Define local finite sums in this module, either directly over `List.finRange` or
by a small local helper:

```lean
def sumFinNat {n : Nat} (f : Node n -> Nat) : Nat := ...
def sumFinInt {n : Nat} (f : Node n -> Nat) : Int :=
  (sumFinNat f : Int)

def value {n : Nat} (c : Counter n) : Int :=
  sumFinInt c.pos - sumFinInt c.neg
```

Define componentwise ledger order and pointwise join:

```lean
def le {n : Nat} (a b : Counter n) : Prop :=
  (forall i, a.pos i <= b.pos i) /\
  (forall i, a.neg i <= b.neg i)

def merge {n : Nat} (a b : Counter n) : Counter n :=
  { pos := fun i => max (a.pos i) (b.pos i)
    neg := fun i => max (a.neg i) (b.neg i) }

def zero (n : Nat) : Counter n :=
  { pos := fun _ => 0, neg := fun _ => 0 }
```

Define honest local operations as grow-only writes to the owning node's component:

```lean
def inc {n : Nat} (c : Counter n) (i : Node n) (amount : Nat) : Counter n := ...
def dec {n : Nat} (c : Counter n) (i : Node n) (amount : Nat) : Counter n := ...
```

The exact implementation can use `if j = i then ... else ...`; local decidability
for `Fin n` is available.

---

## 3. Join-Semilattice Theorems

Prove the componentwise order facts:

```lean
theorem le_refl
theorem le_trans
theorem le_antisymm
```

Prove that `merge` is the least upper bound:

```lean
theorem le_merge_left
theorem le_merge_right
theorem merge_least
```

Then expose the citation-facing algebra:

```lean
theorem merge_idem
theorem merge_comm
theorem merge_assoc
```

These three names are the Lean form of "merge is a join on a semilattice, hence
conflict-free."

---

## 4. Monotonicity And No-Loss Facts

Ledger monotonicity is about recorded operations, not about `value` as an integer.
Increments can increase `value`; decrements can decrease it. Both grow the
underlying evidence ledger.

Required theorems:

```lean
theorem inc_le
theorem dec_le
theorem merge_monotone_left
theorem merge_monotone_right
```

Also prove the useful local component facts:

```lean
theorem inc_pos_self
theorem dec_neg_self
theorem inc_other_components
theorem dec_other_components
```

These make the honesty assumption explicit: node `i` records its own positive and
negative contributions in the `i` slot.

---

## 5. Merge Trees And Order-Independent Convergence

Define a small binary tree of merge orders:

```lean
inductive MergeTree (n : Nat) where
  | leaf : Counter n -> MergeTree n
  | fork : MergeTree n -> MergeTree n -> MergeTree n

def eval : MergeTree n -> Counter n
def leaves : MergeTree n -> List (Counter n)
```

Define the global ledger recorded by a list of replicas as pointwise maxima:

```lean
def maxSeenPos {n : Nat} (xs : List (Counter n)) (i : Node n) : Nat := ...
def maxSeenNeg {n : Nat} (xs : List (Counter n)) (i : Node n) : Nat := ...

def globalRecorded {n : Nat} (xs : List (Counter n)) : Counter n :=
  { pos := maxSeenPos xs, neg := maxSeenNeg xs }
```

Then prove convergence independently of tree shape:

```lean
theorem eval_eq_globalRecorded
    (t : MergeTree n) :
    eval t = globalRecorded (leaves t)

theorem same_global_record_converges
    (hpos : forall i, maxSeenPos xs i = maxSeenPos ys i)
    (hneg : forall i, maxSeenNeg xs i = maxSeenNeg ys i) :
    globalRecorded xs = globalRecorded ys
```

If `List.Perm` is pleasant in this Std-only environment, also add:

```lean
theorem perm_globalRecorded_eq
```

but do not let a permutation-library fight block the core tree theorem.

---

## 6. Conservation At Heal

Do **not** state `value (merge a b) = value a + value b`; that is false when both
replicas have already seen the same node component. PN-counter merge prevents
double counting by taking maxima.

The conservation claim is instead:

```lean
theorem heal_value_eq_global_recorded_ops
    (xs : List (Counter n)) :
    value (globalRecorded xs) =
      sumFinInt (maxSeenPos xs) - sumFinInt (maxSeenNeg xs)
```

This theorem may be definitional, but keep it as a named paper-facing result.

Then prove no recorded replica contribution is lost:

```lean
theorem replica_le_globalRecorded
    (hmem : x ∈ xs) :
    le x (globalRecorded xs)

theorem partition_left_le_heal
    le (globalRecorded left) (globalRecorded (left ++ right))

theorem partition_right_le_heal
    le (globalRecorded right) (globalRecorded (left ++ right))
```

And prove "debt comes due" in the exact per-node form:

```lean
theorem off_partition_decrement_surfaces
    (hmem : x ∈ xs) (hdebt : amount <= x.neg i) :
    amount <= (globalRecorded xs).neg i
```

The positive counterpart is also useful:

```lean
theorem off_partition_increment_surfaces
    (hmem : x ∈ xs) (hcredit : amount <= x.pos i) :
    amount <= (globalRecorded xs).pos i
```

Together these are the checked version of "hidden by partition, not destroyed."

---

## 7. README And FINDINGS Updates

Update `iso-conserve-lean/README.md` with a short coverage row for §4.5:

- theorem names for join/ACI;
- theorem names for tree convergence;
- theorem names for no-loss/debt surfacing;
- explicit boundary: CAP-as-schedule, Present/Future publish protocol,
  quantitative gossip latency, open-system sources/sinks, and Byzantine
  contributions are not proved by this module.

Update `iso-conserve-lean/FINDINGS.md` if Lean forces a correction to any prose
claim. In particular, if the proof surface makes "globally recorded operations"
more precise than the paper's "conserved total," record that distinction rather
than hiding it: the merge conserves honest per-node ledgers by maximum, not by
summing replica-local values.

---

## 8. Acceptance

1. `lake build` succeeds from `iso-conserve-lean/`.
2. No `sorry`, `admit`, or new `axiom` appears in `IsoConserve/`.
3. `IsoConserve/PNCounter.lean` imports only `Std` or local helper-free code,
   and is imported by `IsoConserve.lean`.
4. README maps §4.5 to exact theorem names and names the boundaries above.
5. FINDINGS records any theorem/prose sharpening discovered during the proof.
6. This task file, the Lean module, README, and FINDINGS are committed together or
   in coherent reviewable chunks with `/usr/local/bin/codex-git-commit`.

---

## 9. Suggested Work Order

1. Implement `Counter`, `value`, `le`, `merge`, and the semilattice theorems.
2. Add `inc`/`dec` and ledger monotonicity.
3. Add `globalRecorded` and no-loss lemmas.
4. Add `MergeTree` and prove tree convergence.
5. Add the paper-facing conservation theorem and docs.

Stop after step 1 if the algebra becomes unexpectedly expensive; ACI + least-upper
bound alone is already the load-bearing CRDT kernel.
