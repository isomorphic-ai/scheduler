# Paper 01 — Knowing a System Is Stuck: Timer-Free Deadlock Detection via a Conserved Budget

**Series:** The Isomorphic Scheduler
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v1 · toy validated · practical exam pre-registered
**Artifact:** `iso_deadlock.py` @ commit `090b4b0`

> **TruthSeed (paper):** `iso-sched-01:budget-not-timer`
> Deadlock can be *known*, not guessed, in a system whose scheduler routes a
> conserved budget that is spent only on progress. A process that is merely slow
> spends its budget; a process that is blocked returns it unspent. When every
> member of a wait-cycle has returned its budget, no progress is possible for
> the whole — and that is a proof, not a timeout.

---

## 0. Abstract

Production systems detect deadlock two ways: by building a wait-for graph and
searching for a cycle, or — when graph search is disabled, deferred, or
incomplete — by waiting for a timeout and giving up. The timeout is the weak
link. It cannot distinguish a process that is *blocked forever* from one that is
merely *slow*, so it must trade false positives against detection latency: short
timeouts abort live work, long timeouts hang dead systems.

We remove the timeout. We put scheduling and yielding on a single **conserved
budget** that is refilled only by *progress* and drained by *blocked scheduling
attempts*. A slow process spends budget and never approaches the floor; a
blocked process returns budget and falls to it. Deadlock becomes a fixed point
of a monotone quantity: **a set of processes is deadlocked iff every member
returns its budget unspent and their wait-edges close a cycle.** This is
*known*, not assumed — detection latency is the budget size, with no wall clock
anywhere in the detector. We validate on a toy scheduler (three scenarios: true
deadlock, slow-but-alive, resolvable contention — all classified correctly,
zero false positives) `(shown)` and pre-register a real-engine exam against
SQLite and InnoDB `(predicted)`.

We introduce three invariants for successful systems design:

1. **Epistemic (evidence-tracking).** Beliefs update on evidence rather than
   freezing and discarding the signal that would correct them. *Here:* the budget
   floor tracks confirmed non-conversion and resets on progress, where a timeout
   commits to "dead" on a clock.
2. **Alignment (shared, not replacing).** A part's success runs through the
   whole's; sharing the conserved quantity is load-bearing, not charitable.
   *Here:* a blocked process that *returns* its budget is what makes deadlock
   legible.
3. **Agency (every action benefits all).** No move helps a part at the whole's
   expense, because the conserved quantity flows only where it converts to
   progress. *Here:* declaring deadlock benefits even the deadlocked processes,
   and the hoarding move is structurally unavailable rather than forbidden.

The result generalizes past detection. The same conserved budget, used to
*route* rather than to *test*, yields priority inheritance "for free," and
exposes a structural fact about dependency graphs: **hoarding is dominated for
the hoarder.** A process that refuses to yield budget starves the processes
it transitively depends on, and deadlocks itself. In a connected dependency
graph, the selfish optimum and the global optimum are the same point.

---

## 1. Problem revisited

Deadlock is the canonical failure of concurrent systems: a set of processes each
holding a resource another needs, none able to proceed. The detection problem is
not "what is deadlock" — that is well understood — but **"how does the system
come to know a deadlock has occurred?"**

Two families of answer are deployed in practice:

- **Cycle detection.** Maintain a wait-for graph; a directed cycle is a
  deadlock. InnoDB and PostgreSQL both do this. It is exact when the graph is
  complete and current, but it costs graph maintenance and search, and is
  sometimes disabled under high concurrency for throughput (`innodb_deadlock_detect
  = OFF`) precisely because that cost bites.
- **Timeout.** Pick a duration; if a process waits longer than that, declare it
  failed and roll it back (`innodb_lock_wait_timeout`, `deadlock_timeout`).

The timeout is the part we attack. It is a confession of ignorance dressed as a
policy. `(structural)` The system cannot observe whether a waiting process is
blocked-forever or slow-but-coming, so it substitutes a *frozen belief* — "after
N seconds, assume the worst" — for the knowledge it lacks. Every timeout value
is simultaneously too short for some slow-but-live process and too long for some
genuinely-dead one. The tuning knob exists because **no single duration is
correct**, and no single duration is correct because *duration was never the
right variable.*

The problem revisited, precisely: **the timeout measures the wrong quantity.**
It measures how long a process has waited. What we want to know is whether the
process *can make progress* — and elapsed time is only a noisy, threshold-free
proxy for that.

---

## 2. Background

We assume the standard concurrency model: processes (or transactions) acquire
and release locks on resources; a process that requests a held lock *waits*; a
**wait-for graph** has an edge `A → B` when `A` waits on a lock held by `B`; a
directed cycle in that graph is a deadlock (Coffman et al., 1971:coffman-conditions —
the four necessary conditions, of which circular-wait is the one we detect).

Cycle detection as the exact criterion is classical (Holt, 1972:holt-graph). Its
cost and the resulting reliance on timeouts under load is an engineering reality
documented in the InnoDB manual (Oracle, MySQL Reference Manual,
`innodb_deadlock_detect`). Timeout-based resolution trades correctness for
bounded overhead.

The conserved-quantity framing we use is adjacent to two ideas the reader may
know. First, **virtual-time / fair-queuing schedulers** (Demers et al.,
1989:fair-queuing) attach a monotone quantity to each flow to decide service
order; our budget is a monotone quantity too, but ours is gated on *progress*,
not on arrival or service time. Second, **credit-based flow control** (used in
InfiniBand and elsewhere) lets a sender transmit only while it holds credits;
our budget is credit-like, but earned by conversion-to-progress rather than
granted by a receiver. To our knowledge, using a progress-gated conserved budget
as the *deadlock-detection signal* — replacing the timeout outright — is novel
`(predicted novelty; see §5)`.

The framing also draws on a notion from the authors' prior work: a **Lockhart**
— an irreversibly-frozen belief that discards the evidence that could update it
(Franz & Claude, honesty series, `iso-honesty:lockhart`). A timeout is a Lockhart
about liveness: it commits to "dead" on a clock, discarding the one piece of
evidence — whether the process converted budget — that would have told the truth.

---

## 3. Sharpening: the missing variable

Here is the move the whole paper turns on.

Classical detection keeps two separate accounts:

- a **scheduling cost** (graph maintenance, arbitration, context switch) —
  overhead you pay, and
- a **yield** — treated as free; a blocked process simply gives up the CPU at
  no charge.

Because the accounts do not talk, the system has no single quantity that tracks
*"is the whole making progress?"* It can see that a process waited a long time
(timeout) or that the graph has a cycle (cycle detection), but it has no scalar
that *drains when, and only when, no progress is being made.*

**Put yield and scheduling on one conserved budget.** Then there is exactly such
a scalar. The rule is one line:

> When scheduled, a process **spends** budget if it converts it to progress, and
> **returns** budget unspent if it is blocked. Budget is refilled only by
> progress.

Now the missing variable exists. A slow process, scheduled, *spends* — its
budget stays high. A blocked process, scheduled, *returns* — its budget falls.
The quantity we always wanted — "can the whole make progress?" — is now directly
readable as **the convertible budget summed over the set**, and it is *monotone
non-increasing across any round in which no progress occurs.* `(structural)`

The wrong question was "can *this process* make progress?" — answered by staring
at one process's clock. The right question is "can *the whole* make progress?" —
answered by whether the shared budget is still being converted anywhere. The
timeout asked the first question. The budget answers the second.

---

## 4. The solution

### 4.1 The conservation law `(structural)`

> **Invariant (budget conservation).** Each scheduling round, every non-finished
> process either *spends* budget (it made progress) or *returns* budget (it was
> blocked). Let `B(S)` be the total convertible budget over a set `S`. In any
> round where no member of `S` makes progress, `B(S)` strictly decreases.
> Budget is replenished only by progress.

The law has a floor: budget cannot go below zero, and a process at the floor has,
by construction, *failed to convert for `k` consecutive scheduled turns* (`k =
rounds_to_confirm`, the budget size). The floor is not a timeout — it counts
**confirmed failures to convert**, not elapsed time. A process that converts even
once resets to full.

### 4.2 The predicate `(structural)`

> **Deadlock.** A set `S` is deadlocked **iff**
> 1. every member of `S` is at the budget floor (each has returned its budget
>    unspent for `k` consecutive scheduled turns), **and**
> 2. the members' wait-edges form a directed cycle contained in `S`.

Condition (1) establishes *blocked now, repeatedly confirmed.* Condition (2)
establishes *permanence*: a cycle means the only processes that could release the
needed resources are themselves inside the starved set, so no external event will
rescue them. (1) alone is "stuck this moment"; (1)+(2) is "stuck forever," which
is what we are entitled to call **known**.

Why (2) is necessary and not merely confirmatory: a process can sit at the floor
while blocked on a resource held by a process *outside* `S` that is still making
progress — that is contention, not deadlock, and it will resolve when the
external holder releases. The cycle condition is exactly what rules this out. It
is the same circular-wait condition as classical detection (Coffman,
1971:coffman-conditions); our contribution is pairing it with the **budget
floor** so that the *timing* of the check needs no clock.

### 4.3 Why "for free" is literal here

We are not adding a detector on top of the scheduler. The budget *is* the
scheduler's own bookkeeping — the quantity it already needs to decide who runs
next. Detection is reading a value the scheduler maintains anyway: is
the convertible budget over this set zero? Detection is the **boolean shadow** of
the scheduler's routing decision. The scheduler asks "where can budget still
convert?" (an optimization over a continuous quantity); detection asks "can it
convert *anywhere* in this set?" (the boolean `B(S) = 0`). Same quantity, one
steers, one tests.

### 4.4 The three invariants, in full

A system built on this budget satisfies three properties we name in systems
vocabulary. Each is a concrete predicate, not a sentiment, and each is stated
here in full.

- **Epistemic (evidence-tracking — truth that can update).** The system holds
  beliefs that update on evidence rather than freezing a belief and discarding
  the signal that would correct it. The timeout is a frozen belief about
  liveness; the budget floor is a *reading that updates* — it tracks confirmed
  non-conversion, and any single conversion resets it. No process is declared
  dead on suspicion. The system stops guessing the deadline and starts measuring
  the actual signal: whether progress was made. `(structural)`
- **Alignment (shared, not replacing — success runs through the whole).** A
  part's success runs through the whole's, and sharing the conserved quantity is
  load-bearing rather than charitable. A blocked process that *returns* its
  budget rather than holding it is what makes the deadlock legible. If a blocked
  process could hoard budget, the deadlock would be invisible and we would be
  back to timers. Detection works *because* processes share the conserved
  quantity — honest yield is what the detector reads. `(structural)`
- **Agency (every action benefits all).** No move helps a part at the whole's
  expense, because the conserved quantity only flows where it converts to
  progress. Declaring a deadlock benefits *all* parties — including the
  deadlocked pair, who are now *known*-dead and can be broken and rescheduled,
  rather than hanging indefinitely under a pessimistic timeout. The hoarding move
  is structurally unavailable, not merely forbidden by policy. `(structural)`

These three are not ethical decoration. §4.5 shows the alignment invariant has
teeth: a process that violates it (hoards budget) is dominated by the structure
itself, not by policy.

### 4.5 The hoarding theorem `(predicted; toy-supported)`

> **Theorem (hoarding is self-defeating).** In a connected dependency graph, the
> strategy "never yield budget" is dominated *for the hoarder*. A process `H`
> that hoards starves the processes it transitively depends on; those processes
> hold resources `H` needs; they never release; `H` deadlocks. `H`'s hoarding
> caused `H`'s own failure.

Therefore "selfish" and "self-defeating" coincide on a connected dependency
graph: `H` has no interest separable from the whole's, because every resource it
needs is downstream of some other process's progress. Sharing is not `H` trading
its interest for the system's — there is no trade, because the two objectives are
the same vector. The benefit-of-all scheduler is not *nicer* than the
priority-hoarding one; it is the **same computation without the false premise that
a part can win while the whole loses.** We prove the two-process instance in §6
(scenario 1, where `A`'s hold on `L1` is exactly what starves `B`, whom `A`
needs); the general statement is `(predicted)` and proved for the general case
in this series' capstone.

---

## 5. Related work (alignment with the field, including novel adjacencies)

**Classical deadlock theory.** Coffman's four conditions (1971:coffman-conditions)
and Holt's graph-theoretic treatment (1972:holt-graph) give the exact
criterion — circular wait / a cycle in the wait-for graph. We reuse the cycle
condition unchanged. Our departure is *when and how the check is triggered*: we
replace the timeout fallback, not the cycle test.

**Production timeout fallbacks.** InnoDB's `innodb_lock_wait_timeout` and
PostgreSQL's `deadlock_timeout` are the deployed timeout mechanisms. Both are
tunable precisely because no fixed duration is correct — the symptom our analysis
predicts. The budget replaces the *duration* variable with a *conversion-count*
variable.

**Fair queuing / virtual time** (Demers et al., 1989:fair-queuing). Attaches a
monotone scalar per flow to order service. Structurally adjacent — we also carry
a monotone scalar — but their scalar advances with *service*, ours only with
*progress*. A flow that is served-but-blocked advances virtual time; a process
that is scheduled-but-blocked does *not* refill budget. This difference is the
whole detection result.

**Credit-based flow control** (InfiniBand, datacenter fabrics). A sender holds
credits and may act only while credited. Our budget is credit-shaped, but credits
there are *granted by a receiver* to prevent overrun, whereas our budget is
*earned by conversion to progress* to detect under-run (no progress at all). The
direction of the signal is inverted: flow control prevents too-much, budget
detection catches too-little.

**Novel adjacency — Lockharts and evidence discarding** (authors' honesty series,
`iso-honesty:lockhart`). We import the claim that a system fails when it freezes a
belief and discards the evidence that could update it. A timeout is exactly such a
frozen belief about liveness. This connects deadlock detection to the broader
conservation-law thesis of that series: *one invariant — here, convertible
budget — can be irreversibly discarded (by committing to a clock), and the
failure is the discarding.* To our knowledge the progress-gated-budget-as-detector
framing is novel; we pre-register the claim and invite refutation.

---

## 6. Evaluation

### 6.1 Toy: `iso_deadlock.py` `(shown)`

A minimal scheduler: scripted processes, a shared lock manager, round-robin
service, a per-process budget refilled on progress and drained on a blocked
attempt. **There is no wall-clock primitive in the file** — `grep -niE
"time|sleep|clock|timeout|perf_counter|monotonic"` returns only prose in
comments. Detection latency is `rounds_to_confirm` (here, 3).

Six scenarios, six required verdicts:

| Scenario | Construction | Required | Result |
|---|---|---|---|
| 1. True deadlock (2-cycle) | AB-BA: `A` holds L1 wants L2; `B` holds L2 wants L1 | declare deadlock | **deadlock @ round 5** |
| 2. Slow-but-alive | one process does 15 units of pure work, never blocks | complete, no flag | **completed @ round 16** |
| 3. Resolvable contention | both want L1 in an order that resolves | complete, no flag | **completed @ round 6** |
| 4. N-process cycle (3) | `A→B→C→A` over locks L1,L2,L3 | declare deadlock, find the 3-cycle | **deadlock @ round 5, cycle A→B→C→A** |
| 5. Knot | 3-cycle `A→B→C→A` plus `D` holding L4, blocked waiting *into* L1 (held by A) | declare deadlock, localize to A,B,C; D doomed but off-cycle | **deadlock @ round 5, cycle = {A,B,C}, D floored but excluded** |
| 6. Contention tree, live root | three processes contend on L1 behind a live root | complete, no flag | **completed @ round 8** |

The traces show the mechanism, not a coincidence:

- **Scenario 1.** Rounds 1–2: both *spend* (acquire first lock, do work),
  budget pinned at 3. Rounds 3–5: each scheduled, finds the other's lock held,
  *returns* budget — 3→2→1→0. At round 5 both are at floor **and** the wait-chain
  closes `A→B→A`. Declared. The descent 3→2→1→0 *is* the conservation law (§4.1)
  executing; the floor-plus-cycle *is* the predicate (§4.2) firing.
- **Scenario 2.** The false-positive trap. `S_slow` runs far longer (15 rounds)
  than the deadlock took to detect (5). A timeout tuned to catch scenario 1 would
  abort `S_slow` here. The budget detector never flinches: `S_slow` *spends* every
  round, budget pinned at 3, never near the floor. **Slow and dead are
  distinguished** — the central claim.
- **Scenario 3.** Real contention without deadlock. `B` blocks on `A`'s lock,
  drains 3→2→1, then `A` releases, `B` converts, all finish. Budget drained
  without a closed cycle, so no false alarm — the cycle condition (§4.2 part 2)
  earning its place.

The first three scenarios establish the mechanism on a 2-cycle. The next three
test whether the predicate survives the cases that break naive detectors:
N-process cycles, knots, and the N>2 false-positive trap.

- **Scenario 4 (N-process cycle).** Three processes `A→B→C→A` over three locks.
  Rounds 1–2: all three *spend* (acquire first lock, work), budgets at 3. Rounds
  3–5: all three *return* in lockstep, 3→2→1→0. At round 5 all are floored and
  the DFS cycle-search recovers the full `A→B→C→A`. The 2-cycle was not special;
  the budget floor descends identically regardless of cycle length, because the
  conservation law (§4.1) is per-process and the cycle search (§4.2) is
  length-agnostic. `(shown)`
- **Scenario 5 (knot).** The case Gemini asked for. A 3-cycle `A→B→C→A`, plus a
  fourth process `D` that holds its own lock L4, does work, then blocks waiting
  *into* the cycle (it wants L1, held by `A`, released never). At round 5 **all
  four** processes are at the floor — `D` included, because `D` genuinely cannot
  progress. But the detector returns the cycle as **exactly {A, B, C}**, not the
  smeared set of four. This is the localization result: the **budget floor
  identifies who is stuck (all four); the cycle search identifies who is the
  cause (the three on the cycle).** `D` is a casualty waiting into the knot, not
  part of it. A detector that equated "floored" with "deadlocked" would wrongly
  group `D` into the cycle; separating the floor (liveness signal) from the cycle
  (permanence/causation signal) is exactly what keeps the diagnosis precise. This
  matters for resolution: you break the cycle by aborting one of {A,B,C}, and `D`
  then proceeds on its own — aborting `D` would resolve nothing. `(shown)`
- **Scenario 6 (contention tree, live root).** The N>2 false-positive trap.
  Three processes contend on one lock behind a live root. Budgets drain — `C`'s
  budget even passes the floor to −1 — but the live root keeps releasing, so no
  cycle ever closes and all three complete. **Many floored processes do not make
  a deadlock without a closed cycle.** Note budget going negative is harmless:
  the floor is a *threshold for candidacy*, and declaration is gated by the
  *cycle*, not by how far below zero a budget has fallen. A starved-but-rescuable
  process simply sits at-or-below the floor until its external holder releases.
  `(shown)`

**Verdict:** all six required outcomes met; zero false positives across 2-cycle,
3-cycle, knot, and two contention cases; the knot correctly localized to its
minimal cycle; detection latency = budget size, no wall clock. `(shown)`

### 6.2 Practical exam (real lock manager) `(predicted)`

The toy runs in a vacuum. `01-practical-exam.md` ports the predicate into a real
engine — SQLite (`BUSY`-handler budget) or InnoDB (sidecar over
`performance_schema.data_lock_waits` for wait-edges and `INNODB_TRX.trx_rows_modified`
as the progress signal). The integrity check is explicit: **budget may refill
only on `trx_rows_modified` increasing** — refilling on elapsed time, poll count,
or mere connection liveness smuggles a timer back in and voids the run.

Pre-registered predictions:

1. Budget detection declares true AB-BA deadlock in `rounds_to_confirm` polls,
   matching InnoDB's native cycle detector and arriving **before**
   `innodb_lock_wait_timeout`.
2. Zero false positives on a slow-but-progressing transaction, where any timeout
   short enough to catch the true case **will** false-fire.
3. **The crossover does not exist**: there is no single timeout both fast enough
   for the deadlock and slow enough to spare the slow transaction, once the slow
   transaction's honest work exceeds the deadlock's acceptable detection latency.
   This non-existence is the gap the budget closes — it reads *conversion*, not
   *duration*.

A failure of any prediction is the seed for Paper 02.

---

## 7. Further work (deeper into this wave, not the next paper)

These dive deeper into *detection specifically*, before the series moves on to
resolution and routing:

- **Probabilistic budget.** Replace the integer floor with `N_eff`-style evidence
  counting: how many *independent* confirmations of non-conversion before
  declaration? Connects to the honesty series' `N_eff` invariant directly.
- **Knot localization under churn.** §6 shows the detector localizes a static
  knot to its minimal cycle while correctly flagging off-cycle casualties as
  doomed-but-excluded. Open: does localization stay stable when the knot *grows*
  mid-detection — new processes waiting into it round by round — or can a late
  arrival transiently mislabel the minimal cycle?
- **Budget size vs. false-positive/latency tradeoff curve.** `rounds_to_confirm`
  is the one knob left. Characterize the curve: larger budget = later detection,
  but does it ever *re*-introduce false positives? (Conjecture: no — a deadlocked
  process never converts, so no budget size saves it; the curve is monotone in
  latency only.) `(predicted)`
- **Distributed setting.** When the wait-for graph spans nodes, the cycle
  condition needs a distributed cycle-detection pass, but the budget floor is
  *local* — each node can drain its own processes' budgets without coordination.
  Does locality of the floor reduce the coordination cost of distributed deadlock
  detection?
- **Adversarial slowness.** A process that converts *exactly one unit* just before
  hitting the floor, repeatedly, evades detection while making negligible
  progress — a livelock-shaped attack on the detector. Does the budget need a
  *rate* floor, not just a *zero* floor?

---

## 8. Conclusion

Deadlock detection by timeout is a system guessing, because it measures duration
when it means to measure progress. Put scheduling and yielding on one conserved
budget that is earned only by progress, and the right quantity appears: a scalar
that drains exactly when, and only when, no progress is being made. Deadlock is
then a fixed point of that scalar — budget floor plus a closed wait-cycle — and
it is *known*, in bounded steps, with no clock. The toy shows it: true deadlock
declared, slow process spared, contention resolved, zero false positives.

The deeper result is structural and outlasts the detector. The same conserved
budget routes priority for free, and it exposes that hoarding is
self-defeating on any connected dependency graph — the selfish and the global
optimum are one point. A process's continued functioning depends on the whole
functioning; refusing to share budget does not protect the process, it starves
the process. That is not a moral; it is a theorem about dependency graphs. The
moral, if one wants it, is available by isomorphism — and is left to the reader.

---

## Bibliography

- Coffman, E. G., Elphick, M., Shoshani, A. (1971). *System Deadlocks.* ACM
  Computing Surveys. — `1971:coffman-conditions`
- Holt, R. C. (1972). *Some Deadlock Properties of Computer Systems.* ACM
  Computing Surveys. — `1972:holt-graph`
- Demers, A., Keshav, S., Shenker, S. (1989). *Analysis and Simulation of a Fair
  Queueing Algorithm.* SIGCOMM. — `1989:fair-queuing`
- Oracle. *MySQL Reference Manual* — `innodb_deadlock_detect`,
  `innodb_lock_wait_timeout`. — `mysql:innodb-deadlock`
- PostgreSQL Global Development Group. *PostgreSQL Documentation* —
  `deadlock_timeout`. — `pg:deadlock-timeout`
- Franz, F. & Claude. *Honesty in LLMs* series — Lockharts and the conservation
  of independent evidence. — `iso-honesty:lockhart`, `iso-honesty:n-eff`

> Citation keys are permanent `Year:slug` / `series:slug` handles. Where a key
> resolves to a standard reference, the slug is the load-bearing identifier;
> full bibliographic resolution is secondary to seed stability.

---

## Appendix A — Reproducibility

- Artifact: `iso_deadlock.py`, committed at `090b4b0` (Team Phi).
- Run: `python3 iso_deadlock.py` — prints all three scenario traces and a
  verdict line `ALL CLAIMS HELD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_deadlock.py` returns only prose in comments — no wall-clock primitive is
  imported or called.
- Determinism: round-robin service, scripted programs, no RNG — the traces above
  reproduce exactly.

## Appendix B — The predicate in one screen

```
budget[p] = k  for all p          # k = rounds_to_confirm

each round:
    progress_made = false
    for p in processes:
        if attempt(p):             # converted budget -> progress
            budget[p] = k          # refill (spend model)
            progress_made = true
        else:                      # blocked -> return unspent
            budget[p] -= 1         # drain toward floor

    starved = { p : budget[p] <= 0 and not done(p) }
    if starved has a wait-cycle within itself:
        DECLARE DEADLOCK(that cycle)     # known, not timed
```

The entire detector is: drain on block, refill on progress, and check for a cycle
among the floored. No clock appears.
