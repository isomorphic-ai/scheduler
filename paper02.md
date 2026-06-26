# Paper 02 — Breaking a Knot Without Guessing Who Matters: Deadlock Resolution from the Conserved Ledger

**Series:** The Isomorphic Scheduler
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v1 · toy validated
**Artifact:** `iso_resolve.py` @ commit `9da696a`

> **TruthSeed (paper):** `iso-sched-02:victim-from-ledger`
> Once a deadlock is proven and its cycle localized, the victim to abort need
> not be chosen by a separate cost heuristic. The same conserved quantity that
> drives scheduling — converted progress — already ranks the candidates: the
> cheapest victim is the one that has converted the least. Choosing by this
> ledger is not merely cheaper than choosing by held-locks or priority; it is
> what makes resolution *converge*, because aborting expensive work re-creates
> expensive work.

---

## 0. Abstract

A deadlock detector tells you a set of processes is permanently stuck and, if it
localizes the cycle, *which* processes form it. It does not tell you what to do
next. Resolution — breaking the deadlock — requires choosing a **victim** to
abort and roll back, and the classical choice is a separate cost model: abort the
process holding the fewest locks, or the lowest priority, or the least work done,
by some externally supplied table. We show the cost model is already present in
the system as a conserved quantity, and need not be supplied separately.

Each process carries a ledger of **converted progress** — the units of work and
acquisition it has actually completed. Aborting a process discards exactly that
ledger, so converted progress *is* the cost of choosing it as victim. The
cheapest victim is the least-converted process on the cycle, read directly off
the ledger the scheduler already maintains. We further show this choice is not
just economical but **convergent**: a naive resolver that aborts the
*most*-converted process loses far more progress (666 units vs. 1 in our
ablation) and, worse, **livelocks** — it re-aborts the costly process forever,
because restarting expensive work reproduces the same expensive race. Selecting
the cheap victim terminates; selecting the expensive one does not.

We introduce three invariants for successful systems design:

1. **Epistemic (evidence-tracking).** The system acts on a measured ledger, not a
   guessed priority. *Here:* the victim is chosen from converted-progress counts
   the scheduler observes, not from an external importance table.
2. **Alignment (shared, not replacing).** A part's success runs through the
   whole's; sharing the conserved quantity is load-bearing, not charitable.
   *Here:* the least-converted process yields so the whole can proceed, and its
   sacrifice is minimal precisely because it had the least to lose.
3. **Agency (every action benefits all).** No move helps a part at the whole's
   expense, and no part is singled out to be sacrificed repeatedly. *Here:*
   symmetric cycles rotate the victim across restarts, so resolution never
   starves one fixed process to save the others.

The result generalizes: the same ledger that picks the victim ranks all processes
by sunk cost, which is the quantity any scheduler needs to make any trade-off.
The cost model was never external; it was the conserved quantity all along.

---

## 1. Problem revisited

A deadlock, once known, must be broken. The standard mechanism is **victim
selection and rollback**: choose one process in the deadlock, abort it, release
its held resources (which unblocks the others), and let it retry later. Every
database does a version of this; InnoDB rolls back "the transaction that has the
least number of inserted, updated, or deleted rows" as its victim heuristic.

The hard part is *which* process. The choice is governed by a **cost model**: a
function assigning each candidate a price of abortion. Classical cost models are
external inputs — process priority, number of locks held, wall-clock age, rows
modified — supplied to the resolver as policy. Two problems follow.

First, **the cost model is a second source of truth**, separate from whatever the
scheduler uses to run processes, and it can disagree with reality. A priority
table says process H is important; the actual work H has done may be trivial.
Aborting by priority then throws away the wrong thing.

Second, and subtler, **a bad cost model does not just cost more — it can fail to
terminate.** If the resolver keeps choosing a victim whose restart reproduces the
deadlock, the system loops: abort, restart, re-deadlock, abort, forever. This is
the cyclic-restart livelock, and it is a property of *which* victim is chosen, not
of the detector. A resolver can detect every deadlock perfectly and still never
make progress if it picks victims badly.

The problem revisited: **resolution needs a cost model that is (a) the same truth
the scheduler already runs on, and (b) chosen so that abortion does not reproduce
the deadlock.** We claim both fall out of the conserved budget.

---

## 2. Background

We assume the deadlock-detection setting: processes acquire and release locks; a
wait-for graph has edge `A → B` when `A` waits on a lock held by `B`; a directed
cycle is a deadlock (Coffman et al., 1971:coffman-conditions). Detection localizes
the cycle — the specific processes whose mutual waiting is the deadlock — as
distinct from processes merely blocked *behind* the cycle.

Resolution by victim rollback is standard (Bernstein, Hadzilacos & Goodman,
1987:concurrency-control, on transaction abort and cascading rollback). Victim
selection heuristics — minimum-cost abort, youngest-transaction, fewest-locks —
are surveyed in the same literature. InnoDB's least-rows-modified victim is the
deployed instance most readers will know (Oracle, MySQL Reference Manual).

Two classical hazards bound the design. **Starvation:** a resolver that always
picks the same victim (e.g. always the lowest-priority process) can abort it
indefinitely while others complete, starving it. The standard fix is to raise an
aborted process's priority on each restart (wound-wait / wait-die schemes, Rosenkrantz
et al., 1978:wound-wait, use transaction age to guarantee progress). **Cyclic
restart / livelock:** if the chosen victim's retry deterministically reproduces
the deadlock, no progress is made; randomization or back-off is the usual remedy.

Our contribution is to satisfy both from the conserved budget rather than from an
added priority/age field: the *converted-progress ledger* gives the cost model,
and *restart-count rotation* on that ledger gives starvation- and
livelock-freedom — without a wall clock and without an external importance table.

---

## 3. Sharpening: the cost model is already in the budget

Here is the move.

The detector (companion result) maintains, per process, a budget refilled by
*progress* and drained by *blocked attempts*. To run that detector we already
distinguish a scheduled attempt that **converts** (makes progress) from one that
**returns** (blocked). Count the conversions and you have a per-process ledger:
**`converted` = the total units of progress this process has actually
completed** — work done plus locks acquired.

Now ask what abortion costs. Aborting a process releases its locks and rewinds it
to the start, discarding everything it has done this attempt — discarding exactly
`converted`. So:

> **`converted` is not a proxy for the cost of abortion. It is the cost of
> abortion.** `(structural)`

The cost model we were going to supply externally is identical to a quantity the
scheduler already tracks to detect the deadlock in the first place. The
least-converted process on the cycle is the cheapest victim, by definition, with
no priority table, no age field, no rows-modified special case. The same ledger
that tells us *who is stuck* (via the budget floor) tells us *who is cheapest to
abort* (via the converted count). One conserved quantity, two readings.

The wrong framing was "detection finds the deadlock, then a separate policy
decides the victim." The right framing: **the victim is another reading of the
same ledger.** Detection and resolution are not two subsystems with two truths;
they are two queries against one conserved quantity.

---

## 4. The solution

### 4.1 The ledger and the victim rule `(structural)`

Each process maintains `converted`, incremented on every scheduled attempt that
makes progress (a unit of work, or acquiring a free lock), and reset to zero when
the process is aborted and restarted. The resolver, given a proven cycle `C`:

> **Victim rule.** Abort `argmin_{p ∈ C} (converted(p), restart_count(p), id(p))`.

The primary key is converted progress (cheapest to abort). The secondary key,
`restart_count`, is the rotation that prevents livelock and starvation (§4.3).
The tertiary key is a stable id for determinism. Aborting the victim releases its
locks — which is precisely what unblocks the rest of the cycle — and rewinds it.

### 4.2 Why the cheap victim converges, and the expensive one does not `(shown)`

The economical reading of the victim rule is obvious: lose the least progress.
The structural reading is the real result.

Consider an *uneven* cycle: process A has converted 5 units behind its held lock
before deadlocking; process B has converted almost nothing. Abort B (cheap): B
had not yet entrenched itself, so on restart A — already deep in its work —
proceeds, releases, and B reruns cleanly. The deadlock is gone in one abort.

Abort A (expensive): A releases, restarts, and *re-does its 5 units of work*,
re-acquiring the same lock and re-entering the same race with B. The deadlock
reforms. Abort A again. A re-converts 5 units again. Forever. **Aborting
expensive work re-creates expensive work**, so the expensive victim is also the
one whose abortion reproduces the deadlock. The cheap victim is cheap *and*
terminating; the expensive victim is costly *and* looping. These are the same
property seen twice: a process deep in converted progress is deep in the
structure that caused the deadlock, so removing it removes the least of that
structure.

This is why the ledger-based cost model is not a mere optimization. Choosing the
minimum-converted victim is a **convergence condition**, not just an economy.
`(shown; see §6 ablation: free model completes losing 1 unit; naive
most-converted model livelocks, 666 units lost over 111 aborts)`

### 4.3 Rotation: symmetric cycles and the no-fixed-victim rule `(shown)`

When all processes on the cycle have converted equally (a *symmetric* deadlock —
AB-BA, or a 3-cycle where each did one unit), the converted key ties, and a
purely deterministic resolver picks the same victim every time. That victim
restarts into the identical symmetric race and re-deadlocks: cyclic-restart
livelock again, this time from symmetry rather than from cost.

The secondary key fixes it. `restart_count` ascending means: among equally-cheap
victims, prefer the one aborted *fewest* times. After aborting A once, A's
restart_count is 1 and the others are 0, so the next resolution picks a different
process. The victim **rotates** across the cycle. In a 2-cycle this resolves in
two aborts (abort A, the race re-forms, abort B, now one side runs free); in our
runs the 3-cycle and the knot resolve in the same two aborts, because once two of
the three are forced to take turns, the cycle opens. `(shown)`

Rotation is the *agency* invariant made concrete: **no single process is
sacrificed repeatedly to save the rest.** It is also starvation-freedom without a
clock — wound-wait raises priority by transaction *age* (a wall-clock-adjacent
quantity); we rotate by abort *count* (a pure event count), so the guarantee
holds with no timer.

### 4.4 The three invariants, in full

A resolver built on this ledger satisfies three properties we name in systems
vocabulary. Each is a concrete predicate, not a sentiment, and each is stated
here in full.

- **Epistemic (evidence-tracking — truth that can update).** The system acts on
  a measured quantity that updates with the work, not a frozen external belief
  about importance. The victim is chosen from `converted`, which the scheduler
  observes directly and which changes as processes run; it is not read from a
  priority table fixed in advance and possibly contradicted by what processes
  actually did. A process that has converted little is cheap to abort *because it
  measurably did little*, and that reading updates every round. `(structural)`
- **Alignment (shared, not replacing — success runs through the whole).** A
  part's success runs through the whole's, and yielding the conserved quantity is
  load-bearing rather than charitable. The least-converted process is aborted so
  the whole can proceed; this is the part with the least to lose yielding to
  unblock the rest, and its loss is minimal *because* it had converted least.
  Resolution works by one process sharing its place in the schedule, not by the
  resolver overriding the system from outside. `(structural)`
- **Agency (every action benefits all).** No move helps a part at the whole's
  expense, and no part is singled out to be sacrificed indefinitely. Aborting the
  cheap victim unblocks every other process on the cycle; and the rotation rule
  guarantees that across repeated resolutions the burden of being victim is
  shared, never pinned on one process. The benefit of resolution — progress for
  the whole — reaches even the aborted process, which is restarted and completes
  rather than hanging forever. `(structural)`

These three are not ethical decoration. §4.2 shows the alignment/agency reading
has teeth: the resolver that violates them — sacrificing the process with the
*most* converted progress, overriding the ledger — does not merely cost more, it
fails to terminate.

---

## 5. Related work

**Victim selection and rollback** (Bernstein, Hadzilacos & Goodman,
1987:concurrency-control). The classical treatment of choosing and aborting a
deadlock victim, including minimum-cost-abort heuristics. We reuse the
abort-and-restart mechanism unchanged; our departure is the *source* of the cost
function — a conserved quantity the scheduler already maintains, rather than an
external policy input.

**InnoDB least-rows-modified victim** (Oracle, MySQL Reference Manual). The
deployed heuristic closest to ours: roll back the transaction that changed the
fewest rows. This is, in effect, a converted-progress proxy restricted to writes.
Our ledger generalizes it (any forward-state conversion counts, not only row
writes — the read-only-progress point raised in the companion practical exam) and,
crucially, we show the heuristic is not just economical but **convergent** — a
property the rows-modified rule has but, to our knowledge, is not analyzed as
such in the manual's framing.

**Wound-wait / wait-die** (Rosenkrantz, Stearns & Lewis, 1978:wound-wait).
Deadlock *prevention* by transaction age: older transactions wound younger ones
(or younger ones die and retry), with age guaranteeing progress and
starvation-freedom. Structurally adjacent to our rotation — both prevent one
process being victimized forever — but age is a wall-clock-derived total order,
whereas our `restart_count` is a pure event count. We obtain the same
starvation-freedom guarantee without introducing a clock, which matters for the
series' epistemic invariant (never act on duration where a conserved count will
do).

**Novel adjacency — convergence as a victim-selection criterion.** The
literature frames victim choice as cost minimization (lose the least work) and
treats livelock separately, fixed by randomization or back-off. We observe that
on an uneven cycle the *same* choice — minimum converted progress — delivers both
the cost minimum and convergence, because the quantity that makes a victim
expensive (deep converted progress) is the quantity that makes its abortion
reproduce the deadlock. Cost and convergence are not two criteria to balance; on
this ledger they are the same criterion. To our knowledge this identity is not
stated in the deadlock-resolution literature; we pre-register it as a claim and
invite refutation.

---

## 6. Evaluation

### 6.1 Toy: `iso_resolve.py` `(shown)`

The detector engine, extended with a `converted` ledger and a resolver that, on a
proven cycle, aborts the minimum-`(converted, restart_count, id)` victim, releases
its locks, and rewinds it. **No wall-clock primitive is present.** Detection
latency and resolution both run on event counts.

Four scenarios run in resolve mode; all must complete:

| Scenario | Construction | Result | Aborts | Converted lost |
|---|---|---|---|---|
| AB-BA 2-cycle | symmetric mutual lock | **completed @ r17** | A then B (rotation) | 4 |
| 3-cycle A-B-C | symmetric 3-process cycle | **completed @ r19** | A then B | 4 |
| Knot (D off-cycle) | 3-cycle + D waiting in | **completed @ r19** | A then B (D never aborted) | 4 |
| Uneven cost | A converted 5, B ~0, before deadlock | **completed @ r15** | B only | 1 |

Readings:

- **Symmetric cycles resolve by rotation.** AB-BA, the 3-cycle, and the knot all
  take exactly two aborts (A then B): the converted counts tie, so the first
  abort picks A, the race re-forms, and the second abort picks B (now the
  least-restarted), which opens the cycle. The knot is notable: **D is never
  aborted** — it was off the cycle (a casualty, not a culprit), so the resolver
  correctly leaves it alone and it proceeds once the cycle clears. Localization
  from the detector pays off directly in resolution: you abort a culprit, not a
  casualty. `(shown)`
- **The uneven cycle resolves with one cheap abort.** A had converted 5 units; B
  almost none. The resolver aborts **B**, losing 1 unit, and the system completes.
  The conserved ledger picked the cheap victim with no priority table. `(shown)`

### 6.2 Ablation: free cost model vs. naive `(shown)`

To show the ledger choice is load-bearing, we replace the victim rule with a
**naive** one — abort the *most*-converted process — and rerun the uneven cycle:

| Resolver | Victim rule | Outcome | Converted lost |
|---|---|---|---|
| Free (ledger) | min converted | **completed** | **1** |
| Naive | max converted | **livelock (max_rounds)** | **666 over 111 aborts** |

The naive resolver aborts A (5 units), A restarts, re-converts 5 units, re-enters
the same race, deadlocks again — 111 times, until the round cap. It does not
merely lose 666× more progress; **it never terminates.** The free model completes
losing a single unit. This is §4.2's claim, measured: minimum-converted victim
selection is a convergence condition, not just an economy. `(shown)`

### 6.3 Practical exam pointer

The companion practical exam (real lock manager, SQLite/InnoDB) already defines
the converted-progress signal that this resolver consumes — broadened beyond
row-writes to any forward-state advancement. Porting the resolver means: on the
sidecar's detection of a cycle, abort the transaction with the least forward-state
conversion in that cycle (which maps closely to InnoDB's existing
least-rows-modified victim), and verify the convergence property holds against a
real engine's rollback. A failure there is the next seed.

---

## 7. Further work (deeper into this wave)

- **Convergence proof.** §4.2 shows convergence empirically and argues it
  structurally; a proof is owed. Conjecture: on any cycle, aborting a
  minimum-converted victim strictly reduces a well-founded measure (total
  re-convertible work entrenched in the cycle), so resolution terminates in
  finitely many aborts. `(predicted)`
- **Cost when progress is not unit-valued.** Our `converted` counts uniform
  units. Real work is heterogeneous (a row insert ≠ a full-table scan). Does the
  victim rule survive weighting conversions by true cost, and does the
  cost/convergence identity of §4.2 survive it?
- **Multi-cycle / knot with several disjoint cycles.** One abort breaks one
  cycle; a tangle with several independent cycles needs several. Does
  least-converted-per-cycle compose, or can breaking one cycle cheapen/worsen the
  victim choice in another?
- **Rotation fairness under asymmetry.** Rotation is clean when converted counts
  tie. When they nearly tie but not exactly, the converted key dominates and
  rotation never engages — can a near-symmetric cycle still pin one victim? Does
  the tie need a tolerance band (and does a band reintroduce a tunable knob)?
- **Resolution vs. the scheduler proper.** Here resolution is a discrete event on
  a proven deadlock. The next movement of the series uses the same ledger
  *continuously* — to route budget and prevent the deadlock forming at all rather
  than break it after. The victim cost model is the static shadow of that dynamic
  routing.

---

## 8. Conclusion

Detecting a deadlock leaves a question detection cannot answer: which process to
abort. The classical answer imports a cost model — priority, locks held, rows
modified — as external policy, a second truth that can disagree with what
processes actually did and that, chosen badly, makes resolution loop forever. We
show the cost model was already present. The conserved quantity the scheduler
tracks to detect the deadlock — converted progress — is exactly the cost of
aborting a process, because abortion discards exactly that. The cheapest victim is
the least-converted process on the cycle, read off the ledger with no added table.

And the cheap victim is not merely cheap. Because deep converted progress is deep
entrenchment in the structure that caused the deadlock, aborting the expensive
process reproduces the deadlock while aborting the cheap one dissolves it: minimum
converted progress is a convergence condition. The ablation makes the gap stark —
one unit lost and done, versus a livelock losing hundreds. Symmetric cycles, where
cost ties, are resolved by rotating the victim on abort count, giving
starvation-freedom with no clock. Detection and resolution are not two subsystems
with two truths; they are two readings of one conserved ledger. The cost model was
never external. It was the conserved quantity all along.

---

## Bibliography

- Coffman, E. G., Elphick, M., Shoshani, A. (1971). *System Deadlocks.* ACM
  Computing Surveys. — `1971:coffman-conditions`
- Bernstein, P. A., Hadzilacos, V., Goodman, N. (1987). *Concurrency Control and
  Recovery in Database Systems.* Addison-Wesley. — `1987:concurrency-control`
- Rosenkrantz, D. J., Stearns, R. E., Lewis, P. M. (1978). *System Level
  Concurrency Control for Distributed Database Systems.* ACM TODS. —
  `1978:wound-wait`
- Oracle. *MySQL Reference Manual* — InnoDB deadlock detection and victim
  selection (least-rows-modified). — `mysql:innodb-deadlock`

> Citation keys are permanent `Year:slug` handles; the slug is the load-bearing
> identifier, full bibliographic resolution secondary to seed stability.

---

## Appendix A — Reproducibility

- Artifact: `iso_resolve.py`, committed at `9da696a` (Team Phi).
- Run: `python3 iso_resolve.py` — prints all four resolve-mode scenarios, the
  per-scenario abort log and converted-progress lost, and the free-vs-naive
  ablation, ending in `ALL CLAIMS HELD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_resolve.py` returns only prose in comments.
- Determinism: round-robin service, scripted programs, stable id tie-break, no
  RNG — traces reproduce exactly.

## Appendix B — The resolver in one screen

```
on DEADLOCK(cycle):                      # cycle from the detector
    victim = argmin over p in cycle of
                 (converted[p], restart_count[p], id[p])
    release all locks held by victim     # this unblocks the rest of the cycle
    rewind victim to start of its program
    converted[victim] = 0
    restart_count[victim] += 1
    refresh budget of the other cycle members
    continue                             # system now makes progress

# converted[p] increments on every scheduled attempt that makes progress
# (a unit of work, or acquiring a free lock). It is the cost of aborting p,
# and the minimum over the cycle is both the cheapest and the convergent victim.
```

No clock appears. The victim is a reading of the same conserved ledger the
detector uses; rotation by restart_count gives starvation- and livelock-freedom.
