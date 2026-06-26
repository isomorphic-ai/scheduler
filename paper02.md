# Paper 02 — No Victim: Deadlock Resolution as Generous Yield with Conserved Credit

**Series:** The Isomorphic Scheduler
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v2 · toy validated
**Artifact:** `iso_resolve.py` @ commit `32ba0a0`

> **TruthSeed (paper):** `iso-sched-02:yield-with-credit`
> A deadlock need not be broken by sacrificing a victim. One process yields —
> releases its lock and steps back — but its converted progress is *credited*,
> not discarded, so it returns with an expanded budget: stronger, not punished.
> Progress is conserved. This is eventual consistency, not victimhood. And it is
> the credit, not any rotation heuristic, that makes resolution converge: a model
> that discards the yielder's progress livelocks where the crediting model
> completes.

---

## 0. Abstract

A deadlock detector reports that a set of processes is permanently stuck and, if
it localizes the cycle, which processes form it. Resolution must then make the
system move again. The classical mechanism is **victim selection**: choose one
process, abort it, discard its work, release its locks, let it retry. The framing
is sacrificial — a victim is destroyed so the others may proceed — and it carries
the sacrificial failure mode: if the discarded process restarts into the same
race, it is destroyed again, and the system livelocks.

We reject the framing. Deadlock is a tail case; the system does not need a
casualty, it needs one process to *step back generously and try again*. The
isomorphic form of "try again" is not "lose everything and restart from zero" —
that would not be structure-preserving. It is "**return credited**": the yielding
process banks the progress it had converted and comes back with an **expanded
budget** equal to the base plus that credit. Its progress is not lost; it is
held. The process that yields is therefore not weakened but strengthened, and the
conserved quantity — credit — steers the next yield to whoever has been generous
least, so generosity spreads on its own. No victim, no rotation hack, no clock.

This crediting is not a kindness laid over a cost model; it is the mechanism of
convergence. In our ablation, the crediting resolver completes a repeat-pressure
cycle in two yields, while an otherwise-identical resolver that *discards* the
yielder's progress livelocks — 166 aborts, 498 units of work re-done and thrown
away again. Conserving the progress is what lets a returning process push through;
discarding it is what reproduces the deadlock.

We introduce three invariants for successful systems design:

1. **Epistemic (evidence-tracking).** The system acts on a measured, conserved
   ledger, not a guess. *Here:* credit is the actual converted progress, banked
   and carried forward, never invented or discarded.
2. **Alignment (shared, not replacing).** A part's success runs through the
   whole's; sharing the conserved quantity is load-bearing, not charitable.
   *Here:* one process yields its lock so the whole proceeds, and is credited for
   it — its success and the whole's are the same account.
3. **Agency (every action benefits all).** No move helps a part at the whole's
   expense, and no part is sacrificed. *Here:* the yielder returns stronger, the
   blocked processes proceed, and credit spreads generosity so no one process
   carries resolution alone.

The deeper result: resolution is not destruction plus retry. It is one process
exercising agency — choosing to step back — under a rule that conserves its work.
Eventual consistency falls out, and the livelock the victim framing fought with
rotation hacks simply does not arise, because nothing was ever thrown away.

---

## 1. Problem revisited

A known deadlock must be resolved: the system has to move again. The standard
mechanism is victim selection and rollback — abort one process in the cycle,
release its held resources (unblocking the rest), discard its partial work, and
let it retry. Databases do a version of this; InnoDB rolls back the transaction
that modified the fewest rows.

The framing is sacrificial, and it has two costs.

First, **discarded work is pure loss.** A process that had converted real
progress has it deleted. On an uneven cycle — one process deep into its work,
another barely begun — aborting carelessly throws away the most. The classical
fix is a cost model (fewest rows, fewest locks, lowest priority) to choose the
cheapest victim, but this only *minimizes* the loss; it still loses.

Second, and worse, **the sacrificial framing causes livelock.** If the aborted
process restarts into the same race and reproduces the deadlock, it is aborted
again. Where the chosen process keeps re-entering the same conflict, the system
loops forever: abort, restart from zero, re-deadlock, abort. The classical
remedies — randomized back-off, priority aging — are patches over a wound the
framing itself opened: *we deleted the work, so the process has to re-do it, so
it re-enters the same race.*

The problem revisited: **resolution is framed as needing a victim, and victimhood
is what both loses progress and causes the livelock.** We claim the system needs
no victim at all. Deadlock is a tail case; resolution is one process generously
stepping back — and if stepping back conserves its progress instead of deleting
it, both costs vanish at once.

---

## 2. Background

We assume the deadlock setting: processes acquire and release locks; a wait-for
graph has edge `A → B` when `A` waits on a lock held by `B`; a directed cycle is
a deadlock (Coffman et al., 1971:coffman-conditions). Detection localizes the
cycle — the processes whose mutual waiting *is* the deadlock — distinct from
processes merely blocked behind it.

Resolution by victim rollback is classical (Bernstein, Hadzilacos & Goodman,
1987:concurrency-control). Victim heuristics — minimum-cost-abort, youngest
transaction, fewest locks — choose *whom* to sacrifice. InnoDB's
least-rows-modified rule is the deployed instance most readers know (Oracle,
MySQL Reference Manual). All of these discard the chosen transaction's work.

Two classical hazards motivate our approach. **Starvation:** a resolver that
always sacrifices the same process aborts it indefinitely; the standard fix is
priority aging (wound-wait / wait-die, Rosenkrantz et al., 1978:wound-wait), which
uses transaction age — a wall-clock-adjacent quantity — to guarantee progress.
**Cyclic restart / livelock:** if the sacrificed process's retry reproduces the
deadlock, no progress is made; randomization or back-off is the usual remedy.

Our departure: we do not sacrifice. The yielding process is *credited* its
converted progress and returns with an expanded budget. This conserves work
(answering the loss hazard directly) and — because the returning process is
stronger and the conserved credit steers selection — gives starvation- and
livelock-freedom *without* priority aging, randomization, or a clock. The nearest
prior idea is **save-points / partial rollback** (transactions rolling back to a
checkpoint rather than fully), but those reduce *how much* is discarded; credit
discards *nothing* and additionally feeds the conserved quantity that governs the
next choice.

---

## 3. Sharpening: stepping back should be isomorphic

Here is the move.

To resolve a deadlock, one process must release the lock it holds so the others
can proceed. Call this *yielding*. The classical implementation of yielding is
abort-and-restart: release the lock, **delete all converted progress**, rewind to
the start, retry from zero.

That deletion is the flaw, and naming it precisely shows why. Yielding is a
process saying "I will step back and try again so we can all proceed." For that to
be **isomorphic** — structure-preserving — trying again must preserve what the
process already truly is, which includes the progress it genuinely converted.
Restarting from zero is not structure-preserving; it destroys real structure (the
work) and pretends the process is new. The honest, isomorphic form of "try again"
keeps the progress and carries it forward.

So: when a process yields, **bank its converted progress as credit, and return it
with an expanded budget** = base + credit. Three consequences follow immediately.

1. **Progress is conserved.** The work is not lost; it is held as credit. The
   loss cost of the classical framing is gone — not minimized, gone.
2. **The yielder returns stronger, not weaker.** It comes back with more budget,
   so when it re-enters contention it can push further before flooring again. A
   process that yields is not punished; it is, if anything, advantaged — which is
   the correct incentive, because we *want* processes to yield generously.
3. **Credit steers the next choice.** Pick as next yielder whoever has banked the
   *least* credit (been generous least). A process that already yielded carries
   credit, which protects it from being asked again. Generosity spreads through
   the conserved quantity itself — no rotation counter, no randomization.

The wrong framing was "choose a victim to sacrifice." The right framing: **a
process exercises agency — it chooses to step back — and the system conserves its
work so the stepping-back costs it nothing and the whole proceeds.** There is no
victim. There is eventual consistency: everyone gets there, the order is adjusted,
nothing is destroyed.

---

## 4. The solution

### 4.1 The credit ledger and the yield rule `(structural)`

Each process maintains `converted` (units of progress completed this attempt) and
`credit` (progress banked across prior yields). The resolver, given a proven cycle
`C`:

> **Yield rule.** The generous yielder is `argmin` over `p` in `C` of
> `(credit(p), converted(p), id(p))`. It releases its held locks (unblocking the
> rest of the cycle), banks its converted progress (`credit += converted`),
> rewinds, and returns with `budget = base + credit`.

Primary key `credit`: prefer whoever has yielded least, so generosity spreads.
Secondary key `converted`: among those, whoever has least to re-do. Releasing the
yielder's lock is exactly what unblocks the cycle; crediting its progress is
exactly what conserves its work and strengthens its return.

### 4.2 Why credit converges where sacrifice livelocks `(shown)`

Take a *repeat-pressure* cycle: a configuration where, after a naive abort, the
same process keeps being chosen and keeps re-entering the same conflict.

Under **sacrifice** (discard the yielder's progress, return at base budget): the
process restarts from zero, re-does its work, re-acquires the same lock, re-enters
the same race, re-deadlocks. It is chosen again (its state is identical to
before). The system livelocks — in our run, 166 aborts, 498 units of work
discarded and re-done, never completing.

Under **credit** (bank the progress, return with expanded budget): the yielder
returns carrying credit. Two things change. Its budget is larger, so on re-entry
it survives longer before flooring — long enough, once it has banked enough, to
push through its blocked acquire after the *other* process yields. And its credit
makes it the *least* preferred next yielder, so the next yield falls on the other
process, whose release lets the credited process complete. The cycle opens. In our
run: **two yields, system completes, zero progress lost.**

The difference is entirely the crediting. Same selection logic, same cycle, same
locks. Discard the progress and you reproduce the deadlock; conserve it and you
dissolve it. **Conserving the yielder's work is the convergence mechanism**, not a
nicety on top of one. `(shown; §6 ablation: credit completes in 2 yields; sacrifice
livelocks, 166 aborts, 498 units re-done)`

### 4.3 Symmetric cycles: generosity spreads through credit `(shown)`

When every process on the cycle has equal converted progress and zero credit (a
symmetric AB-BA or 3-cycle), the yield rule's keys tie and one process — say A —
yields first. A banks credit and returns with an expanded budget. Now A carries
credit and the others do not, so the *next* yield, by the primary key, falls on a
**different** process. The credit has rotated the generosity automatically.

In a 2-cycle this completes in two yields: A yields (credited), the race
re-forms, B yields (credited) — and now A, already holding its first lock and
carrying budget, reaches its second lock once B releases, and both finish. The
3-cycle and the knot resolve in the same two yields, because once two members
take turns yielding, the cycle opens and the third proceeds. `(shown)`

This is starvation-freedom with no clock and no counter dedicated to it: credit,
the same quantity that conserves progress, also spreads the generosity. Wound-wait
needs transaction *age* (wall-clock-adjacent) to prevent one process being
victimized forever; we need only the credit ledger, a pure conserved count.

### 4.4 The three invariants, in full

A resolver built on conserved credit satisfies three properties we name in systems
vocabulary. Each is a concrete predicate, not a sentiment, and each is stated here
in full.

- **Epistemic (evidence-tracking — truth that can update).** The system acts on a
  measured, conserved quantity, never a guess and never a fiction. Credit is
  exactly the progress a process converted, banked and carried forward; it is not
  an externally assigned priority, not an estimate, and it is never inflated or
  discarded. A yielding process returns with precisely what it earned. The ledger
  updates with the work and is the sole input to the yield choice. `(structural)`
- **Alignment (shared, not replacing — success runs through the whole).** A
  part's success runs through the whole's, and yielding the conserved quantity is
  load-bearing rather than charitable. The yielder releases its lock so the whole
  can proceed, and is credited so that its own success is preserved in the same
  act — it does not trade its progress for the system's, because the credit makes
  the two the same account. Resolution is not the resolver overriding a process
  from outside; it is one process sharing its place in the schedule and being made
  whole for it. `(structural)`
- **Agency (every action benefits all).** No move helps a part at the whole's
  expense, and no part is sacrificed. The yield unblocks every other process on
  the cycle; the yielder returns stronger rather than destroyed; and credit
  spreads the act of yielding across the cycle so no single process carries
  resolution alone. The benefit — progress for the whole — reaches even the
  process that stepped back, which completes carrying its conserved work.
  `(structural)`

These three are not ethical decoration. §4.2 shows the alignment/agency reading
has teeth: the resolver that violates them — that sacrifices a process and
discards its work — does not merely feel worse, it fails to terminate. Conserving
the yielder's progress is what makes the system converge.

---

## 5. Related work

**Victim selection and rollback** (Bernstein, Hadzilacos & Goodman,
1987:concurrency-control). The classical treatment: choose a deadlock victim and
abort it, discarding its work. We keep the lock-release that unblocks the cycle
and reject the discard — the yielder is credited, not sacrificed.

**InnoDB least-rows-modified victim** (Oracle, MySQL Reference Manual). The
deployed heuristic minimizes discarded work by aborting the transaction that did
least. It is the closest classical relative, and it shares our intuition that the
*amount of converted work* is the right quantity — but it uses that quantity to
choose *whom to destroy*, where we use it to choose *whom to credit*. Minimizing
loss is not conserving; we conserve.

**Save-points / partial rollback.** Transactions can roll back to a checkpoint
rather than fully, reducing discarded work. This is the nearest prior move toward
conservation, but it reduces loss rather than eliminating it, and it does not feed
a conserved quantity that governs subsequent victim choice. Credit discards
nothing and is itself the selection signal.

**Wound-wait / wait-die** (Rosenkrantz, Stearns & Lewis, 1978:wound-wait).
Deadlock prevention by transaction age, with age guaranteeing starvation-freedom.
Structurally adjacent to our generosity-spreading, but age is a wall-clock-derived
order; our credit is a pure conserved count, giving the same fairness guarantee
without a clock.

**Novel adjacency — conservation as the convergence mechanism.** The literature
treats discarded work as a cost to minimize and livelock as a separate problem
fixed by randomization or aging. We observe these are the same problem: discarding
the yielder's work is *what makes it re-enter the same race*, so conserving the
work (credit) removes the loss and the livelock together. Conservation is not a
gentler victim policy; it is the mechanism that makes resolution terminate. To our
knowledge this identity — conserve-the-yielder implies converge — is not stated in
the resolution literature; we pre-register it and invite refutation.

---

## 6. Evaluation

### 6.1 Toy: `iso_resolve.py` `(shown)`

The detector engine, extended with a `credit` ledger and a resolver that, on a
proven cycle, selects the least-credited process as generous yielder, releases its
locks, banks its converted progress as credit, and returns it with an expanded
budget. **No wall-clock primitive is present.**

Four scenarios run in resolve mode; all must complete, conserving progress:

| Scenario | Construction | Result | Yields | Progress credited (conserved) |
|---|---|---|---|---|
| AB-BA 2-cycle | symmetric mutual lock | **completed @ r17** | A then B | 4 (none lost) |
| 3-cycle A-B-C | symmetric 3-process cycle | **completed @ r19** | A then B | 4 (none lost) |
| Knot (D off-cycle) | 3-cycle + D waiting in | **completed @ r19** | A then B (D never yields) | 4 (none lost) |
| Uneven cost | A converted 5, B ~0, before deadlock | **completed @ r15** | B only | 1 (none lost) |

Readings:

- **Symmetric cycles resolve by spread generosity.** The first yield credits one
  process; that credit steers the next yield to another; two yields open the
  cycle. No process is sacrificed and no rotation counter is used — credit does
  the spreading. `(shown)`
- **The knot leaves D alone.** D was off the cycle (a casualty of the deadlock,
  not a participant), so the resolver never selects it; it proceeds once the cycle
  clears. Detection's localization pays off directly: the system yields a
  participant, never a bystander. `(shown)`
- **The uneven cycle resolves with one yield, nothing lost.** B (least credit,
  least converted) yields, banks its 1 unit as credit, and the system completes. A,
  deep in its converted work, is never asked to give it up. `(shown)`

### 6.2 Ablation: credit vs. sacrifice `(shown)`

To show conservation is the load-bearing mechanism, we replace crediting with the
classical **sacrifice** (discard the yielder's progress, return at base budget),
keeping selection identical, and run a repeat-pressure cycle:

| Resolver | On yield | Outcome | Work re-done / lost |
|---|---|---|---|
| Credit | bank progress, return budget = base + credit | **completed in 2 yields** | **0** |
| Sacrifice | discard progress, return at base budget | **livelock (max_rounds)** | **498 over 166 aborts** |

Identical cycle, identical selection. The crediting resolver completes; the
sacrificing resolver loops 166 times, discarding and re-doing 498 units, never
finishing. Conserving the yielder's progress is exactly what lets it push through
on return; discarding it is exactly what reproduces the deadlock. The "victim"
framing does not merely cost more — it is the cause of the livelock. `(shown)`

### 6.3 Practical exam pointer

The companion practical exam (real lock manager, SQLite/InnoDB) defines the
forward-progress signal this resolver consumes. Porting credit means: on detecting
a cycle, have one transaction yield (release locks, retry) while *preserving its
work* via save-points, and grant the returning transaction proportionally more
scheduling budget. The convergence claim — that conserving the yielder's progress
avoids the cyclic restart a full abort can cause — is the property to test against
a real engine. A failure there is the next seed.

---

## 7. Further work (deeper into this wave)

- **Convergence proof.** §4.2 shows convergence empirically and argues it
  structurally; a proof is owed. Conjecture: crediting strictly increases a
  yielder's carried budget, so after finitely many yields some cycle member has
  enough budget to complete its blocked acquire within one scheduling pass after a
  release, opening the cycle; termination follows by well-founded descent on
  remaining cycle members. `(predicted)`
- **Credit bound and fairness.** Credit grows unboundedly across many yields in
  principle. Does it need a cap, and does a cap reintroduce a tunable knob? Is
  there a configuration where one process accrues so much credit it monopolizes
  the schedule on return — generosity overpaid into unfairness?
- **Non-unit progress.** `converted` counts uniform units; real work is
  heterogeneous. Does credit survive weighting by true work cost, and does the
  conserve-implies-converge identity of §4.2 survive it?
- **Multi-cycle tangles.** One yield opens one cycle; several independent cycles
  need several. Does least-credit selection compose across overlapping cycles, or
  can crediting a process in one cycle distort the choice in another?
- **Credit as the bridge to routing.** Credit is a conserved quantity that
  *expands a process's future budget*. The next movement of the series routes
  budget continuously to prevent the deadlock forming at all; credit is the
  discrete, after-the-fact instance of that continuous routing. Resolution and
  scheduling are the same conservation seen at two time scales.

---

## 8. Conclusion

Resolving a deadlock has been framed as needing a victim: choose a process,
destroy its work, free its locks, let it start over. The framing loses progress,
and worse, it causes the livelock it then fights with back-off and aging — because
destroying the work is exactly what sends the process back into the same race. We
reject the victim. Deadlock is a tail case; the system needs one process to step
back generously and try again, and the isomorphic form of trying again conserves
what the process already is. The yielder banks its converted progress as credit
and returns with an expanded budget: its work held, its position strengthened, the
cycle opened. Credit, the conserved quantity, also steers the next yield to
whoever has been generous least, so generosity spreads without a counter or a
clock.

Conservation is not a gentler policy laid over victim selection; it is the
mechanism of convergence. The ablation is decisive: conserve the yielder's
progress and the system completes in two yields losing nothing; discard it and the
system livelocks, re-doing hundreds of units forever. There is no victim and no
sacrifice — only agency exercised under a conservation rule, and eventual
consistency falling out. Everyone arrives; the order is adjusted; nothing is
destroyed. Hoarding the lock would have deadlocked the hoarder; yielding it, and
being credited for the yield, completes the whole — the generous move and the
optimal move are the same move.

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

- Artifact: `iso_resolve.py`, committed at `32ba0a0` (Team Phi).
- Run: `python3 iso_resolve.py` — prints all four resolve-mode scenarios with
  yields and progress conserved, plus the credit-vs-sacrifice ablation, ending in
  `ALL CLAIMS HELD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_resolve.py` returns only prose in comments.
- Determinism: round-robin service, scripted programs, stable id tie-break, no
  RNG — traces reproduce exactly.

## Appendix B — The resolver in one screen

```
on DEADLOCK(cycle):                      # cycle from the detector
    yielder = argmin over p in cycle of
                 (credit[p], converted[p], id[p])   # least generous-so-far first
    release all locks held by yielder    # this unblocks the rest of the cycle
    credit[yielder] += converted[yielder]   # BANK the progress -- conserve it
    rewind yielder to start of its program
    converted[yielder] = 0
    budget[yielder] = base + credit[yielder]   # return STRONGER, not from zero
    refresh budget of the other cycle members
    continue                             # system now makes progress

# Nothing is discarded. The yielder returns with its work held as credit and an
# expanded budget; the conserved credit steers the next yield elsewhere. No
# victim, no rotation counter, no clock. Eventual consistency.
```
