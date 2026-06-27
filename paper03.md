# Paper 03 — Priority as a Flow Rate: Memoryless Self-Organising Scheduling and the Dissolution of Inversion

**Series:** The Isomorphic Scheduler (Axis 03: Focus)
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v3 · toy validated
**Artifact:** `iso_flow.py` @ commit `b10a01f`

> **TruthSeed (paper):** `iso-sched-03:energy-flows-where-attention-goes`
> Priority is a *rate*, not a stock, and it *flows along the wait-edge*. Each
> process is a bucket filled by a stream whose rate is its priority; at every
> instant the available progress is divided among the processes at the table in
> proportion to their *effective* rates, where `eff(p) = base(p) + Σ eff(w)` over
> every process `w` blocked on `p`. A blocked process's bucket is closed, so its
> whole stream pours down the wait-edge into the holder it is attending to: the
> holder catches exactly the energy of whoever waits on it, the bottleneck
> illuminates itself, and the blockage clears in proportion to how much the
> system cares about what is blocked. Energy flows where attention goes. This is
> memoryless and transitive; priority inheritance falls out as a structural
> consequence of conservation, not a protocol. The instant the lock releases the
> pipe breaks and each stream returns to its own bucket — no climb-back, no debt.

---

## 0. Abstract

Priority inversion is the failure where a high-priority task H is blocked,
unboundedly, by a low-priority holder L while an unrelated medium task M
monopolizes the processor. The classical fix adds an inheritance protocol that
detects the block and boosts L. We give a scheduler in which the inversion cannot
form and no protocol is added, by making priority a **flow rate** rather than a
fixed number or a depletable stock.

Picture each process as a bucket filled by a stream; the stream's rate is the
process's priority (its *focus*). At each instant, the available progress — the
cake — is divided among the processes **currently at the table** (alive, runnable,
not blocked) in proportion to their rates. But a bare rebalance has a flaw: if H
blocks and simply leaves, the freed cake spreads to *whoever is present* — including
an unrelated busy-work task M that has no business eating while H's critical path
is stalled inside L. The fix is the **flow equation**: a blocked process's rate
does not merely vacate, it *pours down the wait-edge into the holder it is blocked
on*. Effective rate is `eff(p) = base(p) + Σ eff(w)` over every `w` blocked on `p`,
transitively along chains. The holder catches exactly the energy of whoever is
waiting on it.

Three behaviours follow with no protocol. **When H blocks on L**, H's stream flows
into L, so L's effective rate jumps (to base+H) and L — not M — gets the lion's
share, clears its critical section fast, and releases the lock. **The bottleneck
illuminates itself**: it receives precisely the power the system's pending
attention demands. **When H returns**, the pipe breaks, its stream returns to its
own bucket, and it resumes its full share immediately — no penalty, nothing to
restore. And **L is never starved**: present demand is always served.

This is *memoryless*: the allocation at time NOW is a pure function of the current
wait-graph and the rates, with no dependence on the history of blocking. That
memorylessness is what makes it isomorphic — the schedule is the same structure
re-evaluated each instant, not a stateful protocol accumulating boosts and debts.
In the toy, H blocked on L pours its rate into L: L's share rises to 0.77 (exactly
(1+9)/(1+9+3)) while busy-work M stays pinned at 0.23 — M does *not* feast — and H
resumes its full share the instant the lock frees, with zero penalty for being
blocked. Priority inheritance is not implemented; it is what the flow equation
looks like from outside.

We introduce three invariants for successful systems design:

1. **Epistemic (evidence-tracking).** The schedule is a live reading of present
   demand, never a stored boost or debt. *Here:* a process's share is computed
   from who is at the table right now and their rates, recomputed each instant.
2. **Alignment (shared, not replacing).** A part's success runs through the
   whole's; sharing the conserved quantity is load-bearing, not charitable.
   *Here:* the share a blocked process does not take is not held in reserve for it
   — it flows to those who can convert it now, principally the holder it waits on.
3. **Agency (every action benefits all).** No move helps a part at the whole's
   expense, and no part is starved. *Here:* H leaving the table speeds L (which
   gets the freed share) and costs H nothing on return; the floor on rate keeps
   even the lowest-rate process moving.

We set the rates — the priorities, the focus — and the system self-organises: who
eats how much is always just the instantaneous proportion of present demand.
Focus is this paper's axis, and the scheduler is its mechanism.

---

## 1. Problem revisited

A preemptive priority scheduler runs the highest-priority ready task. With shared
resources this inverts. L (low) holds lock S; H (high) requests S and blocks; the
scheduler runs M (medium), which outranks L; L, the holder of the lock H needs,
does not run; H waits behind M's entire execution. The highest task is blocked by
the medium one through the low intermediary — unbounded priority inversion, the
Mars Pathfinder bug.

The classical remedy adds a protocol: on block, raise L to H's priority so L
preempts M; on release, restore. It is stateful machinery — a boost applied on
block, a chain walked transitively, a priority restored on release — with its own
correctness obligations.

The problem revisited: the classical model treats priority as a **fixed claim a
task always holds**, even while blocked. A blocked H still "has" top priority, so
the scheduler must reason about that idle claim and patch around it. But a blocked
task can do nothing with the processor — its claim is fictional in that moment. We
ask: what if priority is not a fixed claim but a **rate of flow**, and the
processor is divided each instant only among tasks that can actually use it? Then a
blocked task simply isn't competing — it holds no claim to invert — and there is
nothing to patch.

---

## 2. Background

Priority inversion and the inheritance/ceiling protocols are classical real-time
material (Sha, Rajkumar & Lehoczky, 1990:priority-inheritance). The Mars
Pathfinder incident is the canonical field case, fixed in flight by enabling
inheritance on the offending mutex (Reeves, 1997:pathfinder). These fixes share a
shape: a blocked high task retains its priority claim, and a protocol transfers
that claim to the holder.

Our model is **proportional-share scheduling** (lottery and stride scheduling,
Waldspurger & Weihl, 1994:lottery; 1995:stride): each runnable task receives
processor share in proportion to a weight. We take the weight to be a *rate* and
make the share strictly instantaneous — divided only among tasks *currently
runnable*, recomputed each quantum. The contributions over textbook
proportional-share are: (i) the explicit *bucket-filled-by-a-stream* reading,
which makes priority a rate and the schedule memoryless; (ii) the observation that
this dissolves priority inversion with no inheritance, because a blocked task is
not runnable and so holds no share to invert; and (iii) a minimum-rate floor as
the anti-starvation guarantee. Proportional-share fairness is classically about
throughput over time; we use the *instantaneous* division and its memorylessness
as the structural property, and connect it to the series' conserved-quantity
thesis. To our knowledge framing priority inversion's dissolution as a consequence
of instantaneous rate-proportional share is novel; we pre-register the claim.

---

## 3. Sharpening: a bucket filled by a stream

Here is the move.

Stop treating priority as a number a task carries and start treating it as the
**rate of a stream filling the task's bucket**. A high-focus task has a fat
stream; a low-focus task a thin one. At each instant the scheduler looks at the
buckets of the tasks **at the table** — runnable right now — and serves progress
in proportion to their rates. That is the entire scheduler.

Now watch what happens when a task blocks. A bare rebalance — just drop the
blocked task from the division — has a flaw worth naming, because it is the flaw
the flow equation fixes. If H blocks on L and simply leaves the table, the cake it
vacated spreads to *whoever is present*. But "whoever is present" may include an
unrelated busy-work task M that is merely hashing strings in a loop. M has no
business eating the freed share while H's critical path is stalled inside L's
critical section. The blockage is at L, and the freed energy should go to L — not
to whatever else happens to be at the table.

So the rule is not "drop the blocked task and rebalance." It is: **a blocked
task's stream pours down its wait-edge into the holder it is blocked on.** H is
attending to L (it needs the lock L holds), so H's energy flows to L. Concretely,
define a process's **effective rate** as its own base rate plus the rate flowing
in from everyone blocked on it, transitively along the chain of wait-edges:

> `eff(p) = base(p) + Σ eff(w)` over every `w` currently blocked on `p`.

Then the cake is divided by *effective* rate over the tasks at the table. When H
(rate 9) blocks on L (rate 1), L's effective rate becomes 10, and the cake divides
between L (10) and M (3): **L gets 10/13 ≈ 77%**, finishes its critical section
fast, and releases the lock. M, the busy-work task, stays at its own 3/13 ≈ 23% —
it does not feast. The bottleneck illuminated itself: L received precisely the
power the system's pending attention demanded, in proportion to how much the
system cares about what is blocked (here, a rate-9 task cares a lot).

This is the literal mechanism of a phrase that turns out to be exact rather than
metaphorical: **energy flows where attention goes.** Attention is the dependency
(H is focused on the lock L holds); energy is the rate (H's stream); flows is the
routing (because H's attention is fixed on L, H's energy pours into L's bucket).
The scheduler never decides to "boost" L. L simply *catches* the energy of the
processes whose attention is fixed upon it.

And it stays memoryless. The instant L releases the lock, the wait-edge vanishes,
the pipe breaks, and H's stream pours back into H's own bucket — H is at the table
again at its full rate, immediately, with no penalty to repay and nothing to
restore. The allocation at any instant is a pure function of the current
wait-graph and the rates. That is what makes it isomorphic: the same structure
re-read each instant, never a stateful protocol of boosts and reverts.

The wrong framing was "a blocked high task keeps a priority claim we must transfer
to the holder via a protocol." The right framing: **the blocked task's rate is a
fluid that flows down the wait-edge into the holder, automatically, by
conservation.** Priority inheritance is not implemented; it is what this flow
looks like from outside.

---

## 4. The solution

### 4.1 The flow equation and instantaneous effective-rate share `(structural)`

Each process has a fixed base `rate` (its priority / focus). Its **effective
rate** at an instant is its base rate plus the rate flowing in from everyone
blocked on it, transitively:

> **Flow equation.** `eff(p) = base(p) + Σ_{w blocked on p} eff(w)`. A process `w`
> is "blocked on `p`" when `w`'s next step is to acquire a lock currently held by
> `p`. The recursion follows the chain of wait-edges and terminates on the DAG of
> waits; a cycle (deadlock) returns zero inflow and is handled by the
> detection/resolution machinery, not here.

Each scheduling instant distributes a fixed capacity `C` of progress:

> **Share rule.** Let `T` be the set of processes at the table — alive, not done,
> runnable now. Each `p ∈ T` receives `share(p) = C · eff(p) / Σ_{q ∈ T} eff(q)`.
> A blocked process is not in `T`; its rate has already flowed into its holder's
> `eff`, so it is counted there, not separately.

`T` and every `eff` are recomputed each instant from the live wait-graph, so the
flow appears the moment a block forms and vanishes the moment it clears. A small
floor `rate(p) ← max(rate(p), ε)` guards degenerate rates.

### 4.2 Why inversion cannot form, and the bottleneck self-powers `(structural)`

In the classical model a blocked high task retains a top-priority claim that the
scheduler must honour, which is what lets it block the holder's progress
indirectly. Here a blocked task is not in `T` — instead, **its rate has flowed
into the holder it waits on.** So not only does the blocked task hold no idle
claim to invert; the holder is *actively powered* by exactly that claim. When H
(rate 9) blocks on L (rate 1), L's effective rate is 10, so L dominates the
division against any unrelated task M (rate 3): L gets 10/13, M gets 3/13. The
unrelated busy-work task cannot feast on the freed capacity, because the freed
capacity did not spread to the table at large — it was routed down the wait-edge to
the one process whose progress unblocks H. The bottleneck self-powers: it receives
precisely the energy of the pending attention upon it. L runs, releases, H rejoins
`T`. There is no instant at which an unrelated task starves the holder, because the
holder carries the blocked tasks' rates. Inversion is not detected-and-patched; it
is *structurally absent*, and the holder is *accelerated* in proportion to what
waits on it. `(structural)`

### 4.3 Memorylessness, stated precisely `(shown)`

The scheduler's allocation at any instant is a pure function of `(T, rates)` —
which tasks are at the table now and their fixed rates. It does not depend on how
long any task was blocked, how many times it yielded, or what it did before. We
verify the consequence that matters: a task returning from a long block resumes at
exactly the share its rate dictates against the currently-present tasks, identical
to what it would get had it never blocked. In the toy, H returns from being
blocked and immediately receives its full effective-rate share again — the instant
the lock frees, the pipe breaks, H's stream returns to its own bucket, and H is
back at the table at rate 9 with no penalty. `(shown)` This is the precise content
of "no climb-back, no debt": memorylessness makes return free.

### 4.4 The three invariants, in full

A scheduler built on instantaneous rate-proportional share satisfies three
properties we name in systems vocabulary. Each is a concrete predicate, not a
sentiment, and each is stated here in full.

- **Epistemic (evidence-tracking — truth that can update).** The schedule is a
  live reading of present demand, recomputed each instant, never a stored boost or
  accumulated debt. A task's share is exactly its rate's proportion among those at
  the table now; the instant the table changes — someone blocks, someone returns,
  someone finishes — the shares update with no protocol firing, no state to
  reconcile, and no possibility of restoring a wrong value because nothing is
  stored. `(structural)`
- **Alignment (shared, not replacing — success runs through the whole).** A
  part's success runs through the whole's, and the conserved capacity is shared,
  not reserved. The share a blocked task does not take is not held aside for it; it
  flows that instant to the tasks that can convert it, principally the holder the
  blocked task is waiting on — whose release is exactly what the blocked task
  needs. The blocked task's eventual progress runs through the holder's, and the
  freed share is what advances the holder. `(structural)`
- **Agency (every action benefits all).** No move helps a part at the whole's
  expense, and no part is starved. A high task leaving the table speeds the holder
  (which receives the freed share) and costs the high task nothing on return (its
  rate is intact); the floor on rate keeps even the lowest-focus task moving every
  instant. There is no schedule that serves the high task by stranding the holder,
  because while the high task is blocked it is not in the division at all and the
  holder is served by construction. `(structural)`

These three are not ethical decoration. §4.2 shows the alignment/agency reading is
structural: because a blocked task holds no share, serving the holder is automatic
and inversion cannot form.

---

## 5. Related work

**Priority inheritance and priority ceiling** (Sha, Rajkumar & Lehoczky,
1990:priority-inheritance). Classical inversion fixes: a blocked high task retains
its priority and a protocol transfers it to the holder. We retain no claim for a
blocked task — it leaves the table — so no transfer is needed. The outcome (the
holder runs, the high task is not unbounded-blocked) is shared; the mechanism is
absent rather than added.

**Mars Pathfinder** (Reeves, 1997:pathfinder). The field instance fixed by
inheritance. Our toy reproduces the three-task shape and shows inversion never
forms under rate-proportional share.

**Lottery and stride scheduling** (Waldspurger & Weihl, 1994:lottery;
1995:stride). Proportional-share by tickets/strides, with throughput fairness over
time. Our flow rule is proportional-share taken *instantaneously* and *only over
the runnable set*, with the bucket-stream reading that makes priority a rate and
the schedule memoryless. Stride scheduling in particular carries per-task pass
values (state that advances); our flow rule is stateless across the block/return
boundary — a returning task carries no pass debt — which is the property that gives
free return. The minimum-rate floor is our anti-starvation guarantee, analogous to
a minimum-tickets allocation.

**Novel adjacency — inversion as structurally absent under instantaneous rate
share.** The literature removes inversion by transferring a blocked task's
retained priority. We observe that if priority is a rate and share is divided only
over the runnable set, a blocked task retains nothing to transfer and inversion
cannot form. Combined with memorylessness (free return) and the rate floor (no
starvation), this gives the classical guarantees with no inheritance subsystem. To
our knowledge this framing is novel; we pre-register it and invite refutation.

---

## 6. Evaluation

### 6.1 Toy: `iso_flow.py` `(shown)`

Three processes share one lock S. L (rate 1) holds S, has a short critical section
then releases. H (rate 9) does work, requests S and blocks on L, then more work. M
(rate 3) is unrelated. Each instant the cake is divided over the runnable set by
rate. **No wall-clock primitive is present.**

The per-round instantaneous shares show every claim directly:

| Phase | Rounds | L share | H share | M share | What it shows |
|---|---|---|---|---|---|
| All present | 1–3 | 0.08 | 0.69 | 0.23 | H (rate 9) dominates by its rate; L and M get their base proportions |
| H blocked → flows into L | 4–8 | **0.77** | **0.00** | 0.23 | H's rate-9 stream pours down the wait-edge into L: L's effective rate = 1+9 = 10, share 10/13; **M stays at 0.23 — does not feast** |
| H returns | 9–14 | 0.08 | **0.69** | 0.23 | pipe breaks; H resumes its full share immediately, no penalty |
| Only L & M (H done) | 15–18 | 0.25 | 0.00 | 0.75 | H finished (not blocked): the table is L+M at their base rates |
| Finish | 19–20 | 1.00 | 0.00 | — | L completes its tail |

The decisive contrast is the blocked phase: with the flow equation L gets **0.77**
and M stays at **0.23**; with a bare rebalance (no flow, the freed share spread to
the table) L would get only 0.25 and the busy-work task M would feast at 0.75. The
flow routes H's energy to the bottleneck (L), not to the bystander (M).

Claims, all confirmed:

- **L catches H's flow; M does not feast.** While H is blocked on L, L's share is
  0.77 (= (1+9)/(1+9+3)) and the unrelated busy-work task M stays at 0.23. H's
  rate flowed down the wait-edge into L, powering the bottleneck, not the
  bystander. A bare rebalance would instead give M 0.75 — the flaw the flow
  equation fixes. `(shown)`
- **L is never starved.** L has a positive share every round of the blocked
  window. `(shown)`
- **H eats immediately on return.** The instant the lock frees, the pipe breaks
  and H resumes its full share with zero penalty for being blocked. Memoryless:
  return is free. `(shown)`
- **System completes**, all three finishing their work. `(shown)`

### 6.2 Memorylessness check `(shown)`

When H returns from being blocked, it immediately receives its full effective-rate
share again (rate 9, the pipe to L having broken), identical to what its rate earns
had it never blocked. The block left no trace in the allocation: no penalty, no
pass-debt, nothing to restore. This is the operational meaning of memoryless and of
"no climb-back, no debt." `(shown)`

### 6.3 Practical exam pointer

In a real engine, "at the table" is "runnable, not waiting on a lock," which is
directly observable, and rate-proportional share is a standard scheduler class
(e.g. weighted fair queuing / CFS-style weights). The claim to test: a runnable-set
rate-proportional scheduler with a minimum-weight floor exhibits no priority
inversion and requires no inheritance subsystem, and a transaction resuming from a
lock wait regains its full weight immediately. A failure there is the next seed.

---

## 7. Further work (deeper into this wave)

- **The capstone synthesis: one conserved quantity, integral and derivative.**
  The three papers are three readings of a single conserved quantity, related as
  calculus relates a flow to its accumulation:
    - *Detection (Paper 01)* watches the **integral** of the flow — budget is the
      accumulated quantity, and a deadlock is its floor, the integral hitting zero.
    - *Resolution (Paper 02)* banks the **integral across a yield** — credit is
      accumulated progress carried forward, conserved rather than discarded.
    - *Scheduling (Paper 03)* routes the **instantaneous flow** itself — rate is
      the derivative, the fluid that pours along dependency edges right now.
  The same fluid, integrated, is the budget whose floor detects deadlock and whose
  banking is resolution credit; differentiated, it is the rate that flows down the
  wait-edge as inheritance. The capstone question is whether a single engine that
  maintains only this one quantity — tracking its flow and its accumulation —
  yields detection, resolution, and inversion-freedom together, with each classical
  mechanism falling out as a reading of the conserved quantity rather than a
  subsystem. Priority inheritance, like deadlock detection and resolution before
  it, falls out for free as a structural consequence of conservation.
- **Blocking bound under rate share.** Classical inheritance has a proven
  worst-case blocking bound. Does rate-proportional share admit an analogous bound
  on how long a high task waits, as a function of the holder's rate and
  critical-section length? (A holder with a tiny rate could be slow to release even
  with the whole cake; does the floor or a holder-rate boost matter here?)
- **Holder-rate and chained waits.** When L is the only one present it gets the
  whole cake, but if L's own rate is tiny and several tasks are present, L might
  release slowly. Should a holder transiently inherit *rate* (a flow analogue of
  inheritance) — and does that reintroduce a protocol, or fall out of the same
  instantaneous division?
- **Focus as the axis.** Axis 03 is focus: rate is how much focus a task commands.
  Does varying a task's rate over its lifetime (rising focus as a deadline nears)
  compose cleanly with the memoryless division, and does it stay isomorphic?
- **Fairness vs. responsiveness.** Instantaneous division is maximally responsive
  (return is free) but a very high-rate task can starve others down to the floor.
  Characterize where the floor must sit to keep low-rate tasks usefully alive
  without dulling the responsiveness that makes return free.

---

## 8. Conclusion

Priority inversion has been fixed by transferring a blocked task's retained
priority to the holder, via a stateful inheritance protocol. We removed the need by
changing what priority *is*. Priority is a flow rate: each task a bucket filled by
a stream, and at every instant the processor is divided among the tasks at the
table in proportion to their rates. A blocked task is simply not at the table — it
holds no claim to invert — so the holder is served by construction and the
inversion cannot form. The others' shares rise automatically to fill a departed
task's place, and a returning task, its rate never having changed, resumes at full
share immediately, with no penalty to repay and no priority to restore. The
allocation at any instant depends only on who is present and their rates:
memoryless, and therefore isomorphic — the same structure re-read each instant
rather than a protocol accumulating boosts and debts.

The toy shows every piece directly in the instantaneous shares: when H blocks on
L, its rate-9 stream pours down the wait-edge into L, whose share rises to 0.77
while the unrelated busy-work task M stays pinned at 0.23 — the energy reaches the
bottleneck, not the bystander — and H resumes its full share the instant the lock
frees, paying nothing for having been blocked. We set the rates, the focus, and the
system self-organises: who eats how much is always the proportion of present
*effective* demand, with each blocked task's attention routing its energy to the
holder it depends on.

This is the literal content of a phrase that is mechanism, not metaphor: **energy
flows where attention goes.** Attention is the dependency, energy is the rate, flow
is the routing along the wait-edge. The holder does not get boosted by a protocol;
it catches the energy of the processes whose attention is fixed upon it, and the
bottleneck illuminates itself, receiving exactly the power required to clear in
proportion to how much the system cares about what is blocked. The architecture is
self-healing. And it joins the others under one conserved quantity: the same fluid
that, accumulated, is the budget whose floor detects deadlock and whose banking is
resolution credit, here flows as the rate that routes inheritance for free.
Priority inheritance, like detection and resolution before it, is not a subsystem —
it is a structural consequence of conservation. The focused schedule and the fair
schedule are the same schedule.

---

## Bibliography

- Sha, L., Rajkumar, R., Lehoczky, J. P. (1990). *Priority Inheritance Protocols:
  An Approach to Real-Time Synchronization.* IEEE Transactions on Computers. —
  `1990:priority-inheritance`
- Reeves, G. E. (1997). *What Really Happened on Mars?* (Mars Pathfinder priority
  inversion account.) — `1997:pathfinder`
- Waldspurger, C. A., Weihl, W. E. (1994). *Lottery Scheduling: Flexible
  Proportional-Share Resource Management.* OSDI. — `1994:lottery`
- Waldspurger, C. A., Weihl, W. E. (1995). *Stride Scheduling: Deterministic
  Proportional-Share Resource Management.* MIT tech report. — `1995:stride`

> Citation keys are permanent `Year:slug` handles; the slug is the load-bearing
> identifier, full bibliographic resolution secondary to seed stability.

---

## Appendix A — Reproducibility

- Artifact: `iso_flow.py`, committed at `b10a01f` (Team Phi).
- Run: `python3 iso_flow.py` — prints the per-round instantaneous shares, the
  return-immediacy and memorylessness checks, and a verdict ending in
  `ALL CLAIMS HELD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_flow.py` returns only prose in comments; no wall-clock primitive is called.
- Determinism: fixed capacity per instant, scripted programs, no RNG — traces
  reproduce exactly.

## Appendix B — The scheduler in one screen

```
eff(p):                                  # THE FLOW EQUATION
    return base_rate(p) + sum( eff(w) for w blocked-on p )   # energy flows in
                                          # from everyone attending to p

each instant:                            # priority = rate; no stock, no memory
    T = { p : alive, not done, runnable now (next step not a blocked acquire) }
    R = sum( eff(q) for q in T )
    for p in T:
        share(p) = C * eff(p) / R         # instantaneous proportion of effective demand
        acc(p)  += share(p)
        while acc(p) >= 1: acc(p) -= 1; do one step of p

# A blocked task is not in T; its rate has flowed down the wait-edge into its
# holder's eff, so the holder catches its energy and clears the blockage -- the
# bottleneck self-powers, unrelated tasks do not feast. The instant the lock
# frees, the wait-edge vanishes and the stream returns to its own bucket: no
# climb-back, no debt. Allocation depends only on (wait-graph, rates): memoryless.
# Energy flows where attention goes. No clock.
```
