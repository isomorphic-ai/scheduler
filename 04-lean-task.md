# 04 — Lean 4 Formalization Task: The Conservation Law

**Series:** Isomorphic Scheduler · Paper 04 companion
**For:** a Claude Code agent (or human) formalizing the conservation law in Lean 4
**Reference artifact:** `iso_conserve.py` @ commit `cac7350` (the numerical verifier)
**Goal:** discharge laws L1–L4 as machine-checked theorems in Lean 4 (mathlib),
upgrading the paper's `(shown)` numerical evidence to `(proven)`.

> **TruthSeed (task):** `iso-sched-04-lean:Q-conserved-proven`
> The four laws — conservation, monotonicity, fixed-point/absorption, and
> stock = integral of flow — are stated precisely enough to be theorems. L1
> (conservation) is the keystone: prove it as an invariant preserved by every
> transition, and L2–L4 follow from it plus the structure of the step relation.

---

## 0. Why this task exists

The Python verifier (`iso_conserve.py`) checks L1–L4 numerically on toy models to
machine precision. That is strong evidence, not proof: it tests specific runs, not
all runs. A proof assistant closes the gap — it shows the laws hold for *every*
reachable state, not just the ones we simulated. The laws were written to be
dischargeable; this task is to discharge them.

Keep the formalization **faithful to the Python transition system**, not to an
idealized continuous model. The discrete step relation in `iso_conserve.py` is the
object of study. (A continuous-time version is separate further work; see §6.)

---

## 1. The state and the transition system

Model the system as a finite-state transition system over rationals (use `ℚ`, not
`ℝ` — all quantities in the toy are exact rational arithmetic, and `ℚ` keeps proofs
decidable and avoids real-analysis overhead).

### State

```
structure Proc where
  rate            : ℚ        -- base flow rate (≥ 0)
  workNeeded      : ℕ
  holds           : Finset Lock
  wants           : Option Lock
  stock           : ℚ        -- held stock of Q (≥ 0)
  credit          : ℚ        -- banked stock (≥ 0)
  converted       : ℕ
  done            : Bool
  netFlowIntegral : ℚ        -- ledger for L4

structure Sys where
  procs        : List Proc        -- (or Finset / Fin n → Proc)
  locks        : Lock → Option (Fin n)   -- holder of each lock, if any
  reservoir    : ℚ                -- unallocated Q (≥ 0)
  convertCost  : ℚ                -- κ, the Q cost to convert one unit (> 0)
  totalQ       : ℚ                -- fixed total, set at init
```

### The step relation

Translate `Conserved.step` faithfully. One `step` does, in order:

1. **Compute `at_table`**: processes that are `¬done` and whose `wants` is `none`
   or whose wanted lock is held by *itself* (i.e. not blocked on another).
2. **Flow injection**: a quantum `q = min(reservoir, |at_table|)` of Q is moved
   from `reservoir` into the stocks of at-table processes, split by *effective
   rate* (own rate + transitive inflow from processes blocked on them — the flow
   equation). Each recipient's `stock` and `netFlowIntegral` increase; `reservoir`
   decreases by the same total. **Net change to totalQ accounting: zero.**
3. **Conversion**: each at-table process with `stock ≥ convertCost` converts —
   `stock -= convertCost`, `converted += 1`, `netFlowIntegral -= convertCost`,
   and `done := (converted ≥ workNeeded)`, releasing its locks if done.

Define `step : Sys → Sys` (deterministic) matching this exactly. Define
`reachable : Sys → Prop` as the reflexive-transitive closure of `step` from a
well-formed initial state (see §2).

### Effective rate (the flow equation)

```
eff(p) = p.rate + Σ { eff(w) | w blocked on p }    -- transitive, over the wait-DAG
```

For the proofs you may need the wait relation to be acyclic on `at_table`
(a cycle is a deadlock, handled by L3). State `eff` with a termination argument on
the (finite) wait-DAG, or bound the recursion by list length with a visited set,
mirroring the Python `seen` guard. **Gotcha:** `eff` is only used to *split* the
injection quantum; it does not itself move Q. The conservation proof (L1) does not
depend on the *values* of `eff`, only on the fact that the split sums back to the
quantum. Prove that sub-lemma first (the shares sum to `q`), then L1 is clean.

---

## 2. Well-formedness invariant

Define `WF : Sys → Prop` capturing the non-negativity and accounting facts that
must hold initially and be preserved:

```
WF s :=
  s.convertCost > 0
  ∧ s.reservoir ≥ 0
  ∧ (∀ p ∈ s.procs, p.stock ≥ 0 ∧ p.credit ≥ 0 ∧ p.rate ≥ 0)
  ∧ accounted s = s.totalQ          -- the L1 quantity, see below
```

where

```
accounted s :=
  s.reservoir
  + (Σ p ∈ s.procs, p.stock + p.credit)
  + s.convertCost * (Σ p ∈ s.procs, (p.converted : ℚ))
```

**Prove `WF` is an invariant:** `theorem wf_step : WF s → WF (step s)`. This is the
workhorse; L1 is its `accounted` conjunct.

---

## 3. The four theorems to prove

### L1 — Conservation (the keystone)

```
theorem L1_conservation (s : Sys) (h : WF s) :
    accounted (step s) = accounted s
```

**Strategy.** Split `accounted` into the three transfers of one step and show each
is balanced:
- *Injection*: `reservoir` decreases by `q`; the Σ of stocks increases by `q`
  (because the per-process shares sum to `q` — prove `Σ share = q` as a lemma,
  using that the shares are `q * eff(p) / Σ eff`, a partition of unity). Net 0.
- *Conversion*: each conversion moves `convertCost` from a `stock` into
  `convertCost * converted`. Net 0.
- Releasing locks and `done` flags do not touch any Q-bearing field. Net 0.

This proof is pure bookkeeping over finite sums; `Finset.sum` lemmas and
`ring`/`linarith` should close it once the share-sum lemma is in hand.

### L2 — Monotonicity (no progress ⇒ convertible stock non-increasing)

Define a *no-progress step* as one where `Σ converted` is unchanged, and
`convertibleStock s := Σ { p.stock | p ∈ atTable s }`.

```
theorem L2_monotone (s : Sys) (h : WF s)
    (noProgress : totalConverted (step s) = totalConverted s) :
    convertibleStock (step s) ≤ convertibleStock s
```

**Strategy.** No progress means no at-table process had `stock ≥ convertCost` to
convert (else it would have converted, raising `converted`). Key sub-case: when a
set is fully blocked, `at_table` is empty, injection quantum routes to no one (or
to processes that cannot convert), and convertible stock cannot rise because the
only inflow is to runnable processes. The Python drain scenario adds an explicit
per-step drain of blocked stock back to the reservoir; **model that drain in the
step relation for the blocked regime** (it is part of detection — budget drains on
block) so the monotone is strict toward the floor. State carefully whether the
drain is part of `step` or a separate `stepBlocked`; match the Python.

### L3 — Fixed point / absorption (deadlock is absorbing)

Define `deadlocked s := atTable s = ∅ ∧ ¬ allDone s`.

```
theorem L3_absorbing (s : Sys) (h : WF s) (hd : deadlocked s) :
    deadlocked (step s) ∧ totalConverted (step s) = totalConverted s
```

**Strategy.** If `atTable s = ∅`, no process converts (conversion only happens for
at-table processes), so `converted` is unchanged and no lock is released, so the
`wants`/`holds` graph is unchanged, so `atTable (step s) = ∅` still. The state's
Q-relevant structure is fixed: a fixed point, absorbing. Induct to get "never
resumes": `reachable s s' → deadlocked s → deadlocked s' ∧ no progress`.

### L4 — Stock = integral of flow (the unification)

```
theorem L4_stock_is_integral (s : Sys) (h : WF s) (p : Proc) (hp : p ∈ s.procs) :
    p.stock + p.credit = p.netFlowIntegral
```

**Strategy.** This is an invariant maintained *by construction*: every operation
that changes `stock` or `credit` changes `netFlowIntegral` by the same amount
(injection: both +inj; conversion: both −convertCost; yield/bank: stock→credit is
internal, integral unchanged). Prove `theorem l4_step : (∀ p, stock+credit =
netFlowIntegral) → (∀ p, after step, stock+credit = netFlowIntegral)` and that the
initial state satisfies it. **Gotcha:** make sure the yield/credit-banking
operation (from the resolution paper, if you include it) moves stock into credit
*without* touching netFlowIntegral — the integral is over net *external* flow, and
an internal stock→credit move is not external. Document this clearly in the model.

---

## 4. Build / deliverable layout

```
iso-conserve-lean/
  lakefile.lean              -- depends on mathlib4
  IsoConserve/
    Basic.lean               -- Proc, Sys, step, atTable, eff, accounted, WF
    ShareSum.lean            -- lemma: injection shares sum to the quantum
    L1Conservation.lean      -- wf_step, L1_conservation
    L2Monotone.lean
    L3Absorbing.lean
    L4Integral.lean
    Reachable.lean           -- reflexive-transitive closure, "never resumes"
  README.md                  -- how to build; mapping each theorem to the paper's law
```

Pin the mathlib version. Provide `lake build` instructions in the README.

---

## 5. Acceptance criteria

1. `lake build` succeeds with **no `sorry`** anywhere in the four law files and
   `wf_step`. (Grep for `sorry` and `admit` must be empty in `IsoConserve/`.)
2. Each of L1–L4 is stated as above (names may differ; statements must be
   equivalent) and proven from `WF` / the step relation.
3. `wf_step` (well-formedness preserved) is proven; non-negativity of stock,
   credit, reservoir is maintained.
4. The README maps each Lean theorem to its paper law (L1↔conservation, etc.) and
   notes any place the Lean model deviates from `iso_conserve.py`, with
   justification.
5. A short `FINDINGS.md`: did formalization surface any gap, hidden assumption, or
   needed extra hypothesis the Python verifier missed? (This is the scientific
   payload — the proof's job is to find what the simulation hid.)

---

## 6. Explicitly out of scope (further work, do NOT attempt here)

- Continuous-time limit (`S(t) = ∫₀ᵗ (flow − conversion) ds`). Stay discrete.
- Min-cut / max-flow correspondence of the deadlock set.
- Open systems with sources/sinks (process spawning, killing) beyond progress.
- Heterogeneous `convertCost` (position-dependent κ). Keep κ a single constant.
- Proving the *scheduling* (Paper 03) or *resolution* (Paper 02) behaviours
  themselves — this task is ONLY the conservation laws L1–L4. The other papers'
  behavioural claims are separate formalization tasks.

---

## 7. Notes and gotchas (read before starting)

- **Use `ℚ`, not `ℝ`.** All toy arithmetic is exact rational; `ℝ` buys nothing and
  costs decidability and analysis imports.
- **L1 does not need `eff`'s values, only the share-sum.** Prove `Σ share = q`
  early; then L1 is independent of the flow-equation details. This decoupling is
  the single most important structural choice — do not entangle L1 with `eff`.
- **Match the Python step ordering exactly** (inject, then convert). A different
  order changes intermediate states and may break the no-progress characterization
  in L2.
- **The drain in the blocked regime** (L2's strict descent) is real and must be in
  the model or L2 is only `≤`, not `<`-toward-floor. Decide and document.
- **netFlowIntegral is external flow only.** Internal stock↔credit moves must not
  change it (L4 gotcha above).
- Keep `Proc` equality by identity / index, not structural (mirrors the Python
  `eq=False`); use `Fin n` indices into a vector to avoid duplicate-process
  aliasing issues in the sums.

When L1 and L4 are done, the paper's central identity — *budget is the integral of
flow, conserved* — is machine-checked, and that is the win that matters most.
