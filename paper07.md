# Paper 07 — Flexibility Is Not Conserved: Probability, Premature Collapse, and the Phantom Races of a Deterministic Network

**Series:** The Isomorphic Scheduler
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v1 · toy validated
**Artifact:** `iso_flex.py` @ commit `074d788`

> **TruthSeed (paper):** `iso-sched-07:flexibility-is-the-capacity-not-to-collapse`
> The earlier papers used conserved quantities — budget, credit, rate — that move
> and are preserved. Flexibility is a different kind of thing. It is not conserved
> and does not move; it is the capacity to hold a distribution open — to refrain
> from collapsing many possible outcomes into one assumed outcome before the
> evidence justifies it. You do not route flexibility; you either preserve it
> (stay open) or spend it irreversibly (collapse to a point), and once spent it is
> gone, not transferred. This is wisdom: the epistemic invariant at depth, the
> discipline of not mistaking a point estimate for the truth. A network is
> necessarily probabilistic; treating it as deterministic collapses the latency
> distribution prematurely and manufactures phantom race conditions — orderings
> that were always possible but never observed while everything was fast.

---

## 0. Abstract

This series has run on conserved quantities: a budget, a credit, a rate, all
preserved as they move through a system. This paper is about something that is
*not* conserved, and the difference is the point. **Flexibility** — the capacity to
hold a distribution of outcomes open rather than collapse it to a single assumed
one — is not stuff that moves. You do not route it from one place to another; you
either preserve it by staying open, or spend it irreversibly by committing to one
outcome. Once spent it does not reappear elsewhere; it is simply gone. Flexibility
obeys a one-way law (it is monotone non-increasing under collapse, like entropy),
not a conservation law. It is the **wisdom** invariant: the epistemic discipline of
not mistaking a point estimate for the truth.

The concrete problem is the network. A network link has a *latency distribution*,
not a latency, so it is necessarily probabilistic. Yet TCP and most application
code treat it as deterministic: they collapse the distribution to the point estimate
"the call will return by now," commit to that collapsed truth, and *wait* on it.
Two failures follow. First, a slow dependency becomes indistinguishable from a dead
one — the same confusion Paper 06 found between slow-but-live and deadlocked, now at
the network layer. Second, and worse, **phantom race conditions appear**: orderings
that were always possible in the latency distribution but never observed while
everything was fast. Slow a database connection and races emerge "that should not
even exist" — but they always existed, at low probability; premature determinism
merely hid them.

We establish three properties with no wall clock. **(F1) Premature collapse
manufactures phantom races:** a system that assumes a fixed ordering (collapsing the
latency distribution, as code does when it was only ever tested on the fast path)
exhibits races whenever the network samples a tail outcome — verified by a slow tail
that flips the completion order the system assumed. **(F2) Flexibility dissolves
them:** a system that carries the distribution and acts only on the order that
actually resolved has no race in any sample, because it never assumed an order to
violate. **(F3) Flexibility is spent, not moved:** collapsing a decision is
irreversible and local — the foreclosed potential does not reappear anywhere, so
flexibility is monotone non-increasing, a one-way loss, not a conserved quantity.

The three invariants at the network layer:

1. **Epistemic / Wisdom (truth as probability).** Represent the distribution, and
   collapse only on evidence — a genuinely resolved outcome — never on a timer. The
   truth of "which completed first" is a probability until the evidence earns the
   answer; asserting it early is the error.
2. **Agency (act under uncertainty).** Keep the power to act now — hedge, take a
   second path, proceed with a degraded answer, or shed the request — instead of
   surrendering agency to a wait whose duration you do not control.
3. **Alignment (the distribution is shared).** No part treats its local ordering as
   global truth; the probabilistic reality is held in common, so no part's
   correctness rides on an order it merely assumed.

The deeper reading: most "impossible" concurrency bugs in networked systems are
premature collapses. The network offered a distribution; the code took a point;
reality eventually sampled the rest of the distribution, and the difference is the
bug. Flexibility — refusing the premature collapse — is the fix, and it is the one
invariant in this series that you can only keep or spend, never conserve.

---

## 1. Problem revisited

Every prior paper found a conserved quantity. That success risks a blind spot: not
everything that matters in a system is conserved, and treating a non-conserved thing
as conserved is its own error. This paper names the non-conserved invariant —
flexibility — and shows it is exactly what a networked system needs and what the
deterministic abstraction destroys.

The setting is the network, and the specific failure is the one every operator has
seen: a system that runs fine suddenly exhibits race conditions when a dependency
(a database connection, a downstream service) becomes *slow* — not failed, just
slow. The races appear "from nowhere," in code that looked correct, and they are
maddening because they seem to violate orderings the code relied on. The standard
response is to treat them as new bugs introduced by load. They are not new. They
were always present in the system's *latency distribution*, with a probability low
enough that the fast path never sampled them. The slow dependency did not create the
race; it raised the probability of an ordering that was always possible until it
became likely enough to observe.

The problem revisited: this is not eventual consistency (Paper 05), which is about
reconciling divergent state after a partition. It is a layer beneath — about the
*timing* of operations being probabilistic while the code assumes it is
deterministic. The question is whether the three invariants, plus a fourth thing
that is not conserved, can characterize and fix it: can we say precisely what goes
wrong (a premature collapse of a distribution to a point) and what fixes it (the
capacity to not collapse — flexibility)?

---

## 2. Background

**Tail latency and the probabilistic network.** Real systems exhibit heavy-tailed
latency; the gap between median and tail latency is large and consequential (Dean &
Barroso, 2013:tail-at-scale). A network call's completion time is a draw from a
distribution, not a constant. Techniques like hedged and tied requests (ibid.)
explicitly treat latency as probabilistic and act before the slow tail resolves —
which, in our terms, is preserving flexibility (acting under uncertainty rather than
waiting on a collapsed assumption).

**Synchronous/wait-based models.** TCP delivers a reliable byte stream by waiting
and retransmitting; the abstraction it offers up the stack is "the data arrives,"
which invites code to model the call as a blocking operation that returns. The RPC
tradition inherited this and the "fallacies of distributed computing" (Deutsch,
1994:fallacies) catalogue the resulting false assumptions — "the network is
reliable," "latency is zero," "the topology doesn't change" — each a collapse of a
distribution to a convenient point.

**Race conditions and happens-before.** Concurrency correctness is usually framed
via a happens-before order (Lamport, 1978:time-clocks). A race is an ordering the
program did not account for. Our contribution is to note that in a networked system
the happens-before order is itself a *random variable*, so a program that assumes a
fixed happens-before has collapsed a distribution — and the race is the gap between
the assumed point and the actual distribution.

**Novel adjacency — flexibility as a non-conserved invariant.** Where the series'
earlier invariants are conserved, we introduce flexibility as explicitly
*not* conserved: a capacity spent one-way by collapse, governed by a monotone law
rather than a conservation law. Framing premature determinism as a premature
collapse, and the fix as preserving a non-conserved capacity, is to our knowledge
novel; we pre-register it.

---

## 3. Sharpening: the network offers a distribution; the bug is taking a point

Here is the move.

A network latency is a distribution. Code that says "issue the call, then use the
result" has, implicitly, collapsed that distribution to a single assumed outcome:
that the call completes within the time the surrounding logic expects. While the
system is fast, the assumption holds on every observed run, so it looks like a fact.
It is not a fact; it is a point estimate of a distribution, and the unobserved rest
of the distribution is still there.

Now consider two operations A and B whose results feed shared state, where the code
was written (and tested) when A was always faster than B, so it assumes "A completes
first." That assumption is a *collapse*: the latency distributions of A and B
overlap somewhere in their tails, and in that overlap B completes first. The code
has no branch for that order because, on the fast path, it never happened. Slow A
down — a slow DB connection, A's tail at the 99.9th percentile — and the system
samples the overlap. B completes first. The code runs its critical section in an
order it never accounted for. That is the phantom race, and it was always latent: it
lived in the tail of the distribution the code collapsed away.

The fix is not to make the network deterministic (impossible) nor to wait longer
(that is the collapse, restated, and it is what brings systems down — a slow
dependency stalls every waiter). The fix is **flexibility**: carry the distribution
instead of a point, and act on the order that *actually resolves*, whichever it is.
A system that branches on the resolved order — "whichever of A, B completed first is
treated as first" — has no order to get wrong, because it assumed none. The race
does not need to be detected and patched; it cannot form, because the premature
collapse that created it never happened.

This is the wisdom invariant — the epistemic invariant seen at depth. Honest
bookkeeping (the earlier papers' epistemic face) says "account for what you have."
Wisdom says something stronger: "do not mistake a point estimate for the truth; hold
the distribution open until the evidence earns the collapse." And it makes flexibility
visibly *not conserved*. When you collapse "A or B first" to "A first," the
possibility "B first" is not transferred anywhere — it is foreclosed, gone. You spent
flexibility; you did not move it. The wrong framing was "the network is basically
reliable, model the call as returning." The right framing: **the network is a
distribution; keep the distribution; collapse it only when a real outcome resolves;
and know that each collapse is a one-way expenditure of a capacity you cannot get
back.**

---

## 4. The solution: carry the distribution, spend flexibility only on evidence

### 4.1 F1 — Premature collapse manufactures phantom races `(structural; shown)`

> **Claim.** A system that collapses the latency distribution to an assumed
> completion order exhibits a race for every sample of the distribution in which
> the actual order differs from the assumed one. The set of such samples is
> non-empty exactly when the operations' latency distributions overlap.

The assumed order is correct only on the part of the joint distribution consistent
with it; on the complement (the tail overlap), the actual order differs and the
code's critical section executes in an unaccounted order — a race. Verified: with
A's latency in {1, 2, 9} (the 9 a slow-DB tail) and B's in {3, 4}, assuming "A
first" races on exactly the samples (9,3) and (9,4), where B completes first. The
race was always in the distribution; the slow tail merely sampled it. `(shown)`

### 4.2 F2 — Flexibility dissolves the race `(structural; shown)`

> **Claim.** A system that carries the distribution and acts on the resolved order
> (branching on whichever operation actually completed first) has no race in any
> sample, because it never assumed an order to violate.

For every sample the flexible system observes the actual completion order and acts
accordingly; there is no sample on which it is "wrong," because correctness no
longer depends on a collapsed assumption. The race set is empty across the entire
distribution. Verified: zero races over all samples. `(shown)` The cost of this
flexibility is real — the system must be written to handle either order, which is
more work than assuming one — but it is the cost of not collapsing, and it buys the
absence of a whole class of load-induced races.

### 4.3 F3 — Flexibility is spent, not moved (the one-way law) `(structural; shown)`

> **Law (flexibility is non-conserved).** Collapsing a set of open outcomes to one
> is irreversible and local: the foreclosed outcomes do not reappear elsewhere.
> Flexibility — the number of still-open outcomes, or more generally the entropy of
> the live distribution — is monotone non-increasing under collapse. It is spent,
> not conserved.

This is the structural break from the rest of the series. A budget moved from one
process to another is conserved (Paper 04, L1); flexibility collapsed from "A or B
first" to "A first" is *gone* — "B first" is not now held by some other part of the
system, it is foreclosed. Verified: collapsing a two-outcome state to one reduces
flexibility from 2 to 1, and the lost outcome is logged as lost, not transferred.
`(shown)` The law it obeys is monotone (one-way), the mirror image of a conservation
law: conserved quantities are invariant under movement; flexibility only decreases
under collapse. The discipline of wisdom is to spend it deliberately — to collapse
only when a real outcome resolves, never on a guess or a timer — precisely because
you cannot get it back.

### 4.4 The three invariants, in full

- **Epistemic / Wisdom (truth that can update — and is not collapsed early).** The
  system represents the latency distribution and treats "which operation completed
  first" as a probability until a real outcome resolves it. It collapses on
  evidence — an actually-resolved completion — never on elapsed time. This is the
  epistemic invariant at depth: not merely honest accounting of what is known, but
  the discipline of refusing to assert a point estimate as truth before the evidence
  earns it. Wisdom is knowing that the distribution is the truth and the point is a
  bet. `(structural)`
- **Alignment (shared, not replacing — the distribution is held in common).** No
  part treats its local view of the ordering as the global truth. Each part acts on
  the resolved order, which is the same for all, rather than on a private assumption
  about timing. Because the probabilistic reality is shared rather than each part
  collapsing it differently in its own corner, no part's correctness depends on an
  ordering another part did not also observe — which is exactly what prevents the
  phantom race from forming at a boundary between two parts. `(structural)`
- **Agency (act under uncertainty rather than surrender to the wait).** A part keeps
  the power to act at any instant without waiting on an outcome it does not control:
  it can hedge (issue a second, redundant request), take an alternate path, proceed
  with a degraded-but-valid answer, or shed the request. Surrendering agency to a
  blocking wait — the TCP/RPC default — is what lets a slow dependency stall every
  caller and bring a system down. Keeping agency under uncertainty is the active
  form: the part is never hostage to a wait. `(structural)`

These three together are the network-layer reading of the series' invariants, with
the epistemic one deepened into wisdom: hold the distribution (wisdom), share it
(alignment), and act within it without waiting (agency). The first is non-conserved
and one-way; that is what makes it wisdom rather than bookkeeping.

---

## 5. Related work

**Tail at scale and hedged requests** (Dean & Barroso, 2013:tail-at-scale). The
canonical treatment of latency as probabilistic and the practical mechanism (hedge,
do not wait on the tail) that, in our framing, preserves flexibility. We give the
underlying principle: hedging works because it refuses to collapse the latency
distribution to a point and keeps agency under uncertainty.

**Fallacies of distributed computing** (Deutsch, 1994:fallacies). Each fallacy is a
collapse of a distribution to a convenient point ("latency is zero," "the network is
reliable"). We unify the list under one diagnosis: premature determinism, the
spending of flexibility before evidence justifies it.

**Happens-before / logical time** (Lamport, 1978:time-clocks). A race is an
unaccounted ordering. We observe that in a networked system the happens-before order
is a random variable, so assuming a fixed order is a collapse, and the race is the
distance between the assumed point and the live distribution.

**Novel adjacency — the non-conserved invariant.** The series' contribution here is
to identify flexibility as explicitly not conserved — spent one-way by collapse,
governed by a monotone (entropy-like) law — and to derive the network's phantom
races as premature collapses. We pre-register this and invite refutation: a
counterexample would be a load-induced race that persists even when no ordering is
assumed and every action is taken on the resolved order.

---

## 6. Evaluation

### 6.1 Toy: `iso_flex.py` `(shown)`

We enumerate the joint latency distribution of two operations exhaustively and
compare a collapsed (order-assuming) system against a flexible (distribution-carrying)
one. **No wall-clock primitive is present.**

| Property | Check | Result |
|---|---|---|
| F1 premature collapse → races | assume "A first"; A∈{1,2,9}, B∈{3,4} | **PASS** — races on (9,3),(9,4): the slow-A tail |
| F2 flexibility dissolves | act on resolved order, all samples | **PASS** — zero races over the whole distribution |
| F3 flexibility non-conserved | collapse a 2-outcome state | **PASS** — flexibility 2→1, lost outcome foreclosed not transferred |

Readings:

- **F1: the phantom race is a sampled tail.** The race appears on exactly the
  samples where A is slow (latency 9) and therefore B completes first — the orderings
  the fast-path testing never exercised. This is the "race that should not exist"
  made precise: it always existed in the distribution; the slow DB connection raised
  its probability from negligible to observed. `(shown)`
- **F2: no assumption, no race.** The flexible system has zero races because it
  branches on what resolved. The class of load-induced races is not patched but
  prevented — there is no collapsed assumption for load to violate. `(shown)`
- **F3: spent, not moved.** Collapsing forecloses the alternative irreversibly; the
  lost outcome does not show up elsewhere. Flexibility decreases monotonically under
  collapse — a one-way law, structurally unlike the conservation laws of the rest of
  the series. `(shown)`

### 6.2 Honest limitation: a model of order, not a network stack `(shown limitation)`

The toy models the essential structure — a joint latency distribution, a collapsed
assumption versus a resolved-order action — but it is not a network stack. It does
not model retransmission, congestion control, partial failure, or the cost of
hedging (duplicate work, amplified load). The claims F1–F3 are `(shown)` for the
order-distribution model; translating "carry the distribution" into a real
async/runtime discipline (and paying for it honestly — hedging is not free) is
engineering the toy does not perform. We mark the structural claims `(structural)`
and the toy evidence `(shown)`, and name the runtime treatment as further work.
`(shown limitation)`

### 6.3 Practical exam pointer

In a real system the claim to test: identify code paths that assume a completion
order established only on the fast path (A before B because A was always quick), and
either (a) make them branch on the resolved order, or (b) hedge so the slow tail
never gates the caller. Then induce tail latency (slow the dependency deliberately,
a "latency Jepsen") and verify the phantom races do not appear. A race that surfaces
only under induced latency is a premature collapse; the fix is to stop assuming the
order. This is the network-layer companion to Paper 06's "measure conversion, not
duration" — here, "carry the distribution, do not collapse to a point."

---

## 7. Further work (deeper into this wave)

- **A runtime discipline for carrying the distribution.** Specify an async pattern
  (or library) where operations expose their resolved order and code is structurally
  prevented from assuming one — the flexibility-preserving analogue of a type system.
  Include the honest cost model for hedging (when does a second request's duplicate
  work cost less than the tail it avoids?).
- **Flexibility as entropy, quantitatively.** We measured flexibility as a count of
  open outcomes. Define it as the entropy of the live distribution and prove the
  monotone (one-way) law in that setting; relate the rate of flexibility loss to the
  information gained per resolved outcome (a collapse is a measurement; its cost is
  the entropy it removes).
- **When to collapse (the wisdom of timing the spend).** Flexibility is spent one-way,
  so *when* to collapse is the real decision. Characterize the optimal collapse point
  — collapse too early and you risk the phantom race; collapse too late and you pay
  latency/coordination. Is there a conserved trade-off between flexibility spent and
  latency saved?
- **Interaction with the conserved quantities.** The earlier papers' budget/credit/
  rate are conserved; flexibility is not. How do a conserved quantity and a
  non-conserved capacity compose in one system — e.g. does spending flexibility
  (committing to an order) free conserved budget (no longer hedging), trading a
  one-way capacity for a conserved one?
- **Non-conserved invariants generally.** Flexibility may be one of a family of
  non-conserved, monotone invariants (entropy-like) that complement the conserved
  ones. Is there a second law here — a direction of time for systems — distinct from
  the conservation laws, and what else lives in that family?

---

## 8. Conclusion

The series found conserved quantities everywhere it looked, and this paper guards
against the resulting blind spot by naming what is *not* conserved. Flexibility — the
capacity to hold a distribution of outcomes open rather than collapse it to one
assumed point — does not move and is not preserved. You keep it by staying open or
spend it by committing, and once spent it is gone, not transferred. It obeys a
one-way monotone law, the mirror of conservation, and it is the wisdom invariant: the
epistemic discipline of not mistaking a point estimate for the truth.

The network makes the stakes concrete. A link offers a latency distribution; TCP and
the code above it take a point — "the call returns by now" — and wait on it. That
premature collapse makes a slow dependency look dead and, worse, manufactures phantom
race conditions: orderings always latent in the tail of the distribution, invisible
on the fast path, that surface the moment load samples the tail. The races were never
new; the collapse hid them. Carrying the distribution — acting on the order that
actually resolves, never on an assumed one, and keeping the agency to act under
uncertainty rather than waiting — dissolves the entire class, because there is no
collapsed assumption left for load to violate. The fix is flexibility, and flexibility
is the one invariant here you can only keep or spend, never conserve. Wisdom is
knowing the difference: the distribution is the truth, the point is a bet, and every
collapse is a one-way expenditure to be made only when the evidence has finally earned
it.

---

## Bibliography

- Dean, J., Barroso, L. A. (2013). *The Tail at Scale.* Communications of the ACM. —
  `2013:tail-at-scale`
- Deutsch, P. (1994). *The Fallacies of Distributed Computing.* — `1994:fallacies`
- Lamport, L. (1978). *Time, Clocks, and the Ordering of Events in a Distributed
  System.* Communications of the ACM. — `1978:time-clocks`

> Citation keys are permanent `Year:slug` handles; the slug is the load-bearing
> identifier, full bibliographic resolution secondary to seed stability.

---

## Appendix A — Reproducibility

- Artifact: `iso_flex.py`, committed at `074d788` (Team Phi).
- Run: `python3 iso_flex.py` — prints F1 (phantom races from collapse), F2
  (flexibility dissolves them), F3 (flexibility non-conserved), and a verdict ending
  in `ALL HELD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_flex.py` returns only prose in comments.
- Determinism: exhaustive enumeration of the joint latency distribution, no RNG —
  checks reproduce exactly.

## Appendix B — Flexibility in one screen

```
A network latency is a DISTRIBUTION, not a value.

  Collapse  = assume one outcome (e.g. "A completes before B").
  Flexibility = keep the distribution open; act on the order that RESOLVES.

  F1: collapse + a tail sample where the actual order differs = a phantom race.
      (Always latent in the distribution; the slow path just samples it.)
  F2: carry the distribution -> branch on resolved order -> no race, any sample.
  F3: collapse forecloses the alternative IRREVERSIBLY. Flexibility is monotone
      non-increasing -- spent, not moved. NOT conserved (mirror of conservation).

Wisdom: the distribution is the truth; the point is a bet; collapse only on
evidence (a resolved outcome), never on a timer. No clock.
```
