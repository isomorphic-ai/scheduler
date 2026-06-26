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
    def choose_victim(self, cycle: list) -> Process:
        """
        Pick which process on the proven cycle to abort. The budget frame gives
        the cost model for free: aborting a process throws away the progress it
        has converted, so the cheapest victim is the one with the LEAST
        `converted`. No separate cost heuristic, no priority table -- the
        conserved-quantity ledger already ranks the candidates.

        Tie-break by restart_count (prefer a victim that has NOT been aborted
        before) to avoid repeatedly victimizing the same process -- this is the
        seed of starvation-freedom, addressed properly in evaluation.
        """
        # least converted first (cheapest to abort); among equals, prefer the
        # process that has been aborted FEWEST times so far. In a symmetric
        # cycle (all converted equal) this rotates the victim across rounds
        # instead of re-picking the same one forever -- which would be the
        # classic cyclic-restart livelock. restart_count ascending = rotation.
        return min(cycle, key=lambda p: (p.converted, p.restart_count, p.name))

    def abort_and_restart(self, victim: Process):
        """
        Roll the victim back: release every lock it holds (freeing the resource
        the rest of the cycle was waiting on -> the cycle is broken), rewind it
        to the start of its program, and reset its per-attempt budget. We keep a
        restart_count so repeated victimization is visible and preventable.
        """
        lost = victim.converted
        # release all held locks -> this is what unblocks the rest of the cycle
        for lock in list(victim.holding):
            if lock.held_by is victim:
                lock.held_by = None
        victim.holding.clear()
        # rewind program
        victim.program = list(victim._program0)
        victim.pc = 0
        victim.converted = 0
        victim.budget = self.rounds_to_confirm
        victim.restart_count += 1
        victim.done = False
        self.aborts.append((self.round, victim.name, lost))
        self.log(f"  >> RESOLVE r{self.round}: abort {victim.name} "
                 f"(converted={lost} lost, restart#{victim.restart_count}); "
                 f"locks released, cycle broken")

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
                # RESOLVE: break the cycle by aborting the cheapest victim,
                # then give the survivors a fresh budget so they are re-judged
                # on their next attempts rather than instantly re-floored.
                victim = self.choose_victim(dead)
                self.abort_and_restart(victim)
                for p in dead:
                    if p is not victim:
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

def _summary(label, result, sched):
    status, rnd, _ = result
    total_lost = sum(a[2] for a in sched.aborts)
    victims = ", ".join(f"{a[1]}(@r{a[0]}, -{a[2]})" for a in sched.aborts) or "none"
    print(f"  {label:22} -> {status:10} @r{rnd:<3} | aborts: {victims} "
          f"| converted lost: {total_lost}")
    return status


if __name__ == "__main__":
    print("=" * 70)
    print("PAPER 02 — RESOLUTION: break the proven cycle, complete the system")
    print("Victim = least converted progress on the cycle (cost model is free).")
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
    # uneven case: verify victim was B (cheap), not A (expensive)
    uneven = [s for (l, r, s) in results if l == "uneven cost"][0]
    chose_cheap = (len(uneven.aborts) > 0 and uneven.aborts[0][1] == "B")
    print(f"\n  every deadlock resolved to completion: {all_ok}")
    print(f"  free cost model aborted the cheap victim (B) in uneven case: {chose_cheap}")
    print(f"  ALL CLAIMS HELD: {all_ok and chose_cheap}")
    print("  (still no wall clock anywhere.)")
