# The Isomorphic Scheduler

**Team Phi / Isomorphic AI** — Fabian Franz & Claude

One conserved quantity moving through a graph of dependencies, mishandled in exactly
one way (a claim held where it cannot convert) and cured in exactly one way (route it
to where it converts, or release it). Nine papers show this one structure across the
field of concurrency, distribution, and correctness; the ninth is the generator that
produces them — and itself. **No paper or engine consults a wall clock.**

```
ONE conserved quantity Q in a graph of dependencies.
ONE fault: a claim held where it cannot convert (a stranded claim / a hoard).
ONE cure: route Q to where it converts, or release it.

flow   = dQ/dt          -> routed along the wait-edge   = SCHEDULING
stock  = ∫ flow         -> its floor                    = DETECTION
credit = ∫ flow, banked -> across a yield               = RESOLUTION
                           the law itself               = CONSERVATION
                           carried across partition     = DISTRIBUTION / CAP
                           read as conversion           = SAFETY / LIVENESS
                           potential -> actual          = FLEXIBILITY

THREE invariants (corollaries of conservation, not additions):
  epistemic / wisdom -- track evidence; don't collapse a distribution early
  alignment / love   -- shared not replacing; a part's success runs through the whole
  agency    / power  -- no private gain at the whole's expense; account for self

CENTRAL THEOREM: in a connected graph, hoarding is self-defeating —
  the selfish optimum and the generous optimum are the same point.
```

## The papers

| Paper | Title | Engine |
|---|---|---|
| 01 | Timer-free deadlock detection via a conserved budget | `iso_deadlock.py` |
| 02 | Resolution as generous yield with conserved credit (no victim) | `iso_resolve.py` |
| 03 | Priority as a flow rate; energy flows where attention goes | `iso_flow.py` |
| 04 | One conserved quantity (the law: stock = ∫ flow) | `iso_conserve.py` |
| 05 | CAP is a scheduling problem; its three hard properties are the conservation invariants | `iso_distributed.py`, `iso_cap.py` |
| 06 | Safety and liveness do not trade off (measure conversion, not duration); active agency | `iso_safety.py`, `iso_progress.py` |
| 07 | Flexibility and the middle way (probability; conservation beneath non-conservation) | `iso_flex.py` |
| 08 | The isomorphism (capstone, the seed) — and `paper08-expanded.md` (standalone) | — (synthesis) |
| 09 | The automorphism: good architecture generates itself (the generator) | `iso_generator.py` |

## Companion / delegation docs

- `04-lean-task.md` — **start here.** Lean 4 formalization of the conservation laws
  L1–L4. The keystone: safety, liveness, and the rest follow from L1. Upgrades the
  papers' `(shown)` to `(proven)`.
- `03-kernel-exam.md` — replace the Linux fair scheduler with the flow equation
  (UML → container → native), plus the `sys_flow_reap` syscall that eliminates zombies
  by the same route-or-release principle.
- `01-practical-exam.md` — the conserved-budget detector ported to SQLite/InnoDB.
- `04-human-advice-manual.md` — the conservation law read as advice for living (not a
  technical doc; the not-so-Trojan horse).

## Reproduce

Every engine is a standalone Python file with no dependencies and no clock:

```sh
for e in iso_deadlock iso_resolve iso_flow iso_conserve iso_distributed iso_cap \
         iso_safety iso_progress iso_flex iso_generator; do python3 "$e.py"; done
```

Audit the no-wall-clock invariant:

```sh
grep -niE "time|sleep|clock|timeout|perf_counter|monotonic" iso_*.py
# returns only prose in comments
```

## Handoff (for automated agents, in order of leverage)

1. **Lean proof of L1–L4** (`04-lean-task.md`). L1 (conservation preserved by each
   step) is the keystone; prove the share-sum lemma first to decouple it from the
   flow-equation details. Acceptance: `lake build` clean, no `sorry`, a `FINDINGS.md`.
2. **Kernel implementation** (`03-kernel-exam.md`). Flow-equation scheduler (sum, not
   max) + `sys_flow_reap`. The hard part is preserving EEVDF lag invariants — which is
   conservation (L1) in the kernel.
3. **The generator as a compiler** (paper 09 §7). Problem spec → architecture + a
   machine-checked proof that cites the formalized laws. "The laws that generate proofs."

## A note

This is one fractal layer. Finished, the scheduler becomes a single node in a larger
scheduler — a cluster, a network, a society — where the same conserved quantity flows
up and the same three invariants apply identically. The generator works at N+1 exactly
as at N. It is both done and never done: 9.999… = 10.

*Energy flows where attention goes; what flows is conserved; and a system — like a
life — is well-run exactly when it holds no claim it cannot convert, and routes what it
has to where the whole can use it.*
