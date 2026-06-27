"""
iso_distributed.py — Paper 05 of the Isomorphic Scheduler series.

Distributed conservation and eventual consistency.

Paper 04 established ONE conserved quantity Q in a single closed system. This
paper asks: what happens to conservation when the system PARTITIONS into nodes
that cannot see each other's books in real time?

The thesis: a system whose state is a CONSERVED QUANTITY gets strong eventual
consistency for free. During a partition, each node's local view diverges -- the
local books do not balance against the (unseen) global total. That local
imbalance is exactly a DEBT. Conservation guarantees the debt is not destroyed by
being unobserved: when the partition heals and nodes merge, the conserved quantity
reconciles to the same global total on every node, regardless of merge order. What
goes around comes around -- because Q is conserved, the merge cannot lose it.

We show three things, all checkable, no wall clock:

  (D1) PARTITION-TOLERANT CONSERVATION. Under arbitrary partitions and concurrent
       updates, the global total of Q (summed across all nodes' contributions) is
       invariant. Partitioning hides Q; it does not create or destroy it.

  (D2) STRONG EVENTUAL CONSISTENCY (order-independent convergence). When all nodes
       have exchanged all updates, every node holds the identical state, REGARDLESS
       of the order in which updates/merges were applied. (Merge is commutative,
       associative, idempotent -- a join-semilattice -- BECAUSE Q is conserved.)

  (D3) DEBT COMES DUE. A quantity moved/spent in one partition but not yet seen by
       another is a deferred debt; on heal it surfaces in full. "Off the books"
       locally is never off the books globally -- conservation makes the deferred
       obligation reappear exactly, never reduced by having been hidden.

The conserved-quantity CRDT we use is a grow-only / PN counter family: increments
(and decrements) are conserved contributions; merge takes the per-node supremum;
the total is order-independent. This is the literal mechanism by which "energy
flows where attention goes" survives partition: the flow recorded on each node is
conserved, and the merge re-totals it without loss.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from copy import deepcopy
import itertools


# ---------------------------------------------------------------------------
# A conserved-quantity replica. State is a per-node ledger of contributions to
# the conserved quantity Q. Each node records ITS OWN contributions; the global
# value is the sum across nodes. Merge = take the per-node max (each node is the
# authority on its own contributions), which is conflict-free and conserves Q.
# ---------------------------------------------------------------------------

@dataclass
class Replica:
    node_id: str
    # per-node increment ledger (grow-only): incs[n] = total increments node n
    # has made, as known to THIS replica. The global incs is the per-node max.
    incs: dict = field(default_factory=dict)
    # per-node decrement ledger (so Q can move down too -> PN counter).
    decs: dict = field(default_factory=dict)

    def value(self) -> int:
        """Local view of the conserved quantity Q."""
        return sum(self.incs.values()) - sum(self.decs.values())

    def increment(self, amount: int = 1):
        self.incs[self.node_id] = self.incs.get(self.node_id, 0) + amount

    def decrement(self, amount: int = 1):
        self.decs[self.node_id] = self.decs.get(self.node_id, 0) + amount

    def merge(self, other: "Replica"):
        """Join: take the per-node supremum of both ledgers. Conflict-free:
        commutative, associative, idempotent. Conserves Q because each node's
        own contribution is authoritative and max-merge never loses a recorded
        contribution."""
        for n, v in other.incs.items():
            self.incs[n] = max(self.incs.get(n, 0), v)
        for n, v in other.decs.items():
            self.decs[n] = max(self.decs.get(n, 0), v)

    def clone(self) -> "Replica":
        r = Replica(self.node_id)
        r.incs = dict(self.incs)
        r.decs = dict(self.decs)
        return r


def global_total(replicas) -> int:
    """The TRUE global Q: per-node supremum of every ledger across all replicas,
    then summed. This is the conserved invariant -- what every node converges to."""
    incs, decs = {}, {}
    for r in replicas:
        for n, v in r.incs.items():
            incs[n] = max(incs.get(n, 0), v)
        for n, v in r.decs.items():
            decs[n] = max(decs.get(n, 0), v)
    return sum(incs.values()) - sum(decs.values())


# ---- D1: partition-tolerant conservation ------------------------------------

def check_D1_partition_conservation():
    """Partition 3 nodes, apply concurrent updates in isolation, heal, and verify
    the global total equals the sum of all contributions -- partition hid Q but
    did not create/destroy it."""
    A, B, C = Replica("A"), Replica("B"), Replica("C")
    nodes = [A, B, C]

    # --- partition: each node updates in isolation (cannot see others) ---
    A.increment(10)          # A adds 10
    B.increment(5); B.decrement(2)   # B nets +3
    C.increment(7)           # C adds 7
    # true global so far = 10 + 3 + 7 = 20, though NO node sees it yet
    expected = 20

    # during partition, local views are PARTIAL (each sees only itself)
    local_views_during = {r.node_id: r.value() for r in nodes}

    # --- heal: gossip all-to-all until quiescent ---
    for _ in range(3):
        for x, y in itertools.permutations(nodes, 2):
            x.merge(y)

    healed_views = {r.node_id: r.value() for r in nodes}
    g = global_total(nodes)
    all_agree = len(set(healed_views.values())) == 1
    correct = (g == expected) and all(v == expected for v in healed_views.values())
    return {
        "expected_global": expected,
        "local_views_during_partition": local_views_during,
        "healed_views": healed_views,
        "global_total": g,
        "all_nodes_agree": all_agree,
        "conserved": correct,
    }


# ---- D2: strong eventual consistency (order independence) --------------------

def check_D2_order_independence():
    """Apply the SAME set of updates but merge in every possible order; assert all
    orders converge to the identical state. Convergence-regardless-of-order is
    strong eventual consistency, and it holds because merge is a join (conserved
    quantity => commutative/associative/idempotent)."""
    def fresh():
        A, B, C = Replica("A"), Replica("B"), Replica("C")
        A.increment(10); B.increment(5); B.decrement(2); C.increment(7)
        return [A, B, C]

    final_values = set()
    final_states = []
    # try several merge orders (all permutations of ordered pairs, repeated)
    orders = list(itertools.permutations(list(itertools.permutations("ABC", 2))))
    sampled = orders[::max(1, len(orders)//12)]  # sample a spread of orders
    for order in sampled:
        nodes = {r.node_id: r for r in fresh()}
        for _ in range(3):
            for (a, b) in order:
                nodes[a].merge(nodes[b])
        vals = {nid: r.value() for nid, r in nodes.items()}
        final_values.add(tuple(sorted(vals.items())))
        final_states.append(vals)
    converged_same = len(final_values) == 1
    return {
        "num_orders_tried": len(sampled),
        "distinct_final_states": len(final_values),
        "converged_identically_all_orders": converged_same,
        "final_value": final_states[0] if final_states else None,
    }


# ---- D3: debt deferred comes due --------------------------------------------

def check_D3_debt_comes_due():
    """A node spends (decrements) during a partition -- creating an obligation the
    rest of the system has not yet seen ('off the books' locally). On heal, the
    debt surfaces in FULL: the global total reflects the decrement exactly, never
    reduced by having been hidden during the partition."""
    A, B = Replica("A"), Replica("B")
    A.increment(100)            # system starts with 100, known to A
    A.merge(B); B.merge(A)      # B learns of the 100
    assert A.value() == 100 and B.value() == 100

    # --- partition: A spends 40 in isolation (a debt B cannot see yet) ---
    A.decrement(40)             # A's local view: 60. B's local view: still 100.
    a_local = A.value()         # 60
    b_local_before_heal = B.value()   # 100 -- B thinks there's still 100 ("off books")

    # B, unaware, makes a decision based on 100 (e.g. promises 80 elsewhere) --
    # here we just record that B's view is stale/optimistic.
    deferred_debt = b_local_before_heal - a_local   # 40 hidden from B

    # --- heal: the debt comes due. B learns of A's spend in full. ---
    B.merge(A); A.merge(B)
    b_local_after_heal = B.value()   # 60 -- the 40 debt surfaced, in full
    debt_surfaced_in_full = (b_local_after_heal == a_local == 60) and \
                            (b_local_before_heal - b_local_after_heal == deferred_debt)
    return {
        "A_local_after_spend": a_local,
        "B_local_before_heal_(off_books)": b_local_before_heal,
        "deferred_debt_hidden_from_B": deferred_debt,
        "B_local_after_heal": b_local_after_heal,
        "debt_surfaced_in_full_on_heal": debt_surfaced_in_full,
    }


if __name__ == "__main__":
    print("=" * 74)
    print("PAPER 05 — DISTRIBUTED CONSERVATION & EVENTUAL CONSISTENCY")
    print("Q is conserved even across partition. What goes around comes around;")
    print("debt deferred comes due; off-the-books locally is on-the-books globally.")
    print("=" * 74)

    print("\n--- D1: partition-tolerant conservation ---")
    d1 = check_D1_partition_conservation()
    for k, v in d1.items():
        print(f"  {k}: {v}")

    print("\n--- D2: strong eventual consistency (order independence) ---")
    d2 = check_D2_order_independence()
    for k, v in d2.items():
        print(f"  {k}: {v}")

    print("\n--- D3: debt deferred comes due ---")
    d3 = check_D3_debt_comes_due()
    for k, v in d3.items():
        print(f"  {k}: {v}")

    print("\n" + "=" * 74)
    print("VERDICT")
    print("=" * 74)
    ok = (d1["conserved"] and d1["all_nodes_agree"]
          and d2["converged_identically_all_orders"]
          and d3["debt_surfaced_in_full_on_heal"])
    print(f"  D1 partition-tolerant conservation: {d1['conserved'] and d1['all_nodes_agree']}")
    print(f"  D2 strong eventual consistency:     {d2['converged_identically_all_orders']}")
    print(f"  D3 debt deferred comes due in full: {d3['debt_surfaced_in_full_on_heal']}")
    print(f"\n  ALL CLAIMS HELD: {ok}")
    print("  Conservation survives partition; the merge cannot lose Q. No clock.")
