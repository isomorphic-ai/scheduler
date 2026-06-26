# Paper 03 — Priority as a Flow Rate: Memoryless Self-Organising Scheduling and the Dissolution of Inversion

**Series:** The Isomorphic Scheduler (Axis 03: Focus)
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v3 · toy validated
**Artifact:** `iso_flow.py` @ commit `dc6ae01`

> **TruthSeed (paper):** `iso-sched-03:priority-is-a-rate`
> Priority is a *rate*, not a stock. Each process is a bucket filled by a stream
> whose rate is its priority; at every instant the available progress is divided
> among the processes currently at the table, in proportion to their rates. When
> a high-priority process is blocked it is simply not at the table, so the others'
> shares rise automatically to fill the gap — no demotion, no penalty. When it
> returns, its rate never changed, so it eats at full share immediately — no
> climb-back, no debt. The allocation at NOW depends only on who is present and
> their rates: memoryless, and therefore isomorphic. Priority inversion cannot
> form, because a blocked process holds no claim on the processor to invert.

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
not blocked) in proportion to their rates. Three behaviours follow with no extra
mechanism. **When H is away** (blocked, or finished), it takes no share, so the
cake divides among those present and the others' shares — including the holder
L's — **rise automatically**. **When H returns**, its rate is unchanged, so it
**immediately resumes its full share**; there is no penalty to repay and no
priority to restore, because nothing was spent or stored. And **L is never
starved**: while at the table with a positive rate it always receives a positive
share.

This is *memoryless*: the allocation at time NOW is a pure function of who is
present now and their rates, with no dependence on the history of blocking or
yielding. That memorylessness is what makes it isomorphic — the schedule is the
same structure re-evaluated each instant, not a stateful protocol accumulating
boosts and debts. In the toy, a high process blocks and leaves the table; the
holder's share rises (and reaches the whole cake when it is the only one present);
the high process returns and instantly takes its full rate proportion (0.90 of the
cake against the holder, exactly 9/(9+1)) with zero penalty for ten rounds
blocked. Priority inversion never forms because a blocked process holds no
processor claim to be inverted.

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

Now watch the three things happen with no added rule.

- **A task leaves the table** (it blocks on a held lock, or finishes). It is no
  longer served. The cake that instant divides among those still present, so their
  shares **rise automatically** — the holder L, present and runnable, gets a larger
  slice precisely because the high task H is not competing. No one demoted H; H
  removed itself from the division by being unable to eat, and the proportion
  rebalanced. When L is the only one left at the table, L gets the whole cake.
- **A task returns to the table** (its lock frees). Its stream never stopped, its
  rate is unchanged, so the instant it is runnable again it takes its full
  rate-proportion of the cake — **immediately**, with no penalty. There is no debt
  to repay (nothing was spent) and no priority to restore (nothing was changed).
  The high task, blocked for many rounds, resumes at exactly the share its rate
  dictates against whoever is now present.
- **No task starves.** As long as a task is at the table with a positive rate it
  gets a positive share every instant. A small minimum-rate floor guards against a
  degenerate (zero) rate, but the basic guarantee is structural: present demand is
  always served.

The wrong framing was "a blocked high task keeps its priority claim, which we must
transfer to the holder." The right framing: **a blocked task is simply not at the
table, so it holds no claim and the division rebalances to those who can eat.**
Priority is a rate, the schedule is the instantaneous proportion of present
demand, and it is memoryless — the state at NOW depends only on who is present now
and their rates. That memorylessness is exactly what makes the scheduler
isomorphic: the same structure re-read each instant, never a stateful accumulation
of boosts and debts.

---

## 4. The solution

### 4.1 Rate-proportional instantaneous share `(structural)`

Each process has a fixed `rate` (its priority / focus). Each scheduling instant
distributes a fixed capacity `C` of progress:

> **Flow rule.** Let `T` be the set of processes *at the table* — alive, not done,
> and runnable now (next step is not a blocked acquire). Each `p ∈ T` receives
> `share(p) = C · rate(p) / Σ_{q ∈ T} rate(q)`. Processes not at the table receive
> nothing. Shares accumulate; a whole accumulated unit is one step.

`T` is recomputed every instant, so the denominator shrinks the moment a task
leaves and grows when one returns. A small floor `rate(p) ← max(rate(p),
ε)` guards degenerate rates; the anti-starvation property otherwise follows from
"present demand is always in the denominator and so always served."

### 4.2 Why inversion cannot form `(structural)`

In the classical model a blocked high task retains a top-priority claim that the
scheduler must honour, which is what lets it block the holder's progress
indirectly. Here a blocked task is **not in `T`** — it has no share at all while
blocked. So it cannot, by holding an idle claim, deprive the holder of the
processor: the holder is in `T`, the blocked task is not, and the division serves
the holder. The medium task M and the holder L split the cake by their rates; L
runs and releases the lock; the high task H rejoins `T` and resumes. There is no
instant at which H's idle claim prevents L from running, because H has no claim
while blocked. Inversion is not detected-and-patched; it is *structurally absent*.
`(structural)`

### 4.3 Memorylessness, stated precisely `(shown)`

The scheduler's allocation at any instant is a pure function of `(T, rates)` —
which tasks are at the table now and their fixed rates. It does not depend on how
long any task was blocked, how many times it yielded, or what it did before. We
verify the consequence that matters: a task returning from a long block resumes at
exactly the share its rate dictates against the currently-present tasks, identical
to what it would get had it never blocked. In the toy, H returns after ten rounds
blocked and immediately receives 0.90 of the cake against L — exactly `9/(9+1)`,
its uncontested rate proportion — with no penalty. `(shown)` This is the precise
content of "no climb-back, no debt": memorylessness makes return free.

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
| All present | 1–3 | 0.08 | 0.69 | 0.23 | H (rate 9) dominates by its rate; L and M get their proportions |
| H blocked (away) | 4–11 | 0.25 | **0.00** | 0.75 | H leaves the table; L's share **rises 0.08→0.25**, M's to 0.75 — automatic rebalance |
| Only L present | 12–13 | **1.00** | 0.00 | 0.00 | M done, H blocked: L gets the whole cake |
| H returns | 14–18 | 0.10 | **0.90** | 0.00 | H back at full rate **immediately** — 0.90 = 9/(9+1) against L, no climb-back |
| Finish | 19–21 | 1.00 | 0.00 | — | L completes its tail |

Claims, all confirmed:

- **L's share rises automatically when H is away.** 0.08 → 0.25 the instant H
  blocks, and 1.00 when L is the only one present. No demotion of H; the division
  simply rebalanced over the runnable set. `(shown)`
- **L is never starved.** L has a positive share every round of the blocked
  window and never stalls. `(shown)`
- **H eats immediately on return.** At round 14 H resumes at 0.90 — exactly its
  uncontested rate proportion against L — with zero penalty for ten rounds
  blocked. Memoryless: return is free. `(shown)`
- **System completes**, all three finishing their work. `(shown)`

### 6.2 Memorylessness check `(shown)`

H's share when it returns (round 14, against L only) is 0.900, exactly `9/(9+1)`,
its uncontested rate proportion — identical to what its rate would earn had it
never blocked. The block left no trace in the allocation. This is the operational
meaning of memoryless and of "no climb-back, no debt." `(shown)`

### 6.3 Practical exam pointer

In a real engine, "at the table" is "runnable, not waiting on a lock," which is
directly observable, and rate-proportional share is a standard scheduler class
(e.g. weighted fair queuing / CFS-style weights). The claim to test: a runnable-set
rate-proportional scheduler with a minimum-weight floor exhibits no priority
inversion and requires no inheritance subsystem, and a transaction resuming from a
lock wait regains its full weight immediately. A failure there is the next seed.

---

## 7. Further work (deeper into this wave)

- **Rate as the conserved budget.** This paper's rate, Paper 01's detection floor,
  and Paper 02's resolution credit are all the one shared quantity. Capstone
  question: is "rate" simply the *flow* and "budget/credit" the *accumulated
  stock* of one conserved quantity, so that detection, resolution, and scheduling
  are stock-and-flow readings of a single thing?
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

The toy shows every piece directly in the instantaneous shares: the holder's slice
rising from 0.08 to 0.25 to 1.00 as the high task leaves and the table empties, and
the high task resuming at exactly 0.90 — its uncontested rate proportion — the
instant it returns from ten rounds blocked, paying nothing. We set the rates, the
focus, and the system self-organises: who eats how much is always just the
proportion of present demand. This is the focus axis of the series, and it joins
the others under one conserved quantity — the same stream that, accumulated, is the
budget whose floor detects deadlock and whose banking is resolution credit.
Hoarding a claim on the processor while unable to use it is the fiction the
classical model must patch; letting the claim be a live rate, served only when one
is at the table, frees the whole. The focused schedule and the fair schedule are
the same schedule.

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

- Artifact: `iso_flow.py`, committed at `dc6ae01` (Team Phi).
- Run: `python3 iso_flow.py` — prints the per-round instantaneous shares, the
  return-immediacy and memorylessness checks, and a verdict ending in
  `ALL CLAIMS HELD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_flow.py` returns only prose in comments; no wall-clock primitive is called.
- Determinism: fixed capacity per instant, scripted programs, no RNG — traces
  reproduce exactly.

## Appendix B — The scheduler in one screen

```
each instant:                            # priority = rate; no stock, no memory
    T = { p : alive, not done, runnable now (next step not a blocked acquire) }
    R = sum( rate(p) for p in T )
    for p in T:
        share(p) = C * rate(p) / R       # instantaneous proportion of present demand
        acc(p)  += share(p)
        while acc(p) >= 1: acc(p) -= 1; do one step of p

# A blocked task is not in T -> it holds no share -> it cannot strand the holder
# -> inversion cannot form. When it leaves, R shrinks and everyone present rises.
# When it returns, R grows and it resumes at full rate share at once -- no debt,
# no restore. The allocation depends only on (T, rates): memoryless. No clock.
```
