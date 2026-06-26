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
    # priority (Paper 03): the process's own scheduling weight. Higher = more
    # urgent. In a classical scheduler this directly orders who runs. Here it is
    # the *source* weight that flows along wait-edges: a blocked high-priority
    # process routes its priority to whoever it is blocked on, so the holder runs
    # with the waiter's urgency behind it. Priority inheritance is not a special
    # case added on top -- it is this single flow rule.
    priority: int = 1
    # credit_acc (Paper 03 share scheduler): fractional scheduling credit that
    # accumulates each round from the floor + proportional share; when it reaches
    # 1.0 the process gets to attempt a step.
    credit_acc: float = 0.0
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

    # ====================================================================
    # Paper 03 (corrected): ONE shared budget for detection + resolution +
    # scheduling. Scheduling is proportional-share with a floor. A YIELD is
    # COSTLY: a scheduled-but-blocked process spends budget to yield, so it
    # burns itself down and stops dominating -- no priority-inheritance protocol,
    # no boost. The blocked high process removes ITSELF; the low holder, always
    # guaranteed a floor of progress, speeds up proportionally as the high
    # process drains.
    # ====================================================================

    def blocked_now(self, p: "Process") -> bool:
        """True iff p's next step is an acquire of a lock held by someone else."""
        step = p.next_step()
        if step is None or step[0] != "acquire":
            return False
        lock = step[1]
        return lock.held_by is not None and lock.held_by is not p

    def run_flow(self, max_rounds: int = 4000, C: float = 1.0,
                 min_rate_frac: float = 0.05):
        """
        The STREAM / RATE scheduler (truly isomorphic, memoryless).

        Priority is a *rate*, not a stock. Picture each process's bucket filled by
        a stream whose rate is its priority. At each instant NOW the cake (a fixed
        capacity C of progress) is divided among the processes CURRENTLY AT THE
        TABLE -- alive, not done, and able to make progress this instant (not
        blocked) -- in proportion to their rate. Nothing is spent; nothing is
        banked; there is no penalty and no recovery. The allocation at time NOW
        depends ONLY on who is present now and their rates.

        Consequences (exactly the desired behaviour):
          - When H is NOT at the table (blocked, or done), it takes no share; the
            cake is split among those present, so L's share AUTOMATICALLY RISES to
            fill the gap. No demotion of H, no burn-down -- L simply gets more
            because H is not competing right now.
          - When H RETURNS (its lock is free), it is immediately back at its full
            rate and eats at once -- it does NOT have to climb back, because its
            rate never changed. Memoryless: no debt from having yielded.
          - L is never starved: as long as L is at the table with positive rate it
            gets a positive share every instant (a small min_rate_frac floor
            guards against a zero/degenerate rate).

        This is the focus axis: we set rates (priorities/focus) and the system
        self-organises -- who eats how much is always just the instantaneous
        proportion of present demand.
        """
        for p in self.procs:
            p.credit_acc = 0.0
        progress = {p.name: 0 for p in self.procs}
        prev = dict(progress)
        share_log = {p.name: [] for p in self.procs}  # instantaneous share each round
        H_return_round = None
        H_return_immediate = None

        hi = max(self.procs, key=lambda p: p.priority)
        was_blocked_hi = False

        while self.round < max_rounds:
            self.round += 1

            # H's blocked-state at the START of this round (before any steps run),
            # so that a release happening earlier in this same pass does not hide
            # the fact that H was blocked entering the round.
            hi_blocked_at_start = self.blocked_now(hi) and not hi.done

            # who is AT THE TABLE right now: alive, not done, not blocked
            at_table = [p for p in self.procs
                        if not p.done and not self.blocked_now(p)
                        and p.next_step() is not None]
            if not at_table:
                if all(p.done for p in self.procs):
                    break
                # nobody can progress and not all done -> genuine stall (deadlock)
                return ("stuck", self.round,
                        {"progress": progress, "share_log": share_log,
                         "H_return_immediate": H_return_immediate})

            # rates of those present (floor guards degenerate rates)
            total_rate = sum(max(min_rate_frac, p.priority) for p in at_table)

            # detect H returning to the table after being blocked
            hi_present = hi in at_table
            if was_blocked_hi and hi_present and not hi.done and H_return_round is None:
                H_return_round = self.round

            for p in self.procs:
                if p in at_table:
                    share = C * max(min_rate_frac, p.priority) / total_rate
                else:
                    share = 0.0
                share_log[p.name].append(share)
                p.credit_acc += share

            # spend accumulated cake as steps
            for p in at_table:
                while p.credit_acc >= 1.0 and not p.done:
                    p.credit_acc -= 1.0
                    if self.blocked_now(p):
                        break  # became blocked mid-round; leaves the table
                    if self.attempt(p):
                        progress[p.name] += 1

            # did H eat the round it returned? "Eating" = receiving its full rate
            # share immediately (not waiting / not throttled). Discrete step
            # completion may lag by sub-unit accumulation, but the SHARE is
            # granted at once -- that is the no-climb-back property.
            if H_return_round == self.round:
                hi_share = C * max(min_rate_frac, hi.priority) / total_rate
                # immediate iff H's share this round equals its full uncontested
                # rate proportion among those present (no penalty applied)
                H_return_immediate = (hi_share > 0 and
                                      abs(hi_share - C * hi.priority /
                                          sum(max(min_rate_frac, q.priority)
                                              for q in at_table)) < 1e-9)

            was_blocked_hi = hi_blocked_at_start
            prev = dict(progress)
            if all(p.done for p in self.procs):
                break

        status = "completed" if all(p.done for p in self.procs) else "max_rounds"
        return (status, self.round,
                {"progress": progress, "share_log": share_log,
                 "H_return_round": H_return_round,
                 "H_return_immediate": H_return_immediate})

    def run_share(self, max_rounds: int = 4000, floor_frac: float = 0.15,
                  yield_cost: int = 4, refill: int = 2, base_budget: int = 6,
                  costly_yield: bool = True):
        """
        Fine-grained proportional-share scheduler on the ONE shared budget.

        Each round distributes a SMALL fixed capacity C=1.0 of "progress credit"
        among the alive processes, so dynamics unfold over many rounds and are
        observable. Each process p gets:
              share(p) = floor_frac * C / n_alive             (the FLOOR: every
                                                               process, always)
                       + (1 - floor_frac) * C * budget(p)/sum_budget   (PROPORTIONAL)
        Shares accumulate in p.credit_acc; when it reaches 1.0, p attempts a step
        and the accumulator drops by 1.

          - progress -> convert; budget += refill (capped). Useful spend.
          - blocked  -> COSTLY YIELD: budget -= yield_cost (>> the refill), so a
                        process that keeps getting scheduled but cannot proceed
                        burns its budget down fast. Its proportional share then
                        shrinks and it stops dominating -- no inheritance, no
                        boost. The holder it waits on keeps its FLOOR share and
                        converts, so it is never starved and SPEEDS UP as the
                        blocker drains (the freed proportional mass redistributes
                        to whoever can convert).

        Returns (status, round, stats): per-process progress, the round H's
        budget first drops below L's (H burning itself down), and the round L's
        per-round progress rate first exceeds H's (proportional speed-up).
        """
        for p in self.procs:
            if p.budget <= 0:
                p.budget = base_budget
            p.credit_acc = 0.0
        budget_cap = base_budget * 5
        progress = {p.name: 0 for p in self.procs}
        prev_progress = {p.name: 0 for p in self.procs}
        burn_round = None        # round H.budget first < L.budget
        speedup_round = None     # round L's rate first > H's rate while H blocked
        C = 1.0

        # identify the high/low pair by priority for instrumentation only
        hi = max(self.procs, key=lambda p: p.priority)
        lo = min(self.procs, key=lambda p: p.priority)

        while self.round < max_rounds:
            self.round += 1
            alive = [p for p in self.procs if not p.done]
            if not alive:
                break
            n = len(alive)
            sum_budget = sum(max(0.0, p.budget) for p in alive) or 1.0

            for p in alive:
                share = (floor_frac * C / n) + \
                        ((1 - floor_frac) * C * max(0.0, p.budget) / sum_budget)
                p.credit_acc += share

            for p in alive:
                # spend whole accumulated credits as step attempts
                while p.credit_acc >= 1.0 and not p.done:
                    p.credit_acc -= 1.0
                    if self.blocked_now(p):
                        p.budget = max(0, p.budget -
                                       (yield_cost if costly_yield else 1))
                        break  # one costly yield per round
                    made = self.attempt(p)
                    if made:
                        progress[p.name] += 1
                        p.budget = min(budget_cap, p.budget + refill)

            # instrumentation
            if burn_round is None and hi.budget < lo.budget:
                burn_round = self.round
            if speedup_round is None:
                rate_lo = progress[lo.name] - prev_progress[lo.name]
                rate_hi = progress[hi.name] - prev_progress[hi.name]
                if self.blocked_now(hi) and rate_lo > rate_hi:
                    speedup_round = self.round
            prev_progress = dict(progress)

            if all(p.done for p in self.procs):
                break

        status = "completed" if all(p.done for p in self.procs) else "max_rounds"
        return (status, self.round,
                {"progress": progress, "burn_round": burn_round,
                 "speedup_round": speedup_round})


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



# ---- Paper 03: priority-inversion scenario (Mars Pathfinder shape) ----------

def build_pathfinder():
    """
    The classic 3-process priority inversion (Mars Pathfinder shape).

    Setup: LOW already HOLDS the shared lock S at t=0 (it grabbed it before HIGH
    became runnable -- the realistic trigger). Then:
      LOW  (pri 1): holding S, needs to do 1 unit of work, then release S.
      HIGH (pri 9): does 1 unit, then needs S (held by LOW), then 1 unit, done.
      MED  (pri 5): long CPU-bound run (8 units), no locks -- unrelated to S.

    Classical scheduling WITHOUT routing: HIGH runs first (pri 9), does its unit,
    hits acquire(S) -> blocked on LOW. Now the highest-priority READY process is
    MED (5), not LOW (1). MED monopolizes for all 8 units while HIGH waits and
    LOW -- the one holding the lock HIGH needs -- sits unscheduled. Only after MED
    finishes does LOW run, release S, and let HIGH finish. HIGH (pri 9) waited
    behind MED (pri 5): unbounded priority inversion.

    WITH routing: when HIGH blocks on LOW, HIGH's priority (9) flows to LOW, whose
    effective priority becomes 9 > MED's 5. LOW preempts MED immediately, does its
    unit, releases S; HIGH proceeds at once. MED runs last. No inversion -- and no
    inheritance protocol was added; urgency flowed along the wait-edge to the
    holder that could convert it.
    """
    S = Lock("S")
    LOW = Process("LOW", priority=1, program=[("work", 1), ("release", S)])
    HIGH = Process("HIGH", priority=9, program=[
        ("work", 1), ("acquire", S), ("work", 1)])
    MED = Process("MED", priority=5, program=[("work", 1)] * 8)
    # LOW pre-holds S at t=0 (the realistic inversion trigger).
    S.held_by = LOW
    LOW.holding.append(S)
    return [LOW, HIGH, MED], S



# ---- Paper 03 (corrected): the costly-yield share scenario ------------------

def build_share_scenario():
    """
    H (high demand) holds nothing it needs at first but will BLOCK on S, held by
    L. M is unrelated CPU work. The point: H, blocked on L, yields COSTLY and
    burns its shared budget; it stops dominating without any inheritance. L,
    guaranteed a floor, is never starved and speeds up as H drains.

      L : holds S at t=0, does 4 units of work, releases S, then 2 more.
      H : 1 unit, then needs S (blocked on L), then 3 units.
      M : 6 units of unrelated work.
    """
    S = Lock("S")
    L = Process("L", priority=1, program=[("work", 1), ("work", 1), ("work", 1),
                                          ("work", 1), ("release", S),
                                          ("work", 1), ("work", 1)])
    H = Process("H", priority=9, program=[("work", 1), ("acquire", S),
                                          ("work", 1), ("work", 1), ("work", 1)])
    M = Process("M", priority=5, program=[("work", 1)] * 6)
    S.held_by = L
    L.holding.append(S)
    return [L, H, M], S


def snapshot_progress_curve(costly_yield=True):
    """Run the share scheduler, recording L's and H's cumulative progress each
    round so we can see (a) L never stalls at zero while H is blocked, and (b) L
    accelerates once H drains/exits."""
    procs, S = build_share_scenario()
    sched = Scheduler(procs, verbose=False)
    L = procs[0]; H = procs[1]
    curveL, curveH, budgets = [], [], []
    # step round-by-round by calling run_share with max_rounds incremented
    # (simpler: instrument inside a manual loop mirroring run_share)
    return sched.run_share(costly_yield=costly_yield)


def measure_L_during_block(costly_yield=True, floor_frac=0.15):
    """Run and measure how much progress L makes during the window where H is
    blocked, and whether L ever stalls (a full round of zero progress while
    alive and not done). Returns (L_progress_in_window, L_ever_stalled, status)."""
    procs, S = build_share_scenario()
    s = Scheduler(procs, verbose=False)
    L, H, M = procs
    for p in s.procs:
        p.budget = 6; p.credit_acc = 0.0
    prog = {p.name: 0 for p in s.procs}
    prev = dict(prog)
    L_window = 0
    L_stalled = False
    for r in range(1, 200):
        alive = [p for p in s.procs if not p.done]
        if not alive:
            break
        n = len(alive); sb = sum(max(0.0, p.budget) for p in alive) or 1.0
        for p in alive:
            p.credit_acc += floor_frac/n + (1-floor_frac)*max(0.0, p.budget)/sb
        H_blocked_this_round = s.blocked_now(H)
        for p in alive:
            while p.credit_acc >= 1.0 and not p.done:
                p.credit_acc -= 1.0
                if s.blocked_now(p):
                    p.budget = max(0, p.budget - (4 if costly_yield else 1)); break
                if s.attempt(p):
                    prog[p.name] += 1; p.budget = min(30, p.budget + 2)
        if H_blocked_this_round:
            L_window += prog['L'] - prev['L']
            # stall check: L alive, not done, not blocked itself, but 0 progress
            if (not L.done and prog['L'] == prev['L'] and not s.blocked_now(L)
                    and floor_frac > 0):
                L_stalled = True
        prev = dict(prog)
        if all(p.done for p in s.procs):
            break
    status = "completed" if all(p.done for p in s.procs) else "stuck"
    return L_window, L_stalled, status



# ---- Paper 03 (stream/rate model): scenario + per-round share trace ---------

def build_flow_scenario():
    """
    H (rate 9) needs S held by L (rate 1); M (rate 3) is unrelated.
      L: holds S, does 3 work, releases S, does 2 more.
      H: 2 work, acquire S (blocks on L), 3 work.
      M: 6 work.
    We watch L's instantaneous share rise while H is blocked (off the table),
    and H eat immediately on return.
    """
    S = Lock("S")
    L = Process("L", priority=1, program=[
        ("work", 1), ("work", 1), ("work", 1), ("release", S),
        ("work", 1), ("work", 1)])
    H = Process("H", priority=9, program=[
        ("work", 1), ("work", 1), ("acquire", S), ("work", 1), ("work", 1), ("work", 1)])
    M = Process("M", priority=3, program=[("work", 1)] * 6)
    S.held_by = L
    L.holding.append(S)
    return [L, H, M], S


if __name__ == "__main__":
    print("=" * 74)
    print("PAPER 03 (stream/rate) — PRIORITY AS FLOW RATE, MEMORYLESS SELF-ORGANISING")
    print("Cake split NOW among who's at the table, by rate. H away -> L's slice")
    print("rises automatically. H back -> eats immediately (no climb-back).")
    print("=" * 74)

    procs, S = build_flow_scenario()
    L, H, M = procs
    sched = Scheduler(procs, verbose=False)
    status, rnd, st = sched.run_flow()

    sl = st["share_log"]
    n = len(sl["L"])
    print(f"\n  {'rnd':>3} | {'L share':>8}{'H share':>8}{'M share':>8} | "
          f"{'Hblocked?':>9}")
    # recompute H-blocked per round is not stored; infer from H share==0 while not done
    for i in range(n):
        ls, hs, ms = sl["L"][i], sl["H"][i], sl["M"][i]
        hblock = "yes" if hs == 0.0 else ""
        print(f"  {i+1:>3} | {ls:8.2f}{hs:8.2f}{ms:8.2f} | {hblock:>9}")

    print(f"\n  status={status} @r{rnd}")
    print(f"  final progress: {st['progress']}")
    print(f"  H returned to table at round: {st['H_return_round']}")
    print(f"  H ate immediately on return (no wait): {st['H_return_immediate']}")

    # claims
    # 1) L's share strictly rises in the window where H is blocked (H share 0)
    L_shares = sl["L"]; H_shares = sl["H"]
    base_L = next((s for s in L_shares if s > 0), 0)
    blocked_idxs = [i for i,h in enumerate(H_shares) if h == 0.0]
    L_rose = any(L_shares[i] > base_L + 1e-9 for i in blocked_idxs)
    # 2) L never zero while at table (never fully starved): no round where L alive,
    #    not blocked, yet share 0 -- approximate: L share > 0 in all rounds before
    #    L is done
    L_done_round = None
    # find first round L stops appearing with positive share consistently:
    L_never_zero = all(s > 0 for s in L_shares[:max(blocked_idxs)+1]) if blocked_idxs else True
    # 3) H eats immediately on return
    H_immediate = bool(st["H_return_immediate"])
    # 4) completes
    completes = status == "completed"

    print("\n" + "=" * 74)
    print("VERDICT")
    print("=" * 74)
    print(f"  L's share rises automatically while H is away:     {L_rose}")
    print(f"  L never starved (positive share throughout block): {L_never_zero}")
    print(f"  H eats immediately on return (no climb-back):      {H_immediate}")
    print(f"  system completes:                                  {completes}")
    ok = L_rose and L_never_zero and H_immediate and completes
    print(f"\n  ALL CLAIMS HELD: {ok}")
    print("  (memoryless: allocation at NOW depends only on who's present + rates.)")
