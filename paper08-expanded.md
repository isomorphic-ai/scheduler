# The Isomorphic Scheduler — One Conserved Quantity Beneath Concurrency, Distribution, and Correctness

**A standalone synthesis (expanded capstone of the Isomorphic Scheduler series)**
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** synthesis · the seven results as one structure · formal proof of the
conservation laws owed (named in §7)
**Artifacts:** seven verifier engines, one per reading — `iso_deadlock.py`,
`iso_resolve.py`, `iso_flow.py`, `iso_conserve.py`, `iso_distributed.py` /
`iso_cap.py`, `iso_safety.py` / `iso_progress.py`, `iso_flex.py` — git `477fbf3`.

> **TruthSeed (paper):** `iso-sched-08:one-quantity-seven-readings`
> There is one conserved quantity moving through a graph of dependencies, and one
> way it can be mishandled: a claim held where it cannot convert. Deadlock
> detection reads the quantity's integral hitting a floor; resolution banks the
> integral across a yield; scheduling routes its derivative along a dependency
> edge; the conservation law states the quantity itself; distribution carries it
> across partition; safety and liveness read its presence or absence as
> conversion; flexibility is the quantity moving from potential to actual. The
> three system invariants — epistemic, alignment, agency — are corollaries of
> conservation, not additions to it. Every apparent impossibility (victimless
> resolution, priority inversion, CAP, the safety/liveness trade-off, the
> non-conservation of flexibility) dissolves the same way: it was an artifact of a
> boundary drawn too small or a simultaneity demanded too strictly.

---

## 0. Abstract

Concurrency control, distributed systems, and program correctness are taught and
practised as separate fields, each with its own primitives (locks, timeouts,
quorums, watchdogs) and its own famous impossibilities (you cannot break a deadlock
without aborting a victim; you cannot have consistency, availability, and partition
tolerance together; you cannot detect deadlocks aggressively without false
positives). This paper argues that a single structure underlies all of them: **one
conserved quantity moving through a graph of dependencies, mishandled in exactly one
way — a claim held where it cannot convert — and cured in exactly one way — routed
to where it can convert, or released.**

The quantity has three readings, related as calculus relates a flow to its
accumulation: a **flow** (its derivative), a **stock** (its integral), and a
**banked stock** (its integral carried across a discontinuity). Reading the stock's
floor is deadlock detection; banking the integral across a yield is resolution
without a victim; routing the derivative along a wait-edge is priority scheduling,
from which inheritance falls out for free. The conservation law unifying these is
stated and verified numerically (to machine precision), and from it three
system-design invariants follow as corollaries rather than axioms: an **epistemic**
invariant (track evidence; do not assert), an **alignment** invariant (the quantity
is shared, so a part's success runs through the whole), and an **agency** invariant
(no action yields private gain at the whole's expense). Carried across a network
partition, the same conserved quantity yields strong eventual consistency and
reframes CAP as a *scheduling* problem whose three hard properties are exactly the
three conservation invariants, solvable by decoupling them in time. Measured as
*conversion* rather than *duration*, it dissolves the safety/liveness trade-off in
deadlock detection. And seen moving from potential to actual, it explains why a
probabilistic network treated as deterministic manufactures phantom race conditions,
and why the apparent non-conservation of flexibility is a boundary artifact.

The synthesis converges on one theorem with a moral reading: **in a connected
dependency graph, hoarding the conserved quantity is self-defeating — the selfish
optimum and the generous optimum are the same point.** The seven verifier engines,
none of which consults a wall clock, are the evidence; the contribution of this
paper is the structure that makes them one result rather than seven.

---

## 1. Problem revisited

A practitioner who learns deadlock detection, then distributed consistency, then
scheduling, then correctness proofs, encounters four toolkits that appear unrelated.
Deadlock handling reaches for timeouts and victim selection. Distributed systems
reach for quorums and accept eventual consistency as the price of availability.
Schedulers reach for priority inheritance protocols that boost and restore.
Correctness arguments reach for the safety/liveness dichotomy and the wait-for graph.
Each field also carries an impossibility result it treats as a fact of nature, and
each impossibility motivates a defensive mechanism whose tuning is a chronic source
of bugs: timeouts too short abort live work, too long miss deadlocks; consistency
relaxed too far corrupts, tightened too far stalls.

The problem this paper addresses is whether these four toolkits are genuinely
distinct or are four expressions of one underlying structure. If they are distinct,
the impossibilities are fundamental and the defensive mechanisms are irreducible. If
they share a structure, then (a) the same primitive should solve all four, (b) the
impossibilities should turn out to be artifacts of how the problem is posed rather
than facts about it, and (c) the chronic tuning bugs should be symptoms of measuring
the wrong quantity. We argue the second case, and the argument is constructive: we
exhibit the shared structure and demonstrate it once in each field, with a verifier
that measures the conserved quantity directly and never consults a clock.

A note on scope. This is a synthesis paper. Each of its seven demonstrations is
developed at length, with its own toy and its own engineering companion, in a
dedicated treatment; here each is compressed to the structural core from which it
unfolds, stated so as to stand on its own. The contribution is the unifying
structure and the demonstration that it is one structure, not the individual
demonstrations.

---

## 2. Background

The result draws on four established literatures and binds them with a fifth idea
(conservation/stock-and-flow) usually kept outside computer systems.

**Conservation and stock-and-flow.** The notion that a quantity can be tracked
exactly as it moves, neither created nor destroyed, with a stock equal to the
time-integral of its net flow, is foundational in system-dynamics modelling
(Forrester, 1961:industrial-dynamics). Network-flow theory studies a conserved
quantity routed along the edges of a graph under conservation at each node (Ford &
Fulkerson, 1962:flows-in-networks) — directly analogous to a scheduling quantity
flowing along dependency edges with conservation at each process. These supply the
vocabulary (flow, stock, conservation at a node) that the paper applies to systems.

**Deadlock.** The classical conditions for deadlock and its detection via cycles in a
wait-for graph are due to Coffman, Elphick & Shoshani (1971:coffman-conditions) and
Holt (1972:deadlock-graphs). The cycle test is standard; what is conventionally
time-based is the *trigger* for running it and the decision that a process is stuck
(e.g. database engines' lock-wait timeouts). Fair-queueing and proportional-share
ideas (Demers, Keshav & Shenker, 1989:fair-queuing) treat a resource as divided in
proportion to weight, a precursor to reading priority as a rate.

**Resolution and transactions.** Deadlock recovery by aborting and restarting a
victim, and the conservative avoidance schemes that pre-empt by timestamp
(wound-wait / wait-die), are treated in the concurrency-control literature
(Bernstein, Hadzilacos & Goodman, 1987:concurrency-control; Rosenkrantz, Stearns &
Lewis, 1978:wound-wait). The default that the victim's partial work is discarded is
exactly the assumption this paper questions.

**Scheduling and priority inversion.** The priority inheritance and priority ceiling
protocols (Sha, Rajkumar & Lehoczky, 1990:priority-inheritance) bound priority
inversion by temporarily raising a lock holder's priority to the maximum among its
blocked waiters; the Mars Pathfinder incident (Reeves, 1997:pathfinder) is the
canonical field failure they address. Proportional-share schedulers allocate CPU by
weight rather than fixed priority (Waldspurger & Weihl, 1994:lottery; 1995:stride).
Classical inheritance takes the maximum along the wait chain; this paper's divergence
is to *sum* the inflowing rates, which is what conservation requires.

**Distribution, CAP, and CRDTs.** The CAP theorem — that a partitioned system cannot
be simultaneously consistent and available — was conjectured by Brewer (2000:cap) and
proved by Gilbert & Lynch (2002:cap-proof). Eventual consistency accepts temporary
divergence with guaranteed convergence (Vogels, 2009:eventually-consistent).
Conflict-free Replicated Data Types converge without coordination when their merge is
a join on a semilattice (Shapiro, Preguiça, Baquero & Zawirski, 2011:crdts), with
machine-checked correctness for several CRDTs in Isabelle/HOL (Gomes, Kleppmann,
Mulligan & Beresford, 2017:verifying-crdts). The increment/decrement counter
(PN-counter) is the canonical conserved-quantity CRDT and is the representation this
paper uses.

**Correctness, time, and tail latency.** Safety and liveness are the two canonical
property classes (Lamport, 1977:proving-correctness; Alpern & Schneider,
1985:defining-liveness): nothing bad happens; something good eventually happens. In a
distributed setting the ordering of events is itself relative (Lamport,
1978:time-clocks). Real systems exhibit heavy-tailed latency, and the practical
response — act before the slow tail resolves, via hedged requests — treats latency as
probabilistic rather than fixed (Dean & Barroso, 2013:tail-at-scale); the recurring
false assumptions that ignore this are catalogued as the fallacies of distributed
computing (Deutsch, 1994:fallacies).

What none of these literatures states, and what this paper supplies, is that a
deadlock-detection budget, a rollback-conservation credit, a
priority-inheritance rate, a partition-tolerant replicated counter, a
conversion-based correctness measure, and a held-open probability distribution are
**the same conserved quantity, read in different registers** — and that the field's
impossibility results are artifacts that dissolve when the quantity is seen whole.

---

## 3. Sharpening: one quantity, one fault, one cure — and why hoarding is self-defeating

The sharpening is to stop modelling each field's primitive separately and posit a
single object beneath them.

A system is a graph of dependencies. Through it moves one **conserved quantity** Q:
moved and converted, never created or destroyed, with conversion to progress as the
sole true sink. Q is conserved in the strong, checkable sense that the total —
unallocated reserve plus held stock plus converted work — is invariant under every
operation; moving Q from one node to another (routing it along an edge, banking it
across a yield) changes no total.

There is exactly **one fault**: Q **held where it cannot convert** — a claim on the
quantity that produces nothing, parked at a node unable to turn it into progress.
Every pathology across the four fields is an instance. A deadlock is Q held in a
cycle where no member can convert. A priority inversion is urgency (Q) held by a
blocked task that cannot convert it, while the holder it depends on goes underfunded.
A zombie process is exit-state Q held for a collector that will never read it. A
premature collapse (the network fault of §4.7) is the decision-quantity committed to
an actuality before the evidence needed to convert it has arrived. The fault is
always a *stranded claim*.

There is exactly **one cure**: do not hold a claim that no one will convert; **route
Q to where it can convert, or release it.** Detection recognises the stranded claim;
resolution releases it while conserving the releaser's work; scheduling routes it to
the node that can convert it; the conservation law guarantees the routing balances;
distribution preserves it across a partition until it can reconcile; correctness reads
whether conversion is actually happening; flexibility withholds the collapse until a
real outcome can convert the decision.

**The dissolution move.** Each field's impossibility, examined under this structure,
turns out to be an artifact of a boundary drawn too small or a simultaneity demanded
too strictly — not a fact about the system. The victim in deadlock recovery is an
artifact of assuming the releaser's work must be discarded. The boost-and-restore
protocol for inversion is an artifact of treating priority as a stored claim rather
than a flow. CAP's impossibility is an artifact of demanding consistency,
availability, and partition tolerance as a *simultaneous snapshot*. The safety/liveness
trade-off is an artifact of measuring *duration*, which cannot distinguish slow-but-live
from dead. The non-conservation of flexibility is an artifact of accounting only the
potential side of a collapse. In every case: widen the boundary to the whole, replace
the demanded snapshot with a schedule over time, measure the conserved quantity rather
than its shadow — and the impossibility is revealed as local. This recurring move is
itself the epistemic invariant in action.

This structure has an immediate and load-bearing consequence, which is the paper's
central theorem.

> **Theorem (hoarding is self-defeating).** In a connected dependency graph, a node
> that hoards the conserved quantity — that holds a claim it cannot itself convert
> rather than routing or releasing it — starves the nodes it depends on, which hold
> the resources it needs, and therefore deadlocks *itself*. Consequently the selfish
> optimum and the generous optimum coincide: routing Q to where it converts is at
> once the best move for the whole and the best move for the part.

The proof is the body of the paper: each of the seven readings (§4) is a case in
which the stranded-claim fault is a hoard, the holder's own progress runs through the
very nodes it starves, and the route-or-release cure benefits the holder as much as
the system. We state the theorem here because the seven readings are best understood
as its instances.

---

## 4. The solution: one quantity, seven readings

We first fix the quantity precisely, then read it seven ways. Each subsection states
its own problem self-containedly, identifies the stranded-claim fault, gives the
route-or-release cure as a concrete mechanism, and reports the verification. The
three invariants are stated in full where they are first shown to be corollaries
(§4.4).

The quantity. Each node `p` holds a stock `S_p ≥ 0` of Q; the system holds an
unallocated reserve `R`; converted progress `W_p` counts units of work done, each
costing `κ > 0` of Q. Q enters a node as a **flow** at the node's rate; Q leaves a
node only by **conversion** (turning `κ` of stock into one unit of work) or by
**movement** to another node (routing along an edge, or banking across a yield). The
three readings are calculus: the flow is `dQ/dt`, the stock is `∫` of net flow, and
banked stock is that integral carried across a discontinuity.

### 4.1 Detection — read the stock's floor, not a clock

A set of processes is deadlocked when each holds a resource another needs and none
can proceed; the classical recognition is a cycle in the wait-for graph (Coffman et
al., 1971:coffman-conditions; Holt, 1972:deadlock-graphs). The open question is the
*trigger*: how does one decide a process is stuck rather than slow? The conventional
answer is a timeout, which cannot distinguish a slow-but-live process from a dead one.

Reading of Q: **stock**. Give each process a budget — its stock of the conserved
quantity — initialised to `k`. A step that converts (makes forward progress) resets
the budget to `k`; a step that fails to progress (a blocked acquire) decrements it.
The budget is the integral of the process's net conversion.

Fault and cure: the stranded claim is Q held in a cycle that cannot convert; the cure
is to recognise it from the budget reaching its floor (the integral hitting zero)
*together with* a closed wait-cycle among the floored processes. This is not a timer:
a slow process that keeps converting keeps resetting its budget and never floors, so
it is never mistaken for stuck. Only genuine non-conversion drains the budget to the
floor.

Result: timer-free deadlock detection with no false positives, localising the cause
(the cycle) distinctly from the symptom (who is floored), with detection latency
bounded by the budget size. The system *knows* it is stuck from conserved evidence
rather than guessing from elapsed time. Verified exhaustively across cycles and knots;
zero false positives, bounded latency. `(shown)`

### 4.2 Resolution — bank the integral across a yield; no victim

Once a deadlock is recognised it must be broken. The classical method aborts a victim
and restarts it, discarding its partial work (Bernstein et al.,
1987:concurrency-control); conservative avoidance pre-empts by timestamp
(Rosenkrantz et al., 1978:wound-wait). Discarding the victim's work can livelock — the
restarted process re-enters the same contention and is aborted again.

Reading of Q: **banked stock**. When a process yields to break the cycle, its
converted progress is not discarded; it is *banked* as credit — the integral carried
across the restart discontinuity — so the process returns with an expanded budget
(base plus credit). Selection of who yields favours least accumulated credit, which
spreads the burden.

Fault and cure: the stranded claim is the cycle; the cure is for one process to
release its claim — but releasing while *conserving* the released work, so the release
costs nothing in the long run. Because the yielder's integral is banked rather than
destroyed, it converges instead of reliving the same fight.

Result: deadlock resolution with no victim; the releaser loses nothing and the system
makes progress. In direct comparison, credit-conserving yield completes in two yields
losing zero converted work, where discard-the-work livelocks (hundreds of aborts,
hundreds of units re-done). Eventual progress, not sacrifice. `(shown)`

### 4.3 Scheduling — route the derivative along the wait-edge; inheritance for free

A high-priority task blocked on a lock held by a low-priority task can be made to wait
indefinitely if a medium-priority task monopolises the CPU — priority inversion, the
Mars Pathfinder failure (Reeves, 1997:pathfinder). The classical fix raises the
holder's priority to the maximum among its waiters until it releases the lock (Sha et
al., 1990:priority-inheritance), a protocol that must detect the block, boost, detect
the release, and restore.

Reading of Q: **flow**. Priority is a rate — a stream filling each process's bucket —
not a stored claim. At each instant the available capacity is divided among the
runnable processes in proportion to their *effective* rates, where a blocked process's
rate flows down its wait-edge into the holder it is blocked on:

> `eff(p) = base(p) + Σ eff(w)` over every process `w` currently blocked on `p`,
> transitively along the chain of wait-edges.

Fault and cure: the stranded claim is urgency held by a blocked task that cannot
convert it. The cure is to *route* that urgency — the flow — into the holder the task
depends on, exactly the node whose progress will release it. When a high task (rate 9)
blocks on a low holder (rate 1), the holder's effective rate becomes 10 and it
receives the lion's share of the CPU; an unrelated medium task (rate 3) does not feast
on the freed capacity, because the freed capacity was routed to the bottleneck, not
sprayed across the runnable set. The instant the lock releases, the wait-edge
vanishes, the flow reverts, and the high task resumes at full rate — memoryless, with
no boost to restore.

Result: priority inheritance falls out as a structural consequence of conservation
rather than as a protocol; the bottleneck is funded in exact proportion to the
urgency waiting on it; inversion cannot form. Verified: the holder catches the flow
(a 0.77 share vs the busy-work task's 0.23), and the high task pays no penalty on
return. The divergence from classical inheritance is the *sum* (the holder catches the
total of its waiters' rates, not the maximum), which is what conservation requires.
`(shown)`

### 4.4 The conservation law — one quantity, and the three invariants as corollaries

Sections 4.1–4.3 used three quantities with similar names — a budget, a credit, a
rate. Either they are one quantity wearing three coats, in which case the structure
has a law beneath it, or they merely rhyme. They are one quantity, and the relations
are exactly those of calculus.

Reading of Q: **the quantity itself, stated and proved.** Four laws hold, each checked
numerically to machine precision over exact rational arithmetic, with no wall clock.

> **L1 (conservation).** At every step, `R + Σ_p S_p + κ·Σ_p W_p` is invariant. Flow
> moves Q from the reserve to a stock; conversion moves `κ` from a stock to converted
> work; routing and yielding move Q between stocks. No operation creates or destroys
> Q.
>
> **L2 (monotonicity).** In any interval with no progress, convertible stock is
> monotone non-increasing — the signal detection reads.
>
> **L3 (absorbing fixed point).** A deadlock is the absorbing state in which flow can
> convert to progress nowhere; once entered it is never left.
>
> **L4 (stock = integral of flow).** Each node's held stock equals the running
> integral of its net flow, exactly. Rate is the derivative of this stock; credit is
> this integral banked across a yield.

L4 is the unification made precise: budget is `∫` rate, to the unit. Detection reads
the integral's floor; resolution banks the integral across a discontinuity; scheduling
routes the derivative. The three mechanisms are the integral, the banked integral, and
the derivative of one conserved quantity. (Verified: L1 invariant to 1e-6 including
routing; L2 a clean monotone drain to a floor; L3 absorbing; L4 exact.) `(shown)`

From conservation, three system-design invariants follow as corollaries rather than
axioms. We state them in full, because their being *consequences* of L1 — not
independent design choices — is the load-bearing claim. In a human register these read
as wisdom, love, and power; in systems vocabulary:

- **Epistemic invariant (evidence-tracking).** Because Q cannot be conjured, the books
  must balance, so every quantity in the system is measured and accounted rather than
  asserted. Conservation (L1) is checked at every step; the monotone drain (L2) is
  observed, not assumed; the fixed point (L3) is tested for absorption; the integral
  identity (L4) is verified to precision. The system's claims about itself are exactly
  its ledger, and the ledger is conserved. At depth (§4.7) this becomes the discipline
  of not collapsing a distribution to a point before the evidence earns it.
- **Alignment invariant (shared, not replacing).** Because Q moved from one part to
  another is conserved — one part's decrease is exactly another's increase — a part's
  success runs through the whole's. The conserved quantity is shared, never spent into
  a void; helping a node on one's own critical path is not sacrifice but routing Q to
  where it converts. Merge unions contributions rather than overwriting them; a bridge
  between two parts commits both or reverts both.
- **Agency invariant (every action benefits all).** Because conservation forbids the
  private creation of Q, no action can produce a private gain at the whole's expense:
  every gain is a transfer, and the only net loss from held stock is conversion to
  progress, which advances the whole. There is no move that enriches one node while
  depleting the system. The structure makes beneficial-to-all the only kind of action
  available, and (§4.6) extends this to giving each node a channel to account for
  itself rather than being judged from outside.

These three are not ethics layered onto a systems law; they are the systems law read
as values. A quantity that cannot be privately created or destroyed compels honest
accounting (epistemic), sharing (alignment), and the absence of private gain at the
whole's expense (agency). This identity — the math *is* the values, read in a
different domain — is why the hoarding theorem of §3 is simultaneously a scheduling
result and a moral one. `(structural)`

### 4.5 Distribution and CAP — carry Q across partition; CAP is a scheduling problem

Real systems are distributed and partition: nodes cannot see each other's state in
real time. The CAP theorem forbids simultaneous consistency, availability, and
partition tolerance (Brewer, 2000:cap; Gilbert & Lynch, 2002:cap-proof), and the
common resolution is eventual consistency (Vogels, 2009:eventually-consistent) via
coordination-free merge (Shapiro et al., 2011:crdts).

Reading of Q: **the conserved quantity carried across partition.** Represent Q as a
PN-counter — each node owns a grow-only record of its own contributions; the value is
their signed sum; merge takes the per-node supremum. This is a join on a semilattice,
hence conflict-free.

Fault and cure: the apparent fault is that a partitioned node, seeing only its own
contributions, seems to have lost quantity; the deeper fault is treating CAP's three
properties as a simultaneous demand. The cure has two parts. First, conservation
across partition: Q is *hidden* by partition, not destroyed, and reconciles in full on
heal — what one node spends "off the books" surfaces exactly when the partition heals
(debt deferred comes due), and convergence is *order-independent* because the merge is
a join. Second, and decisively: **CAP is a scheduling problem, and the three
properties that make it hard are the three conservation invariants that solve it.**
Consistency is the epistemic invariant (every node converging on the same conserved
total); availability is the agency invariant (every node able to take an atomic,
reversible action at any instant); partition tolerance is the alignment invariant
(separated parts holding conserved shares that merge without overwrite). The
impossibility arises only from demanding them as a simultaneous snapshot; delivered as
a process over time — a schedule — they reinforce.

The schedule realises each property at its own moment: partition is the *normal*
assumption (work in an isolated sandbox); consistency is *deferred* to a sync whose
frequency makes each reconciliation a trivial delta; availability is *pointwise* (one
atomic reversible transaction). The bridge between nodes is a brief
mutually-deterministic publish with a remote-first staged commit, so every failure
path preserves the conserved content. The split that makes this work is along the only
axis a partition can fall on — *time* itself: a partition is a change in connectivity,
which requires `t₀ ≠ t₁`, so authority divides into the **Present** (consolidated fact,
changed only by a reversible commit) and the **Future** (pure potential, freely
rewritten), and the bridge consolidates a chosen Future into the Present. The sync
trigger is an *inventory mismatch* (a flat checksum reconciliation), not a clock, so
eventual consistency is *measured*, not hoped for.

Result: strong eventual consistency for free, and CAP solved by scheduling the three
invariants in time rather than trading them. Verified: partition-tolerant conservation
(isolated views converge to the conserved total), order-independent convergence (one
final state over many merge orders), debt surfacing in full on heal, and every
publish-failure path preserving subspaces. `(shown)`

### 4.6 Safety and liveness — measure conversion, not duration; then ask

A deadlock detector must be **safe** (never abort a live process) and **live** (always
catch a real deadlock, within a bound) — the two canonical property classes (Lamport,
1977:proving-correctness; Alpern & Schneider, 1985:defining-liveness). A timeout
forces a trade-off: short enough to catch real deadlocks aborts slow-but-live
processes; long enough to protect them misses or delays deadlocks. The trade-off looks
fundamental.

Reading of Q: **conversion — its presence or absence.** The budget of §4.1 measures
conversion, not duration. A slow-but-live process and a deadlocked one are
indistinguishable by elapsed time (neither finishes promptly) but perfectly
distinguishable by conversion (the live one is making progress, the dead one is not).

Fault and cure: the fault is measuring duration, the shadow, which conflates the two
states; the cure is to measure the conserved quantity, conversion, which separates
them. Safety follows from L2: a live process converts, refills its budget, never
floors, is never falsely flagged. Liveness follows from L3: a dead set converts
nowhere, drains to the floor in bounded steps, is caught. The two properties use the
same fact — budget tracks conversion — in the two cases, so there is nothing to trade.

There remains a case external measurement cannot see: a process at 100% CPU producing
nothing looks, from outside, identical to one doing hard internal work. The cure is to
stop inferring and **ask**: a progress signal (`SIG_PROGRESS`) to which a process
replies with a monotone counter. A rising counter refills the budget (the useful
process is spared — the case external inference could not save); a flat counter drains
it (the spinner is reclaimed, no clock). This upgrades agency from passive ("we never
falsely abort") to active ("we give each process a channel to account for itself"). A
process can lie, but that is the liar's problem, not the detector's: a lie corrupts the
liar's own evidence and is caught by an out-of-band reputation check comparing reported
to delivered progress. The detector provides the honest channel; it does not police
honesty.

Result: safety and liveness both hold, with no trade-off and bounded latency; a
slow-but-live process and a deadlock are classified correctly *at the same budget
size*, which no single timeout can do. Verified exhaustively (zero false positives,
zero false negatives, bounded latency) and the progress-signal case verified (useful
kept, spinner reclaimed, liar caught by reputation). `(shown)`

### 4.7 Flexibility and the middle way — Q moving from potential to actual

A network link has a latency *distribution*, not a latency; it is necessarily
probabilistic, and acting before the slow tail resolves (hedging) is the practical
acknowledgement of this (Dean & Barroso, 2013:tail-at-scale). Yet TCP and the code
above it treat the network as deterministic — collapsing the distribution to the point
estimate "the call returns by now" and waiting on it — one of the fallacies of
distributed computing (Deutsch, 1994:fallacies). Because the ordering of networked
events is relative (Lamport, 1978:time-clocks), a program that assumes a fixed
completion order has collapsed a random variable to a point.

Reading of Q: **the decision-quantity moving from potential to actual.** A decision,
while open, exists as potential distributed across its mutually-exclusive branches;
when it collapses, it becomes one actuality. **Flexibility** is the capacity to hold
that distribution open — to refrain from collapsing it before the evidence justifies.

Fault and cure: the fault is *premature collapse* — committing to an outcome (an
assumed completion order) before the evidence to convert it has arrived. This
manufactures phantom race conditions: orderings that were always latent in the tail of
the latency distribution but never observed while the system was fast. Slow a database
connection and reality samples the tail; a race "that should not exist" appears,
though it always existed at low probability. The cure is flexibility: carry the
distribution, act on the order that *actually resolves* (never an assumed one), and
keep the agency to act under uncertainty — hedge, take a second path, proceed
degraded — rather than surrender to a wait. A system that branches on the resolved
order has no assumption for load to violate, so the entire class of phantom races
cannot form.

The middle way. Flexibility appears to be the one *non*-conserved invariant: watched
on the potential side, a collapse only decreases it. But this is a boundary artifact —
the same kind as CAP's demanded simultaneity. A collapse does not destroy potential
into nothing; it *converts* one decision from the potential side (Future) into the
actual side (Present). What the Future loses, the Present gains, to the unit, so the
whole — potential plus actuality — is conserved. Conservation and non-conservation are
one transformation seen from two sides: from the Future, flexibility spent; from the
Present, actuality created; the same event. This is L4 (`stock = ∫ flow`) and the
Future→Present bridge of §4.5 at their deepest: collapsing potential *is* the bridge
that consolidates Future into Present. What is genuinely the agent's to choose is not
*whether* the decision moves (it must, and is conserved when it does) but *when* —
collapsing only when a real outcome resolves it, never on a guess or a timer.
Collapsing early is what manufactures the race.

Result: phantom races dissolved by carrying the distribution; flexibility located as
the wisdom of timing the collapse to the arrival of evidence; the apparent
non-conservation dissolved by accounting the whole. Verified: premature collapse
produces races on exactly the tail samples, carrying the distribution yields zero
races over the whole distribution, and the one decision has whole = 1 before and after
collapse (potential 1→0 as actuality 0→1). `(shown)`

---

## 5. Related work

We position the synthesis against the literatures it unifies, and state what is novel
relative to each.

**Conservation and network flow.** Stock-and-flow accounting (Forrester,
1961:industrial-dynamics) and conserved flow routed along graph edges (Ford &
Fulkerson, 1962:flows-in-networks) supply the vocabulary; L1 is the conservation those
frameworks take as foundational and L4 is their stock = ∫ flow identity. The novelty is
applying them *inside* a scheduler and identifying a deadlock-detection budget, a
rollback credit, and an inheritance rate as the integral, banked integral, and
derivative of one such quantity — and deriving the classical deadlock and inversion
results as consequences of its conservation laws.

**Deadlock detection and recovery.** Cycle detection in the wait-for graph (Coffman et
al., 1971:coffman-conditions; Holt, 1972:deadlock-graphs) is classical and our cycle
test is standard; the novelty is the conserved-quantity *trigger and starvation
decision* (conversion, not time), which yields both the timer-free detection of §4.1
and the no-trade-off safety/liveness result of §4.6. Against victim-based recovery
(Bernstein et al., 1987:concurrency-control) and timestamp pre-emption (Rosenkrantz et
al., 1978:wound-wait), the novelty is conserving the releaser's work as banked credit
so that resolution has no victim (§4.2).

**Scheduling and inversion.** Against priority inheritance and ceiling protocols (Sha
et al., 1990:priority-inheritance) and proportional-share schedulers (Demers et al.,
1989:fair-queuing; Waldspurger & Weihl, 1994:lottery; 1995:stride), the novelty is
expressing inheritance as a conserved *flow* summed along the wait-graph (rather than a
boosted maximum managed by a protocol), so inversion-freedom is structural and
memoryless (§4.3). The sum-not-maximum divergence is a direct prediction of
conservation and is, to our knowledge, not present in the inheritance literature.

**Distribution, CAP, CRDTs.** We do not evade CAP (Brewer, 2000:cap; Gilbert & Lynch,
2002:cap-proof): under partition the system is available and eventually consistent
(Vogels, 2009:eventually-consistent). The PN-counter and its join-semilattice
convergence are standard (Shapiro et al., 2011:crdts; verified by Gomes et al.,
2017:verifying-crdts). The novelty is the framing of eventual consistency as
conservation reasserting itself, of partition divergence as conserved debt, and —
centrally — of CAP as a *scheduling* problem whose three hard properties are the three
conservation invariants, solved by decoupling them in time along the Present/Future
axis. Reframing a famous impossibility as a scheduling-in-time problem is the
contribution; CRDTs are the tool it uses, not the result.

**Correctness, time, tail latency.** Against the safety/liveness dichotomy (Lamport,
1977:proving-correctness; Alpern & Schneider, 1985:defining-liveness), the novelty is
showing the trade-off in deadlock detection is an artifact of measuring duration and
dissolves under a conserved conversion measure (§4.6). Against the tail-at-scale
treatment of latency and hedging (Dean & Barroso, 2013:tail-at-scale) and the fallacies
of distributed computing (Deutsch, 1994:fallacies), the novelty is the underlying
principle — premature collapse of a probabilistic distribution manufactures phantom
races — and the middle-way resolution of flexibility's apparent non-conservation
(§4.7). The relativity of event order (Lamport, 1978:time-clocks) is what makes a fixed
assumed order a collapse.

**The unifying novelty.** Across all of the above, the contribution that is not present
in any single literature is the claim — and its sevenfold demonstration — that these are
one conserved quantity read in different registers, that the three system invariants are
corollaries of its conservation rather than independent design goals, and that the
field's impossibility results are boundary or simultaneity artifacts. We pre-register
this and invite refutation; a counterexample would be a pathology in one of the seven
domains that is genuinely *not* a stranded claim, or an impossibility among them that
survives widening the boundary to the whole.

---

## 6. Evaluation

The evidence is seven verifier engines, one per reading, each measuring the conserved
quantity directly. Every engine is audited to contain no wall-clock primitive
(`grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"` returns only prose),
and every engine uses exact arithmetic or exhaustive enumeration so its checks
reproduce deterministically.

| Reading | Engine | What it verifies | Result |
|---|---|---|---|
| 4.1 Detection | `iso_deadlock.py` | budget-floor + cycle catches deadlocks/knots; no false positives; latency = budget size | **PASS** |
| 4.2 Resolution | `iso_resolve.py` | credit-yield completes losing 0 work; discard-work livelocks | **PASS** |
| 4.3 Scheduling | `iso_flow.py` | blocked rate flows to holder (0.77 vs 0.23); busy-work does not feast; memoryless return | **PASS** |
| 4.4 Conservation | `iso_conserve.py` | L1 invariant (incl. routing), L2 monotone, L3 absorbing, L4 exact | **PASS** |
| 4.5 Distribution / CAP | `iso_distributed.py`, `iso_cap.py` | partition-tolerant conservation; order-independent convergence; debt comes due; CAP protocol with subspace-preserving failure paths | **PASS** |
| 4.6 Safety / liveness | `iso_safety.py`, `iso_progress.py` | exhaustive: 0 false positives, 0 false negatives, bounded latency; SIG_PROGRESS keeps useful, reclaims spinner, catches liar | **PASS** |
| 4.7 Flexibility | `iso_flex.py` | premature collapse → races on tail samples; carrying distribution → 0 races; whole conserved across collapse | **PASS** |

The engines are evidence for the structure, not the structure itself. Two limitations
are stated plainly. First, the conservation laws (§4.4) are verified *numerically* on
toy models, not machine-checked; they are stated precisely enough to be discharged in a
proof assistant (L1 as a preserved invariant is the keystone, from which L2–L4 and the
safety/liveness results of §4.6 follow), and that formalisation is the first item of
§7. Second, the distributed and network results (§4.5, §4.7) hold for *closed* conserved
models; the open-system extensions that would turn their broader readings (ecological
debt; real network runtimes) into theorems are named in §7, not claimed here. Within
those bounds, the seven engines jointly demonstrate that the single structure of §3
holds in each field.

---

## 7. Further work

Collected from the seven readings, in rough order of leverage.

- **Machine-checked conservation laws (the keystone).** Discharge L1–L4 in Lean or Coq
  over the transition system; L1 (conservation preserved by each step) is the keystone,
  and the share-sum lemma decouples it from the flow-equation details. Safety and
  liveness (§4.6) then follow as corollaries of L2 and L3, and the rest of the series
  inherits machine-checked rigor. A standalone version of this paper would lead with
  these as `(proven)` rather than `(shown)`.
- **The flow-equation kernel and its syscalls.** Replace an operating system's fair
  scheduler (CFS/EEVDF) with effective weight computed from the wait-graph by the flow
  equation of §4.3, summed not maximised, preserving the scheduler's lag/eligibility
  invariants (which are conservation in the kernel). Add the `SIG_PROGRESS` signal of
  §4.6 and a result-delivery reaping syscall that eliminates zombies by the same
  route-or-release principle. Test under induced inversion and induced tail latency.
- **Open-system conservation (sources and sinks).** Extend the closed law to accounted
  flux across a boundary (a continuity equation with source/sink terms). This is what
  would turn §4.5's evocative readings — debt deferred surfacing in a coupled ledger,
  off-the-books resources reappearing as debt elsewhere — from inspiration into theorem,
  by making "off the books here" provably "on the books there."
- **Min-cut and the deadlock set.** If the scheduling rate flowing along wait-edges is a
  flow network (Ford & Fulkerson, 1962:flows-in-networks), does the deadlocked set
  correspond to a min-cut, and does max-flow characterise the maximal schedulable
  throughput around a contended resource?
- **Quantitative eventual consistency.** Eventual consistency (§4.5) guarantees
  convergence but not its time. Under a gossip model with given fanout and partition
  duration, bound the time-to-converge — the "eventually" made quantitative — connecting
  to the bounded-latency detection of §4.1.
- **Flexibility as entropy, and the second-law question.** Define flexibility (§4.7) as
  the entropy of the live distribution and prove the directional law in that setting.
  The open question is whether the from-inside-time, directional view of conservation is
  a genuine *second law* for systems (an arrow of time) or simply the first law seen as a
  schedule — the same question the middle-way result raises.
- **A runtime discipline for carrying the distribution.** Specify an async pattern or
  library in which code is structurally prevented from assuming a completion order
  (§4.7), with an honest cost model for hedging (when a second request's duplicate work
  costs less than the tail it avoids).
- **Byzantine contributions.** PN-counter conservation (§4.5) assumes each node honestly
  records its own contribution; the progress signal (§4.6) likewise assumes honest
  self-report, policed only by reputation. Characterise the conserved-quantity analogue
  of Byzantine fault tolerance: can a merge detect a contribution that violates
  conservation?

---

## 8. Conclusion

Concurrency control, distributed consistency, scheduling, and correctness are usually
four fields with four toolkits and four impossibilities. This paper has argued they are
one structure: a single conserved quantity moving through a graph of dependencies,
mishandled in exactly one way — held where it cannot convert — and cured in exactly one
way — routed to where it can, or released. The quantity has three readings related by
calculus, and the four fields are seven readings of it: detection reads its stock's
floor; resolution banks that stock across a yield; scheduling routes its derivative
along a wait-edge; the conservation law states the quantity and proves the three system
invariants are its corollaries; distribution carries it across partition and reframes
CAP as a scheduling problem whose hard properties are those very invariants; safety and
liveness read its conversion and cease to trade off; and flexibility watches it move
from potential to actual, dissolving both the network's phantom races and its own
apparent non-conservation. Each reading was demonstrated by a verifier that measures the
conserved quantity and never consults a clock.

Two threads run through all seven. The first is the dissolution move: every
impossibility encountered — the victim in deadlock recovery, the inversion protocol,
CAP, the safety/liveness trade-off, the non-conservation of flexibility — turned out to
be an artifact of a boundary drawn too small or a simultaneity demanded too strictly,
and dissolved when the whole was seen. The second is the identity of the systems law and
the values: the epistemic, alignment, and agency invariants are not ethics imposed on a
mechanism but the conservation law read in a human register, which is why the same
structure yields a scheduling theorem and a moral one. That theorem is the paper's
spine — in a connected dependency graph, hoarding the conserved quantity is
self-defeating, because the holder's own progress runs through the very nodes it
starves, so the selfish optimum and the generous optimum are the same point.

The series is called Isomorphic because that is the finding rather than the framing:
seven results, one shape. This document is that shape, written so the seven can be read
back out of it — and so a standalone treatment, once the conservation laws are
machine-checked, can be assembled from it by deriving the background from the literature
and leading with the proof. Energy flows where attention goes; what flows is conserved;
and a system — like a life — is well-run exactly when it holds no claim it cannot
convert, and routes what it has to where the whole can use it.

---

## Bibliography

Conservation and network flow
- Forrester, J. W. (1961). *Industrial Dynamics.* MIT Press. — `1961:industrial-dynamics`
- Ford, L. R., Fulkerson, D. R. (1962). *Flows in Networks.* Princeton University Press. — `1962:flows-in-networks`

Deadlock, resolution, transactions
- Coffman, E. G., Elphick, M., Shoshani, A. (1971). *System Deadlocks.* ACM Computing Surveys. — `1971:coffman-conditions`
- Holt, R. C. (1972). *Some Deadlock Properties of Computer Systems.* ACM Computing Surveys. — `1972:deadlock-graphs`
- Bernstein, P. A., Hadzilacos, V., Goodman, N. (1987). *Concurrency Control and Recovery in Database Systems.* Addison-Wesley. — `1987:concurrency-control`
- Rosenkrantz, D. J., Stearns, R. E., Lewis, P. M. (1978). *System Level Concurrency Control for Distributed Database Systems.* ACM TODS. — `1978:wound-wait`

Scheduling and priority inversion
- Sha, L., Rajkumar, R., Lehoczky, J. P. (1990). *Priority Inheritance Protocols: An Approach to Real-Time Synchronization.* IEEE Transactions on Computers. — `1990:priority-inheritance`
- Reeves, G. E. (1997). *What Really Happened on Mars?* (Mars Pathfinder priority inversion account.) — `1997:pathfinder`
- Demers, A., Keshav, S., Shenker, S. (1989). *Analysis and Simulation of a Fair Queueing Algorithm.* SIGCOMM. — `1989:fair-queuing`
- Waldspurger, C. A., Weihl, W. E. (1994). *Lottery Scheduling: Flexible Proportional-Share Resource Management.* OSDI. — `1994:lottery`
- Waldspurger, C. A., Weihl, W. E. (1995). *Stride Scheduling: Deterministic Proportional-Share Resource Management.* MIT tech report. — `1995:stride`

Distribution, CAP, CRDTs
- Brewer, E. (2000). *Towards Robust Distributed Systems* (CAP conjecture, PODC keynote). — `2000:cap`
- Gilbert, S., Lynch, N. (2002). *Brewer's Conjecture and the Feasibility of Consistent, Available, Partition-Tolerant Web Services.* ACM SIGACT News. — `2002:cap-proof`
- Vogels, W. (2009). *Eventually Consistent.* Communications of the ACM. — `2009:eventually-consistent`
- Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011). *Conflict-free Replicated Data Types.* SSS. — `2011:crdts`
- Gomes, V. B. F., Kleppmann, M., Mulligan, D. P., Beresford, A. R. (2017). *Verifying Strong Eventual Consistency in Distributed Systems.* OOPSLA (Isabelle/HOL). — `2017:verifying-crdts`

Correctness, time, tail latency
- Lamport, L. (1977). *Proving the Correctness of Multiprocess Programs.* IEEE Transactions on Software Engineering. — `1977:proving-correctness`
- Alpern, B., Schneider, F. B. (1985). *Defining Liveness.* Information Processing Letters. — `1985:defining-liveness`
- Lamport, L. (1978). *Time, Clocks, and the Ordering of Events in a Distributed System.* Communications of the ACM. — `1978:time-clocks`
- Dean, J., Barroso, L. A. (2013). *The Tail at Scale.* Communications of the ACM. — `2013:tail-at-scale`
- Deutsch, P. (1994). *The Fallacies of Distributed Computing.* — `1994:fallacies`

> Citation keys are permanent `Year:slug` handles; the slug is the load-bearing
> identifier, full bibliographic resolution secondary to seed stability. This paper's
> own seed, `iso-sched-08:one-quantity-seven-readings`, is the generator from which the
> seven readings unfold.

---

## Appendix A — Reproducibility

- Artifacts: the seven engines listed in the header, committed at `477fbf3` (Team Phi).
- Run each with `python3 <engine>.py`; each prints its checks and a verdict.
- No-timer audit (per engine): `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic" <engine>.py` returns only prose in comments.
- Determinism: exact rational arithmetic or exhaustive enumeration throughout; no RNG in the verifiers. Checks reproduce exactly.

## Appendix B — The whole structure in one screen

```
ONE conserved quantity Q in a graph of dependencies.
ONE fault: a claim held where it cannot convert (a stranded claim / a hoard).
ONE cure: route Q to where it converts, or release it.

Q has three readings (calculus):
  flow   = dQ/dt          -> routed along the wait-edge       = SCHEDULING   (4.3)
  stock  = ∫ flow         -> its floor                        = DETECTION    (4.1)
  credit = ∫ flow, banked -> carried across a yield           = RESOLUTION   (4.2)
  the quantity itself, stated and proved (L1–L4)              = CONSERVATION (4.4)
  carried across partition (hidden, not lost)                 = DISTRIB/CAP  (4.5)
  read as conversion present/absent                           = SAFETY/LIVE  (4.6)
  moving from potential to actual                             = FLEXIBILITY  (4.7)

THREE invariants, corollaries of conservation (L1), not additions:
  epistemic  -- track evidence; do not collapse a distribution early
  alignment  -- shared, not replacing; a part's success runs through the whole
  agency     -- no private gain at the whole's expense; account for self

DISSOLUTION move (recurs): every impossibility is an artifact of a boundary too
  small or a simultaneity too strict. Widen to the whole; schedule over time;
  measure the conserved quantity, not its shadow. Then it dissolves.

CENTRAL THEOREM: in a connected graph, hoarding is self-defeating — the selfish
  optimum and the generous optimum are the same point. The math is the ethic.

No wall clock anywhere. Energy flows where attention goes; what flows is conserved.
```
