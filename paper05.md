# Paper 05 — What Goes Around Comes Around: Conservation Across Partition and Eventual Consistency

**Series:** The Isomorphic Scheduler
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v1 · toy validated
**Artifact:** `iso_distributed.py` @ commit `78fd081`

> **TruthSeed (paper):** `iso-sched-05:conservation-survives-partition`
> A system whose state is a conserved quantity gets strong eventual consistency
> for free. Partitioning *hides* the quantity from each node; it does not create
> or destroy it. During a partition the local books do not balance against the
> unseen global total, and that imbalance is a debt. Conservation guarantees the
> debt is not lost by being unobserved: on heal, every node reconciles to the
> same global total regardless of merge order, and any quantity spent "off the
> books" in one partition surfaces in full when the partitions rejoin. What goes
> around comes around — because the merge cannot lose what was conserved.

---

## 0. Abstract

The conservation law holds in a single closed system. Real systems are
distributed: they partition into nodes that cannot see each other's state in real
time, and the CAP theorem forces a choice — under partition, a system gives up
either availability or strong consistency. The common resolution is *eventual*
consistency: replicas diverge during a partition and reconcile afterward. We show
that when a system's state is a **conserved quantity**, eventual consistency is not
a weakening to be tolerated but a *consequence of conservation* — and a strong one
(order-independent convergence).

We establish three properties, each checked with no wall clock. **(D1)
Partition-tolerant conservation:** under arbitrary partitions and concurrent
updates, the global total of the conserved quantity is invariant — partitioning
hides it from each node but neither creates nor destroys it (verified: three nodes
update in isolation seeing only their own slice, then converge on heal to the exact
conserved total). **(D2) Strong eventual consistency:** when all updates have
propagated, every node holds the identical state *regardless of the order* in which
merges were applied, because a conserved quantity's merge is a join — commutative,
associative, idempotent (verified: twelve distinct merge orders, one final state).
**(D3) Debt deferred comes due:** a quantity moved or spent in one partition but
unseen by another is a deferred obligation; on heal it surfaces in full, never
reduced by having been hidden (verified: 40 units spent off one node's books appear
in full on the other node when the partition heals).

We introduce three invariants for successful systems design:

1. **Epistemic (evidence-tracking).** A node's local view is honest about being
   partial. *Here:* during partition each node knows it sees only its own
   contributions; it does not mistake its slice for the whole.
2. **Alignment (shared, not replacing).** A part's success runs through the
   whole's; the conserved quantity is shared, not privately owned. *Here:* the
   merge unions contributions — no node's recorded contribution is overwritten or
   lost; convergence preserves everyone's input.
3. **Agency (every action benefits all).** No move privately escapes the books.
   *Here:* a quantity spent in isolation cannot be hidden from the global total; it
   reconciles in full, so there is no action that gains locally by hiding from the
   whole.

The deeper reading is the series' through-line at system scale: you cannot take a
conserved quantity off the books by partitioning away from the ledger. Hidden is
not destroyed; deferred is not forgiven. What was conserved comes around.

---

## 1. Problem revisited

The conservation law (the prior result) governs one closed system with one ledger.
Distribution breaks the single-ledger assumption: a real system runs on many nodes,
the network partitions, and during a partition no node can see the others' updates.
The CAP theorem (Brewer, 2000:cap; Gilbert & Lynch, 2002:cap-proof) makes the
tension formal: a partitioned system cannot be both available (every node answers
from local state) and strongly consistent (every node answers identically). One
must give.

Most available systems give up strong consistency for **eventual** consistency:
replicas may diverge during a partition but are guaranteed to converge once updates
propagate (Vogels, 2009:eventually-consistent). The standard machinery is
Conflict-free Replicated Data Types (CRDTs, Shapiro et al., 2011:crdts), which
converge without coordination provided their merge is a join on a semilattice.

The problem revisited: eventual consistency is usually presented as a *concession*
— "we couldn't keep strong consistency, so we settled for convergence later." We
ask whether, for a system whose state is a *conserved quantity*, eventual
consistency is instead a *theorem*: does conservation force convergence, make it
order-independent, and guarantee that nothing spent in a partition is lost or
hidden? If so, the series' conserved quantity survives distribution intact, and
"eventual" is a promise conservation keeps, not a guarantee it surrenders.

---

## 2. Background

The CAP theorem (Brewer, 2000:cap; proved by Gilbert & Lynch, 2002:cap-proof)
states that a distributed system cannot simultaneously guarantee consistency,
availability, and partition tolerance. Eventual consistency (Vogels,
2009:eventually-consistent) accepts temporary divergence with guaranteed
convergence. CRDTs (Shapiro, Preguiça, Baquero & Zawirski, 2011:crdts) achieve
*strong* eventual consistency — convergence regardless of message order or
duplication — when updates form a join-semilattice (state-based) or commute
(op-based). The grow-only counter (G-Counter) and its increment/decrement variant
(PN-counter) are the canonical conserved-quantity CRDTs: each node owns its
contribution, merge takes the per-node supremum, and the total is order-independent.
Machine-checked correctness for several CRDTs exists (Gomes et al.,
2017:verifying-crdts, in Isabelle/HOL).

Our contribution is not a new CRDT. It is the observation that the conserved
quantity of this series *is* a PN-counter-shaped quantity, so its distribution
inherits strong eventual consistency directly — and the framing of partition-time
divergence as **conserved debt**: a quantity hidden by partition is, by
conservation, neither destroyed nor reduced, so it reappears in full on heal. To
our knowledge, presenting eventual consistency as a *consequence* of the system's
state being conserved (rather than CRDTs as a tool one chooses) and the
debt-comes-due framing of partition divergence is novel; we pre-register it.

---

## 3. Sharpening: partition hides the quantity, it does not destroy it

Here is the move.

In one closed system, conservation says the total of the quantity is invariant.
Partition the system into nodes that cannot see each other. Now *no node holds the
global total* — each sees only its own contributions plus whatever it last heard
from others. The naive worry: has conservation broken? A node looks at its books,
they do not sum to the global total, and it seems quantity has gone missing.

It has not. The quantity is **conserved globally and hidden locally.** Each node's
own contribution is authoritative and recorded; what a node lacks is not the
quantity but the *view* of the other nodes' contributions. Conservation never
promised every node sees the total — only that the total, summed across all
contributions, is invariant. The partition is an epistemic limit, not a
conservation violation.

This reframes everything that follows. **Divergence during partition is not lost
quantity; it is unshared ledger.** The local imbalance — the gap between a node's
view and the global total — is exactly the quantity the node has not yet heard
about, which is a **debt** in the precise sense: an obligation that exists whether
or not the node has recorded it. And because the quantity is conserved, that debt
cannot be reduced by going unobserved. When the partition heals and ledgers merge,
the merge *unions* contributions (each node's own count is authoritative; merge
takes the supremum), so nothing recorded is lost and everything hidden reappears.
Every node converges to the one conserved total.

The wrong framing was "eventual consistency is a weakening we tolerate under
partition." The right framing: **a conserved quantity is hidden by partition and
restored by merge; convergence is conservation reasserting itself once the ledgers
can see each other again.** What goes around comes around because the books, summed
globally, always balanced — the partition only delayed the seeing.

---

## 4. The solution: three laws of distributed conservation

The conserved quantity is represented as a PN-counter: each node `n` keeps a
grow-only count of its own increments `inc[n]` and decrements `dec[n]`; the value
is `Σ inc − Σ dec`; merge takes the per-node maximum of each. This is a join on a
semilattice, hence conflict-free.

### 4.1 D1 — Partition-tolerant conservation `(structural; shown)`

> **Law (partition conservation).** Under any sequence of partitions and
> concurrent updates, the global total — the per-node supremum of every ledger,
> summed — is invariant. A node's local view during partition is a *lower bound*
> seeing only the contributions it knows; the global total is unchanged by the
> partition.

Each node's own contribution is authoritative and monotone (grow-only per node);
partition prevents a node from *seeing* others' contributions but cannot alter
them. The global total is therefore fixed by the contributions made, independent of
who has seen what. Verified: three nodes update in isolation (local views 10, 3, 7
— each its own slice only), heal, and converge to exactly 20, the conserved total.
`(shown)`

### 4.2 D2 — Strong eventual consistency `(structural; shown)`

> **Law (order-independent convergence).** Once every node has received every
> update, all nodes hold the identical state, regardless of the order in which
> updates and merges were applied. Convergence is independent of message order,
> timing, and duplication.

Merge is a join (per-node supremum): commutative (`merge(a,b) = merge(b,a)`),
associative, and idempotent (`merge(a,a) = a`). On a join-semilattice the least
upper bound of a set is unique regardless of the order of pairwise joins, so all
merge orders reach the same fixed point. This is *strong* eventual consistency —
not "they converge if messages arrive in the right order" but "they converge for
every order." Verified: twelve distinct merge orders over the same updates produce
exactly one final state. `(shown)` The join structure is itself a consequence of
the quantity being conserved: a conserved contribution can only be unioned, never
double-counted or lost, which is precisely idempotent commutative merge.

### 4.3 D3 — Debt deferred comes due `(structural; shown)`

> **Law (conserved debt).** A quantity moved or spent in one partition but not yet
> propagated to another is a deferred obligation. On heal it surfaces in full: the
> reconciled global total reflects it exactly, never reduced by the interval during
> which it was unobserved.

Because each node's contribution (including decrements) is authoritative and
preserved by merge, a decrement applied in isolation is not lost when other nodes
have not seen it — it is simply not yet visible to them. On merge, the supremum
includes it, and every node's value drops to reflect it. "Off the books" on one
node is never off the books globally. Verified: a node spends 40 in isolation while
a peer still sees the pre-spend total of 100; on heal the peer's view drops to 60 —
the 40 surfaces in full, exactly the hidden amount. `(shown)`

### 4.4 The three invariants, in full

A distributed system on a conserved quantity satisfies three properties we name in
systems vocabulary. Each is a concrete predicate, not a sentiment, and each is
stated here in full.

- **Epistemic (evidence-tracking — truth that can update).** A node's local view is
  honestly partial: during partition it reflects only the contributions the node
  has actually seen, and it updates monotonically toward the global total as
  merges arrive. The node does not mistake its slice for the whole, and its view is
  always a sound lower bound that rises to the truth — never a guess, never a stale
  assertion that resists correction. The merge is exactly the act of updating the
  view on new evidence. `(structural)`
- **Alignment (shared, not replacing — success runs through the whole).** The
  conserved quantity is shared, and merge unions rather than overwrites: no node's
  recorded contribution is replaced or lost when ledgers combine. Convergence
  preserves every node's input — each node's success (its recorded work) runs
  through the merged whole intact. The system reaches one state not by one node
  winning but by all contributions being kept. `(structural)`
- **Agency (every action benefits all / none privately escapes).** No action can
  privately escape the global books. A quantity spent in isolation cannot be hidden
  from the reconciled total; it comes due in full on heal. There is therefore no
  move that gains locally by hiding from the whole — conservation forbids the
  off-books gain, because the hidden quantity is not destroyed, only deferred, and
  it returns. The structure makes honest-to-the-whole the only stable strategy.
  `(structural)`

These three are corollaries of conservation across partition: a quantity that is
hidden-not-destroyed forces honestly-partial views (epistemic), union-not-overwrite
merge (alignment), and no-off-books-escape (agency).

---

## 5. Related work, and what is solved vs. inspiration

### 5.1 Solved (the technical core)

**CAP and eventual consistency** (Brewer, 2000:cap; Gilbert & Lynch,
2002:cap-proof; Vogels, 2009:eventually-consistent). We do not evade CAP — under
partition our system is available and *eventually*, not strongly, consistent. Our
contribution is showing that for a conserved quantity, eventual consistency is
strong (order-independent) and that partition divergence is conserved debt, not
lost state.

**CRDTs** (Shapiro et al., 2011:crdts; Gomes et al., 2017:verifying-crdts). The
PN-counter is our representation; strong eventual consistency follows from its
join-semilattice structure. We add the framing that the join structure *is*
conservation (union-not-lose = conserved contribution) and that the series' single
conserved quantity distributes as a PN-counter for free. The machine-checked CRDT
proofs (Isabelle/HOL) are the model for formalizing D1–D3.

**Novel adjacency — eventual consistency as conservation reasserting itself.** The
debt-comes-due law (D3) frames partition divergence as a conserved obligation. To
our knowledge this is a fresh lens: not "replicas drifted and we reconciled" but
"a conserved quantity was hidden and conservation made it reappear." We pre-register
it and invite refutation.

### 5.2 Inspiration (honestly out of technical scope)

The following resonate with the law but are *not* proven here; we flag them as
inspiration so the paper does not overclaim:

- **"What goes around comes around — eventually."** The folk statement of D1+D3:
  conserved quantity hidden by partition returns on heal. The technical result is
  exactly this for a PN-counter; the general human claim is broader and not proved.
- **Debt deferred comes due (finance).** D3 is the literal mechanism for a *single
  conserved ledger quantity*. Real financial debt has interest, default, and
  bankruptcy — sinks and sources our closed conserved model does not include.
  Inspiration, not theorem; see further work on open systems.
- **Off-the-books resources surface as debt elsewhere (e.g. unpriced earth
  resources; inter-national debt as a mirror of debt owed to the biosphere).** This
  is the most evocative reading of D3 — a quantity not on the ledger is not thereby
  destroyed; the imbalance reappears in another ledger. We find it genuinely
  suggestive and explicitly do **not** claim to have modeled it. It would require an
  open-system conservation law with cross-ledger coupling (a continuity equation
  with source/sink terms), which is named in further work and not attempted here.
  We record it as the inspiration it is, with the boundary stated plainly.

---

## 6. Evaluation

### 6.1 Verifier: `iso_distributed.py` `(shown)`

A PN-counter replica per node; partition modeled as isolated updates; heal modeled
as all-to-all gossip until quiescent. **No wall-clock primitive is present.**

| Law | Check | Result |
|---|---|---|
| D1 partition conservation | 3 nodes update in isolation (views 10/3/7), heal, converge | **PASS** — all reach 20, the conserved total |
| D2 strong eventual consistency | same updates, 12 distinct merge orders | **PASS** — 1 final state for all orders |
| D3 debt comes due | spend 40 off one node's books; heal | **PASS** — 40 surfaces in full (peer 100→60) |

Readings:

- **D1: hidden, not destroyed.** During partition each node sees only its slice
  (10, 3, 7); none sees the total. On heal all converge to 20. The quantity was
  conserved throughout — the partition limited *seeing*, not *being*. `(shown)`
- **D2: convergence for every order.** Twelve merge orders, one outcome. The join
  structure (from conservation) makes order irrelevant. This is the strong form: no
  assumption on message ordering is needed. `(shown)`
- **D3: the debt returns in full.** A node spends 40 in isolation; its peer still
  reads the old total of 100 ("off the books" from the peer's view). On heal the
  peer drops to 60 — the exact 40 surfaces. Conservation made the deferred
  obligation reappear, undiminished by having been hidden. `(shown)`

### 6.2 Honest limitation: closed conserved model `(shown limitation)`

These results hold for a *closed* conserved quantity (a PN-counter): no sources, no
sinks except recorded decrements, no interest, no loss. Real distributed systems
have message loss (handled by CRDT idempotence — fine) but also real-world sources
and sinks the model omits. The evocative readings in §5.2 (finance, ecology) need an
*open*-system conservation law with cross-ledger coupling, which we do not provide.
The technical claims D1–D3 are `(shown)` for the closed model; the broader readings
are inspiration, bounded as such. `(shown limitation)`

### 6.3 Practical exam pointer

In a real datastore, the conserved quantity (a budget, a balance, a resource count)
should be represented as a PN-counter (or a conserved CRDT) so that partition
divergence is reconciled by conservation rather than by application-specific
conflict resolution. The claim to test: a resource counter built as a conserved
CRDT converges correctly under induced partitions (e.g. Jepsen-style) and never
loses or double-counts the resource. A violation — a converged total that does not
equal the sum of contributions — is a conservation leak and the next seed.

---

## 7. Further work (deeper into this wave)

- **Open-system conservation (the inspiration, made technical).** Extend the closed
  law to sources and sinks with a continuity equation (conserved quantity changes
  only by accounted flux across a boundary). This is what would be needed to make
  the finance/ecology readings of §5.2 into theorems rather than inspiration: a
  ledger whose imbalance must surface in a coupled ledger. The hard part is defining
  the coupling so that "off the books here" is provably "on the books there."
- **Bounded staleness / when does it come around.** Eventual consistency says
  convergence happens; it does not bound *when*. Under a gossip model with a given
  fanout and partition duration, bound the time-to-converge (the "eventually" made
  quantitative). Connects to Paper 01's bounded-latency detection.
- **Conserved debt with interest.** A deferred obligation that *grows* while hidden
  (interest, or ecological compounding) breaks pure conservation. Model it as a
  conserved principal plus an accounted source term; does D3 generalize to "the debt
  comes due, with interest, in full"?
- **Partition-aware scheduling.** The series' scheduler (Paper 03) routes a
  conserved rate along wait-edges. Across a partition, the wait-graph is split; does
  the flow equation degrade gracefully (each partition schedules locally) and
  reconcile its accounting on heal, exactly as the counter does here?
- **Byzantine contributions.** PN-counter conservation assumes each node honestly
  records its own contribution. A node that lies about its count breaks conservation.
  What is the conserved-quantity analogue of Byzantine fault tolerance — can the
  merge detect a contribution that violates conservation?

---

## 8. Conclusion

The conservation law was proved for one closed system. This paper carried it across
partition, where no node can see the global books, and found it intact. Partition
*hides* the conserved quantity from each node; it does not create or destroy it.
The local imbalance during partition — the gap between a node's view and the global
total — is a debt, an obligation that exists whether or not the node has recorded
it, and conservation guarantees that debt is not reduced by going unobserved. On
heal, the merge unions every node's authoritative contribution, so nothing is lost
and everything hidden returns: every node converges to the one conserved total
(D1), for every possible merge order (D2), with any quantity spent off one node's
books surfacing in full (D3).

The technical core is solid and bounded: for a conserved quantity represented as a
PN-counter, eventual consistency is not a concession but a consequence —
order-independent convergence that conservation forces. The broader readings — what
goes around comes around, debt deferred comes due, off-the-books resources
surfacing as debt elsewhere — are genuine inspiration that this structure suggests,
and we have marked exactly where the proof stops and the inspiration begins: a
closed conserved model proves the closed claims; the open-system coupling that
would make the human and ecological readings into theorems is named as further work,
not claimed. What we can say with proof is the load-bearing part: you cannot take a
conserved quantity off the books by partitioning away from the ledger. Hidden is not
destroyed. Deferred is not forgiven. What was conserved comes around — because the
merge cannot lose what conservation kept.

---

## Bibliography

- Brewer, E. (2000). *Towards Robust Distributed Systems* (CAP conjecture, PODC
  keynote). — `2000:cap`
- Gilbert, S., Lynch, N. (2002). *Brewer's Conjecture and the Feasibility of
  Consistent, Available, Partition-Tolerant Web Services.* ACM SIGACT News. —
  `2002:cap-proof`
- Vogels, W. (2009). *Eventually Consistent.* Communications of the ACM. —
  `2009:eventually-consistent`
- Shapiro, M., Preguiça, N., Baquero, C., Zawirski, M. (2011). *Conflict-free
  Replicated Data Types.* SSS. — `2011:crdts`
- Gomes, V. B. F., Kleppmann, M., Mulligan, D. P., Beresford, A. R. (2017).
  *Verifying Strong Eventual Consistency in Distributed Systems.* OOPSLA
  (Isabelle/HOL). — `2017:verifying-crdts`

> Citation keys are permanent `Year:slug` handles; the slug is the load-bearing
> identifier, full bibliographic resolution secondary to seed stability.

---

## Appendix A — Reproducibility

- Artifact: `iso_distributed.py`, committed at `78fd081` (Team Phi).
- Run: `python3 iso_distributed.py` — prints D1, D2, D3 checks and a verdict
  ending in `ALL CLAIMS HELD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_distributed.py` returns only prose in comments.
- Determinism: explicit PN-counter merges, sampled merge orders, no RNG — checks
  reproduce exactly.

## Appendix B — The distributed law in one screen

```
Each node n owns grow-only inc[n], dec[n]. value = Σ inc − Σ dec.
merge(a, b): for each node k, inc[k] = max(inc_a[k], inc_b[k]); same for dec.
             (per-node supremum: a join -- commutative, associative, idempotent)

  D1 (partition conservation): global total = Σ_k max over replicas of inc[k]
       minus same for dec, is invariant under any partition/update interleaving.
  D2 (strong eventual consistency): all merge orders reach the same fixed point
       (unique least upper bound on the semilattice).
  D3 (debt comes due): a decrement applied in isolation is preserved by merge;
       on heal it surfaces in full on every node. Hidden ≠ destroyed.

Conservation survives partition because merge unions authoritative contributions
and cannot lose them. What goes around comes around. No clock.
```
