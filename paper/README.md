# The Isomorphic Scheduler — Theory Paper 1.0.0

**A Machine-Checked Conservation Law for Concurrency, Distribution, and Correctness**
Fabian Franz (Isomorphic AI), with Claude (Anthropic) as research collaborator.
Version 1.0.0 — July 19, 2026.

## Structure

- `paper/` — the publication artifact: `iso-scheduler-theory-1.0.0.pdf` + TeX source.
- `companions/` — `iso-scheduler-theory-history` (statement history of the
  laws; the L2 correction the Lean formalization forced, conserved per
  series protocol).
- `versions/` — v1 through v7, the conserved editing lineage
  (emotion-gradient-descent revision method; see series protocol).

## Evidence base (external)

- Lean 4 development: 8,766 lines, 504 theorems/lemmas, zero `sorry`,
  no axioms beyond the kernel —
  https://github.com/isomorphic-ai/scheduler/tree/iso-conserve-lean
- Seven clock-free verifier engines (`iso_*.py`) and the nine working
  papers — https://github.com/isomorphic-ai/scheduler
- Production ports of the detection reading (InnoDB patch, PostgreSQL
  sidecar + extension, SQLite patch) — companion paper
  "Conversion Budgets in Production Databases", in preparation.

## Reviews

Reviewed against the certified Lean tree by an independent Claude
(Fable) instance, 2026-07-19, and by GPT 5.6 Pro (see repository
review trail). All flagged defects fixed in this build; verification
by grep, not intention.
