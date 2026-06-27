"""
iso_progress.py — Paper 06 addendum: real agency via self-reported progress.

Paper 06 measured conversion EXTERNALLY: the scheduler infers progress from
observable state change (a lock acquired, a work-step completed). That works when
progress is externally visible. It fails for the case agency most wants to fix:

  A process at 100% CPU that produces nothing looks, from outside, IDENTICAL to a
  process at 100% CPU doing hard internal computation. Externally, neither changes
  observable state for a long time. The detector cannot tell the useful one from
  the spinning one -- so it must either let spinners burn forever (no agency to
  reclaim the CPU) or risk aborting the useful one (a safety/agency violation).

The fix is to stop INFERRING conversion and instead ASK. Give the process real
agency: a progress signal SIG_PROGRESS to which it replies with a monotone
progress counter on a syscall line ("I am at N; last time I was at M < N").

  - If it answers with a rising counter: it IS converting -> budget refills ->
    never flagged. The useful 100%-CPU process is now distinguishable and safe.
  - If it does not answer, or its counter does not rise: it is NOT converting ->
    budget drains -> reclaimable. The spinner is now reclaimable WITHOUT a clock
    and without falsely accusing the useful process.

A process CAN lie (report progress it is not making). That is fine: it is the
liar's problem, not the detector's. Lying corrupts the liar's own evidence
(epistemic invariant) and is a reputation matter (a process that lies about
progress and then fails to deliver is accountable); the detector's only job is to
PROVIDE THE HONEST CHANNEL, not to enforce honesty. Truth-telling is the
cooperative equilibrium; defection is visible and self-punishing over time.

This is the agency invariant upgraded from "we never falsely abort" (passive) to
"we give every process the means to account for itself" (active). No wall clock.
"""

from __future__ import annotations
from dataclasses import dataclass, field


@dataclass(eq=False)
class Task:
    name: str
    # ground-truth nature (the detector does NOT see this; only the test does):
    #   "useful"   -> doing real internal work, progress counter genuinely rises
    #   "spinning" -> 100% CPU, no real progress, counter does not rise
    #   "liar"     -> spinning, but reports a rising counter anyway
    nature: str
    budget: int = 0
    reported: int = 0          # last progress value it reported
    true_progress: int = 0     # ground truth (test-only)
    reclaimed: bool = False
    flagged_liar: bool = False

    def on_sig_progress(self):
        """The process's reply to SIG_PROGRESS. Returns its progress counter on
        the 'syscall line'. This is the process exercising agency: accounting for
        itself. Honesty is the PROCESS's responsibility, not the detector's."""
        if self.nature == "useful":
            self.true_progress += 1           # genuinely advanced
            self.reported = self.true_progress
            return self.reported
        if self.nature == "spinning":
            # honestly cannot report progress (or reports its flat counter)
            return self.reported              # stays flat -> truthful non-progress
        if self.nature == "liar":
            # spins (no true progress) but reports a rising number anyway
            self.reported += 1                # the lie
            # true_progress does NOT advance
            return self.reported
        return self.reported


class ProgressDetector:
    """Asks instead of infers. Each round, sends SIG_PROGRESS; a task whose
    reported counter rises refills budget; one whose counter is flat drains and
    is reclaimed at the floor. Lies are accepted at face value (the detector does
    not police honesty) -- but a separate, optional VERIFIER can later compare
    promised vs delivered to assign reputation, which is where a liar pays."""
    def __init__(self, tasks, k=3):
        self.tasks = tasks
        self.k = k
        for t in tasks:
            t.budget = k

    def round(self):
        for t in self.tasks:
            if t.reclaimed:
                continue
            before = t.reported
            now = t.on_sig_progress()          # ASK
            if now > before:
                t.budget = self.k              # reported progress -> refill
            else:
                t.budget -= 1                  # no reported progress -> drain
                if t.budget <= 0:
                    t.reclaimed = True         # reclaim the CPU, no clock used

    def run(self, rounds=12):
        for _ in range(rounds):
            self.round()


def verify_reputation(task):
    """Optional out-of-band check: did reported progress match delivered (true)
    progress? A liar reports rising counters while true_progress stays flat. This
    is NOT the detector's job in-loop; it is the reputation system that makes
    lying the liar's problem. Returns True if the task was honest."""
    # honest iff every reported increment corresponds to a true increment
    return task.reported == task.true_progress


def scenario():
    return [
        Task("useful",   "useful"),    # 100% CPU, real work -> must be SAFE
        Task("spinner",  "spinning"),  # 100% CPU, nothing  -> must be reclaimed
        Task("liar",     "liar"),      # 100% CPU, lies      -> not our problem in-loop
    ]


if __name__ == "__main__":
    print("=" * 76)
    print("PAPER 06 ADDENDUM — REAL AGENCY VIA SELF-REPORTED PROGRESS (SIG_PROGRESS)")
    print("Don't infer progress from outside -- ASK. The process accounts for")
    print("itself. Honesty is the process's responsibility, not the detector's.")
    print("=" * 76)

    tasks = scenario()
    det = ProgressDetector(tasks, k=3)
    det.run(rounds=12)

    print(f"\n  {'task':10}{'nature':10}{'reported':>9}{'true':>6}{'reclaimed':>11}")
    print("  " + "-"*52)
    for t in tasks:
        print(f"  {t.name:10}{t.nature:10}{t.reported:>9}{t.true_progress:>6}"
              f"{str(t.reclaimed):>11}")

    useful = next(t for t in tasks if t.name == "useful")
    spinner = next(t for t in tasks if t.name == "spinner")
    liar = next(t for t in tasks if t.name == "liar")

    print("\n  IN-LOOP DETECTOR (asks, does not police honesty):")
    print(f"    useful 100%-CPU process kept alive (SAFE):     {not useful.reclaimed}")
    print(f"    spinning process reclaimed (no clock):         {spinner.reclaimed}")
    print(f"    liar survives in-loop (accepted at face value): {not liar.reclaimed}")

    print("\n  OUT-OF-BAND REPUTATION (makes lying the liar's problem):")
    print(f"    useful is honest (reported == delivered):      {verify_reputation(useful)}")
    print(f"    spinner is honest (truthfully reported flat):  {verify_reputation(spinner)}")
    print(f"    liar is caught (reported != delivered):        {not verify_reputation(liar)}")

    print("\n" + "=" * 76)
    print("VERDICT")
    print("=" * 76)
    ok = ((not useful.reclaimed) and spinner.reclaimed
          and verify_reputation(useful) and (not verify_reputation(liar)))
    print(f"  Real agency works: useful kept, spinner reclaimed, liar accountable: {ok}")
    print("  The detector provides the honest channel; it does not enforce honesty.")
    print("  A process can lie, but that is the liar's problem. No wall clock.")
