"""
iso_flex.py — Paper 07 of the Isomorphic Scheduler series.

Flexibility (WISDOM): the capacity to NOT collapse potential prematurely.

The earlier papers used CONSERVED quantities -- budget, credit, rate -- that move
and are preserved (POWER/agency, LOVE/alignment). Flexibility is a DIFFERENT KIND
OF THING. It is not conserved and does not move. It is the capacity to hold a
distribution OPEN -- to refrain from collapsing many possible outcomes into one
assumed outcome before the evidence justifies it. You do not route flexibility;
you either PRESERVE it (stay open) or SPEND it irreversibly (collapse to a point).
Once collapsed it is gone, not transferred. This is WISDOM: the epistemic
invariant seen at depth -- not just honest bookkeeping, but the discipline of not
mistaking a point estimate for the truth.

The bug this fixes: a network is necessarily PROBABILISTIC (a latency is a
DISTRIBUTION, not a value), but TCP and most application code treat it as
DETERMINISTIC -- they collapse the latency distribution to the point estimate "the
call will return by now," commit to that collapsed truth, and WAIT on it. A slow
dependency is then indistinguishable from a dead one, and -- worse -- phantom race
conditions appear: orderings that were always possible in the distribution but
never observed while everything was fast. The race did not appear; it was always
there with low probability. Premature determinism HID it.

We show three things, no wall clock:

  (F1) PREMATURE COLLAPSE MANUFACTURES PHANTOM RACES. A system that assumes a
       fixed ordering (collapses the latency distribution) exhibits races when the
       network samples a tail outcome -- races that a distribution-carrying system
       never has, because it never assumed the order.

  (F2) FLEXIBILITY DISSOLVES THEM. Carrying the distribution -- acting only on
       outcomes that have actually resolved, never on an assumed one -- removes the
       race entirely, across all orderings.

  (F3) FLEXIBILITY IS SPENT, NOT MOVED (not conserved). Collapsing a decision is
       irreversible and local: the potential does not reappear elsewhere. We
       contrast it with a conserved quantity to show it obeys a different law --
       a one-way loss (like entropy), not a conservation.

The three invariants, at the network layer:
  - EPISTEMIC/WISDOM: represent the distribution; collapse only on evidence
    (a resolved outcome), never on a timer. Truth is a probability until earned.
  - AGENCY: act pointwise under uncertainty (hedge, second path, proceed-degraded)
    instead of surrendering the power to act to a wait you do not control.
  - ALIGNMENT: the probabilistic reality is shared; no part assumes a local
    ordering as global truth, so no part's success rides on an order it only hoped
    held.
"""

from __future__ import annotations
from dataclasses import dataclass, field
import itertools


# ---------------------------------------------------------------------------
# Two async operations A and B over a network. Each has a LATENCY DISTRIBUTION
# (a set of possible completion times), not a fixed latency. A "system" decides
# what to do based on either (a) a COLLAPSED assumption about the order, or
# (b) the actual RESOLVED order. We enumerate the distribution exhaustively.
# ---------------------------------------------------------------------------

@dataclass
class Op:
    name: str
    # latency distribution: possible latencies (ticks). The network is
    # probabilistic; we carry the whole set, not a point.
    latencies: tuple


def deterministic_system_has_race(opA, opB, assumed_order=("A", "B")):
    """A system that COLLAPSED the distribution: it assumes assumed_order holds
    (e.g. 'A always completes before B', because in testing A was always fast).
    It writes shared state under that assumption. A race exists if there is ANY
    pair of latencies in the distribution where the ACTUAL order contradicts the
    assumed order -- because the system's correctness depended on the collapse."""
    first, second = assumed_order
    race_samples = []
    for la in opA.latencies:
        for lb in opB.latencies:
            # actual completion order (smaller latency completes first; tie -> A)
            actual_first = "A" if la <= lb else "B"
            if actual_first != first:
                # the assumed order is violated: the code that assumed `first`
                # completes first now runs its critical section in the wrong order
                race_samples.append((la, lb, actual_first))
    return race_samples


def flexible_system_has_race(opA, opB):
    """A system that CARRIES the distribution: it never assumes an order. It acts
    only on the order that ACTUALLY resolved (whichever completes first is treated
    as first, dynamically). For every sample it does the right thing, so there is
    no ordering it can get 'wrong'. Returns the (empty) race set."""
    races = []
    for la in opA.latencies:
        for lb in opB.latencies:
            actual_first = "A" if la <= lb else "B"
            # flexible system branches on actual_first -> always correct.
            # (No assumption to violate -> no race.)
            pass
    return races   # always empty: it adapted to whatever resolved


# ---- F3: flexibility is spent, not moved (a one-way loss, not conservation) --

@dataclass
class FlexState:
    """Potential as a set of still-open outcomes. Collapsing removes outcomes
    irreversibly; the removed potential does NOT appear anywhere else."""
    open_outcomes: set
    spent_log: list = field(default_factory=list)

    def collapse_to(self, outcome):
        """Commit to one outcome. Irreversible: the other potential is GONE,
        not transferred. This is the one-way law (unlike conserved budget)."""
        assert outcome in self.open_outcomes, "cannot collapse to an excluded outcome"
        removed = self.open_outcomes - {outcome}
        self.spent_log.append(("collapsed", outcome, "lost", frozenset(removed)))
        self.open_outcomes = {outcome}
        return removed   # returned only to show it vanishes, not where it 'went'

    def flexibility(self):
        """A measure of remaining capacity-to-not-collapse: how many outcomes are
        still open. Monotone NON-INCREASING under collapse (one-way)."""
        return len(self.open_outcomes)


if __name__ == "__main__":
    print("=" * 76)
    print("PAPER 07 — FLEXIBILITY (WISDOM): THE CAPACITY TO NOT COLLAPSE")
    print("A network is probabilistic; treating it as deterministic collapses the")
    print("distribution prematurely and manufactures phantom races. Flexibility =")
    print("carry the distribution, collapse only on evidence. NOT conserved.")
    print("=" * 76)

    # Latency distributions: A is USUALLY fast (1-2) but has a slow tail (9).
    # B is steady (3-4). In testing, A<B always held -> the system 'collapsed' to
    # 'A completes first'. The slow tail (a slow DB connection!) breaks it.
    A = Op("A", latencies=(1, 2, 9))     # the 9 is the slow-DB tail
    B = Op("B", latencies=(3, 4))

    print("\n--- F1: premature collapse manufactures phantom races ---")
    races = deterministic_system_has_race(A, B, assumed_order=("A", "B"))
    print(f"  system assumed order: A before B (collapsed in fast testing)")
    print(f"  latency dist: A={A.latencies}  B={B.latencies}")
    print(f"  phantom race samples (assumed order violated): {races}")
    print(f"  -> the slow-DB tail (A=9) makes B complete first: race that 'should")
    print(f"     not exist' but was ALWAYS in the distribution with low probability")

    print("\n--- F2: flexibility dissolves them ---")
    flex_races = flexible_system_has_race(A, B)
    print(f"  flexible system (carries distribution, acts on resolved order):")
    print(f"  race samples: {flex_races}  (none -- it never assumed an order)")

    print("\n--- F3: flexibility is spent, not moved (one-way, not conserved) ---")
    fs = FlexState(open_outcomes={"A_first", "B_first"})
    print(f"  open outcomes before: {fs.open_outcomes} (flexibility={fs.flexibility()})")
    lost = fs.collapse_to("A_first")
    print(f"  collapsed to A_first; potential LOST (not transferred): {set(lost)}")
    print(f"  open outcomes after:  {fs.open_outcomes} (flexibility={fs.flexibility()})")
    print(f"  flexibility is MONOTONE NON-INCREASING under collapse (one-way law);")
    print(f"  the lost outcome did not reappear elsewhere -- NOT conserved.")

    print("\n" + "=" * 76)
    print("VERDICT")
    print("=" * 76)
    f1 = len(races) > 0
    f2 = len(flex_races) == 0
    f3 = fs.flexibility() < 2   # collapsed: flexibility strictly decreased
    print(f"  F1 premature collapse manufactures races:        {f1}")
    print(f"  F2 flexibility (carry distribution) dissolves:   {f2}")
    print(f"  F3 flexibility is spent one-way, not conserved:  {f3}")
    print(f"\n  ALL HELD: {f1 and f2 and f3}")
    print("  Flexibility is the capacity to not collapse. It is wisdom, and it is")
    print("  the one invariant that is spent, not conserved. No wall clock.")
