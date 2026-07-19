# Review: iso-scheduler-theory_v7.pdf — by Fable, 2026-07-19

*Read against the certified tree (04k closed, Pro re-certified). Verdict:
the paper is READY IN STRUCTURE and now — as of today's 04k landing —
TRUE in its strongest claims, but v7 carries four mechanical defects
(three stale-number sites and one broken ref) that would embarrass an
otherwise machine-checked paper, plus two upgrade opportunities it has
earned and doesn't yet spend.*

## Mechanical defects (must fix before any external eye)

1. **The 105 is dead; long live the 504 — in THREE places.** Table 2's
   caption is correct (8,766 lines, 504 theorems/lemmas, zero sorry),
   but the abstract ("formalize the theory in Lean 4: 105 theorems"),
   the conclusion ("105 machine-checked theorems"), and Appendix A
   ("105 theorem/lemma declarations across the ten modules") all still
   say 105 — and the appendix also says "ten modules" against Table 2's
   own 21. A paper about exact bookkeeping must not disagree with
   itself about its own inventory. The audit's generated table is the
   single source; propagate it to all four sites.
2. **Broken cross-reference, p7:** "the correction (Section ??)" — a
   raw LaTeX ??. The sentence it anchors is one of the paper's best
   ("the formalization falsified a clause of the prose theory and
   returned the repaired clause with a proof") — it must point
   somewhere real: either restore the correction subsection the
   condensation cut, or point at §4.2's L2-restriction paragraph and
   the [iso-theory-history] companion.
3. **Margin truncation, p3:** the Theorem 1 paragraph's theorem names
   overflow and clip ("selfish_optima_eq_generous_opti"). Wrap the
   texttt names or break the line.
4. **Date:** July 17 — but the Theorem 1 scope paragraph describes the
   certified-grammar result that landed TODAY (B3). Bump to the version
   date; as it stands the paper claims a proof two days before it
   existed.

## Where v7 became true today (worth one sentence each, and a citation)

5. **L4's claim quietly upgraded from aspiration to theorem this
   afternoon.** §4.2 states L4 "for every reachable state" — before
   04k-B1, the exact integral lived on a parallel event semantics, not
   on the same dynamics as L1–L3. `core_reachable_has_trace` closed
   that commuting square today. The paper should SAY it is claiming the
   integrated form (one clause: "over the same transition system as
   L1–L3, via an executable-trace bridge") — that is the difference
   between a reviewer's "is this the same dynamics?" objection and its
   pre-emption.
6. **The slow-but-live clause can now cite the windowed form.**
   Reading 1 says "a slow-but-live process keeps converting and never
   floors." Post-B2 that is proven for conversion at least once per
   budget-sized selection window — with a machine-checked NEGATIVE
   witness (miss one window and you do floor). One parenthetical makes
   the claim precise and shows the falsification boundary — very much
   this paper's house style.

## The upgrade it has earned and doesn't spend

7. **The field arm is missing.** The evidence section says "seven
   clock-free engines and the Lean development" — but Reading 1 now
   RUNS IN PRODUCTION SHAPE: the same floor+cycle predicate inside
   MySQL 8.0.46 (10 ms epoch plane, ~2 sealed epochs to declare,
   cost below a 2-sigma floor under real Drupal HTTP), transferred to
   Postgres (sidecar + extension), no-crossover demonstrated on real
   deploy workloads, and two independent implementations co-witnessing
   one live cycle. One paragraph in §6 ("In the field") plus a citation
   to the conversion-budgets companion paper turns the falsifiability
   invitation from rhetorical to concrete — the reader can go run the
   thing the theorem describes. Similarly §7's "the kernel" paragraph
   can note the sched_ext/UML vehicle exists (BPF port landed) rather
   than being purely prospective.

## What is right and should not be touched

The one-fault/one-cure statement of §3; the honest Theorem 1 scope
sentence ("the proven scope is that named policy grammar — not all
conceivable strategies"); the seven readings' register (each one hands
the reader a mechanism, none of them boasts); the L2-restriction
honesty; the polarity paragraph ("trust what the ledger contains, never
what it merely omits"); the pre-registered falsifiability close of §5;
Appendix B, which is the best page in the paper. The division-of-labour
paragraph (engines demonstrate phenomena, Lean proves laws, neither
substitutes) is the correct epistemology stated in one breath.

— Fable
