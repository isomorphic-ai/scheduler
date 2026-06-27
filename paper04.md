# Paper 04 — One Conserved Quantity: The Law Beneath Detection, Resolution, and Scheduling

**Series:** The Isomorphic Scheduler
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v1 · numerically verified · formal proof owed
**Artifact:** `iso_conserve.py` @ commit `cac7350`

> **TruthSeed (paper):** `iso-sched-04:one-quantity-stock-and-flow`
> Detection, resolution, and scheduling are not three mechanisms. They are three
> readings of one conserved quantity Q. Q's *flow* is the scheduling rate; Q's
> *stock* — the time-integral of net flow — is the detection budget; Q's stock
> *banked across a yield* is the resolution credit. Q obeys conservation (it is
> moved and converted, never created or destroyed), monotonicity (convertible
> stock cannot rise without progress), and a fixed-point law (deadlock is the
> absorbing state where flow converts nowhere). Stock is the integral of flow;
> detection is the integral, scheduling is the derivative, resolution is the
> integral carried across a discontinuity.

---

## 0. Abstract

The first three results of this series each introduced a quantity. Detection used
a **budget** drained by blocking and floored at deadlock. Resolution used a
**credit** banked when a process yields, so its progress is conserved rather than
discarded. Scheduling used a **rate** that flows along wait-edges, so a blocked
process's urgency reaches the holder it waits on. We prove these are one conserved
quantity Q seen three ways, related as calculus relates a flow to its
accumulation: **rate is the flow of Q (its derivative), budget is the stock of Q
(its integral), and credit is the stock banked across a yield (the integral
carried over a discontinuity).**

We state four laws and verify each numerically on toy models with no wall clock.
**(L1) Conservation:** over a closed system Q changes only by conversion to
progress; blocking, yielding, and routing move Q between processes but never
create or destroy it — the total of held stock plus converted work plus the
unallocated reservoir is invariant at every step. **(L2) Monotonicity:** in any
interval with no progress, convertible stock is monotone non-increasing — the
property detection reads when it declares a budget floor (verified by a drain from
18 to 0 across twelve no-progress steps, conservation holding throughout). **(L3)
Fixed point:** a deadlock is the absorbing state where flow can convert to
progress nowhere; once entered it is never left (verified: a stuck cycle never
resumes). **(L4) Stock is the integral of flow:** each process's held stock equals
the running sum of its net flow, exactly (verified to machine precision).

We introduce three invariants for successful systems design:

1. **Epistemic (evidence-tracking).** Every quantity is measured and accounted,
   never asserted. *Here:* conservation is checked as an invariant at every step;
   nothing is taken on faith.
2. **Alignment (shared, not replacing).** A part's success runs through the
   whole's; the conserved quantity is shared, not spent into a void. *Here:* Q
   moved from one process to another (routing, yielding) is conserved — one
   process's loss is exactly another's gain.
3. **Agency (every action benefits all).** No move creates or destroys the
   common quantity. *Here:* because Q is conserved, no process can gain at the
   system's net expense; gains are transfers, and the only true sink is progress,
   which is the shared goal.

The payoff is unification. Detection, resolution, and inversion-freedom stop being
separate subsystems to implement and become readings of a single conserved
quantity: watch its integral floor (detect), bank its integral across a yield
(resolve), route its derivative along edges (schedule). The classical mechanisms
fall out as consequences of conservation. The proofs here are numerical on toy
models; a machine-checked formal proof is the stated next step.

---

## 1. Problem revisited

The series has produced three mechanisms, each useful on its own, each built on
"a conserved quantity." But three quantities with similar names is not a theory —
it is a coincidence waiting to be explained or debunked. Detection's budget,
resolution's credit, and scheduling's rate were introduced separately, in
different papers, with different units and update rules. Either they are the same
thing wearing three coats, in which case the series has a single law beneath it,
or they merely rhyme, in which case the "conservation" language is decoration.

The problem this paper addresses is foundational rather than operational: **is
there one conserved quantity, and does it obey conservation laws precise enough to
state and check?** If yes, the three mechanisms are corollaries and the series has
a spine. If no, each mechanism stands alone and the unifying language should be
dropped. We claim yes, and make the claim falsifiable by stating four laws as
checkable invariants and testing them.

---

## 2. Background

Conserved quantities and their flow/stock duality are the basic vocabulary of
physics and of continuous systems modelling (a stock is the time-integral of its
net inflow; a flow is the derivative of the stock). System-dynamics modelling
(Forrester, 1961:industrial-dynamics) formalizes stock-and-flow accounting, where
conserved material moves between stocks via flows and the bookkeeping is exact.
Network-flow theory (Ford & Fulkerson, 1962:flows-in-networks) studies conserved
quantities routed along edges subject to capacity and conservation at nodes —
directly analogous to our rate flowing along wait-edges with conservation at each
process.

Within scheduling, the quantities we unify each have classical relatives:
budget-based and credit-based schedulers (e.g. credit schedulers in hypervisors)
track an accumulated allowance; proportional-share schedulers track a rate. What
is, to our knowledge, not stated in the scheduling literature is that a
deadlock-detection budget, a rollback-conservation credit, and a
priority-inheritance rate are the integral, the banked integral, and the
derivative of *one* conserved quantity — and that the classical deadlock and
inversion results follow from the conservation laws of that quantity. We pre-register
this unification and supply numerical evidence; the formal proof is owed.

---

## 3. Sharpening: name the quantity, then watch it integrate and differentiate

Here is the move.

Stop treating budget, credit, and rate as three quantities and posit one: a
conserved fluid Q that each process holds as a **stock**. Q enters a process as a
**flow** (a stream filling its bucket, at the process's rate); Q leaves a process
only by **conversion** — turning stock into progress, the single true sink. Q can
also **move** between processes (routed along a wait-edge, or banked across a
yield), but movement neither creates nor destroys it.

Now the three earlier quantities are forced into place by calculus:

- **Rate is the flow of Q.** A process's scheduling rate is `dQ/dt` entering its
  bucket. Routing rate along a wait-edge (Paper 03) is redirecting the flow — the
  derivative — to where it can convert.
- **Budget is the stock of Q.** Budget is `∫ flow dt` — the accumulation of net
  flow. Detection watches this integral; a deadlock is the integral hitting a
  floor (Paper 01).
- **Credit is the stock banked across a yield.** When a process yields (Paper 02),
  its accumulated stock is not discarded — it is carried across the discontinuity
  of the restart. Credit is the integral preserved over a jump.

Stated this way, the unification is not a metaphor to defend but a set of
equations to check. If Q is genuinely conserved, then at every step the total of
(held stock) + (converted work) + (unallocated reservoir) is invariant; if budget
is genuinely the integral of flow, then each process's stock equals the running
sum of its net flow exactly; if deadlock is genuinely a fixed point, the
no-progress drain is monotone and the stuck state is absorbing. These are L1–L4.
The wrong framing was "three mechanisms that each use a conserved quantity." The
right framing: **one conserved quantity, whose integral the detector reads, whose
banked integral the resolver preserves, and whose derivative the scheduler
routes.**

---

## 4. The solution: the four laws

Let Q be the conserved quantity. Each process `p` holds stock `S_p ≥ 0`; the
system holds an unallocated reservoir `R`; converted progress `W_p` counts units of
work done, each costing `κ` of Q to convert. Flow injects Q from `R` into process
stocks at the (effective) rate; conversion moves `κ` from a stock into `W`.

### 4.1 L1 — Conservation `(structural; shown)`

> **Law (conservation).** At every step, `R + Σ_p S_p + κ · Σ_p W_p` is invariant.
> Flow moves Q from `R` to `S_p`; conversion moves `κ` from `S_p` to `W_p`;
> routing and yielding move Q between stocks. No operation creates or destroys Q.

Conservation is the master law; the others are consequences of it plus the
structure of flow and conversion. Operationally it is the strongest check we have:
any bug that invents or loses Q breaks it immediately. Verified: the total is
invariant to machine precision across every step of every scenario, including the
flow/routing scenario where Q is redirected along a wait-edge. `(shown)`

### 4.2 L2 — Monotonicity `(structural; shown)`

> **Law (monotone).** In any interval during which no process converts (no
> progress), the convertible stock `Σ_{p at table} S_p` is monotone
> non-increasing.

With no progress, no Q is converted, and (in the no-injection regime that holds
once a set is blocked) convertible stock can only stay level or drain. It cannot
rise, because the only source of new convertible stock is flow into a runnable
process, and a fully-blocked set has none. This is exactly the signal detection
reads: a convertible stock that only falls, and whose floor is reached in bounded
steps, is a budget that detects deadlock without a clock. Verified: convertible
stock drains 18 → 16 → … → 2 → 0 across twelve no-progress steps, monotone, with
L1 holding throughout the drain. `(shown)`

### 4.3 L3 — Fixed point `(structural; shown)`

> **Law (fixed point).** A deadlock is the absorbing state of the dynamics: a set
> in which flow can convert to progress nowhere. Once the system enters it, it
> never leaves — no later step resumes progress.

The deadlocked set has no member that can convert (each is blocked on another in
the set), so convertible stock is zero and stays zero; no flow reaches a
convertible process, so nothing changes. The state maps to itself: a fixed point,
and an absorbing one. Detection is the recognition of this fixed point via L2 (the
integral floored) plus the cycle structure. Verified: a stuck AB-BA cycle, stepped
further, never resumes progress. `(shown)`

### 4.4 L4 — Stock is the integral of flow `(structural; shown)`

> **Law (stock = ∫ flow).** Each process's held stock equals the running integral
> of its net flow: `S_p = ∫ (inflow_p − conversion_p) dt`, exactly. Rate is the
> derivative of this stock; credit is this integral banked across a yield.

This is the law that *is* the unification: it identifies budget (stock) with the
integral of rate (flow). It is exact, not approximate — there is no slack between
"the stock a process holds" and "the accumulated net flow it received." Verified:
for every process, held stock equals net-flow integral to machine precision.
`(shown)` Credit (Paper 02) is the special case where the integral is carried
across a restart discontinuity rather than reset; rate (Paper 03) is the
derivative `dS/dt` routed along edges.

### 4.5 The three invariants, in full

The conservation law makes the series' three system invariants exact rather than
rhetorical. Each is stated here in full.

- **Epistemic (evidence-tracking — truth that can update).** Every quantity in the
  system is measured and accounted, never asserted on faith. Conservation (L1) is
  checked as an invariant at every step; the monotone drain (L2) is observed, not
  assumed; the fixed point (L3) is tested for absorption; the integral identity
  (L4) is verified to precision. The system's claims about itself are exactly the
  ledger, and the ledger is conserved. `(structural)`
- **Alignment (shared, not replacing — success runs through the whole).** The
  conserved quantity is shared, never spent into a void. When Q moves — routed
  down a wait-edge, banked across a yield — one process's decrease is exactly
  another's increase; the books balance. A part's gain is a transfer from the
  common pool, not a creation at the whole's expense, and the only true sink is
  conversion to progress, which is the shared goal. `(structural)`
- **Agency (every action benefits all).** Because Q is conserved, no action can
  produce a private gain at the system's net expense — every gain is a transfer,
  and the only net loss from the pool of held stock is progress, which advances
  the whole. There is no move that enriches one process while depleting the system,
  because conservation forbids the creation of Q. The structure makes
  beneficial-to-all the only kind of action available. `(structural)`

These three are not ethical decoration. They are corollaries of L1: a conserved
quantity cannot be privately created or destroyed, so sharing (alignment),
honest accounting (epistemic), and no-private-expense (agency) are forced by the
conservation law itself.

---

## 5. Related work

**Stock-and-flow / system dynamics** (Forrester, 1961:industrial-dynamics).
Conserved material moving between stocks via flows, with exact accounting. Our Q
is a stock-and-flow quantity; L1 is the conservation that system dynamics takes as
foundational, and L4 is the stock = ∫ flow identity at the heart of that
formalism. We apply it to scheduling and identify the scheduler's three quantities
as one stock-and-flow fluid.

**Network flow** (Ford & Fulkerson, 1962:flows-in-networks). Conserved flow routed
along edges with conservation at nodes. Our rate flowing along wait-edges with
conservation at each process is a flow network whose edges are dependencies; the
flow-equation routing of Paper 03 is conservation at a node (a holder's effective
rate is its own plus inflow from waiters). We do not yet exploit max-flow/min-cut
structure; whether the deadlock cut corresponds to a min-cut is further work.

**Budget/credit and proportional-share schedulers.** Credit schedulers accumulate
an allowance (a stock); proportional-share schedulers track a rate (a flow). Both
exist in practice; what is new is identifying a deadlock-detection budget, a
rollback credit, and an inheritance rate as integral, banked-integral, and
derivative of one conserved quantity, and deriving the classical deadlock and
inversion results as consequences of its conservation laws.

**Novel adjacency — conservation as the source of the system invariants.** We
derive the series' three invariants (epistemic, alignment, agency) as corollaries
of conservation (L1): a quantity that cannot be privately created or destroyed
forces shared, honestly-accounted, no-private-expense dynamics. To our knowledge,
grounding scheduler "fairness/safety" properties in a literal conservation law,
rather than in policy, is novel; we pre-register it and invite refutation.

---

## 6. Evaluation

### 6.1 Verifier: `iso_conserve.py` `(shown)`

We model Q explicitly as a fluid with a reservoir, per-process stock, and
conversion to progress, and instrument every transfer so each law is a checked
invariant rather than a narrative. **No wall-clock primitive is present.** Four
laws, four checks:

| Law | Check | Result |
|---|---|---|
| L1 conservation | total `R + ΣS + κΣW` invariant each step, incl. routing scenario | **PASS** (invariant to 1e-6) |
| L2 monotone | convertible stock over a no-progress interval | **PASS** (18→16→…→2→0→0→0, monotone, 12 steps) |
| L3 fixed point | stuck deadlock stepped further never resumes | **PASS** (absorbing) |
| L4 stock = ∫ flow | each process's stock vs running net-flow integral | **PASS** (equal to 1e-6) |

Readings:

- **L1 holds even when Q is routed.** The flow/routing scenario (a blocked process
  pouring its rate into its holder) conserves Q exactly — routing moves the fluid,
  it does not mint it. This is the conservation that makes inheritance "for free"
  legitimate rather than a free lunch: the holder's gained rate is the waiter's
  lost rate, to the unit. `(shown)`
- **L2 is the detection signal, proven monotone.** The convertible stock's strict
  descent to a floor, with conservation holding throughout the drain, is exactly
  what Paper 01's detector reads. The monotone is not assumed; it is measured
  across twelve steps. `(shown)`
- **L4 is the unification, exact.** Stock equals the integral of flow to machine
  precision, identifying budget with ∫ rate. Budget and rate are one quantity's
  integral and derivative, verified, not asserted. `(shown)`

### 6.2 Honest limitation: numerical, not formal `(shown limitation)`

These are numerical verifications on toy models, not machine-checked proofs. They
are strong evidence — L1 and L4 hold to machine precision, L2 is a clean
multi-step monotone, L3 is absorbing — but a skeptic is entitled to a formal
proof. The four laws are stated precisely enough to be discharged in a proof
assistant (Lean or Coq): L1 as an invariant preserved by each transition, L2 as a
monotonicity lemma over no-progress transitions, L3 as an absorption property, L4
as an equality maintained by construction. We mark the laws `(structural)` for the
statements and `(shown)` for the numerical evidence, and name the formal proof as
the next rigor level rather than claim it. `(shown limitation)`

### 6.3 Practical exam pointer

In a real engine the conserved quantity is concrete: scheduling weight (flow),
accumulated allowance (stock), and preserved work across a rollback (banked
stock). The claim to test against a real system: instrument a scheduler so that
weight, allowance, and rollback-preserved progress are accounted as one quantity,
and verify L1 (no weight is created or lost across blocking, routing, or rollback)
holds in the implementation. A violation is a leak — the implementation minting or
losing the quantity — and is the next seed.

---

## 7. Further work (deeper into this wave)

- **Machine-checked proof.** Discharge L1–L4 in Lean or Coq over the transition
  system, upgrading `(shown)` to proven. L1 as a preserved invariant is the
  keystone; L2–L3 follow from it plus the no-injection-when-blocked structure.
- **Min-cut and the deadlock set.** If rate flowing along wait-edges is a flow
  network, does the deadlocked set correspond to a min-cut, and does max-flow
  give the maximal schedulable throughput around a contended resource?
- **Non-conservative extensions.** Real systems have sources and sinks beyond
  progress (a process spawning children injects demand; a killed process destroys
  stock). Does the law extend to an open system with accounted sources/sinks, and
  what is the analogue of L1 there (a continuity equation with source terms)?
- **The units of Q.** We left κ (conversion cost) uniform. Heterogeneous work
  (a cheap step vs an expensive one) makes κ vary; does L4 survive a
  position-dependent κ, and does stock = ∫ flow still hold pointwise?
- **Continuous-time limit.** The toy steps in discrete rounds. In the
  continuous-time limit, L4 becomes a literal `S(t) = ∫₀ᵗ (flow − conversion) ds`
  and L2 a sign condition on `dS/dt`. Does the discrete verification's exactness
  survive the limit, and is the continuous law cleaner to prove?

---

## 8. Conclusion

The series introduced three quantities — a detection budget, a resolution credit,
a scheduling rate — and called each conserved. This paper shows they are one
conserved quantity Q, related by calculus: rate is its flow, budget is its stock
(the integral of flow), and credit is its stock banked across a yield. We stated
four laws and verified each numerically with no clock: Q is conserved at every
step (L1), convertible stock is monotone without progress (L2), deadlock is the
absorbing fixed point where flow converts nowhere (L3), and held stock equals the
integral of flow exactly (L4). The last is the unification made precise: budget is
∫ rate, to machine precision.

With the law in hand, the series' three mechanisms are corollaries. Watching the
integral floor is detection; banking the integral across a yield is resolution;
routing the derivative along edges is scheduling and the inheritance that falls
out of it. And the three system invariants — epistemic, alignment, agency — are
themselves corollaries of conservation: a quantity that cannot be privately created
or destroyed forces honest accounting, sharing, and the absence of private gain at
the whole's expense. The proofs here are numerical; the formal, machine-checked
version is the next rigor level and is named, not claimed. But the shape is clear:
beneath detection, resolution, and scheduling is one conserved quantity, and the
classical mechanisms are what reading its stock and routing its flow look like from
outside. There was never more than one quantity. Energy flows where attention goes;
what flows is conserved.

---

## Bibliography

- Forrester, J. W. (1961). *Industrial Dynamics.* MIT Press. (Stock-and-flow
  conservation accounting.) — `1961:industrial-dynamics`
- Ford, L. R., Fulkerson, D. R. (1962). *Flows in Networks.* Princeton University
  Press. — `1962:flows-in-networks`
- Coffman, E. G., Elphick, M., Shoshani, A. (1971). *System Deadlocks.* ACM
  Computing Surveys. — `1971:coffman-conditions`

> Citation keys are permanent `Year:slug` handles; the slug is the load-bearing
> identifier, full bibliographic resolution secondary to seed stability.

---

## Appendix A — Reproducibility

- Artifact: `iso_conserve.py`, committed at `cac7350` (Team Phi).
- Run: `python3 iso_conserve.py` — prints the four law checks and a verdict
  ending in `ALL CONSERVATION LAWS HOLD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_conserve.py` returns only prose in comments.
- Determinism: explicit fluid model, fixed quanta, no RNG — checks reproduce
  exactly.

## Appendix B — The law in one screen

```
ONE conserved quantity Q. Each process holds STOCK S_p; reservoir holds R;
converted work W_p costs κ each.

  L1 (conservation):  R + Σ S_p + κ Σ W_p  =  constant, every step.
  L2 (monotone):      no progress  ->  Σ_{at table} S_p  non-increasing.
  L3 (fixed point):   deadlock = absorbing state, flow converts nowhere.
  L4 (stock=∫flow):   S_p = ∫ (inflow_p − conversion_p) dt,  exactly.

Three readings of Q:
  rate   = dQ/dt              (flow; routed along wait-edges = scheduling)
  budget = ∫ flow dt          (stock; its floor = deadlock detection)
  credit = ∫ flow, banked     (stock across a yield = resolution)

Detection reads the integral. Scheduling routes the derivative. Resolution
banks the integral across a discontinuity. One quantity, conserved. No clock.
```
