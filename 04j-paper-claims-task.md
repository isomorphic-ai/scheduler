# 04j - Lean 4 Formalization Task: Paper Claims Closure Layer

**Series:** Isomorphic Scheduler - combined paper / Paper 08 closure
**Depends on:** `04d-core-trace-task.md`, `04e-lean-task.md`,
`04f-rate-routing-task.md`, `04g-detector-progress-task.md`,
`04h-resolution-yield-task.md`, `04i-theorem1-task.md`,
`paper08-expanded.md`, `iso-conserve-lean/NEXT-TASKS.md` Round 4b WP7, and
`GPT-5.6-pro-feedback--lean.md` §7
**Goal:** create a compiled paper-to-Lean closure layer so the paper's named
claims cite theorem names at a pinned commit, and so evidence audits are generated
rather than hand-counted.

> **TruthSeed (task):** `iso-sched-04j-paper-claims`
> The final Lean surface should read like Appendix B: one quantity, one fault, one
> cure, then theorem aliases for each paper claim. If a claim is empirical or
> out-of-scope, it belongs in the coverage table, not as a fake theorem.

---

## 0. Non-Negotiable Boundaries

Do **not** implement this before the mathematical modules it names have landed.
This task is a closure layer, not a substitute for missing proofs.

Do **not** add theorem-shaped placeholders, axioms, `sorry`, or trivial
`(h : X) : X := h` wrappers to make the table look complete.

Do **not** collapse the engine/Lean division. Engines demonstrate concrete
phenomena; Lean proves laws and bridge instances. The README/paper table should say
which is which.

Do **not** count lines, modules, or theorems manually in the release evidence. Add a
repeatable audit command or script.

---

## 1. Paper Claims This Task Targets

From `paper08-expanded.md` Appendix B:

> ONE fault: a claim held where it cannot convert (a stranded claim / a hoard).
> ONE cure: route Q to where it converts, or release it.

> Q has three readings (calculus):
> flow = dQ/dt; stock = integral of flow; credit = integral banked across a yield.

> THREE invariants, corollaries of conservation (L1), not additions:
> epistemic, alignment, agency.

> CENTRAL THEOREM: in a connected graph, hoarding is self-defeating -- the selfish
> optimum and the generous optimum are the same point.

From the Pro feedback §7:

> Add something like `IsoConserve/PaperClaims.lean` containing imports or aliases
> for every named claim in Sections 4 and 6.

> The file should read almost like Appendix B.

> Preserve the engine/Lean division honestly.

> Automate the evidence audit.

---

## 2. Headline Module

Add:

```text
iso-conserve-lean/IsoConserve/PaperClaims.lean
```

This file should import the completed theorem modules and expose paper-facing names.
Suggested namespace:

```lean
namespace IsoConserve
namespace PaperClaims
```

The module should contain aliases or thin corollaries for proved claims, for example:

```lean
theorem L1_conservation := ...
theorem L2_monotonicity := ...
theorem L3_absorption := ...
theorem L4_stock_integral := ...
```

Use stronger existing theorem names where appropriate, but the paper-facing names
should be stable and citation-ready.

Required headline surface after all prior work packages land:

```lean
L1_conservation
L2_monotonicity
L3_absorption
L4_stock_integral
detection_sound
detection_complete_bounded
live_process_not_detected
resolution_yield_loses_no_work
routed_rate_conserved
priority_inversion_cannot_form
pn_counter_merge_converges
pn_counter_debt_surfaces
progress_signal_useful_kept
progress_signal_spinner_reclaimed
collapse_whole_invariant
hoarding_is_self_defeating
selfish_optima_eq_generous_optima
epistemic_invariant
alignment_invariant
agency_invariant
```

If a listed theorem is not yet proved, leave it out and document the gap in the
coverage table. Do not create a placeholder.

---

## 3. Canonical Bridge Modules

Where a paper claim cites an engine phenomenon and the equations are formalized,
add finite rational bridge modules:

```text
IsoConserve/CanonicalConservation.lean
IsoConserve/CanonicalDetection.lean
IsoConserve/CanonicalResolution.lean
IsoConserve/CanonicalRateRouting.lean
```

These modules should reproduce exact finite instances with theorem-level results:

- conservation canonical step;
- detector zero false positive / bounded true deadlock instance;
- credit-yield versus discard instance;
- rate-routing `10/13` versus `3/13` instance.

For readings whose engines remain empirical or expansion-only, say so:

- CAP-as-schedule publish protocol;
- progress-signal reputation beyond the toy theorem;
- phantom-race distribution traces beyond the collapse identity;
- production-kernel scheduling.

---

## 4. Coverage Matrix

Update `iso-conserve-lean/README.md` with a generated or mechanically maintained
matrix:

```text
paper section -> claim -> Lean theorem -> engine witness -> status -> boundary
```

Required rows:

- §3 central theorem;
- §4.1 detection;
- §4.2 resolution;
- §4.3 scheduling/rate routing;
- §4.4 L1-L4 and invariants;
- §4.5 PN-counter distribution;
- §4.6 safety/liveness and progress signal;
- §4.7 flexibility collapse;
- Noether obstruction / future normalized uniqueness.

The matrix must distinguish:

- **proved**: Lean theorem exists and `#print axioms` is clean;
- **bridge proved**: finite engine instance reproduced in Lean;
- **engine shown**: deterministic/exhaustive engine evidence only;
- **out of scope**: intentionally excluded by task file.

---

## 5. Evidence Audit Command

Add a repeatable audit script, tentatively:

```text
tools/lean-evidence-audit
```

or a Lake script if that is cleaner.

It should run from the repo root or `iso-conserve-lean/` and produce:

```text
lake build
grep -Rnw IsoConserve -e sorry -e admit
grep -Rnw IsoConserve -e "axiom "
#print axioms <every headline theorem>
source-line total
theorem/lemma total
module inventory
theorem-to-paper matrix
```

Suggested generated output:

```text
iso-conserve-lean/EVIDENCE-AUDIT.md
```

The audit command may be conservative. If parsing Lean theorem declarations
perfectly is too expensive, use a simple `rg "^theorem |^lemma "` count and label it
as a syntactic count.

---

## 6. Exclusions

The closure layer should explicitly exclude the Pro feedback's non-pass items:

- automorphism;
- route/share/defer generator result;
- universal formal encoding of all seven domain isomorphisms;
- open-system continuity equations;
- min-cut/max-flow correspondence;
- quantitative eventual consistency;
- entropy as a second law;
- Byzantine conservation;
- production-kernel scheduling.

These are not failures of the closure layer. They are future-work rows.

---

## 7. Acceptance

1. `IsoConserve/PaperClaims.lean` builds and is imported by `IsoConserve.lean`.
2. Every theorem exported by `PaperClaims.lean` is a proved alias/corollary, not an
   axiom or placeholder.
3. `lake build` succeeds.
4. No `sorry`, `admit`, or new `axiom` appears in `IsoConserve/`.
5. The evidence audit command runs and writes or prints the matrix/counts.
6. README cites the coverage matrix and a pinned commit.
7. FINDINGS records any claim that remains empirical, out-of-scope, or sharpened by
   the proof surface.

---

## 8. Suggested Work Order

1. Add `PaperClaims.lean` with only currently proved aliases.
2. Add the coverage matrix with honest statuses.
3. Add the audit command and generated audit output.
4. Add canonical bridge modules as prior work packages make them possible.
5. Re-run the audit and update README/FINDINGS at the final pinned commit.

Stop if a desired paper-facing theorem has no proved source. The right move is to
mark the gap, not to synthesize a theorem-shaped placeholder.
