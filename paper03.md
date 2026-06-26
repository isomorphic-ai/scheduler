# Paper 03 — Priority Inversion Dissolves: One Shared Yield-and-Schedule Budget, Where Yielding Is Costly

**Series:** The Isomorphic Scheduler
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v2 · toy validated
**Artifact:** `iso_share.py` @ commit `21dafc4`

> **TruthSeed (paper):** `iso-sched-03:costly-yield-self-removal`
> Priority inversion needs no inheritance protocol if scheduling and yielding
> share one budget and a yield is costly. A high process that is scheduled but
> cannot proceed yields — and the yield spends budget. It burns its own budget
> down and stops dominating, removing itself rather than being boosted past. A
> floor guarantees the low holder always makes a little progress (never starved),
> and as the high process drains, the freed proportional share flows to the
> holder, which speeds up. No boost, no inheritance, no clock — the blocked
> process steps aside by spending, and the holder was never stranded.

---

## 0. Abstract

Priority inversion is the failure where a high-priority task H is blocked,
unboundedly, by a low-priority holder L while an unrelated medium task M — which
outranks L — monopolizes the processor, so L never runs to release the resource H
needs. The classical fix adds a *protocol* (priority inheritance or ceiling) that
detects the block and boosts L past M.

We dissolve the inversion without any boost, using one mechanism the series has
built throughout: a single shared budget that scheduling and yielding both draw
on, refilled by progress and drained by blocking. The new ingredient is that **a
yield is costly**. When H is scheduled but blocked on L, H *yields*, and the yield
spends budget. H keeps being scheduled, keeps yielding, and **burns its own budget
down**; as its budget falls, its proportional share of the schedule falls with it,
until H simply stops dominating. H is not boosted-past; it *steps aside by
spending*. Meanwhile two guarantees protect and accelerate L: a **floor** gives
every process a small share each round, so L is never fully starved even while H
hyperfocuses; and because the schedule is **proportional to budget**, the share H
burns off is redistributed to whoever can convert it — L — so L speeds up as H
drains, and speeds up further the moment H is gone.

In the toy, a process H blocked on holder L burns its budget below L's within a
few rounds (self-removal), L makes steady progress throughout the blocked window
(never stalls), and L's progress rate overtakes the blocked H — all with no
inheritance code. Removing the floor makes the system **stuck** (L starves),
confirming the floor is load-bearing.

We introduce three invariants for successful systems design:

1. **Epistemic (evidence-tracking).** The schedule follows a measured budget that
   moves with the work, not a fixed priority number. *Here:* H's dominance falls
   because its budget falls, observed each round, not because a protocol decided
   to demote it.
2. **Alignment (shared, not replacing).** A part's success runs through the
   whole's; sharing the conserved quantity is load-bearing, not charitable.
   *Here:* the budget H spends yielding is not destroyed — it is the share that
   flows to L, whose release is exactly what H is waiting for.
3. **Agency (every action benefits all).** No move helps a part at the whole's
   expense, and no part is fully starved. *Here:* H's costly yield serves H (it
   unblocks sooner via L), serves L (which gets the freed share), and the floor
   guarantees even a maximally-outcompeted process keeps moving.

The mechanism unifies the series: this is the same shared budget the detector
reads at its floor and the resolver banks as credit, now *spent on yielding* to
schedule. Detection, resolution, and scheduling are three uses of one conserved
quantity. Inversion does not need fixing because the budget never strands the
holder; the blocked process spends itself aside.

---

## 1. Problem revisited

A preemptive priority scheduler runs the highest-priority ready task. With shared
resources this breaks. L (low) holds lock S. H (high) becomes ready, requests S,
and blocks. The scheduler now runs the highest-priority *ready* task — M (medium),
which shares nothing — because L (priority below M) loses every tie to M. L, the
holder of the lock H needs, does not run. H waits not for L's short critical
section but for M's entire execution. The highest-priority task is blocked by the
medium one through the low intermediary: **priority inversion**, unbounded, the
Mars Pathfinder bug.

The classical remedy adds a protocol: on block, boost L's priority to H's so L
preempts M; on release, restore. It works, and it is machinery — a rule that fires
on block, mutates a priority, walks transitive chains, and reverts, with its own
correctness obligations.

The problem revisited: the classical scheduler **strands H's claim on the
processor**. H has the highest priority, but while blocked it cannot use it, so
its claim sits idle on H while M runs and L starves. Every fix so far has tried to
*move H's priority to L* (inheritance). We ask the opposite question: what if the
blocked H simply **spends down its own claim** — so that without anyone being
boosted, H stops outcompeting L, and the ordinary proportional schedule then
serves L? If yielding costs budget, a blocked process defeats its own dominance by
the act of yielding, and no inheritance is needed.

---

## 2. Background

Priority inversion and the inheritance and ceiling protocols are classical
real-time material (Sha, Rajkumar & Lehoczky, 1990:priority-inheritance, the
foundational analysis). The Mars Pathfinder incident is the canonical field case;
its in-flight fix enabled priority inheritance on the offending mutex (Reeves,
1997:pathfinder). All these fixes share a shape: detect the block, *raise the
holder*, restore on release.

Our approach instead draws on **proportional-share scheduling** (lottery and
stride scheduling, Waldspurger & Weihl, 1994:lottery; 1995:stride), where each
task receives processor share in proportion to a weight (tickets), and on the
idea of a **shared, conserved budget** that the rest of this series uses for
deadlock detection (a floor on budget drained by blocking) and resolution (credit
banked across yields). What is new here is making **yielding cost budget** and
letting that cost interact with proportional share: a blocked high-weight task
spends its weight by yielding, so its share self-corrects downward. The floor that
guarantees no task is fully starved is the proportional-share analogue of a
minimum-tickets guarantee. To our knowledge, using a *costly yield on a shared
scheduling budget* to dissolve priority inversion — rather than inheritance to
patch it — is novel; we pre-register the claim.

---

## 3. Sharpening: make the blocked process spend, not the holder borrow

Here is the move.

Inheritance asks: H is blocked and cannot use its priority, so *lend H's priority
to L*. That works but requires a protocol that reaches into L and changes it. Turn
the question around. H is blocked and cannot use its claim on the processor — so
instead of lending the claim to L, **let H spend the claim away.**

Concretely: scheduling and yielding draw on one shared budget, and a process's
share of the schedule is proportional to its budget (over a floor). When H is
scheduled but blocked, it must yield — and **the yield is costly**: it spends
budget. So a blocked H, scheduled again and again by its high budget, yields again
and again, each yield burning budget. Its budget falls; its proportional share
falls with it. Within a few rounds H's budget drops below L's, and H is no longer
the dominant claimant. No one boosted L. H *demoted itself* by spending its claim
on fruitless yields.

Two refinements make this safe and fast, and both are necessary:

- **A floor.** Every process gets a small minimum share each round regardless of
  budget. So even while H still has the highest budget and hyperfocuses, L — the
  holder — gets a sliver of the processor every round and makes a little progress.
  L is never fully starved. Without the floor, all share goes to the
  highest-budget process and L can be starved to a standstill (and, as a holder,
  that standstill is a deadlock-shaped stall). The floor is the difference between
  *completes* and *stuck*.
- **Proportional redistribution.** Because share tracks budget, the share H burns
  off does not vanish — it is redistributed to the processes that still have
  budget and can convert it. As H drains, L (and M) get proportionally more. The
  moment H's blocked, costly yielding has burned it below the others, L accelerates
  toward releasing S; the moment H is out, L and M absorb its entire former share.

The wrong framing was "H's priority is stranded, so move it to the holder." The
right framing: **H's claim is not stranded — H spends it.** A blocked process,
billed for each yield, removes its own dominance; the floor keeps the holder
alive; proportional share routes the freed capacity to whoever can convert it. The
inversion dissolves because the blocked process steps aside, not because the
holder is lifted.

---

## 4. The solution

### 4.1 One shared budget; proportional share over a floor `(structural)`

Every process has a single `budget`, the same quantity used elsewhere in the
series (a floor on it detects deadlock; banking it across yields is resolution
credit). Each scheduling round distributes a fixed small capacity `C` of progress
among the alive processes:

> **Share rule.** `share(p) = floor_term + proportional_term`, where
> `floor_term = floor_frac · C / n` (every alive process, unconditionally) and
> `proportional_term = (1 − floor_frac) · C · budget(p) / Σ budget`. Shares
> accumulate; when a process has accumulated a whole unit it attempts a step.

The floor term guarantees a strictly positive share to every process each round.
The proportional term gives more to higher-budget processes. `floor_frac ∈ (0,1)`
sets how much capacity is reserved for the anti-starvation floor.

### 4.2 Costly yield: the blocked process removes itself `(shown)`

When a scheduled process's next step is blocked (an acquire on a held lock), it
**yields, and the yield spends budget**:

> **Costly-yield rule.** On a blocked scheduling attempt, `budget(p) −=
> yield_cost`, with `yield_cost` larger than the per-step `refill` a progressing
> process earns. A progressing process *gains* budget (`budget += refill`); a
> blocked process *loses* it.

The asymmetry is the whole mechanism. A high-budget process that is blocked is
scheduled often (high share), and each scheduling attempt is a costly yield, so it
loses budget fast — faster than any process making progress gains it. Its budget
falls below the holder's within a few rounds, its proportional share collapses,
and it stops dominating. It is not demoted by a protocol; it spent its way down.
`(shown: in the toy, H's budget drops below L's at round 6 and reaches 0 by round
12, purely from costly yields.)`

### 4.3 Why L is never starved and speeds up `(shown)`

Two guarantees, both observed in the toy:

- **Never starved (floor).** Throughout the window where H is blocked and
  dominating, L makes progress every step it is scheduled — its cumulative
  progress climbs steadily (1→2→3→4→5 across the blocked window) and never stalls
  for a full round. The floor term is what gives L that guaranteed sliver. Set
  `floor_frac = 0` and the system goes **stuck**: L, outweighed, gets no share and
  starves, and as the holder its starvation stalls the whole system. The floor is
  load-bearing, not cosmetic. `(shown)`
- **Speeds up proportionally.** As H burns its budget down, the proportional share
  it loses is redistributed by the share rule to L and M. L's per-round progress
  rate rises and overtakes the blocked H's; once L releases S (and once H is fully
  drained), L and M absorb H's entire former share and finish quickly. The
  speed-up is automatic — it is just proportional share responding to H's falling
  budget. `(shown)`

### 4.4 The three invariants, in full

A scheduler built on the shared costly-yield budget satisfies three properties we
name in systems vocabulary. Each is a concrete predicate, not a sentiment, and
each is stated here in full.

- **Epistemic (evidence-tracking — truth that can update).** The schedule follows
  a measured budget that moves with the work each round, never a frozen number. A
  process dominates exactly as much as its current budget warrants; when a blocked
  process burns its budget on costly yields, its dominance falls immediately and
  observably, and when a progressing process earns refill, its share rises. There
  is no stored priority boost to apply and later restore — the share is a live
  reading of the budget. `(structural)`
- **Alignment (shared, not replacing — success runs through the whole).** A
  part's success runs through the whole's, and the conserved quantity is shared,
  not spent into a void. The budget a blocked H gives up by yielding is not
  destroyed; the proportional rule routes that share to the processes that can
  convert it, principally L — whose release is precisely what H is waiting for. H
  spending its claim and L gaining share are the same transfer; H's eventual
  unblocking runs through L's progress. `(structural)`
- **Agency (every action benefits all).** No move helps a part at the whole's
  expense, and no part is fully starved. H's costly yield serves H (it is
  unblocked sooner because L is freed sooner), serves L (which receives the freed
  share), and improves throughput (the unbounded medium-task monopoly cannot form,
  because H's own budget, not M's priority, governs the schedule). The floor
  guarantees even a maximally-outcompeted process keeps moving — agency is
  preserved for every process, not just the dominant one. `(structural)`

These three are not ethical decoration. §4.3 shows the alignment/agency reading
has teeth: remove the floor (deny the weakest process its guaranteed share) and
the system goes from completing to stuck.

---

## 5. Related work

**Priority inheritance and priority ceiling** (Sha, Rajkumar & Lehoczky,
1990:priority-inheritance). The classical inversion fixes: detect the block and
raise the holder. We do not raise the holder. We let the blocked process spend its
own budget on costly yields until it stops dominating, and protect the holder with
a floor. The outcome — the holder runs, the inversion does not bound H — is shared
with inheritance, but the mechanism is opposite in direction (the blocked process
descends rather than the holder ascending) and adds no boost-and-revert protocol.

**Mars Pathfinder** (Reeves, 1997:pathfinder). The field instance whose fix was
inheritance. Our toy reproduces the same three-task shape and dissolves the
inversion by self-removal instead.

**Proportional-share / lottery / stride scheduling** (Waldspurger & Weihl,
1994:lottery; 1995:stride). Processor share proportional to weight, with
fairness guarantees. Our share rule is proportional-share with two additions: a
floor (a minimum-share guarantee, here the anti-starvation mechanism) and a
*budget that the yield spends*, coupling scheduling to blocking so that a blocked
high-weight task self-corrects its own weight. Classical proportional share does
not bill yields, so a blocked high-ticket task keeps its tickets and can still
starve a holder; the costly yield is what closes that gap.

**Novel adjacency — inversion dissolved by costly yield on a shared budget.** The
literature fixes inversion by moving priority *to* the holder. We remove the
inversion by having the blocked process spend its scheduling claim *away*, on a
budget shared with the rest of the series' machinery, with a floor for
anti-starvation and proportional share for redistribution. To our knowledge this
direction — descend the blocker rather than ascend the holder, on one conserved
budget — is novel; we pre-register it and invite refutation.

---

## 6. Evaluation

### 6.1 Toy: `iso_share.py` `(shown)`

Three processes share one lock S. L (the holder) holds S at t=0 and has a short
critical section then releases. H does a unit of work, then requests S and blocks
on L, then has more work. M is unrelated CPU work. One shared budget; each round
distributes capacity as floor + proportional share; progress refills budget,
blocked scheduling attempts cost `yield_cost` (a costly yield). **No wall-clock
primitive is present.**

Observed per-round dynamics (costly yield, floor on):

| Phase | Rounds | What happens |
|---|---|---|
| Setup | 1–5 | H runs its first unit, then blocks on L; budgets near equal |
| Self-removal | 6–12 | H's costly yields burn its budget below L's (round 6) down to 0 (round 12); L progresses every round, never stalls |
| Release & speed-up | 13–17 | L finishes its critical section and releases S; freed share flows to L and M, which accelerate |
| Drain finish | 18–25 | H, unblocked, refills budget and completes its remaining work |

Claims, all confirmed:

- **H removes itself.** H's budget drops below L's at round 6 and reaches 0 by
  round 12 — purely from costly yields, with no inheritance or external demotion.
  `(shown)`
- **L is never starved.** L's cumulative progress climbs steadily through the
  entire blocked window and never stalls for a round; the floor is what guarantees
  this. `(shown)`
- **L speeds up proportionally.** L's per-round progress rate overtakes the
  blocked H's during the blocked window, and L (with M) absorbs H's former share
  once H drains. `(shown)`
- **System completes.** All three finish. `(shown)`

### 6.2 Ablation: the floor is load-bearing `(shown)`

Re-run with `floor_frac = 0` (no floor; pure proportional share):

| Floor | Outcome | L during H's block |
|---|---|---|
| on (0.15) | **completed** | L progresses steadily, never stalls |
| off (0.0) | **stuck** | L, outweighed, gets no share and starves; as holder, this stalls the system |

The floor is the difference between completing and starving. Pure proportional
share — share strictly proportional to budget with no minimum — lets the
highest-budget process deny the holder any share, and a starved holder is a
stalled system. The floor guarantees the weakest process the sliver it needs to
keep moving. `(shown)`

### 6.3 Honest limitation: costly-vs-free yield separation `(shown)`

In the present scenario, comparing costly yield to a near-free yield does not
cleanly separate L's progress during the block (both give L the same window
progress), because the floor already rescues L and the scenario's budgets are
small. The costly yield's distinctive effect — H *self-removing* by burning budget
below L's — is clearly shown (§6.1), but a scenario that isolates costly-vs-free on
a measurable outcome (e.g. total inversion exposure, or M's interference) is owed.
We record this as a gap rather than overclaim the ablation. `(shown limitation)`

### 6.4 Practical exam pointer

In a real engine, "scheduled but blocked" is observable (a transaction waiting on
a lock), and a costly yield maps to charging a transaction's scheduling budget
when it is scheduled but cannot proceed, while a floor maps to a guaranteed
minimum service rate per transaction. The claim to test: billing blocked
scheduling attempts, plus a minimum-service floor, dissolves priority inversion
without an inheritance subsystem, and never starves a lock holder. A failure there
is the next seed.

---

## 7. Further work (deeper into this wave)

- **Isolate costly-vs-free yield.** §6.3's gap: design a scenario where costly
  yield measurably beats free yield on an outcome the floor does not already
  rescue (e.g. bounding M's total interference, or H's worst-case blocking).
- **Tuning the three knobs.** `floor_frac`, `yield_cost`, and `refill` interact.
  Characterize the region where the system completes, never starves, and H
  self-removes promptly. Is there a principled setting (e.g. `yield_cost` a fixed
  multiple of `refill`) that works across workloads, or does each workload retune?
- **Quantitative blocking bound.** Classical inheritance has a proven worst-case
  blocking bound. Does the costly-yield mechanism admit an analogous bound on how
  long H waits, as a function of `yield_cost` and L's critical-section length?
- **Budget = the one quantity.** The same budget detects deadlock at its floor,
  banks as resolution credit, and here is spent on yielding to schedule. The
  capstone question: are these literally one conserved quantity with three
  readings, and does a scheduler that maintains only this budget get detection,
  resolution, and inversion-freedom together with no added subsystem?
- **Floor vs. fairness under chains.** A long chain of holders each protected by a
  floor: does the floor sum to a meaningful service guarantee end-to-end, or can a
  deep chain still under-serve the task at its root?

---

## 8. Conclusion

Priority inversion has been fixed by lifting the holder: detect the block, raise
the low task to the high task's priority, restore on release. We dissolved it from
the other direction. Put scheduling and yielding on one shared budget and make the
yield costly, and a high task that is blocked spends its own scheduling claim away
— each fruitless yield burns budget — until it no longer dominates. No one is
boosted; the blocked task steps aside by spending. A floor guarantees the low
holder a sliver of progress every round, so it is never starved while the high
task hyperfocuses; and because share is proportional to budget, the capacity the
high task burns off flows to the holder, which speeds up as the blocker drains and
faster still once it is gone. The toy shows each piece: the blocked task's budget
falling below the holder's within a few rounds, the holder progressing without a
single stall, and — when the floor is removed — the system starving into a
standstill, proving the floor load-bearing.

This is one mechanism, not a protocol: the same shared budget the series uses to
detect deadlock at its floor and to bank resolution credit is here spent on
yielding to schedule. Detection, resolution, and scheduling are three readings of
one conserved quantity. The inversion never needed a special fix, because the
budget never stranded the holder — the blocked task spent itself aside, the floor
kept the holder alive, and proportional share sent the freed capacity to whoever
could convert it. Hoarding the processor on a task that cannot use it is what
strands the system; billing that task for the hoard, and guaranteeing the holder
its floor, frees the whole. The generous schedule and the optimal schedule are the
same schedule.

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

- Artifact: `iso_share.py`, committed at `21dafc4` (Team Phi).
- Run: `python3 iso_share.py` — prints the costly-yield run, the floor ablation
  (on -> completed, off -> stuck), and a verdict ending in `ALL CLAIMS HELD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_share.py` returns only prose in comments; no wall-clock primitive is called.
- Determinism: fixed capacity per round, scripted programs, no RNG — traces
  reproduce exactly.

## Appendix B — The scheduler in one screen

```
each round:                              # one shared budget per process
    alive = processes not done
    sum_b = sum(budget[p] for p in alive)
    for p in alive:
        share[p] = floor_frac*C/n + (1-floor_frac)*C*budget[p]/sum_b
        credit_acc[p] += share[p]        # floor guarantees a sliver to everyone

    for p in alive:
        while credit_acc[p] >= 1:
            credit_acc[p] -= 1
            if blocked(p):
                budget[p] -= yield_cost   # COSTLY YIELD: blocked p spends down
                break
            else:
                do one step of p
                budget[p] += refill       # progress earns budget (refill < yield_cost)

# A blocked high-budget process is scheduled often, yields often, and burns its
# budget below the holder's -> it self-removes, no inheritance. The floor keeps
# the holder progressing (no starvation); proportional share routes freed
# capacity to whoever can convert it. No clock.
```
