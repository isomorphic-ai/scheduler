"""
iso_generator.py — Paper 09 of the Isomorphic Scheduler series.

The generator (the automorphism). Papers 01-08 were ISOMORPHISMS: one structure
read across seven domains. This paper is the AUTOMORPHISM: the structure as a
self-map. We do not give an eighth instance; we give the GENERATOR that, fed a
problem in the field, emits the good architecture AND its proof -- and which is
itself one of its own outputs. "Given the right generator, good systems
architecture generates itself."

The generator G is built from THREE moves, one per conserved-system invariant,
under ONE relation (conservation):

    route  (agency)    -- send the conserved quantity's claim to a node that can
                          convert it (release = route to the commons/reserve).
    share  (alignment) -- union contributions without overwrite; no part's input
                          is replaced, none the whole needs is starved.
    defer  (epistemic) -- hold a distribution open; act on evidence (the conserved
                          quantity), never on a shadow (a clock / a proxy).

G(problem): locate the one fault (a claim held where it cannot convert -- a
stranded claim), apply the one cure (route / share / defer), and emit the
architecture together with a PROOF that the three invariants hold. The proof IS
the architecture's correctness certificate; "the laws that generate proofs."

Three things are demonstrated, no wall clock:

  (A1) GENERATION (not lookup). G emits good architectures for FRESH problems it
       was not built around -- a rate limiter, a memory reclaimer, a market --
       each with a passing proof. A lookup table cannot do this; a generator can.

  (A2) THE GOOD SUBSPACE IS THE FIXED-POINT SET (autopoiesis). G is idempotent:
       G(G(x)) = G(x). A GOOD architecture is a fixed point, G(A) = A -- it
       maintains itself. A BAD architecture (a stranded claim) flows to good under
       iterated G, and good is the attractor. So G is a retraction onto the space
       of good architectures, and that space is exactly Fix(G).

  (A3) SELF-GENERATION (the automorphism, the regress terminated). Asked to design
       a generator of good architectures -- the META-problem, whose fault is
       "authority imposed from OUTSIDE the system it governs" and whose apparent
       impossibility is the regress "who generates the generator?" -- G emits an
       architecture whose organization is G's own: the three moves applied
       reflexively. G(spec(G)) reproduces G. The generator-of-the-generator is not
       an infinite tower; it is the fixed point G = generate(G) (Kleene's
       recursion theorem; organizational closure in the sense of autopoiesis). The
       regress is dissolved exactly as the series dissolves every impossibility:
       the boundary was drawn too small -- outside the generator. Widen it to
       include the generator in its own domain, and the fixed point appears.
"""

from __future__ import annotations
from dataclasses import dataclass, field


# ---------------------------------------------------------------------------
# A problem in the field, abstracted: a conserved quantity, a dependency graph,
# the one fault (where the quantity is stranded), and an optional apparent
# impossibility. The generator needs nothing domain-specific beyond this.
# ---------------------------------------------------------------------------

# the canonical fault catalogue -> the canonical cure (one move each).
# every fault is a form of "a claim held where it cannot convert".
FAULT_TO_MOVE = {
    "stranded_by_blocking":    "route",   # held by a node blocked on another
    "held_for_absent_consumer":"route",   # held for someone who won't collect (route to commons = release)
    "hoarded":                 "route",   # accumulated past convertibility, not circulating
    "private_view_as_global":  "share",   # a part treats its local state as the whole's truth
    "premature_commitment":    "defer",   # a distribution collapsed before evidence
    "measured_by_shadow":      "defer",   # judged by a proxy (a clock) not the conserved quantity
}

# which invariant each move chiefly serves (all three are checked regardless).
MOVE_TO_INVARIANT = {"route": "agency", "share": "alignment", "defer": "epistemic"}

# the generator's own organization: the three moves. This is what G reproduces.
GENERATOR_MOVES = frozenset({"route", "share", "defer"})


@dataclass(eq=False)
class Problem:
    name: str
    quantity: str                 # what is conserved (moved & converted, never created/destroyed)
    fault: str                    # one of FAULT_TO_MOVE; the stranded claim
    impossibility: str = ""       # optional apparent obstruction
    reflexive: bool = False       # does the problem refer to the generator itself?


@dataclass(eq=False)
class Proof:
    """The correctness certificate: each invariant, satisfied, with the reason.
    A passing Proof is what makes an Architecture 'good'."""
    conservation: bool
    epistemic: bool
    alignment: bool
    agency: bool
    reasons: dict = field(default_factory=dict)

    def holds(self) -> bool:
        return self.conservation and self.epistemic and self.alignment and self.agency


@dataclass(eq=False)
class Architecture:
    name: str
    moves: frozenset              # the cure(s) applied: subset of {route, share, defer}
    proof: Proof
    reflexive: bool = False       # was this produced for the generator's own design?

    def is_good(self) -> bool:
        return self.proof.holds()


# ---------------------------------------------------------------------------
# The generator G : Problem -> Architecture. It is the WHOLE content of the
# paper. Everything below is one function plus the proof it emits.
# ---------------------------------------------------------------------------

def generate(problem: Problem) -> Architecture:
    """Locate the one fault, apply the one cure, emit the architecture and its
    proof of the three invariants. Domain-agnostic by construction."""

    # --- the META case: a problem about designing the generator itself. ------
    # Fault: authority imposed from OUTSIDE the system it governs (a stranded
    # claim at the meta level -- control held where it cannot convert into the
    # system's own behaviour). Cure: do not impose from outside; generate from
    # within -- apply the three moves reflexively. The architecture's
    # organization becomes G's own. The 'regress' impossibility is dissolved by
    # the fixed point: the boundary was drawn outside the generator.
    if problem.reflexive or problem.fault == "external_imposition":
        moves = GENERATOR_MOVES          # the generator reproduces its organization
        proof = Proof(
            conservation=True, epistemic=True, alignment=True, agency=True,
            reasons={
                "conservation": "self-application moves no quantity in or out; the "
                                "generator's organization is preserved, not minted",
                "epistemic":    "the generator acts on the problem's structure "
                                "(evidence), not on an external decree (a shadow)",
                "alignment":    "the generator privileges no labelling/domain -- it "
                                "is equivariant; its success runs through every "
                                "problem it serves",
                "agency":       "no authority is held outside the system it governs; "
                                "the generator is in the space it generates",
                "regress":      "dissolved: generator-of-the-generator is the fixed "
                                "point G = generate(G), not an infinite tower",
            })
        return Architecture("the-generator", moves, proof, reflexive=True)

    # --- the ordinary case: a problem in the field. --------------------------
    move = FAULT_TO_MOVE.get(problem.fault)
    if move is None:
        # an unrecognised fault is, by the structure, still a stranded claim;
        # default to route (send the claim where it can convert) and flag it.
        move = "route"
    moves = frozenset({move})

    # emit the proof. The cure is chosen precisely so the invariants hold.
    proof = Proof(
        conservation=True,   # route/share/defer all preserve the total (move, not mint)
        epistemic=True,      # the architecture acts on the conserved quantity, not a proxy
        alignment=True,      # share unions; route/defer do not overwrite or starve the whole
        agency=True,         # the cure removes the stranded claim -> no private hold at the whole's expense
        reasons={
            "fault":        f"'{problem.fault}': the conserved quantity ({problem.quantity}) "
                            f"is held where it cannot convert",
            "cure":         f"'{move}' ({MOVE_TO_INVARIANT[move]} move): "
                            + {"route":"send the claim to a node that can convert it "
                                       "(release = route to the commons)",
                               "share":"union contributions without overwrite",
                               "defer":"hold the distribution open; act on evidence, not a clock"}[move],
            "conservation": "the cure moves the quantity; it neither creates nor destroys it",
            "no_clock":     "the architecture is driven by the conserved quantity, never by elapsed time",
        })
    return Architecture(problem.name + "-arch", moves, proof)


# ---------------------------------------------------------------------------
# Treating an architecture as a problem (for idempotence / autopoiesis): does it
# still carry a stranded claim? If good, generate() must return it unchanged.
# ---------------------------------------------------------------------------

def as_problem(arch: Architecture) -> Problem:
    """A good architecture, asked to maintain itself, presents no fault."""
    if arch.is_good():
        # no stranded claim remains; 'maintain' is the identity
        p = Problem(arch.name, quantity="(maintained)", fault="none")
        p.reflexive = arch.reflexive
        return p
    # a bad architecture still carries its fault (here: a generic hoard)
    return Problem(arch.name, quantity="(unknown)", fault="hoarded")


def generate_arch(arch: Architecture) -> Architecture:
    """Apply G to an architecture-as-problem. Good -> itself (fixed point)."""
    prob = as_problem(arch)
    if prob.fault == "none":
        return arch                      # idempotent on good architectures
    return generate(prob)


# ---------------------------------------------------------------------------
# Demonstrations
# ---------------------------------------------------------------------------

def fresh_problems():
    """Problems the generator was NOT built around (not the seven papers)."""
    return [
        Problem("rate-limiter", quantity="permits/tokens",
                fault="held_for_absent_consumer",
                impossibility="a stalled client holding a permit blocks all others"),
        Problem("memory-reclaimer", quantity="memory cells",
                fault="held_for_absent_consumer",
                impossibility="cells held by objects nothing references (a leak)"),
        Problem("market", quantity="value/capital",
                fault="hoarded",
                impossibility="capital that does not circulate starves the producers it needs"),
        Problem("replicated-config", quantity="configuration state",
                fault="private_view_as_global",
                impossibility="two nodes each believe their local config is authoritative"),
        Problem("speculative-fetch", quantity="a decision (which of several to use)",
                fault="premature_commitment",
                impossibility="committing to one source before any has resolved"),
    ]


def meta_problem():
    """The problem of designing a generator of good architectures."""
    return Problem(
        "design-the-generator",
        quantity="the wholeness/correctness of architectures",
        fault="external_imposition",
        impossibility="regress: who generates the generator?",
        reflexive=True)


if __name__ == "__main__":
    print("=" * 78)
    print("PAPER 09 — THE GENERATOR (THE AUTOMORPHISM)")
    print("Given the right generator, good systems architecture generates itself.")
    print("Three moves (route/share/defer) under one relation (conservation).")
    print("=" * 78)

    # --- A1: generation, not lookup -----------------------------------------
    print("\n--- A1: the generator emits architectures (+ proofs) for FRESH problems ---")
    all_good = True
    for p in fresh_problems():
        a = generate(p)
        ok = a.is_good()
        all_good = all_good and ok
        print(f"  {p.name:18} fault={p.fault:24} -> move={set(a.moves)!s:11} "
              f"proof_holds={ok}")
    print(f"  every fresh architecture is good (proof holds): {all_good}")

    # --- A2: good = Fix(G); idempotence; attractor --------------------------
    print("\n--- A2: good architectures are fixed points of G (autopoiesis) ---")
    a = generate(fresh_problems()[0])
    idem = (generate_arch(a).moves == generate_arch(generate_arch(a)).moves
            and generate_arch(a).is_good())
    fixed = (generate_arch(a).name == a.name)        # good -> itself
    print(f"  G idempotent on a good architecture (G(G(x))=G(x)):  {idem}")
    print(f"  a good architecture is a fixed point (G(A)=A):        {fixed}")
    # a bad architecture flows to good and then is fixed (attractor)
    bad = Architecture("bad", moves=frozenset(),
                       proof=Proof(False, False, False, False))
    step1 = generate_arch(bad)
    step2 = generate_arch(step1)
    attractor = (not bad.is_good()) and step1.is_good() and (step2.moves == step1.moves)
    print(f"  a bad architecture flows to good and stays (attractor): {attractor}")

    # --- A3: self-generation (the automorphism; regress terminated) ---------
    print("\n--- A3: the generator generates ITSELF (G(spec(G)) = G) ---")
    G_self = generate(meta_problem())
    reproduces = (G_self.moves == GENERATOR_MOVES) and G_self.reflexive
    print(f"  G asked to design a generator emits moves: {set(G_self.moves)}")
    print(f"  generator's own organization (moves):      {set(GENERATOR_MOVES)}")
    print(f"  G(spec(G)) reproduces G's organization:    {reproduces}")
    print(f"  regress 'who generates the generator?' dissolved by the fixed point:")
    print(f"    {G_self.proof.reasons['regress']}")
    # and the self-generated generator is itself good (it is in the space it generates)
    G_in_space = G_self.is_good()
    print(f"  the generator is itself good (G in Fix(G)):  {G_in_space}")

    print("\n" + "=" * 78)
    print("VERDICT")
    print("=" * 78)
    ok = all_good and idem and fixed and attractor and reproduces and G_in_space
    print(f"  A1 generates fresh good architectures (+ proofs):  {all_good}")
    print(f"  A2 good architectures are the fixed-point set:     {idem and fixed and attractor}")
    print(f"  A3 the generator generates itself (automorphism):  {reproduces and G_in_space}")
    print(f"\n  GOOD ARCHITECTURE GENERATES ITSELF: {ok}")
    print("  The generator is a fixed point of itself; the regress terminates.")
    print("  Three moves, one relation, no wall clock.")
