# Paper 03 — Priority Inversion for Free: Inheritance as Urgency Flowing Along the Wait-Edge

**Series:** The Isomorphic Scheduler
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v1 · toy validated
**Artifact:** `iso_route.py` @ commit `91ad002`

> **TruthSeed (paper):** `iso-sched-03:urgency-flows`
> Priority inheritance need not be a protocol bolted onto a scheduler. If a
> blocked process's urgency *flows along its wait-edge* to the holder it is
> blocked on, then the holder runs with the waiter's priority — and classical
> priority inversion cannot occur. Inheritance is not added; it is what the
> single flow rule "urgency goes to whoever can convert it" looks like from
> outside. A blocked process cannot spend its own priority, so it lends it to
> the one who can.

---

## 0. Abstract

Priority inversion is the failure in which a high-priority task is blocked,
indirectly and unboundedly, by a lower-priority one. A high task H needs a
resource held by a low task L; an unrelated medium task M, outranking L, is
scheduled instead of L; L never runs to release the resource; H waits behind M
despite outranking it. This reset the Mars Pathfinder. The standard fix is a
*protocol* added to the scheduler — priority inheritance or priority-ceiling —
that detects the block and temporarily boosts L's priority.

We show the protocol is unnecessary because the boost is already implied by a
single conservation-style rule. Give each process a priority, and schedule by
**effective priority**: a process's effective priority is the maximum of its own
and the effective priority of every process blocked on it, transitively along
the wait-edges. Then a blocked high task's urgency *flows* to the holder it waits
on, the holder runs with that urgency, and the medium task no longer preempts the
holder a high task needs. Inversion does not occur — not because we detected and
patched it, but because the urgency was never stranded. We never write an
inheritance rule; inheritance is what the flow rule looks like from outside.

In our toy reproduction of the Pathfinder shape, the classical scheduler exhibits
eight rounds of inversion (the high task waits while the medium task runs to
completion); the routed scheduler exhibits zero, completing in the same number of
rounds, with the low holder visibly running at its *own* priority 1 but
*effective* priority 9 — the high task's urgency, flowed down the wait-edge.

We introduce three invariants for successful systems design:

1. **Epistemic (evidence-tracking).** The schedule follows the actual dependency
   structure, not a fixed priority number. *Here:* effective priority is read
   from the live wait-edges each round, so it updates the instant a block forms
   or clears.
2. **Alignment (shared, not replacing).** A part's success runs through the
   whole's; sharing the conserved quantity is load-bearing, not charitable.
   *Here:* the high task's urgency is shared with the holder it depends on,
   because the high task's success runs through the low task's release.
3. **Agency (every action benefits all).** No move helps a part at the whole's
   expense. *Here:* running the low holder at inherited urgency serves the high
   waiter, the low holder, and overall throughput at once; there is no schedule
   that serves the high task by stranding the holder it needs.

The deeper result closes the series' arc: the credit of the resolution paper —
banked progress that expands a process's future budget — is the discrete,
after-the-fact instance of this same flow. Resolution routes the conserved
quantity once a deadlock has formed; scheduling routes it continuously so the
inversion never forms. They are one conservation law at two time scales.

---

## 1. Problem revisited

A preemptive priority scheduler runs, at each instant, the highest-priority task
that is *ready*. This is correct and efficient until tasks share resources.

Consider three tasks and one shared lock S. Task L (low priority) holds S. Task H
(high priority) becomes ready, runs, and requests S — and blocks, because L holds
it. H is now not ready. The scheduler looks for the highest-priority ready task
and finds M (medium priority), which shares nothing with S. M runs. M outranks L,
so whenever L and M are both ready, M is chosen. L, the holder of the lock H
needs, does not run. H waits — not for L's short critical section, but for M's
entire execution, which may be unbounded. H, the highest-priority task in the
system, is blocked by M, a lower-priority task, through the intermediary L. This
is **priority inversion**, and in its unbounded form it is a safety-critical bug:
it famously caused repeated system resets on the Mars Pathfinder.

The classical remedy adds a **protocol**. Under *priority inheritance*, when H
blocks on L, the scheduler detects this and temporarily raises L's priority to
H's, so L preempts M, releases S, and H proceeds; L's priority then reverts.
Under *priority ceiling*, each lock carries a ceiling priority and acquirers are
boosted preemptively. Both work. Both are machinery added on top of the
scheduler: a rule that fires on block, mutates a priority, and reverts on release,
with its own correctness obligations (transitivity across chains of blocks,
restoring the right priority when several locks are held).

The problem revisited: **inversion is treated as a pathology to detect and patch,
and inheritance as a protocol to add.** We ask whether the patch is implied by a
more basic rule about where urgency should go — whether, stated correctly, the
scheduler never strands the urgency in the first place, so there is nothing to
patch.

---

## 2. Background

Priority inversion and the inheritance and ceiling protocols are classical
real-time systems material (Sha, Rajkumar & Lehoczky, 1990:priority-inheritance,
the foundational analysis of both protocols and their blocking bounds). The Mars
Pathfinder incident is the canonical field example: a high-priority bus-management
task blocked by a low-priority meteorological task through a shared mutex, with an
unrelated medium task causing the unbounded delay; the fix deployed in flight was
to enable priority inheritance on the mutex (Reeves, 1997:pathfinder).

The structure of the fix is always the same: on block, raise the holder; on
release, restore. Priority inheritance raises reactively to the specific waiter's
priority; priority ceiling raises proactively to a per-lock constant. Both must
handle *transitive* inheritance — H blocked on M' blocked on L must flow H's
priority all the way to L — which the protocols implement as an explicit chain
walk.

Our framing recasts the same effect as a *flow* of a conserved scheduling weight
along wait-edges, computed as part of the scheduling decision rather than applied
as a separate mutation. The transitive chain walk that the protocol performs
explicitly becomes, in our formulation, simply the definition of effective
priority — a maximum taken over the transitive closure of the inverse wait-edge
relation. To our knowledge, presenting inheritance as the *definition of the
scheduling key* rather than as a protocol that edits priorities is the novel
framing; the resulting schedule coincides with classical inheritance where they
overlap (§5).

---

## 3. Sharpening: a blocked process cannot spend its own urgency

Here is the move.

Priority is the weight that decides who runs. In the classical scheduler, a
blocked process keeps its priority but cannot use it — it is not ready, so its
priority sits idle while the resource it needs goes unserved. That idle priority
is the whole problem: H's urgency exists, but it is stranded on H, who can do
nothing with it, while the task that *could* act on it — L, the holder — runs at
its own low priority or not at all.

Ask the conservation question the series keeps asking: the urgency is a quantity;
where should it go to be converted into progress? H cannot convert it — H is
blocked. The only process whose running would advance H is L, the holder. So the
urgency should **flow to L**. Concretely: define a process's **effective
priority** as the maximum of its own priority and the effective priority of every
process blocked on it, transitively along the wait-edges. Schedule by effective
priority.

Now H's priority is no longer stranded. The instant H blocks on L, L's effective
priority becomes at least H's, because H is blocked on L. L therefore outranks M
and is scheduled; L releases S; H proceeds. M runs afterward. The inversion never
happens — not because a detector fired, but because the urgency was routed to the
process that could spend it.

The wrong framing was "a blocked high task waits, and we must detect this and
boost the holder." The right framing: **urgency flows to whoever can convert it,
and a blocked process's urgency therefore flows down its wait-edge to its
holder.** Priority inheritance is not a protocol we add. It is what this one flow
rule looks like from the outside. We do not write "on block, raise the holder";
we write "effective priority is the max over the wait-edge," and the raising is
already there.

---

## 4. The solution

### 4.1 Effective priority `(structural)`

Each process has a fixed own-priority. The scheduler runs, each round, the ready
process of highest **effective priority**, defined as:

> **Effective priority.** `eff(p) = max( own_priority(p), max over { w : w is
> blocked on p } of eff(w) )`, where "w is blocked on p" means w's next action is
> to acquire a lock currently held by p. The recursion follows the inverse
> wait-edges and terminates because, absent a deadlock cycle, the wait-for graph
> is a DAG; a cycle (deadlock) is handled by the detection/resolution machinery,
> not here.

A *ready* process is one whose next step is not blocked (work and release are
always ready; acquire is ready iff the lock is free or already held by the
process). The scheduler picks `argmax` of effective priority over ready
processes.

This single definition carries inheritance. A blocked waiter w contributes
`eff(w)` to its holder p, so p's effective priority rises to meet its most urgent
waiter, transitively. When the block clears (p releases, w becomes ready and no
longer blocked on p), w drops out of p's max and p's effective priority falls
back on its own — the "revert on release" of the classical protocol, here just
the max being recomputed over the now-current edges. Nothing is mutated or
restored; the key is recomputed from live structure each round.

### 4.2 Why inversion cannot occur under routing `(shown)`

Claim: under effective-priority scheduling, no medium task M can run while a
higher-priority task H is blocked on a strictly-lower-priority holder L.

Suppose H is blocked on L. Then by definition `eff(L) ≥ eff(H) ≥ own(H) >
own(M)`. Among ready tasks, L is ready (it holds S and its next step is work or
release, not a block) and `eff(L) > own(M) = eff(M)` (M has no waiters, so its
effective priority is its own). The scheduler picks the maximum effective
priority, so it picks L over M. Therefore M does not run while H is blocked on L:
the inversion signature is impossible. `(structural)` Transitively, if H is
blocked on L' which is blocked on L, the same maximum flows H's urgency to L
through L', and the chain of holders all outrank M. `(structural)`

The toy confirms it: in the routed run, the holder LOW is scheduled at own
priority 1 but **effective priority 9**, preempts MED, releases the lock, and HIGH
finishes immediately — zero inversion rounds. `(shown)`

### 4.3 "For free" stated precisely `(structural)`

"For free" is a strong claim and we mean it literally, not rhetorically. It does
*not* mean inheritance costs no computation — computing effective priority walks
the wait-edges, the same walk the classical protocol performs. It means
inheritance is **not a separate mechanism**: there is no code path that detects a
block, mutates a priority, and reverts it. There is one scheduling rule — pick the
ready process of highest effective priority — and effective priority is defined by
the flow. The inheritance behavior is not added to that rule; it is entailed by
it. Remove "inheritance" from the system and there is nothing to remove, because
nothing named inheritance was ever written. That is the sense of free: not zero
cost, but zero added mechanism — the behavior falls out of the definition of the
scheduling key.

### 4.4 The three invariants, in full

A scheduler built on effective-priority flow satisfies three properties we name in
systems vocabulary. Each is a concrete predicate, not a sentiment, and each is
stated here in full.

- **Epistemic (evidence-tracking — truth that can update).** The schedule follows
  the live dependency structure rather than a frozen number. Effective priority is
  recomputed from the current wait-edges every round, so the instant a block forms
  the holder's urgency rises, and the instant it clears the urgency falls back —
  no stored boosted-priority to mutate and later restore, and so no risk of
  restoring the wrong one. The scheduling key is always a current reading of who
  depends on whom. `(structural)`
- **Alignment (shared, not replacing — success runs through the whole).** A
  part's success runs through the whole's, and sharing the conserved quantity is
  load-bearing rather than charitable. A high task's urgency is shared with the
  holder it is blocked on precisely because the high task's success runs through
  that holder's release — the two successes are the same event seen from two
  sides. The holder does not borrow status it did not earn; it carries exactly the
  urgency of the work that depends on it. `(structural)`
- **Agency (every action benefits all).** No move helps a part at the whole's
  expense. Running the holder at inherited urgency advances the high waiter (it
  gets unblocked sooner), the holder (it completes its critical section), and
  total throughput (the unbounded medium-task delay is gone) simultaneously. There
  is no schedule that serves the high task while stranding the holder it needs;
  serving the waiter and serving the holder are the same act. `(structural)`

These three are not ethical decoration. §4.2 shows the alignment/agency reading
has teeth: a scheduler that violates them — that lets a process keep urgency it
cannot convert, stranding it instead of flowing it to the holder — is exactly the
classical scheduler, and it exhibits unbounded inversion.

---

## 5. Related work

**Priority inheritance and priority ceiling** (Sha, Rajkumar & Lehoczky,
1990:priority-inheritance). The foundational protocols and their blocking-time
bounds. Our routed scheduler produces the same schedule as priority inheritance on
the cases where both apply: the holder runs at the maximum priority among its
(transitive) waiters. The difference is presentational and structural — we obtain
that schedule from the definition of the scheduling key rather than from a
block-triggered mutation-and-revert protocol — but we claim no different *outcome*
than inheritance where they overlap; we claim a simpler *derivation* and the
removal of the protocol's separate correctness obligations (it cannot restore the
wrong priority because it stores none).

**Mars Pathfinder** (Reeves, 1997:pathfinder). The canonical field instance,
whose in-flight fix was to enable inheritance on the offending mutex. Our toy
reproduces this exact shape (high/low sharing a lock, unrelated medium task
causing the unbounded delay) and shows the routed scheduler never enters the
inversion.

**Priority ceiling vs. our flow.** Ceiling protocols boost *proactively* by a
per-lock constant, preventing inversion and also chained blocking and deadlock at
the cost of requiring statically known ceilings. Our flow is *reactive* like
inheritance (it boosts only when a block actually exists) and so does not require
static ceilings, but unlike classical inheritance it computes the boost as the
scheduling key rather than storing it. A ceiling-style proactive variant of our
flow (route a lock's ceiling to any holder pre-emptively) is possible and noted as
further work.

**Novel adjacency — inheritance as the scheduling key, not a protocol.** The
contribution is the reframing: define effective priority as the max over the
transitive inverse-wait closure, schedule by it, and inheritance is entailed
rather than implemented. This connects priority inversion to the series'
conservation thesis — urgency is a quantity that must flow to where it converts —
and unifies it with deadlock resolution (Paper 02), where the same flow appears as
credit expanding a yielder's future budget. To our knowledge this unification of
priority inheritance and progress-credit as one conserved flow at two time scales
is novel; we pre-register it and invite refutation.

---

## 6. Evaluation

### 6.1 Toy: `iso_route.py`, the Pathfinder shape `(shown)`

Three processes share one lock S. LOW (own priority 1) holds S at t=0 — the
realistic inversion trigger. HIGH (own priority 9) runs, does a unit of work, then
requests S and blocks on LOW. MED (own priority 5) is an eight-unit CPU-bound run
sharing nothing. We run the identical scenario twice: with urgency routing off
(classical) and on (flow). **No wall-clock primitive is present.**

| Scheduler | Inversion rounds | Completes | Notable |
|---|---|---|---|
| Classical (no routing) | **8** | r14 | HIGH (pri 9) blocked while MED (pri 5) runs all 8 units; LOW runs only after MED finishes |
| Routed (flow) | **0** | r14 | LOW scheduled at own pri 1 / **effective pri 9**; preempts MED, releases S; HIGH finishes at once; MED runs last |

Readings:

- **Classical exhibits the bug.** For eight consecutive rounds the inversion
  signature fires: HIGH is blocked on LOW, but MED — outranking LOW — is scheduled
  instead. HIGH, the highest-priority task, waits behind MED, the medium one, for
  MED's entire run. This is the Pathfinder failure reproduced. `(shown)`
- **Routed eliminates it with no inheritance code.** The decisive line in the
  trace is `run LOW (own pri 1, eff 9)`: LOW's own priority is unchanged at 1, but
  its effective priority is 9 because HIGH is blocked on it and HIGH's urgency
  flowed down the wait-edge. LOW outranks MED, preempts it, releases S; HIGH
  proceeds immediately. Zero inversion rounds. There is no statement in the engine
  that raises LOW's priority on block; the `eff 9` is the max in the
  effective-priority definition, computed from the live wait-edge. `(shown)`

### 6.2 Practical exam pointer

In a real engine the wait-edges are already materialized (e.g. InnoDB's
`data_lock_waits.blocking_trx_id` gives exactly "who is blocked on whom"). A
routed scheduler reads those edges to compute effective priority as the max over
the transitive closure, and schedules transactions by it. The claim to test
against a real system: scheduling by effective priority produces the same
anti-inversion behavior as enabling priority inheritance, without a separate
inheritance code path, and reverts correctly when a wait clears because the key is
recomputed rather than stored. A failure there is the next seed.

---

## 7. Further work (deeper into this wave)

- **Proactive (ceiling-style) flow.** Our flow is reactive — it boosts a holder
  only once a waiter is actually blocked on it. A proactive variant would route a
  lock's ceiling priority to any holder pre-emptively, matching priority-ceiling's
  prevention of chained blocking. Does ceiling behavior fall out of a forward flow
  as cleanly as inheritance falls out of the reverse flow?
- **Flow under the deadlock cycle.** Effective priority is defined on the DAG of
  wait-edges; a deadlock is a cycle, where the recursion would loop. We currently
  hand cycles to the detector/resolver. Is there a single quantity that is
  effective-priority off a cycle and yield-credit on one — i.e. does the cycle
  guard in the recursion correspond exactly to the hand-off to resolution?
- **Quantitative blocking bound.** Classical inheritance has a proven blocking
  bound (a high task waits at most the sum of certain critical sections). Does the
  flow formulation reproduce that bound, and does computing it as a key change the
  constant?
- **Credit and urgency as one quantity.** Paper 02's credit expands a returning
  yielder's *budget*; this paper's flow expands a holder's *priority*. Both route
  a conserved scheduling weight along dependency edges. Are budget and priority
  two projections of one quantity, and does scheduling by their combination
  subsume both detection-time and resolution-time behavior?
- **Fairness vs. flow.** Routing all urgency to a holder can, in a pathological
  chain, make a low task carry maximal priority for a long time. Does this ever
  starve a genuinely-mid-priority task that is not in any waiter's dependency, and
  if so is that a real cost or only an apparent one?

---

## 8. Conclusion

Priority inversion has been treated as a pathology to detect and inheritance as a
protocol to add: on block, raise the holder; on release, restore. We showed the
protocol is implied by a more basic rule. A blocked process cannot spend its own
urgency, so the urgency must flow to the process that can — the holder it is
blocked on. Define effective priority as the maximum over the transitive
wait-edges and schedule by it, and the high task's urgency reaches the low holder
automatically: the holder runs at its own priority but its dependents' effective
urgency, preempts the unrelated medium task, releases the lock, and the high task
proceeds. The inversion does not occur, because the urgency was never stranded.

This is "for free" in the exact sense: not without computation, but without a
separate mechanism. We never wrote an inheritance rule; inheritance is what the
flow rule looks like from outside. The toy shows it starkly — eight rounds of
inversion under the classical scheduler, zero under the flow, with the low holder
visibly carrying effective priority 9 it never owned. And it closes the series'
arc: the credit that conserved a yielder's progress in resolution and the urgency
that reaches a holder in scheduling are the same conserved weight routed along the
same dependency edges — once after a deadlock forms, once continuously so it never
does. Hoarding urgency on a process that cannot spend it is what strands the
system; letting it flow to whoever can convert it is what frees the whole. The
generous routing and the optimal routing are the same routing.

---

## Bibliography

- Sha, L., Rajkumar, R., Lehoczky, J. P. (1990). *Priority Inheritance Protocols:
  An Approach to Real-Time Synchronization.* IEEE Transactions on Computers. —
  `1990:priority-inheritance`
- Reeves, G. E. (1997). *What Really Happened on Mars?* (Mars Pathfinder priority
  inversion account.) — `1997:pathfinder`
- Coffman, E. G., Elphick, M., Shoshani, A. (1971). *System Deadlocks.* ACM
  Computing Surveys. — `1971:coffman-conditions`

> Citation keys are permanent `Year:slug` handles; the slug is the load-bearing
> identifier, full bibliographic resolution secondary to seed stability.

---

## Appendix A — Reproducibility

- Artifact: `iso_route.py`, committed at `91ad002` (Team Phi).
- Run: `python3 iso_route.py` — prints the classical and routed runs of the
  Pathfinder scenario and a verdict ending in `ALL CLAIMS HELD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_route.py` returns only prose in comments; no wall-clock primitive is called.
- Determinism: priority-ordered single-process-per-round scheduling, scripted
  programs, stable index tie-break, no RNG — traces reproduce exactly.

## Appendix B — The scheduler in one screen

```
eff(p):                                  # effective priority
    return max( own_priority(p),
                max( eff(w) for w in processes
                     if w is blocked on p ) )   # urgency flows up the wait-edge

each round:
    ready = { p : p not done and p's next step is not blocked }
    chosen = argmax over ready of eff(p)        # schedule by effective priority
    run chosen

# A blocked high task w contributes eff(w) to its holder p, so p outranks any
# unrelated medium task and runs to release the lock. No "on block, raise holder"
# statement exists; inheritance is entailed by the definition of eff. No clock.
```
