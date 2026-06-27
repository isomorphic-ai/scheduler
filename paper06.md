# Paper 06 — Safety and Liveness Do Not Trade Off: No False Positives as a Theorem

**Series:** The Isomorphic Scheduler
**Authors:** Fabian Franz & Claude (Team Phi / Isomorphic AI)
**Status:** draft v1 · exhaustively verified · formal proof owed
**Artifact:** `iso_safety.py` @ commit `cbd3a36`

> **TruthSeed (paper):** `iso-sched-06:conversion-not-duration`
> A conserved-budget deadlock detector achieves safety (no false positives) and
> liveness (no false negatives, bounded latency) *together*, with no trade-off
> between them, because the budget measures *conversion* (progress) rather than
> *duration* (time). A slow-but-live process refills its budget by converting and
> therefore can never reach the floor while alive, so it is never falsely aborted
> (safety, from the monotonicity law). A truly deadlocked set converts nowhere,
> floors its budget, and is recognized in a bounded number of steps (liveness,
> from the absorbing-fixed-point law). The classical timeout must trade these off
> because it measures time, which slow-but-live and deadlocked states share;
> the budget separates them because only one of those states converts.

---

## 0. Abstract

A deadlock detector has two duties that classically pull against each other.
*Safety:* never declare a deadlock that is not one — never abort a process that is
merely slow. *Liveness:* always detect a real deadlock, and do so within a bounded
time. A timeout-based detector must trade these off: a short timeout detects real
deadlocks quickly (good liveness) but aborts slow-but-live processes (bad safety);
a long timeout protects slow processes (good safety) but detects real deadlocks
slowly or misses them (bad liveness). The trade-off is forced because a timeout
measures *duration*, and a slow-but-live process and a deadlocked one are
indistinguishable by duration alone — both simply fail to finish quickly.

We show the conserved-budget detector escapes the trade-off entirely, because it
measures *conversion* (whether progress is being made) rather than *duration* (how
much time has passed). A slow process that keeps converting refills its budget and
never reaches the floor; a deadlocked set converts nowhere, drains to the floor,
and is detected. Conversion distinguishes the two states that duration conflates.

We establish both properties not on a single scenario but by **exhaustive search**
over a family of small systems (two- and three-process, two- and three-lock,
covering independent work, resolving contention, slow-but-live processes, AB-BA
deadlock, and a three-cycle deadlock) across budget sizes k ∈ {1,2,3,5}, comparing
the detector's verdict against independently-computed ground truth. The result:
**zero false positives** (no live system ever declared deadlocked, including the
slow-but-live cases that defeat any timeout at small k) and **zero false
negatives** (every truly deadlocked system detected), with **bounded latency**
growing as k + setup, not unboundedly. Safety and liveness both hold, and the
data shows directly that they are distinguished *at the same budget size* — which a
timeout cannot do.

We introduce three invariants for successful systems design:

1. **Epistemic (evidence-tracking).** The detector declares only what the evidence
   shows. *Here:* a deadlock verdict requires both a floored budget *and* a closed
   wait-cycle — measured conversion failure plus measured structure, never an
   inference from elapsed time.
2. **Alignment (shared, not replacing).** A correct verdict serves the whole.
   *Here:* safety protects the slow-but-live process (it is not sacrificed to a
   timer), and liveness protects the rest (a real deadlock is cleared) — the
   detector serves both rather than trading one for the other.
3. **Agency (every action benefits all).** No process is aborted for a property it
   does not have. *Here:* only a process that has genuinely stopped converting, in
   a closed cycle, is ever flagged — no false abort is possible, so no process
   pays for the detector's impatience.

The deeper reading: a trade-off that looks fundamental can be an artifact of
measuring the wrong quantity. Safety-versus-liveness is forced only if you measure
duration. Measure conversion — the conserved quantity — and both fall out together.

---

## 1. Problem revisited

Paper 01 introduced the conserved-budget detector and showed it working on
scenarios: it caught AB-BA deadlock, a three-cycle, and a knot, while leaving a
slow-but-live process alone. Scenarios are evidence, not proof. The strong claim a
detector must earn is a *theorem*: across all systems in some class, it never
errs — no false positive (safety) and no false negative (liveness) — and it detects
within a bound (bounded liveness).

The reason this is not automatic is the classical trade-off. Deadlock detection by
timeout is forced to choose: the same elapsed time that indicates "deadlocked" also
describes "slow but working," so any timeout threshold either fires on slow-but-live
processes (false positive) or waits too long / misses real deadlocks (poor
liveness). Textbook treatments present safety and liveness as competing goals to be
balanced. The problem revisited: is the trade-off *fundamental*, or is it an
artifact of the measured quantity? If the budget detector measures something that
distinguishes slow-but-live from deadlocked, the trade-off dissolves and both
properties can be proved to hold at once.

---

## 2. Background

Safety and liveness are the two canonical classes of correctness property (Lamport,
1977:proving-correctness; Alpern & Schneider, 1985:defining-liveness): informally,
safety says "nothing bad happens," liveness says "something good eventually
happens." Deadlock detection must satisfy a safety property (do not falsely declare
deadlock — do not abort a live process) and a liveness property (do detect real
deadlocks, within a bound). Classical deadlock handling (Coffman et al.,
1971:coffman-conditions; Holt, 1972:deadlock-graphs) detects deadlock via
wait-for-graph cycles, but the *trigger* for running the check, and the decision
that a process is stuck, is conventionally time-based, which is where the
safety/liveness tension enters.

The budget detector replaces the time trigger with a conserved-quantity trigger.
Its theoretical basis is the conservation law of the series: the budget is the
stock (integral) of the conserved quantity, monotone non-increasing without
progress (L2 of the conservation paper), and a deadlock is the absorbing fixed
point where convertible stock floors and stays floored (L3). This paper uses those
two laws to argue safety and liveness, and verifies the argument exhaustively. The
relation between safety/liveness and a conserved measure of progress (rather than
time) is, to our knowledge, not drawn in the classical literature; we pre-register
it.

---

## 3. Sharpening: measure conversion, not duration

Here is the move.

The safety/liveness trade-off is real *for a detector that measures duration*, and
only for such a detector. A slow-but-live process and a deadlocked process are
identical when viewed through elapsed time: neither has finished, and no amount of
waiting tells you which is which, because the slow one will eventually finish and
the dead one never will, but "eventually" is exactly what a timeout cannot see. So
a duration-based detector is stuck choosing a threshold, and every threshold either
abandons safety (fires on the slow) or abandons liveness (misses the dead).

Now change the measured quantity from duration to **conversion**: not "how long has
this taken" but "is this process turning budget into progress." This single change
separates the two states that duration conflates:

- A **slow-but-live** process *is converting* — slowly, but each conversion refills
  its budget back to full. It therefore never reaches the budget floor while alive.
  By the monotonicity law (convertible stock falls only when there is no progress),
  a converting process is provably off the floor. So it is *never* flagged: safety,
  for free, with no threshold to tune.
- A **deadlocked** set *converts nowhere* — every member is blocked on another in
  the set, no one makes progress, every budget drains monotonically to the floor,
  and (by the absorbing-fixed-point law) stays there. The floor is reached in a
  bounded number of steps (at most the budget size), and combined with the closed
  wait-cycle, the deadlock is declared: liveness, bounded.

The two properties no longer compete because the quantity that distinguishes them
is now the one being measured. Conversion is present in exactly the live case and
absent in exactly the dead case; the budget is the integral of conversion; so the
budget floor is reached in exactly the dead case and never in the live case. Safety
and liveness are not balanced against each other — they are two readings of the same
conserved quantity, and both hold because the quantity is the right one.

The wrong framing was "tune the detector to balance false positives against missed
detections." The right framing: **stop measuring duration, which cannot tell
slow-but-live from dead; measure conversion, which can; and both safety and liveness
follow from the conserved budget.**

---

## 4. The solution: safety and liveness from one budget

The detector (from Paper 01): each process has a budget initialized to k. On a step
that makes progress (converts), its budget resets to k. On a step that fails to
progress (a blocked acquire), its budget decrements. A process is *starved* when its
budget reaches the floor (≤ 0). A **deadlock** is declared when a set of starved
processes forms a closed wait-cycle.

### 4.1 Safety: no false positives `(structural; shown)`

> **Claim (safety).** The detector never declares a deadlock for a set containing a
> member that can still convert. A slow-but-live process is never falsely flagged.

A live process — one that will make progress — converts, and on conversion its
budget resets to k. By the monotonicity law, a budget only falls in a step with no
progress; a converting process raises its budget back to full. Therefore a process
that converts at least once every k steps never reaches the floor, regardless of how
*slow* it is in wall-clock terms (it may take arbitrarily long between conversions
in time, but in *conversion* terms it is never starved). Since the deadlock verdict
requires the floor, a live process is never part of a deadlock verdict. Safety holds
not by threshold but by the structural fact that conversion refills the budget.
`(structural)` Verified exhaustively below: zero false positives, including
slow-but-live processes that a timeout would abort at small k. `(shown)`

### 4.2 Liveness: detection, and bounded `(structural; shown)`

> **Claim (liveness).** The detector declares every true deadlock, within a bounded
> number of steps (at most the budget size k plus the setup to form the cycle).

In a true deadlock every member is blocked on another member; none converts; so by
the monotonicity law every member's budget falls every step, reaching the floor in
at most k steps. The deadlock is the absorbing fixed point (it never resumes), so
once floored the set stays floored, and the closed wait-cycle is present by
definition of deadlock. Floor plus cycle is the verdict, so the deadlock is declared
within k + (cycle-formation) steps — bounded, and independent of wall-clock time.
`(structural)` Verified: every truly deadlocked system is detected, with latency
growing as k + setup (3, 4, 5, 7 rounds for k = 1, 2, 3, 5), never unbounded.
`(shown)`

### 4.3 Why they do not trade off `(structural)`

The classical trade-off is forced by a shared symptom: slow-but-live and deadlocked
both fail to finish promptly, so a duration detector cannot separate them and must
sacrifice one property. The budget detector measures conversion, which is *present*
in the live case and *absent* in the dead case — so the very quantity it reads is
the one that distinguishes the cases. Safety (4.1) uses "conversion refills the
budget" (live ⇒ off the floor); liveness (4.2) uses "no conversion drains the
budget" (dead ⇒ on the floor). Both are the same fact — budget tracks conversion —
read in the two cases. There is nothing to trade because there is no shared symptom
to confuse: the detector is blind to duration and sees only conversion, and
conversion is exactly what differs. `(structural)`

### 4.4 The three invariants, in full

- **Epistemic (evidence-tracking — truth that can update).** The detector asserts a
  deadlock only on direct evidence: a measured budget floor (conversion has
  demonstrably stopped) *and* a measured closed wait-cycle (the structure that makes
  the stop permanent). It never infers "stuck" from elapsed time, which is not
  evidence of stoppage but only of slowness. Every verdict is backed by the two
  measured facts, and a process that resumes converting updates its own budget away
  from the floor — the evidence tracks the reality. `(structural)`
- **Alignment (shared, not replacing — success runs through the whole).** A correct
  detector serves every part at once: safety serves the slow-but-live process by
  refusing to sacrifice it to a timer, and liveness serves the rest of the system by
  clearing a genuine deadlock. The detector does not advance one part's interest at
  another's expense — it is not "protect the slow at the cost of missing deadlocks"
  nor "catch deadlocks at the cost of aborting the slow." Both hold, so the whole is
  served. `(structural)`
- **Agency (every action benefits all).** No process is ever aborted for a property
  it does not have. Only a process that has genuinely ceased converting, and sits in
  a closed cycle, is flagged — so no live process pays for the detector's
  impatience, because the detector has none. The single action the detector takes
  (declaring deadlock) is provably confined to processes that are truly stuck, so it
  never harms a process that could have proceeded. `(structural)`

These three are corollaries of measuring conversion: an evidence-based verdict
(epistemic) that serves slow and fast alike (alignment) and never falsely aborts
(agency) is exactly what a conserved-conversion budget delivers.

---

## 5. Related work

**Safety and liveness** (Lamport, 1977:proving-correctness; Alpern & Schneider,
1985:defining-liveness). The canonical two property classes. We instantiate them for
deadlock detection and show that, measured by a conserved conversion budget rather
than by time, they cease to trade off. The general lesson — that a safety/liveness
tension can be an artifact of the measured quantity — is, to our knowledge, a fresh
framing.

**Deadlock detection** (Coffman et al., 1971:coffman-conditions; Holt,
1972:deadlock-graphs). Wait-for-graph cycle detection is classical; our cycle test
is standard. The contribution is the *trigger and starvation decision* via a
conserved budget (conversion) rather than time, which is what yields the
no-trade-off result.

**Novel adjacency — the trade-off as a measurement artifact.** We argue (and verify)
that safety vs. liveness in deadlock detection is forced only by measuring duration,
and dissolves under a conserved conversion measure. We pre-register this and invite
refutation: a counterexample would be a system that is live but whose detector
necessarily floors, or dead but necessarily never floors, under the conversion
budget.

---

## 6. Evaluation

### 6.1 Exhaustive check: `iso_safety.py` `(shown)`

We enumerate a family of small systems and, for each and for each budget size
k ∈ {1,2,3,5}, compare the detector's verdict against independently-computed ground
truth (run with no detector to a large horizon; deadlocked iff it reaches a state
where no process can ever progress). **No wall-clock primitive is present.**

| Family | Truly dead? | Detector verdict | Note |
|---|---|---|---|
| indep (2 independent workers) | no | completed | trivially live |
| contend (sequential lock) | no | completed | contention resolves |
| **slow (A: 12 work steps)** | **no** | **completed** | **slow-but-live — never flagged at any k** |
| abba (AB-BA) | yes | deadlock | detected, latency k+setup |
| 3cycle (three-cycle) | yes | deadlock | detected, latency k+setup |
| slow-contend (slow then lock) | no | completed | slow holder, still resolves |

Results across all systems × all k:

- **Safety: zero false positives.** No live system is ever declared deadlocked. The
  `slow` family — a process doing twelve work steps — completes cleanly at every k,
  including k = 1, where any timeout calibrated to catch the AB-BA deadlock (which
  floors in 3 rounds) would necessarily also abort the slow process. The budget
  detector distinguishes them *at the same k*. `(shown)`
- **Liveness: zero false negatives.** Every truly deadlocked system (abba, 3cycle)
  is detected. `(shown)`
- **Bounded latency.** Detection round grows as k + setup: 3, 4, 5, 7 rounds for
  k = 1, 2, 3, 5. The latency is the budget size plus the steps to form the cycle,
  never unbounded and never time-dependent. `(shown)`

The decisive cell is the `slow` row at k = 1 against the `abba` row at k = 1: a
slow-but-live process (completes in 12 rounds) and a deadlock (floors in 3) are
classified correctly *at the same budget size*. A timeout at any single threshold
cannot separate these — set it below 12 and the slow process is aborted; set it
above and the deadlock waits. The budget separates them because it reads conversion,
not duration. This is the no-trade-off result, shown.

### 6.2 Honest limitation: a finite family, not all systems `(shown limitation)`

This is an exhaustive check over a *finite family* of small systems (two/three
processes, two/three locks, six structural families, four budget sizes), not a proof
over all systems. It is strong evidence — every case in a deliberately
adversarial-for-the-detector family (including the slow-but-live cases that target
safety) is classified correctly — but it is not a universal proof. The safety and
liveness claims are stated structurally in §4.1–4.2 and are dischargeable in a proof
assistant over the general transition system (safety from L2 monotonicity, liveness
from L3 absorption); we mark them `(structural)` for the statements and `(shown)` for
the exhaustive evidence, and name the formal proof as the next rigor level. `(shown
limitation)`

### 6.3 Practical exam pointer

In a real system the claim to test is: replace a deadlock/livelock *timeout* with a
conversion budget (reset on forward progress, decrement on a blocked wait), and
verify that (a) no slow-but-live transaction is ever aborted, and (b) every true
deadlock is still caught within budget-size steps. A false positive in production —
a live transaction aborted — is a safety leak and means progress was mis-measured
(something counted as "no progress" that was progress); a missed deadlock is a
liveness leak. Both are the next seed.

---

## 7. Further work (deeper into this wave)

- **Machine-checked proof.** Discharge safety (from L2) and liveness with bounded
  latency (from L3) in Lean/Coq over the general transition system, upgrading the
  exhaustive `(shown)` to a universal `(proven)`. This composes with the Paper 04
  Lean task: safety/liveness are corollaries of the conservation laws proved there.
- **What counts as conversion.** Safety depends entirely on the progress signal
  being honest (a step that genuinely advances state must count as conversion, and
  nothing else may). Characterize the minimal faithful progress signal for a real
  system (the Paper 01 practical exam's "forward-state progress, not duration"),
  and the failure modes when it is mis-specified (read-only progress, adversarial
  slowness).
- **Partial deadlocks and knots.** The family here covers cycles. Extend the
  exhaustive check to knots (a cycle plus off-cycle processes blocked on it) and
  verify safety/liveness localize correctly (the off-cycle processes are not
  falsely flagged; the cycle is).
- **Quantitative latency bound.** Prove the exact latency bound (k + cycle-formation
  steps) as a theorem and characterize the worst-case cycle-formation cost as a
  function of the number of processes and locks.

---

## 8. Conclusion

A deadlock detector must be safe (never abort a live process) and live (always catch
a real deadlock, within a bound), and these duties classically trade off. We showed
the trade-off is not fundamental — it is an artifact of measuring duration, which
cannot tell a slow-but-live process from a deadlocked one. The conserved-budget
detector measures conversion instead, which is present in exactly the live case and
absent in exactly the dead case, and so both properties hold together: a converting
process refills its budget and is never falsely flagged (safety, from
monotonicity), and a deadlocked set drains to the floor and is detected in bounded
steps (liveness, from the absorbing fixed point). We verified this exhaustively
across a family of small systems and budget sizes — zero false positives, zero false
negatives, latency growing as k + setup — and the decisive observation is that the
detector separates a slow-but-live process from a deadlock *at the same budget
size*, which no single timeout can do.

The lesson generalizes past deadlock. A trade-off that appears fundamental may be
the shadow of measuring the wrong quantity. Safety against liveness looks
unavoidable through the lens of time; through the lens of the conserved quantity —
conversion — it disappears, because the conserved quantity is precisely what
distinguishes the states that time conflates. Measure the right thing, and the
properties you wanted stop competing and start coinciding. The proofs here are
exhaustive over a finite family; the universal, machine-checked version is named as
the next step and rests on the same conservation laws the series has been proving
all along.

---

## Bibliography

- Lamport, L. (1977). *Proving the Correctness of Multiprocess Programs.* IEEE TSE.
  — `1977:proving-correctness`
- Alpern, B., Schneider, F. B. (1985). *Defining Liveness.* Information Processing
  Letters. — `1985:defining-liveness`
- Coffman, E. G., Elphick, M., Shoshani, A. (1971). *System Deadlocks.* ACM
  Computing Surveys. — `1971:coffman-conditions`
- Holt, R. C. (1972). *Some Deadlock Properties of Computer Systems.* ACM Computing
  Surveys. — `1972:deadlock-graphs`

> Citation keys are permanent `Year:slug` handles; the slug is the load-bearing
> identifier, full bibliographic resolution secondary to seed stability.

---

## Appendix A — Reproducibility

- Artifact: `iso_safety.py`, committed at `cbd3a36` (Team Phi).
- Run: `python3 iso_safety.py` — prints the per-family, per-k classification table,
  the detection-latency table, and a verdict ending in `SAFETY AND LIVENESS BOTH
  HOLD: True`.
- No-timer audit: `grep -niE "time|sleep|clock|timeout|perf_counter|monotonic"
  iso_safety.py` returns only prose in comments.
- Determinism: round-robin scheduling, no RNG; ground truth computed by detector-free
  simulation. Checks reproduce exactly.

## Appendix B — Safety and liveness in one screen

```
budget(p): reset to k on a converting step; decrement on a blocked (no-progress) step.
starved(p): budget(p) <= 0.
deadlock verdict: a set of starved processes forming a closed wait-cycle.

  SAFETY  (no false positive): live p converts at least every k steps -> budget
          resets -> never floors -> never in a verdict.  (from L2 monotonicity)
  LIVENESS(no false negative): dead set converts nowhere -> every budget floors in
          <= k steps -> floor + cycle -> declared.        (from L3 absorption)

No trade-off: the two use the SAME fact (budget tracks conversion) in the two cases.
A timeout must trade them because duration cannot tell slow-but-live from dead.
Conversion can. No clock.
```
