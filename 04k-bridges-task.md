# 04k — The Three Bridges: L4 traces, real windows, dynamical Theorem 1

**Series:** Iso-Scheduler Lean · post-04j closure round
**Assignee:** Lean-Goblin (codex) — `goblin@i9:~/scheduler/iso-conserve-lean`
**Source:** GPT-5.6-pro-feedback--lean.md (2026-07-19 15:12 UTC section) — all
findings verified in source by Fable (Review #9). The Pro's proof targets are
adopted with the adjustments below.

> **TruthSeed (task):** `iso-lean-04k:derive-dont-install`
> Twelve of fifteen rows pass. The three that remain share one shape: a
> theorem currently *states* what the paper needs via a definition that
> *installs* it (payoffs attached, windows ignored, traces parallel to the
> dynamics). Close each by DERIVING the quantity from the transition system
> the other theorems already run on. No new theory — commuting squares and
> honest quantifiers.

## Order (pre-decided): B2 → B1 → T1 → B3; R1 immediately, in parallel

Rationale: B2 is the smallest and repairs a claimed paper distinction
(slow-but-live); B1 is mechanical plumbing with a known shape; T1 before B3
because B3's realized-run proofs want steps that constructively produce
well-formed states.

## WP-B2 — A window predicate whose window is load-bearing

`convertsWithinEverySelectionWindow` ignores `_window` and demands conversion
on EVERY selection. Replace with a genuine windowed condition. Two acceptable
forms (pick one, record the choice in FINDINGS):

1. The Pro's segment form: every contiguous selection segment of p with
   ≥ window selections contains a selection at which p canConvert.
2. The invariant form (likely simpler): no run of `budgetCap` consecutive
   non-converting selections of p occurs between refills.

Restate `periodic_conversion_never_floors` and `live_process_not_detected`
over the real condition. Keep the old every-selection theorems only if they
fall out free, renamed `*_every_selection` so nobody mistakes them for the
windowed claim.

**Gate (both directions — the window must bite):**
- Positive witness: a concrete schedule where p converts exactly once per
  window and is never floored (theorem, not comment).
- Negative witness: a schedule where p misses one window and IS floored
  (theorem). Without the negative witness we cannot distinguish the new
  predicate from the old one — that is exactly how `_window` slipped past
  two reviewers.

## WP-B1 — The commuting square: CoreRel ↔ typed traces

Adopt the Pro's targets verbatim:

```
core_step_has_event      : CoreRel s t → ∃ e, EventRel s e t
core_reachable_has_trace : RTC CoreRel s t → ∃ trace, TypedRun s trace t
L4_for_core_reachable    : RTC CoreRel s t → stock/credit difference = flowIntegral of that trace
```

Events must carry their plans (or an `eventOfStep` witness) so `EventRel`
enforces admissibility — `applyEvent`'s arbitrary deltas are the thing being
retired, not re-wrapped. When done, DELETE the obligations comment at
CoreTrace.lean:1376–85 — it is discharged, and a stale obligations note is a
false FINDINGS entry in waiting.

**Fallback (reviewable, not silent):** if one CoreRel arm resists (suspect:
claim-release), a bridge over CoreRel-minus-that-arm with the exclusion named
in the theorem name AND a FINDINGS entry is acceptable for this round.

## WP-T1 — Preservation: transitions PRODUCE well-formed states

Currently transitions relate caller-supplied WF endpoints; `workStep` can
mark a process done while it still holds locks (violating done_holds_nothing
— the Pro's concrete example, verified). Strengthen plans with the missing
obligations (e.g. completion requires empty lock set or carries the
releases) and prove preservation for all seven step kinds plus
`resolutionYield`:

```
CoreWF s → ValidPlan s pl → CoreWF (apply pl s)
```

Package as constructors returning `WFState`. Do not weaken CoreWF to make
this easy — the record is the paper's ontology; the plans are the free
variable.

## WP-B3 — Theorem 1: derive the payoffs, don't install them

The current kernel is correct and stays (it is the reviewed local theorem).
The upgrade, per the Pro's targets:

```
DependencyPath s i j     := Relation.TransGen (blockedOn s) i j
routeState               : an ACTUAL transition — q moves i→j, state changes
CanConvertAfterRoute     : CanConvertQty (routeState s i j q) j q   -- post-route counterfactual
RealizedOwn/WholeConversion : measured as final-minus-initial conversion totals over a real run
route_realizes_conversion : Stranded → Path → CanConvertAfterRoute →
                            ∃ t, RTC CoreRel (routeState …) t ∧ realized = q
hoard_realizes_zero_conversion
route_strictly_dominates_hoard          -- over realized quantities
selfish_optimum_contains_no_stranded_claim
selfish_optima_eq_generous_optima       -- over the actual Policy type
```

**The one deep design point — surface it in FINDINGS BEFORE implementing:**
realized own-conversion for i along a TransGen path needs the return leg
(j's conversion flowing back to i) to exist in the dynamics. If the current
CureRel arms cannot express the return, extending them is allowed — but the
extension must conserve `accounted` (prove it) and must not perturb
`monotone_under_adversary`. Design note first, then code.

**Fallback (pre-decided):** if the unrestricted Policy quantifier resists,
the reviewable fallback is Policy over a NAMED finite action grammar
(compositions of route/hoard/release), restriction stated in the theorem
name. What is not acceptable is the current state continuing to be
described as the paper's Theorem 1.

## WP-R1 — Packaging + counts (immediate, parallel)

1. Next archive to any external reviewer ships: `lean-toolchain`,
   `lake-manifest.json`, EVIDENCE-AUDIT.md, and a build transcript. The Pro
   audited source without kernel execution because our export omitted the
   toolchain files the repo already has — packaging defect, not proof gap.
2. Extend the audit tool's `#print axioms` list with the Pro's four headline
   names (PaperClaims: L1_conservation, core_trace_integral, detector_sound,
   hoarding_is_self_defeating — adjust to the actual exported names and note
   any renames).
3. Reconcile 427 (Pro) vs 431 (audit) declaration counts: state the counting
   rule in the audit output (one line).
4. Paper-number staleness (1,717 lines/105 theorems/10 modules → current) is
   the PAPER author's item, not yours — but regenerate the current numbers
   table via the audit tool so it is ready to paste.

## Standing guardrails (unchanged)

No `sorry`/`admit`/new `axiom`; `monotone_under_adversary` untouched;
deviations = FINDINGS at discovery; commit via codex-git-commit with
explicit pathspecs; task file ships with the tree; every claimed gate has a
committed artifact (`git ls-files` is the check, never `ls` — this bit the
MySQL track twice today).
