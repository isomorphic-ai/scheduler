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
                 verbose: bool = True):
        self.procs = procs
        self.rounds_to_confirm = rounds_to_confirm
        self.verbose = verbose
        # Each process starts with budget = rounds_to_confirm. Spending refills
        # it; returning unspent decrements it. Hitting 0 = "has provably failed
        # to convert for `rounds_to_confirm` consecutive scheduled turns."
        for p in procs:
            p.budget = rounds_to_confirm
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
            return True  # pure progress, always convertible

        if kind == "acquire":
            lock = step[1]
            if lock.held_by is None:
                lock.held_by = p
                p.holding.append(lock)
                p.pc += 1
                return True            # acquiring a free lock IS progress
            if lock.held_by is p:
                p.pc += 1
                return True            # re-entrant, fine
            return False               # BLOCKED: lock held by someone else

        if kind == "release":
            lock = step[1]
            if lock.held_by is p:
                lock.held_by = None
                p.holding.remove(lock)
            p.pc += 1
            return True

        raise ValueError(f"unknown step {step}")

    # -- who is process p waiting on right now? (for cycle detection) ----------
    def waiting_on(self, p: Process) -> Optional[Process]:
        step = p.next_step()
        if step is None or step[0] != "acquire":
            return None
        lock = step[1]
        if lock.held_by is not None and lock.held_by is not p:
            return lock.held_by
        return None

    # -- the detector: budget floor + closed wait-cycle ------------------------
    def detect_deadlock(self) -> Optional[list[Process]]:
        # candidates: alive, not done, budget exhausted (returned unspent
        # `rounds_to_confirm` times in a row -> provably non-converting)
        starved = [p for p in self.procs
                   if not p.done and p.budget <= 0]
        if not starved:
            return None

        # Now confirm the *permanence*: a closed wait-cycle among starved procs.
        starved_set = set(starved)
        for start in starved:
            # walk the wait chain; a cycle staying inside starved_set = deadlock
            seen = []
            cur = start
            while cur is not None and cur in starved_set and cur not in seen:
                seen.append(cur)
                cur = self.waiting_on(cur)
            if cur is not None and cur in seen:
                # found a cycle; return it from the point of closure
                idx = seen.index(cur)
                return seen[idx:]
        return None

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
                return ("deadlock", self.round, dead)

        return ("max_rounds", self.round, None)


# ---- Scenarios --------------------------------------------------------------

def scenario_deadlock(rounds_to_confirm=3, verbose=True):
    """Classic AB-BA deadlock: A holds L1 wants L2, B holds L2 wants L1."""
    L1, L2 = Lock("L1"), Lock("L2")
    A = Process("A", program=[("acquire", L1), ("work", 1),
                              ("acquire", L2), ("release", L2), ("release", L1)])
    B = Process("B", program=[("acquire", L2), ("work", 1),
                              ("acquire", L1), ("release", L1), ("release", L2)])
    return Scheduler([A, B], rounds_to_confirm, verbose).run()


def scenario_slow_but_alive(rounds_to_confirm=3, verbose=True):
    """
    The false-positive trap: S is SLOW (lots of work) but never blocked.
    A timer might fire on it. The budget detector must NOT — it spends every
    round, so its budget never hits the floor.
    """
    slow_work = [("work", 1)] * (rounds_to_confirm * 5)
    S = Process("S_slow", program=slow_work)
    T = Process("T_fast", program=[("work", 1)])
    return Scheduler([S, T], rounds_to_confirm, verbose).run()


def scenario_resolvable_contention(rounds_to_confirm=3, verbose=True):
    """
    Real contention that is NOT deadlock: both want L1, but in an order that
    resolves. Must complete, never declare deadlock.
    """
    L1 = Lock("L1")
    A = Process("A", program=[("acquire", L1), ("work", 1), ("release", L1)])
    B = Process("B", program=[("acquire", L1), ("work", 1), ("release", L1)])
    return Scheduler([A, B], rounds_to_confirm, verbose).run()


if __name__ == "__main__":
    print("=" * 64)
    print("SCENARIO 1: true AB-BA deadlock (must be PROVEN, no timer)")
    print("=" * 64)
    r1 = scenario_deadlock()
    print("result:", r1[0], "at round", r1[1], "\n")

    print("=" * 64)
    print("SCENARIO 2: slow-but-alive (must NOT be falsely flagged)")
    print("=" * 64)
    r2 = scenario_slow_but_alive()
    print("result:", r2[0], "at round", r2[1], "\n")

    print("=" * 64)
    print("SCENARIO 3: resolvable contention (must COMPLETE)")
    print("=" * 64)
    r3 = scenario_resolvable_contention()
    print("result:", r3[0], "at round", r3[1], "\n")

    print("=" * 64)
    print("VERDICT")
    print("=" * 64)
    print(f"  deadlock scenario   -> {r1[0]:10}  (want: deadlock)")
    print(f"  slow-alive scenario -> {r2[0]:10}  (want: completed)")
    print(f"  contention scenario -> {r3[0]:10}  (want: completed)")
    ok = (r1[0] == "deadlock" and r2[0] == "completed" and r3[0] == "completed")
    print(f"\n  ALL CLAIMS HELD: {ok}")
    print("  (and: grep this file for 'time' — there is no wall clock.)")
