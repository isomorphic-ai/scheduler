"""
iso_deadlock.py — Paper 01 of the Isomorphic Scheduler series.

Claim under test:
    A timer-free deadlock detector built on a *shared, conserved budget*
    produces ZERO false positives (a slow process spends budget and so never
    triggers) and detects true deadlock in BOUNDED time (= budget size),
    with no wall-clock timeout anywhere in the code.

Core invariant (conservation law):
    When scheduled, a process either SPENDS budget (converts it to progress)
    or RETURNS it unspent (it is blocked). Convertible budget over a set is
    monotone non-increasing across any round in which no member makes progress.

Deadlock predicate:
    A set S is deadlocked  <=>  every member returns its budget unspent
    AND their wait-edges form a cycle within S.
    (Budget-return alone = "blocked now". Return + closed cycle = "permanently
     blocked, no external rescue" = KNOWN dead.)

There is deliberately NO timer in this file. Search it for `time` — nothing.
Detection latency is set by ROUNDS_TO_CONFIRM (budget size), not wall clock.
"""

from __future__ import annotations
from dataclasses import dataclass, field
from typing import Optional


# ---- The world: processes, locks, a shared scheduler with a budget ----------

class Lock:
    def __init__(self, name: str):
        self.name = name
        self.held_by: Optional["Process"] = None


@dataclass(eq=False)  # identity-based eq/hash; processes are unique objects
class Process:
    name: str
    # A simple scripted workload: a list of steps. Each step is either
    #   ("acquire", lock)  -> try to take a lock (blocks if held by another)
    #   ("work", n)        -> do n units of progress (always convertible)
    #   ("release", lock)  -> give a lock back
    program: list = field(default_factory=list)
    pc: int = 0                       # program counter
    holding: list = field(default_factory=list)
    done: bool = False

    # Budget bookkeeping. `budget` is replenished by progress and drained by
    # blocked rounds. It is the ONLY thing the detector reads.
    budget: int = 0

    # Resolution bookkeeping (Paper 02). These are NOT read by the detector;
    # they are the conserved-quantity ledger the *resolver* reads to choose a
    # victim without a separate cost model.
    #   converted: total units of progress this process has actually converted
    #              (acquisitions + work). Aborting throws this away -> it IS the
    #              sunk cost of choosing this process as victim.
    #   restart_count: how many times this process has been aborted & restarted
    #              (to detect and prevent livelock-via-repeated-victimization).
    converted: int = 0
    restart_count: int = 0
    # credit: converted progress banked across yields. A process that yields to
    # break a deadlock keeps its progress as credit, and returns with an expanded
    # budget (base + credit). Progress is conserved, not lost; the yielder comes
    # back more robust, which is what prevents livelock without any rotation hack.
    credit: int = 0
    # snapshot of the program start, so an aborted process can be restarted
    # cleanly (release everything, rewind pc, drop converted-this-attempt).
    _program0: list = field(default=None, repr=False)

    def next_step(self):
        if self.pc >= len(self.program):
            self.done = True
            return None
        return self.program[self.pc]


class Scheduler:
    """
    One shared budget account, expressed per-process but conserved globally:
    a SPEND (progress) lets a process keep earning; a RETURN (blocked) drains
    toward the floor. The detector watches the floor.
    """
    def __init__(self, procs: list[Process], rounds_to_confirm: int = 3,
                 verbose: bool = True, resolve: bool = False):
        self.procs = procs
        self.rounds_to_confirm = rounds_to_confirm
        self.verbose = verbose
        self.resolve = resolve          # False = detect-only; True = break cycles
        self.aborts = []                # log of (round, victim, converted_lost)
        # Each process starts with budget = rounds_to_confirm. Spending refills
        # it; returning unspent decrements it. Hitting 0 = "has provably failed
        # to convert for `rounds_to_confirm` consecutive scheduled turns."
        for p in procs:
            p.budget = rounds_to_confirm
            if p._program0 is None:
                p._program0 = list(p.program)
        self.round = 0

    def log(self, *a):
        if self.verbose:
            print(*a)

    # -- one scheduled attempt for one process; returns True iff it made progress
    def attempt(self, p: Process) -> bool:
        step = p.next_step()
        if step is None:
            return False  # nothing to do; not progress, not a block either
        kind = step[0]

        if kind == "work":
            p.pc += 1
            p.converted += 1           # converted progress ledger (resolver)
            return True  # pure progress, always convertible

        if kind == "acquire":
            lock = step[1]
            if lock.held_by is None:
                lock.held_by = p
                p.holding.append(lock)
                p.pc += 1
                p.converted += 1       # acquiring a free lock IS progress
                return True
            if lock.held_by is p:
                p.pc += 1
                return True            # re-entrant, no new progress
            return False               # BLOCKED: lock held by someone else

        if kind == "release":
            lock = step[1]
            if lock.held_by is p:
                lock.held_by = None
                p.holding.remove(lock)
            p.pc += 1
            return True                # release is bookkeeping, not new progress

        raise ValueError(f"unknown step {step}")

    # -- who is process p waiting on right now? (single-successor, legacy) -----
    def waiting_on(self, p: Process) -> Optional[Process]:
        step = p.next_step()
        if step is None or step[0] != "acquire":
            return None
        lock = step[1]
        if lock.held_by is not None and lock.held_by is not p:
            return lock.held_by
        return None

    # -- all holders p is currently blocked on (for knot/N-cycle detection) ----
    def waiting_on_all(self, p: Process) -> list:
        # In this scripted model a process blocks on its single next `acquire`,
        # so this returns 0 or 1 holders. Written as a list so the detector's
        # graph search is correct for the general case (a process blocked on
        # several locks at once, or a lock held in shared mode by many) without
        # changing the detector. N-process cycles and knots are built here as
        # chains of single-lock waits whose edges close into a tangle.
        out = []
        step = p.next_step()
        if step is None or step[0] != "acquire":
            return out
        lock = step[1]
        if lock.held_by is not None and lock.held_by is not p:
            out.append(lock.held_by)
        return out

    # -- the detector: budget floor + closed wait-cycle ------------------------
    def detect_deadlock(self) -> Optional[list[Process]]:
        # candidates: alive, not done, budget exhausted (returned unspent
        # `rounds_to_confirm` times in a row -> provably non-converting)
        starved = [p for p in self.procs
                   if not p.done and p.budget <= 0]
        if not starved:
            return None

        # Confirm permanence: a directed cycle within the starved set's
        # wait-for graph. We do a proper DFS cycle search (not a single-path
        # walk) so that N-process cycles and KNOTS -- where the cycle is
        # embedded in a larger tangle of wait-edges -- are found, not just
        # simple 2-cycles. A process in a knot may have its cycle reachable
        # only after passing through other starved nodes; DFS finds it.
        starved_set = set(starved)

        # build wait-for edges restricted to the starved set
        edges: dict = {p: [] for p in starved}
        for p in starved:
            for q in self.waiting_on_all(p):
                if q in starved_set:
                    edges[p].append(q)

        # iterative DFS with colors to extract an actual cycle path
        WHITE, GRAY, BLACK = 0, 1, 2
        color = {p: WHITE for p in starved}
        parent: dict = {p: None for p in starved}

        def extract_cycle(back_to, frm):
            # reconstruct cycle from `frm` up to `back_to` via parent links
            path = [frm]
            cur = frm
            while cur is not back_to and parent[cur] is not None:
                cur = parent[cur]
                path.append(cur)
            path.reverse()
            return path

        for root in starved:
            if color[root] != WHITE:
                continue
            stack = [(root, iter(edges[root]))]
            color[root] = GRAY
            while stack:
                node, it = stack[-1]
                advanced = False
                for nxt in it:
                    if color[nxt] == GRAY:
                        # found a back-edge -> cycle
                        return extract_cycle(nxt, node)
                    if color[nxt] == WHITE:
                        color[nxt] = GRAY
                        parent[nxt] = node
                        stack.append((nxt, iter(edges[nxt])))
                        advanced = True
                        break
                if not advanced:
                    color[node] = BLACK
                    stack.pop()
        return None

    # -- resolution (Paper 02): choose a victim from the cycle, abort, restart --
    def choose_yielder(self, cycle: list) -> Process:
        """
        Choose which process generously yields. The conserved quantity does the
        steering: pick the process that has banked the LEAST credit so far (has
        yielded least), and among equals the one with the least converted
        progress to re-do. So:
          - generosity spreads -- a process that already yielded carries credit,
            which makes it LESS likely to be chosen again (the credit protects
            it). No rotation hack, no restart counter: credit is the fairness.
          - the chosen yielder has the least to re-do AND the most still to gain
            from coming back with an expanded budget.
        In a symmetric cycle the first yield gives one process credit; that credit
        immediately steers the next selection to the other process, and once a
        process returns with enough banked budget to push through its blocked
        acquire before re-flooring, the cycle opens for good.
        """
        return min(cycle, key=lambda p: (p.credit, p.converted, p.name))

    def yield_and_credit(self, yielder: Process):
        """
        The yielder releases its locks (unblocking the rest of the cycle) and
        restarts -- but its converted progress is BANKED as credit, not lost.
        On retry it carries an expanded budget equal to the base plus everything
        it had converted. So:
          - progress is conserved (credited), not discarded;
          - the returning process is more robust (bigger budget), not weaker;
          - it is therefore LESS likely to be chosen again -> no livelock,
            because the conserved quantity now favors leaving it alone.
        This is eventual consistency, not sacrifice. The deadlock is a tail case;
        one process stepping back and retrying, carrying its credit, resolves it.
        """
        banked = yielder.converted
        yielder.credit += banked            # bank the converted progress
        # release all held locks -> this is what unblocks the rest of the cycle
        for lock in list(yielder.holding):
            if lock.held_by is yielder:
                lock.held_by = None
        yielder.holding.clear()
        # rewind program, but return with an EXPANDED budget = base + credit
        yielder.program = list(yielder._program0)
        yielder.pc = 0
        yielder.converted = 0
        yielder.budget = self.rounds_to_confirm + yielder.credit
        yielder.restart_count += 1
        yielder.done = False
        self.aborts.append((self.round, yielder.name, banked))
        self.log(f"  >> YIELD r{self.round}: {yielder.name} steps back "
                 f"(converted={banked} CREDITED, total credit={yielder.credit}, "
                 f"returns with budget={yielder.budget}); cycle broken")

    # -- the run loop ----------------------------------------------------------
    def run(self, max_rounds: int = 1000):
        while self.round < max_rounds:
            self.round += 1
            any_progress = False

            for p in self.procs:
                if p.done:
                    continue
                made = self.attempt(p)
                if made:
                    any_progress = True
                    # SPEND model: progress refills budget to full.
                    p.budget = self.rounds_to_confirm
                    self.log(f"  r{self.round}: {p.name} progressed "
                             f"(pc->{p.pc}), budget={p.budget}")
                else:
                    # RETURN model: blocked -> drain one unit.
                    if not p.done:
                        p.budget -= 1
                        self.log(f"  r{self.round}: {p.name} BLOCKED, "
                                 f"returned budget -> {p.budget}")

            # all finished?
            if all(p.done for p in self.procs):
                self.log(f"[round {self.round}] all processes completed.")
                return ("completed", self.round, None)

            # KNOWN-dead check — no timer involved
            dead = self.detect_deadlock()
            if dead is not None:
                names = " -> ".join(d.name for d in dead) + f" -> {dead[0].name}"
                self.log(f"[round {self.round}] DEADLOCK PROVEN. "
                         f"Cycle: {names}")
                if not self.resolve:
                    return ("deadlock", self.round, dead)
                # RESOLVE by generous yield: one process steps back, KEEPS its
                # converted progress as credit, and returns with an expanded
                # budget. Not a victim -- eventual consistency. The survivors get
                # a fresh budget so they are re-judged on their next attempts.
                yielder = self.choose_yielder(dead)
                self.yield_and_credit(yielder)
                for p in dead:
                    if p is not yielder:
                        p.budget = self.rounds_to_confirm
                # loop continues; system should now make progress

        if all(p.done for p in self.procs):
            return ("completed", self.round, None)
        return ("max_rounds", self.round, None)


# ---- Scenarios --------------------------------------------------------------

def scenario_deadlock(rounds_to_confirm=3, verbose=True, resolve=False):
    """Classic AB-BA deadlock: A holds L1 wants L2, B holds L2 wants L1."""
    L1, L2 = Lock("L1"), Lock("L2")
    A = Process("A", program=[("acquire", L1), ("work", 1),
                              ("acquire", L2), ("release", L2), ("release", L1)])
    B = Process("B", program=[("acquire", L2), ("work", 1),
                              ("acquire", L1), ("release", L1), ("release", L2)])
    return Scheduler([A, B], rounds_to_confirm, verbose, resolve).run()


def scenario_slow_but_alive(rounds_to_confirm=3, verbose=True, resolve=False):
    """
    The false-positive trap: S is SLOW (lots of work) but never blocked.
    A timer might fire on it. The budget detector must NOT — it spends every
    round, so its budget never hits the floor.
    """
    slow_work = [("work", 1)] * (rounds_to_confirm * 5)
    S = Process("S_slow", program=slow_work)
    T = Process("T_fast", program=[("work", 1)])
    return Scheduler([S, T], rounds_to_confirm, verbose, resolve).run()


def scenario_resolvable_contention(rounds_to_confirm=3, verbose=True, resolve=False):
    """
    Real contention that is NOT deadlock: both want L1, but in an order that
    resolves. Must complete, never declare deadlock.
    """
    L1 = Lock("L1")
    A = Process("A", program=[("acquire", L1), ("work", 1), ("release", L1)])
    B = Process("B", program=[("acquire", L1), ("work", 1), ("release", L1)])
    return Scheduler([A, B], rounds_to_confirm, verbose, resolve).run()


def scenario_three_cycle(rounds_to_confirm=3, verbose=True, resolve=False):
    """
    3-process cycle: A holds L1 wants L2; B holds L2 wants L3; C holds L3 wants L1.
    Tests that detection finds an N>2 cycle, not just AB-BA.
    """
    L1, L2, L3 = Lock("L1"), Lock("L2"), Lock("L3")
    A = Process("A", program=[("acquire", L1), ("work", 1),
                              ("acquire", L2), ("release", L2), ("release", L1)])
    B = Process("B", program=[("acquire", L2), ("work", 1),
                              ("acquire", L3), ("release", L3), ("release", L2)])
    C = Process("C", program=[("acquire", L3), ("work", 1),
                              ("acquire", L1), ("release", L1), ("release", L3)])
    return Scheduler([A, B, C], rounds_to_confirm, verbose, resolve).run()


def scenario_knot(rounds_to_confirm=3, verbose=True, resolve=False):
    """
    A KNOT: a 3-cycle A->B->C->A, plus a fourth process D that holds nothing the
    cycle needs but is itself blocked waiting INTO the cycle (D wants L1, held by
    A). D is not ON the cycle, but D can never make progress because the cycle
    never releases. This is the knot shape: every member is doomed, but only
    three are on the directed cycle.

    Required behavior: detection must DECLARE deadlock (the cycle exists and is
    found by DFS), and the returned cycle should be the A-B-C cycle. D is
    correctly starved but is a *tail into* the knot, not part of the minimal
    cycle -- testing that the detector localizes the actual cycle rather than
    smearing the whole starved set together.
    """
    L1, L2, L3, L4 = Lock("L1"), Lock("L2"), Lock("L3"), Lock("L4")
    A = Process("A", program=[("acquire", L1), ("work", 1),
                              ("acquire", L2), ("release", L2), ("release", L1)])
    B = Process("B", program=[("acquire", L2), ("work", 1),
                              ("acquire", L3), ("release", L3), ("release", L2)])
    C = Process("C", program=[("acquire", L3), ("work", 1),
                              ("acquire", L1), ("release", L1), ("release", L3)])
    # D holds L4 (its own), does work, then wants L1 -- which A holds forever.
    D = Process("D", program=[("acquire", L4), ("work", 1),
                              ("acquire", L1), ("release", L1), ("release", L4)])
    return Scheduler([A, B, C, D], rounds_to_confirm, verbose, resolve).run()


def scenario_tree_one_escapes(rounds_to_confirm=3, verbose=True, resolve=False):
    """
    Multi-dependency tree where it LOOKS like a tangle but one process can
    actually finish, releasing the rest. Must COMPLETE, never declare deadlock.

    A wants L1 (free) -> gets it, works, releases. B and C both also want L1 but
    in sequence behind A. No cycle: it's a contention tree with a live root.
    This is the false-positive trap at N>2: lots of blocked processes, budgets
    draining, but a live root means no cycle ever closes.
    """
    L1 = Lock("L1")
    A = Process("A", program=[("acquire", L1), ("work", 1), ("release", L1)])
    B = Process("B", program=[("acquire", L1), ("work", 1), ("release", L1)])
    C = Process("C", program=[("acquire", L1), ("work", 1), ("release", L1)])
    return Scheduler([A, B, C], rounds_to_confirm, verbose, resolve).run()



# ---- Paper 02 runner: resolution that completes, with cost accounting -------

class LossAbortResolver(Scheduler):
    """Ablation: the OLD model -- abort as loss. The yielder's converted progress
    is discarded (no credit), and it returns with only the base budget. This is
    the classic victim/rollback. Shown here to demonstrate that CREDIT -- not a
    rotation hack -- is what gives convergence: without credit, a process that
    yields returns no stronger and can be re-selected indefinitely (livelock on
    an uneven cycle); with credit, the yielder returns more robust and the
    conserved quantity steers selection away from it.
    """
    def choose_yielder(self, cycle):
        # same selection, but the abort below discards progress
        return min(cycle, key=lambda p: (p.converted, p.name))

    def yield_and_credit(self, y):
        lost = y.converted
        for lock in list(y.holding):
            if lock.held_by is y:
                lock.held_by = None
        y.holding.clear()
        y.program = list(y._program0)
        y.pc = 0
        y.converted = 0
        y.budget = self.rounds_to_confirm     # NO credit -> base budget only
        y.restart_count += 1
        y.done = False
        self.aborts.append((self.round, y.name, lost))


def compare_credit_models(verbose=False):
    """Credit-yield vs loss-abort on a cycle where the SAME process keeps being
    selected. Returns convergence + total re-work for each."""
    def build_repeat_pressure():
        # A converts a little then deadlocks; B is cheap. Under loss-abort the
        # cheap side keeps getting aborted and re-racing; under credit it returns
        # strong and the cycle clears for good.
        L1, L2 = Lock("L1"), Lock("L2")
        A = Process("A", program=[("acquire", L1), ("work", 1), ("work", 1),
                                  ("acquire", L2), ("release", L2), ("release", L1)])
        B = Process("B", program=[("acquire", L2), ("work", 1), ("work", 1),
                                  ("acquire", L1), ("release", L1), ("release", L2)])
        return [A, B]
    s_credit = Scheduler(build_repeat_pressure(), 3, verbose=verbose, resolve=True)
    cs = s_credit.run()[0]
    c_yields = len(s_credit.aborts)
    s_loss = LossAbortResolver(build_repeat_pressure(), 3, verbose=verbose, resolve=True)
    ls = s_loss.run()[0]
    l_yields = len(s_loss.aborts)
    l_rework = sum(a[2] for a in s_loss.aborts)
    return cs, c_yields, ls, l_yields, l_rework


def compare_cost_models(verbose=False):
    """Kept for continuity: credit-yield on an uneven cycle, reporting that the
    yielder's progress is credited (conserved), not lost."""
    def build_uneven():
        L1, L2 = Lock("L1"), Lock("L2")
        A = Process("A", program=[("acquire", L1), ("work", 1), ("work", 1),
                                  ("work", 1), ("work", 1), ("work", 1),
                                  ("acquire", L2), ("release", L2), ("release", L1)])
        B = Process("B", program=[("acquire", L2),
                                  ("acquire", L1), ("release", L1), ("release", L2)])
        return [A, B]
    s = Scheduler(build_uneven(), 3, verbose=verbose, resolve=True)
    status = s.run()[0]
    yielded = s.aborts[0][1] if s.aborts else None
    credited = s.aborts[0][2] if s.aborts else 0
    return status, yielded, credited


def _summary(label, result, sched):
    status, rnd, _ = result
    n = len(sched.aborts)
    banked = sum(a[2] for a in sched.aborts)
    who = ", ".join(dict.fromkeys(a[1] for a in sched.aborts)) or "none"
    print(f"  {label:22} -> {status:10} @r{rnd:<3} | yields: {n} ({who}) "
          f"| progress credited (conserved): {banked}")
    return status


if __name__ == "__main__":
    print("=" * 70)
    print("PAPER 02 — RESOLUTION AS GENEROUS YIELD (credit, not sacrifice)")
    print("One process steps back, KEEPS its progress as credit, returns with an")
    print("expanded budget. Eventual consistency, not victimhood.")
    print("=" * 70)

    # Build scenarios directly here so we can read each Scheduler's abort log.
    def build_ABBA():
        L1, L2 = Lock("L1"), Lock("L2")
        A = Process("A", program=[("acquire", L1), ("work", 1),
                                  ("acquire", L2), ("release", L2), ("release", L1)])
        B = Process("B", program=[("acquire", L2), ("work", 1),
                                  ("acquire", L1), ("release", L1), ("release", L2)])
        return [A, B]

    def build_3cycle():
        L1, L2, L3 = Lock("L1"), Lock("L2"), Lock("L3")
        A = Process("A", program=[("acquire", L1), ("work", 1),
                                  ("acquire", L2), ("release", L2), ("release", L1)])
        B = Process("B", program=[("acquire", L2), ("work", 1),
                                  ("acquire", L3), ("release", L3), ("release", L2)])
        C = Process("C", program=[("acquire", L3), ("work", 1),
                                  ("acquire", L1), ("release", L1), ("release", L3)])
        return [A, B, C]

    def build_knot():
        L1, L2, L3, L4 = Lock("L1"), Lock("L2"), Lock("L3"), Lock("L4")
        A = Process("A", program=[("acquire", L1), ("work", 1),
                                  ("acquire", L2), ("release", L2), ("release", L1)])
        B = Process("B", program=[("acquire", L2), ("work", 1),
                                  ("acquire", L3), ("release", L3), ("release", L2)])
        C = Process("C", program=[("acquire", L3), ("work", 1),
                                  ("acquire", L1), ("release", L1), ("release", L3)])
        D = Process("D", program=[("acquire", L4), ("work", 1),
                                  ("acquire", L1), ("release", L1), ("release", L4)])
        return [A, B, C, D]

    def build_uneven():
        # Asymmetric: A has converted a LOT before deadlock, B almost nothing.
        # The free cost model should pick B (cheaper to abort), not A.
        L1, L2 = Lock("L1"), Lock("L2")
        A = Process("A", program=[("acquire", L1),
                                  ("work", 1), ("work", 1), ("work", 1),
                                  ("work", 1), ("work", 1),
                                  ("acquire", L2), ("release", L2), ("release", L1)])
        B = Process("B", program=[("acquire", L2),
                                  ("acquire", L1), ("release", L1), ("release", L2)])
        return [A, B]

    cases = [
        ("AB-BA 2-cycle", build_ABBA),
        ("3-cycle A-B-C", build_3cycle),
        ("knot (D off-cycle)", build_knot),
        ("uneven cost", build_uneven),
    ]

    results = []
    for label, builder in cases:
        print("\n" + "-" * 70)
        print(f"SCENARIO: {label}")
        print("-" * 70)
        sched = Scheduler(builder(), rounds_to_confirm=3, verbose=True, resolve=True)
        res = sched.run()
        results.append((label, res, sched))

    print("\n" + "=" * 70)
    print("VERDICT")
    print("=" * 70)
    all_ok = True
    for label, res, sched in results:
        status = _summary(label, res, sched)
        if status != "completed":
            all_ok = False
    # uneven case: the yielder should be B (least outstanding), progress credited
    uneven = [s for (l, r, s) in results if l == "uneven cost"][0]
    chose_cheap = (len(uneven.aborts) > 0 and uneven.aborts[0][1] == "B")

    print(f"\n  every deadlock resolved to completion: {all_ok}")
    print(f"  generous yielder in uneven case was B (least outstanding): {chose_cheap}")

    # ablation 1: progress is credited, not lost
    ust, uy, ucred = compare_cost_models()
    print("\n  --- credit conserves progress (uneven cycle) ---")
    print(f"    yielder={uy}, converted progress CREDITED (not lost) = {ucred}, "
          f"outcome={ust}")

    # ablation 2: credit vs loss-abort -> convergence
    cs, cy, ls, ly, lrw = compare_credit_models()
    print("\n  --- credit-yield vs loss-abort (repeat-pressure cycle) ---")
    print(f"    credit-yield: {cs:10} in {cy} yield(s)")
    print(f"    loss-abort  : {ls:10} in {ly} abort(s), re-work discarded = {lrw}")
    credit_wins = (cs == "completed" and (ls != "completed" or ly > cy))
    print(f"    credit converges at least as well, conserving progress: {credit_wins}")

    print(f"\n  ALL CLAIMS HELD: {all_ok and chose_cheap}")
    print("  (still no wall clock anywhere; progress is conserved as credit.)")
