import IsoConserve.RateRouting
import IsoConserve.ResolutionYield
import IsoConserve.PNCounter
import IsoConserve.Polarity

namespace IsoConserve
namespace TheoremOne

open CoreTrace

noncomputable section

local instance propDecidable (p : Prop) : Decidable p :=
  Classical.propDecidable p

structure Outcome (n m : Nat) where
  state : CoreState n m
  ownBenefit : ProcId n -> Qty
  wholeBenefit : Qty

inductive Action (n m : Nat) where
  | hoard : ProcId n -> Qty -> Action n m
  | route : ProcId n -> ProcId n -> Qty -> Action n m
  | release : ProcId n -> Qty -> Action n m

def HoldsClaim {n m : Nat} (s : CoreState n m) (i : ProcId n)
    (q : Qty) : Prop :=
  q <= (s.procs i).stock

def CanConvertQty {n m : Nat} (s : CoreState n m) (i : ProcId n)
    (q : Qty) : Prop :=
  0 < q /\ q <= (s.procs i).stock /\ runnable s i /\
    unfinished s i /\ s.convertCost <= q

def StrandedClaim {n m : Nat} (s : CoreState n m) (i : ProcId n)
    (q : Qty) : Prop :=
  0 < q /\ HoldsClaim s i q /\ ¬ CanConvertQty s i q

def DependencyReturn {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) : Prop :=
  blockedOn s i j

def DependsOnWhole {n m : Nat} (s : CoreState n m) (i : ProcId n) : Prop :=
  exists j, DependencyReturn s i j

def actionOwn {n m : Nat} (s : CoreState n m) (actor : ProcId n) :
    Action n m -> Qty
  | Action.hoard i q =>
      if actor = i /\ CanConvertQty s i q then q else 0
  | Action.route i j q =>
      if actor = i /\ CanConvertQty s j q /\ DependencyReturn s i j then q else 0
  | Action.release _i _q => 0

def actionWhole {n m : Nat} (s : CoreState n m) : Action n m -> Qty
  | Action.hoard i q => if CanConvertQty s i q then q else 0
  | Action.route _i j q => if CanConvertQty s j q then q else 0
  | Action.release _i _q => 0

def applyAction {n m : Nat} (s : CoreState n m) (a : Action n m) :
    Outcome n m :=
  { state := s
    ownBenefit := fun i => actionOwn s i a
    wholeBenefit := actionWhole s a }

def ownConversion {n m : Nat} (i : ProcId n) (o : Outcome n m) : Qty :=
  o.ownBenefit i

def wholeConversion {n m : Nat} (o : Outcome n m) : Qty :=
  o.wholeBenefit

theorem route_stranded_claim_strictly_dominates_hoard {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hq : 0 < q)
    (hstranded : StrandedClaim s i q)
    (hcan : CanConvertQty s j q)
    (hreturn : DependencyReturn s i j) :
    ownConversion i (applyAction s (Action.route i j q)) >
      ownConversion i (applyAction s (Action.hoard i q)) := by
  have hnotCan : ¬ CanConvertQty s i q := hstranded.2.2
  unfold ownConversion applyAction actionOwn
  simp [hcan, hreturn, hnotCan]
  exact hq

theorem release_weakly_dominates_hoard_for_stranded_claim {n m : Nat}
    {s : CoreState n m} {i : ProcId n} {q : Qty}
    (hstranded : StrandedClaim s i q) :
    ownConversion i (applyAction s (Action.release i q)) >=
      ownConversion i (applyAction s (Action.hoard i q)) := by
  have hnotCan : ¬ CanConvertQty s i q := hstranded.2.2
  unfold ownConversion applyAction actionOwn
  simp [hnotCan]

inductive ClaimChoice where
  | hoard
  | route
  | release
deriving DecidableEq, Repr

def actionForChoice {n m : Nat} (i j : ProcId n) (q : Qty) :
    ClaimChoice -> Action n m
  | ClaimChoice.hoard => Action.hoard i q
  | ClaimChoice.route => Action.route i j q
  | ClaimChoice.release => Action.release i q

def ownChoiceValue {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) (choice : ClaimChoice) : Qty :=
  ownConversion i (applyAction s (actionForChoice i j q choice))

def wholeChoiceValue {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) (choice : ClaimChoice) : Qty :=
  wholeConversion (applyAction s (actionForChoice i j q choice))

def SelfishBestInClaimSet {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) (choice : ClaimChoice) : Prop :=
  forall alt, ownChoiceValue s i j q choice >= ownChoiceValue s i j q alt

def GenerousBestInClaimSet {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) (choice : ClaimChoice) : Prop :=
  forall alt, wholeChoiceValue s i j q choice >= wholeChoiceValue s i j q alt

theorem route_selfish_optimal_in_claim_set {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hstranded : StrandedClaim s i q)
    (hcan : CanConvertQty s j q)
    (hreturn : DependencyReturn s i j) :
    SelfishBestInClaimSet s i j q ClaimChoice.route := by
  intro alt
  have hnotCan : ¬ CanConvertQty s i q := hstranded.2.2
  have hqpos : 0 < q := hstranded.1
  have hqnonneg : 0 <= q := by grind
  cases alt <;>
    simp [ownChoiceValue, actionForChoice, ownConversion, applyAction,
      actionOwn, hcan, hreturn, hnotCan, hqnonneg]

theorem route_generous_optimal_in_claim_set {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hstranded : StrandedClaim s i q)
    (hcan : CanConvertQty s j q) :
    GenerousBestInClaimSet s i j q ClaimChoice.route := by
  intro alt
  have hnot : ¬ CanConvertQty s i q := hstranded.2.2
  have hqpos : 0 < q := hstranded.1
  have hqnonneg : 0 <= q := by grind
  cases alt <;>
    simp [wholeChoiceValue, actionForChoice, wholeConversion, applyAction,
      actionWhole, hcan, hnot, hqnonneg]

theorem selfish_optimum_contains_no_stranded_claim {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hq : 0 < q)
    (hstranded : StrandedClaim s i q)
    (hcan : CanConvertQty s j q)
    (hreturn : DependencyReturn s i j) :
    ¬ SelfishBestInClaimSet s i j q ClaimChoice.hoard := by
  intro hbest
  have hnotCan : ¬ CanConvertQty s i q := hstranded.2.2
  have hroute := hbest ClaimChoice.route
  simp [ownChoiceValue, actionForChoice,
    ownConversion, applyAction, actionOwn, hcan, hreturn, hnotCan] at hroute
  have hnle : ¬ q <= 0 := by
    intro hle
    grind
  exact hnle hroute

theorem generous_optimum_contains_no_stranded_claim {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hq : 0 < q)
    (hstranded : StrandedClaim s i q)
    (hcan : CanConvertQty s j q) :
    ¬ GenerousBestInClaimSet s i j q ClaimChoice.hoard := by
  intro hbest
  have hnot : ¬ CanConvertQty s i q := hstranded.2.2
  have hroute := hbest ClaimChoice.route
  simp [wholeChoiceValue, actionForChoice,
    wholeConversion, applyAction, actionWhole, hcan, hnot] at hroute
  have hnle : ¬ q <= 0 := by
    intro hle
    grind
  exact hnle hroute

theorem selfish_optima_eq_generous_optima {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hstranded : StrandedClaim s i q)
    (hcan : CanConvertQty s j q)
    (hreturn : DependencyReturn s i j) :
    SelfishBestInClaimSet s i j q ClaimChoice.route /\
      GenerousBestInClaimSet s i j q ClaimChoice.route :=
  ⟨route_selfish_optimal_in_claim_set hstranded hcan hreturn,
    route_generous_optimal_in_claim_set hstranded hcan⟩

theorem hoarding_is_self_defeating {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hq : 0 < q)
    (hstranded : StrandedClaim s i q)
    (hcan : CanConvertQty s j q)
    (hreturn : DependencyReturn s i j) :
    ownConversion i (applyAction s (Action.route i j q)) >
      ownConversion i (applyAction s (Action.hoard i q)) :=
  route_stranded_claim_strictly_dominates_hoard hq hstranded hcan hreturn

structure Policy (n m : Nat) where
  act : CoreState n m -> Action n m

def applyPolicy {n m : Nat} (P : Policy n m) (s : CoreState n m) :
    Outcome n m :=
  applyAction s (P.act s)

def SelfishOptimal {n m : Nat} (P : Policy n m) (i : ProcId n)
    (s : CoreState n m) : Prop :=
  forall P', ownConversion i (applyPolicy P s) >=
    ownConversion i (applyPolicy P' s)

def GenerousOptimal {n m : Nat} (P : Policy n m)
    (s : CoreState n m) : Prop :=
  forall P', wholeConversion (applyPolicy P s) >=
    wholeConversion (applyPolicy P' s)

/-!
## Dynamical payoff surface

The definitions above are the reviewed local, installed-payoff kernel.  The
surface below is deliberately separate: actions produce certified core runs,
and their values are measured only from conversion counters in the initial and
final states.
-/

def DependencyPath {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) : Prop :=
  Relation.TransGen (blockedOn s) i j

def routeClaimDelta {n : Nat} (i j : ProcId n) (q : Qty)
    (p : ProcId n) : Qty :=
  if p = i then -q else if p = j then q else 0

def routeState {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) : CoreState n m :=
  { s with
    procs := fun p =>
      { s.procs p with stock := (s.procs p).stock + routeClaimDelta i j q p } }

theorem routeState_source_stock {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) :
    ((routeState s i j q).procs i).stock = (s.procs i).stock - q := by
  simp [routeState, routeClaimDelta]
  grind

theorem routeState_target_stock {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) (hne : i ≠ j) :
    ((routeState s i j q).procs j).stock = (s.procs j).stock + q := by
  simp [routeState, routeClaimDelta, Ne.symm hne]

def CanConvertAfterRoute {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) : Prop :=
  CanConvertQty (routeState s i j q) j q

/-- Executability data missing from the rational `CanConvertQty` predicate:
`q` is an exact positive number of conversion quanta, the endpoints differ,
and the beneficiary has room for all returned work. -/
structure ExactCanConvertAfterRoute {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) where
  units : Nat
  units_pos : 0 < units
  qty_eq : q = s.convertCost * (units : Qty)
  endpoints_distinct : i ≠ j
  beneficiary_unfinished : unfinished s i
  within_work :
    (s.procs i).convertedTotal + units <= (s.procs i).workNeeded
  can_convert : CanConvertAfterRoute s i j q

theorem blockedOn_routeState_iff {n m : Nat} (s : CoreState n m)
    (i j p r : ProcId n) (q : Qty) :
    blockedOn (routeState s i j q) p r <-> blockedOn s p r := by
  simp [blockedOn, routeState, routeClaimDelta]

theorem blocked_routeState_iff {n m : Nat} (s : CoreState n m)
    (i j p : ProcId n) (q : Qty) :
    blocked (routeState s i j q) p <-> blocked s p := by
  simp only [blocked]
  constructor <;> rintro ⟨r, hr⟩
  · exact ⟨r, (blockedOn_routeState_iff s i j p r q).1 hr⟩
  · exact ⟨r, (blockedOn_routeState_iff s i j p r q).2 hr⟩

theorem runnable_routeState_iff {n m : Nat} (s : CoreState n m)
    (i j p : ProcId n) (q : Qty) :
    runnable (routeState s i j q) p <-> runnable s p := by
  constructor
  · rintro ⟨hdone, hblocked⟩
    refine ⟨?_, ?_⟩
    · simpa [routeState, routeClaimDelta] using hdone
    · intro hb
      exact hblocked ((blocked_routeState_iff s i j p q).2 hb)
  · rintro ⟨hdone, hblocked⟩
    refine ⟨?_, ?_⟩
    · simpa [routeState, routeClaimDelta] using hdone
    · intro hb
      exact hblocked ((blocked_routeState_iff s i j p q).1 hb)

theorem unfinished_routeState_iff {n m : Nat} (s : CoreState n m)
    (i j p : ProcId n) (q : Qty) :
    unfinished (routeState s i j q) p <-> unfinished s p := by
  simp [unfinished, routeState, routeClaimDelta]

theorem dependencyPath_routeState_iff {n m : Nat} (s : CoreState n m)
    (i j a b : ProcId n) (q : Qty) :
    DependencyPath (routeState s i j q) a b <-> DependencyPath s a b := by
  constructor
  · intro h
    induction h with
    | single hstep =>
        exact Relation.TransGen.single
          ((blockedOn_routeState_iff s i j _ _ q).1 hstep)
    | tail hprefix hstep ih =>
        exact Relation.TransGen.tail ih
          ((blockedOn_routeState_iff s i j _ _ q).1 hstep)
  · intro h
    induction h with
    | single hstep =>
        exact Relation.TransGen.single
          ((blockedOn_routeState_iff s i j _ _ q).2 hstep)
    | tail hprefix hstep ih =>
        exact Relation.TransGen.tail ih
          ((blockedOn_routeState_iff s i j _ _ q).2 hstep)

def claimRoutePlan {n m : Nat} (s : WFState n m)
    (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    RoutePlan s.state := by
  have hqpos : 0 < q := hstranded.1
  have hq : 0 <= q := by grind
  have hheld : q <= (s.state.procs i).stock := by
    simpa [HoldsClaim] using hstranded.2.1
  have hjrunRoute : runnable (routeState s.state i j q) j :=
    hexact.can_convert.2.2.1
  have hjrun : runnable s.state j :=
    (runnable_routeState_iff s.state i j j q).1 hjrunRoute
  exact
  { delta := routeClaimDelta i j q
    sum_delta_zero := by
      calc
        sumFin (routeClaimDelta i j q) = -q + q := by
          exact RateRouting.sumFin_pair hexact.endpoints_distinct (-q) q
        _ = 0 := by grind
    stock_after_nonneg := by
      intro p
      by_cases hpi : p = i
      · subst p
        simp [routeClaimDelta]
        grind
      · by_cases hpj : p = j
        · subst p
          have hj := s.wf.stock_nonneg j
          simp [routeClaimDelta, Ne.symm hexact.endpoints_distinct]
          grind
        · have hp := s.wf.stock_nonneg p
          change 0 <= (s.state.procs p).stock + routeClaimDelta i j q p
          have hdelta : routeClaimDelta i j q p = 0 := by
            simp [routeClaimDelta, hpi, hpj]
          rw [hdelta]
          grind
    delta_blocked_nonpos := by
      intro p hpblocked
      by_cases hpi : p = i
      · subst p
        simp [routeClaimDelta]
        grind
      · by_cases hpj : p = j
        · subst p
          exact False.elim (hjrun.2 hpblocked)
        · simp [routeClaimDelta, hpi, hpj] }

def routedClaimWFState {n m : Nat} (s : WFState n m)
    (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hexact : ExactCanConvertAfterRoute s.state i j q) : WFState n m :=
  routeStepOfWF s (claimRoutePlan s i j q hstranded hexact)

theorem routedClaimWFState_state {n m : Nat} (s : WFState n m)
    (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    (routedClaimWFState s i j q hstranded hexact).state =
      routeState s.state i j q := by
  simp [routedClaimWFState, routeStepOfWF, claimRoutePlan,
    routeState, routeStep, routeProc]

theorem routed_claim_is_routeRel {n m : Nat} (s : WFState n m)
    (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    RouteRel s (routedClaimWFState s i j q hstranded hexact) := by
  exact routeStepOfWF_is_routeRel s
    (claimRoutePlan s i j q hstranded hexact)

def RealizedOwnConversion {n m : Nat} (i : ProcId n)
    (initial final : CoreState n m) : Qty :=
  initial.convertCost *
    (((final.procs i).convertedTotal : Qty) -
      ((initial.procs i).convertedTotal : Qty))

def RealizedWholeConversion {n m : Nat}
    (initial final : CoreState n m) : Qty :=
  initial.convertCost *
    (CoreTrace.totalConverted final - CoreTrace.totalConverted initial)

structure CertifiedOutcome {n m : Nat} (initial : WFState n m) where
  final : WFState n m
  reachable : RTC CoreRel initial final

def hoardCertifiedOutcome {n m : Nat} (s : WFState n m) :
    CertifiedOutcome s :=
  { final := s
    reachable := RTC.refl s }

theorem hoard_realizes_zero_conversion {n m : Nat} (s : WFState n m)
    (i : ProcId n) :
    RealizedOwnConversion i s.state (hoardCertifiedOutcome s).final.state = 0 /\
      RealizedWholeConversion s.state (hoardCertifiedOutcome s).final.state = 0 := by
  simp [hoardCertifiedOutcome, RealizedOwnConversion,
    RealizedWholeConversion, CoreTrace.totalConverted]
  grind

def releaseClaimAmount {n : Nat} (i : ProcId n) (q : Qty)
    (p : ProcId n) : Qty :=
  if p = i then q else 0

def releaseClaimPlan {n m : Nat} (s : WFState n m)
    (i : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q) :
    CoreTrace.DrainPlan s.state :=
  { amount := releaseClaimAmount i q
    amount_nonneg := by
      have hqpos : 0 < q := hstranded.1
      intro p
      by_cases hp : p = i
      · subst p
        simp [releaseClaimAmount]
        grind
      · simp [releaseClaimAmount, hp]
    stock_after_nonneg := by
      intro p
      by_cases hp : p = i
      · subst p
        have hheld : q <= (s.state.procs i).stock := by
          simpa [HoldsClaim] using hstranded.2.1
        simp [releaseClaimAmount]
        grind
      · have hstock := s.wf.stock_nonneg p
        change 0 <= (s.state.procs p).stock - releaseClaimAmount i q p
        have hzero : releaseClaimAmount i q p = 0 := by
          simp [releaseClaimAmount, hp]
        rw [hzero]
        grind }

def releaseCertifiedOutcome {n m : Nat} (s : WFState n m)
    (i : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q) : CertifiedOutcome s :=
  let final := drainStepOfWF s (releaseClaimPlan s i q hstranded)
  { final := final
    reachable := RTC.tail (RTC.refl s)
      (Or.inr (Or.inl (drainStepOfWF_is_drainRel s
        (releaseClaimPlan s i q hstranded)))) }

theorem release_realizes_zero_conversion {n m : Nat} (s : WFState n m)
    (i : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q) :
    RealizedOwnConversion i s.state
        (releaseCertifiedOutcome s i q hstranded).final.state = 0 /\
      RealizedWholeConversion s.state
        (releaseCertifiedOutcome s i q hstranded).final.state = 0 := by
  simp [releaseCertifiedOutcome, RealizedOwnConversion,
    RealizedWholeConversion, CoreTrace.drainStepOfWF, CoreTrace.drainStep,
    CoreTrace.drainProc, CoreTrace.totalConverted]
  grind

@[simp] theorem routeState_convertCost {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) :
    (routeState s i j q).convertCost = s.convertCost := by
  rfl

@[simp] theorem routeState_convertedTotal {n m : Nat} (s : CoreState n m)
    (i j p : ProcId n) (q : Qty) :
    ((routeState s i j q).procs p).convertedTotal =
      (s.procs p).convertedTotal := by
  simp [routeState, routeClaimDelta]

theorem totalConverted_routeState {n m : Nat} (s : CoreState n m)
    (i j : ProcId n) (q : Qty) :
    CoreTrace.totalConverted (routeState s i j q) =
      CoreTrace.totalConverted s := by
  unfold CoreTrace.totalConverted
  apply sumFin_congr
  intro p
  simp

def conversionReturnPlanAfterRoute {n m : Nat} (s : WFState n m)
    (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    ConversionReturnPlan
      (routedClaimWFState s i j q hstranded hexact).state := by
  let routed := routedClaimWFState s i j q hstranded hexact
  have hrouted : routed.state = routeState s.state i j q :=
    routedClaimWFState_state s i j q hstranded hexact
  have hpost := hexact.can_convert
  exact
  { beneficiary := i
    converter := j
    units := hexact.units
    endpoints_distinct := hexact.endpoints_distinct
    dependency_path := by
      rw [hrouted]
      exact (dependencyPath_routeState_iff s.state i j i j q).2 hpath
    beneficiary_unfinished := by
      rw [hrouted]
      exact (unfinished_routeState_iff s.state i j i q).2
        hexact.beneficiary_unfinished
    converter_runnable := by
      rw [hrouted]
      exact hpost.2.2.1
    converter_unfinished := by
      rw [hrouted]
      exact hpost.2.2.2.1
    units_pos := hexact.units_pos
    within_work := by
      rw [hrouted]
      simpa [routeState, routeClaimDelta] using hexact.within_work
    converter_stock_after_nonneg := by
      rw [hrouted]
      have hstock : q <= ((routeState s.state i j q).procs j).stock :=
        hpost.2.1
      have hspent :
          (routeState s.state i j q).convertCost * (hexact.units : Qty) = q := by
        simp [hexact.qty_eq]
      rw [hspent]
      grind }

def routeConvertedWFState {n m : Nat} (s : WFState n m)
    (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) : WFState n m :=
  let routed := routedClaimWFState s i j q hstranded hexact
  conversionReturnStepOfWF routed
    (conversionReturnPlanAfterRoute s i j q hstranded hpath hexact)

theorem routed_claim_is_core_step {n m : Nat} (s : WFState n m)
    (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    CoreRel s (routedClaimWFState s i j q hstranded hexact) := by
  right; right; right; left
  exact routed_claim_is_routeRel s i j q hstranded hexact

theorem route_conversion_return_is_core_step {n m : Nat}
    (s : WFState n m) (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    CoreRel (routedClaimWFState s i j q hstranded hexact)
      (routeConvertedWFState s i j q hstranded hpath hexact) := by
  right; right; right; right; right
  exact conversionReturnStepOfWF_is_conversionReturnRel
    (routedClaimWFState s i j q hstranded hexact)
    (conversionReturnPlanAfterRoute s i j q hstranded hpath hexact)

theorem routeConvertedWFState_beneficiary_total {n m : Nat}
    (s : WFState n m) (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    ((routeConvertedWFState s i j q hstranded hpath hexact).state.procs i).convertedTotal =
      ((routedClaimWFState s i j q hstranded hexact).state.procs i).convertedTotal +
        hexact.units := by
  exact conversionReturnStep_beneficiary_convertedTotal
    (routedClaimWFState s i j q hstranded hexact).state
    (conversionReturnPlanAfterRoute s i j q hstranded hpath hexact)

theorem routeConvertedWFState_totalConverted {n m : Nat}
    (s : WFState n m) (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    CoreTrace.totalConverted
        (routeConvertedWFState s i j q hstranded hpath hexact).state =
      CoreTrace.totalConverted
          (routedClaimWFState s i j q hstranded hexact).state +
        (hexact.units : Qty) := by
  exact conversionReturnStep_totalConverted
    (routedClaimWFState s i j q hstranded hexact).state
    (conversionReturnPlanAfterRoute s i j q hstranded hpath hexact)

theorem route_realizes_conversion {n m : Nat} (s : WFState n m)
    (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    exists t,
      RTC CoreRel (routedClaimWFState s i j q hstranded hexact) t /\
        RealizedWholeConversion
            (routedClaimWFState s i j q hstranded hexact).state t.state = q /\
        RealizedOwnConversion i
            (routedClaimWFState s i j q hstranded hexact).state t.state = q := by
  let routed := routedClaimWFState s i j q hstranded hexact
  let final := routeConvertedWFState s i j q hstranded hpath hexact
  refine ⟨final, RTC.tail (RTC.refl routed) ?_, ?_, ?_⟩
  · exact route_conversion_return_is_core_step
      s i j q hstranded hpath hexact
  · unfold RealizedWholeConversion
    rw [routeConvertedWFState_totalConverted
      s i j q hstranded hpath hexact]
    have hcost : routed.state.convertCost = s.state.convertCost := by
      simp [routed, routedClaimWFState, routeStepOfWF, routeStep]
    rw [hcost]
    have hqty := hexact.qty_eq
    grind
  · unfold RealizedOwnConversion
    rw [routeConvertedWFState_beneficiary_total
      s i j q hstranded hpath hexact]
    have hcost : routed.state.convertCost = s.state.convertCost := by
      simp [routed, routedClaimWFState, routeStepOfWF, routeStep]
    rw [hcost]
    have hqty := hexact.qty_eq
    grind

def routeCertifiedOutcome {n m : Nat} (s : WFState n m)
    (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    CertifiedOutcome s :=
  { final := routeConvertedWFState s i j q hstranded hpath hexact
    reachable := RTC.tail
      (RTC.tail (RTC.refl s)
        (routed_claim_is_core_step s i j q hstranded hexact))
      (route_conversion_return_is_core_step
        s i j q hstranded hpath hexact) }

theorem route_certified_outcome_realizes_conversion {n m : Nat}
    (s : WFState n m) (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    RealizedWholeConversion s.state
        (routeCertifiedOutcome s i j q hstranded hpath hexact).final.state = q /\
      RealizedOwnConversion i s.state
        (routeCertifiedOutcome s i j q hstranded hpath hexact).final.state = q := by
  constructor
  · unfold routeCertifiedOutcome RealizedWholeConversion
    rw [routeConvertedWFState_totalConverted
      s i j q hstranded hpath hexact]
    rw [routedClaimWFState_state, totalConverted_routeState]
    have hqty := hexact.qty_eq
    grind
  · unfold routeCertifiedOutcome RealizedOwnConversion
    rw [routeConvertedWFState_beneficiary_total
      s i j q hstranded hpath hexact]
    rw [routedClaimWFState_state]
    simp only [routeState_convertedTotal]
    have hqty := hexact.qty_eq
    grind

theorem realized_route_strictly_dominates_hoard {n m : Nat}
    (s : WFState n m) (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    RealizedOwnConversion i s.state
        (routeCertifiedOutcome s i j q hstranded hpath hexact).final.state >
      RealizedOwnConversion i s.state (hoardCertifiedOutcome s).final.state := by
  rw [(route_certified_outcome_realizes_conversion
    s i j q hstranded hpath hexact).2]
  rw [(hoard_realizes_zero_conversion s i).1]
  exact hstranded.1

theorem route_strictly_dominates_hoard {n m : Nat}
    (s : WFState n m) (i j : ProcId n) (q : Qty)
    (hstranded : StrandedClaim s.state i q)
    (hpath : DependencyPath s.state i j)
    (hexact : ExactCanConvertAfterRoute s.state i j q) :
    RealizedOwnConversion i s.state
        (routeCertifiedOutcome s i j q hstranded hpath hexact).final.state >
      RealizedOwnConversion i s.state (hoardCertifiedOutcome s).final.state :=
  realized_route_strictly_dominates_hoard
    s i j q hstranded hpath hexact

/-- The named finite fallback: exactly the designated hoard, route-and-return,
and release executions for one certified stranded claim. -/
inductive FiniteCertifiedClaimPolicy where
  | hoard
  | route
  | release
deriving DecidableEq, Repr

structure FiniteCertifiedClaimContext (n m : Nat) where
  initial : WFState n m
  beneficiary : ProcId n
  converter : ProcId n
  qty : Qty
  stranded : StrandedClaim initial.state beneficiary qty
  path : DependencyPath initial.state beneficiary converter
  executable : ExactCanConvertAfterRoute initial.state beneficiary converter qty

def runFiniteCertifiedClaimPolicy {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    FiniteCertifiedClaimPolicy -> CertifiedOutcome ctx.initial
  | FiniteCertifiedClaimPolicy.hoard => hoardCertifiedOutcome ctx.initial
  | FiniteCertifiedClaimPolicy.route =>
      routeCertifiedOutcome ctx.initial ctx.beneficiary ctx.converter ctx.qty
        ctx.stranded ctx.path ctx.executable
  | FiniteCertifiedClaimPolicy.release =>
      releaseCertifiedOutcome ctx.initial ctx.beneficiary ctx.qty ctx.stranded

def finiteCertifiedClaimPolicyOwnValue {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m)
    (choice : FiniteCertifiedClaimPolicy) : Qty :=
  RealizedOwnConversion ctx.beneficiary ctx.initial.state
    (runFiniteCertifiedClaimPolicy ctx choice).final.state

def finiteCertifiedClaimPolicyWholeValue {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m)
    (choice : FiniteCertifiedClaimPolicy) : Qty :=
  RealizedWholeConversion ctx.initial.state
    (runFiniteCertifiedClaimPolicy ctx choice).final.state

theorem finite_certified_claim_policy_hoard_own_value {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    finiteCertifiedClaimPolicyOwnValue ctx
      FiniteCertifiedClaimPolicy.hoard = 0 := by
  exact (hoard_realizes_zero_conversion ctx.initial ctx.beneficiary).1

theorem finite_certified_claim_policy_hoard_whole_value {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    finiteCertifiedClaimPolicyWholeValue ctx
      FiniteCertifiedClaimPolicy.hoard = 0 := by
  exact (hoard_realizes_zero_conversion ctx.initial ctx.beneficiary).2

theorem finite_certified_claim_policy_route_own_value {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    finiteCertifiedClaimPolicyOwnValue ctx
      FiniteCertifiedClaimPolicy.route = ctx.qty := by
  exact (route_certified_outcome_realizes_conversion
    ctx.initial ctx.beneficiary ctx.converter ctx.qty
    ctx.stranded ctx.path ctx.executable).2

theorem finite_certified_claim_policy_route_whole_value {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    finiteCertifiedClaimPolicyWholeValue ctx
      FiniteCertifiedClaimPolicy.route = ctx.qty := by
  exact (route_certified_outcome_realizes_conversion
    ctx.initial ctx.beneficiary ctx.converter ctx.qty
    ctx.stranded ctx.path ctx.executable).1

theorem finite_certified_claim_policy_release_own_value {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    finiteCertifiedClaimPolicyOwnValue ctx
      FiniteCertifiedClaimPolicy.release = 0 := by
  exact (release_realizes_zero_conversion
    ctx.initial ctx.beneficiary ctx.qty ctx.stranded).1

theorem finite_certified_claim_policy_release_whole_value {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    finiteCertifiedClaimPolicyWholeValue ctx
      FiniteCertifiedClaimPolicy.release = 0 := by
  exact (release_realizes_zero_conversion
    ctx.initial ctx.beneficiary ctx.qty ctx.stranded).2

theorem finite_certified_claim_policy_own_eq_whole {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m)
    (choice : FiniteCertifiedClaimPolicy) :
    finiteCertifiedClaimPolicyOwnValue ctx choice =
      finiteCertifiedClaimPolicyWholeValue ctx choice := by
  cases choice with
  | hoard =>
      rw [finite_certified_claim_policy_hoard_own_value,
        finite_certified_claim_policy_hoard_whole_value]
  | route =>
      rw [finite_certified_claim_policy_route_own_value,
        finite_certified_claim_policy_route_whole_value]
  | release =>
      rw [finite_certified_claim_policy_release_own_value,
        finite_certified_claim_policy_release_whole_value]

def SelfishOptimalInFiniteCertifiedClaimPolicies {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m)
    (choice : FiniteCertifiedClaimPolicy) : Prop :=
  forall alternative,
    finiteCertifiedClaimPolicyOwnValue ctx choice >=
      finiteCertifiedClaimPolicyOwnValue ctx alternative

def GenerousOptimalInFiniteCertifiedClaimPolicies {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m)
    (choice : FiniteCertifiedClaimPolicy) : Prop :=
  forall alternative,
    finiteCertifiedClaimPolicyWholeValue ctx choice >=
      finiteCertifiedClaimPolicyWholeValue ctx alternative

theorem finite_certified_claim_policy_route_selfish_optimal {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    SelfishOptimalInFiniteCertifiedClaimPolicies ctx
      FiniteCertifiedClaimPolicy.route := by
  intro alternative
  cases alternative with
  | hoard =>
      rw [finite_certified_claim_policy_route_own_value,
        finite_certified_claim_policy_hoard_own_value]
      have hq := ctx.stranded.1
      grind
  | route => grind
  | release =>
      rw [finite_certified_claim_policy_route_own_value,
        finite_certified_claim_policy_release_own_value]
      have hq := ctx.stranded.1
      grind

theorem finite_certified_claim_policy_route_generous_optimal {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    GenerousOptimalInFiniteCertifiedClaimPolicies ctx
      FiniteCertifiedClaimPolicy.route := by
  intro alternative
  cases alternative with
  | hoard =>
      rw [finite_certified_claim_policy_route_whole_value,
        finite_certified_claim_policy_hoard_whole_value]
      have hq := ctx.stranded.1
      grind
  | route => grind
  | release =>
      rw [finite_certified_claim_policy_route_whole_value,
        finite_certified_claim_policy_release_whole_value]
      have hq := ctx.stranded.1
      grind

theorem finite_certified_claim_policy_hoard_not_selfish_optimal {n m : Nat}
    (ctx : FiniteCertifiedClaimContext n m) :
    ¬ (SelfishOptimalInFiniteCertifiedClaimPolicies ctx
      FiniteCertifiedClaimPolicy.hoard) := by
  intro hbest
  have hroute := hbest FiniteCertifiedClaimPolicy.route
  rw [finite_certified_claim_policy_hoard_own_value,
    finite_certified_claim_policy_route_own_value] at hroute
  have hq := ctx.stranded.1
  grind

theorem finite_certified_claim_policy_selfish_optima_eq_generous_optima
    {n m : Nat} (ctx : FiniteCertifiedClaimContext n m)
    (choice : FiniteCertifiedClaimPolicy) :
    SelfishOptimalInFiniteCertifiedClaimPolicies ctx choice <->
      GenerousOptimalInFiniteCertifiedClaimPolicies ctx choice := by
  constructor
  · intro hself alternative
    rw [← finite_certified_claim_policy_own_eq_whole ctx choice,
      ← finite_certified_claim_policy_own_eq_whole ctx alternative]
    exact hself alternative
  · intro hgenerous alternative
    rw [finite_certified_claim_policy_own_eq_whole ctx choice,
      finite_certified_claim_policy_own_eq_whole ctx alternative]
    exact hgenerous alternative

theorem selfish_optimum_contains_no_stranded_claim_in_finite_certified_policies
    {n m : Nat} (ctx : FiniteCertifiedClaimContext n m) :
    ¬ (SelfishOptimalInFiniteCertifiedClaimPolicies ctx
      FiniteCertifiedClaimPolicy.hoard) :=
  finite_certified_claim_policy_hoard_not_selfish_optimal ctx

theorem selfish_optima_eq_generous_optima_in_finite_certified_policies
    {n m : Nat} (ctx : FiniteCertifiedClaimContext n m)
    (choice : FiniteCertifiedClaimPolicy) :
    SelfishOptimalInFiniteCertifiedClaimPolicies ctx choice ↔
      GenerousOptimalInFiniteCertifiedClaimPolicies ctx choice :=
  finite_certified_claim_policy_selfish_optima_eq_generous_optima ctx choice

structure DebtLedger (n : Nat) where
  asset : ProcId n -> Qty
  debt : ProcId n -> ProcId n -> Qty

def netAgainst {n : Nat} (d : DebtLedger n)
    (debtor creditor : ProcId n) : Qty :=
  d.asset debtor - d.debt debtor creditor

def totalDebtIssued {n : Nat} (d : DebtLedger n) : Qty :=
  sumFin (fun debtor => sumFin (fun creditor => d.debt debtor creditor))

def totalDebtHeld {n : Nat} (d : DebtLedger n) : Qty :=
  sumFin (fun creditor => sumFin (fun debtor => d.debt debtor creditor))

def globalNetDebt {n : Nat} (d : DebtLedger n) : Qty :=
  totalDebtIssued d - totalDebtHeld d

def budgetTransfer {n : Nat} (d : DebtLedger n)
    (debtor creditor : ProcId n) (q : Qty) : DebtLedger n :=
  { asset := fun p =>
      if p = debtor then d.asset p + q
      else if p = creditor then d.asset p - q
      else d.asset p
    debt := fun p r =>
      if p = debtor /\ r = creditor then d.debt p r + q else d.debt p r }

theorem budget_transfer_creates_equal_debit {n : Nat}
    (d : DebtLedger n) (debtor creditor : ProcId n) (q : Qty) :
    (budgetTransfer d debtor creditor q).asset debtor = d.asset debtor + q /\
      (budgetTransfer d debtor creditor q).debt debtor creditor =
        d.debt debtor creditor + q := by
  simp [budgetTransfer]

theorem global_debt_sums_to_zero {n : Nat} (d : DebtLedger n) :
    globalNetDebt d = 0 := by
  unfold globalNetDebt totalDebtIssued totalDebtHeld
  rw [RateRouting.sumFin_swap]
  grind

theorem stolen_budget_is_not_net_progress {n : Nat}
    (d : DebtLedger n) (debtor creditor : ProcId n) (q : Qty) :
    netAgainst (budgetTransfer d debtor creditor q) debtor creditor =
      netAgainst d debtor creditor := by
  unfold netAgainst budgetTransfer
  simp
  grind

def returnedDebt {n m : Nat} (s : CoreState n m) (d : DebtLedger n)
    (debtor creditor : ProcId n) : Qty :=
  if DependencyReturn s debtor creditor then d.debt debtor creditor else 0

theorem dependency_makes_debt_return_to_debtor {n m : Nat}
    {s : CoreState n m} (d : DebtLedger n)
    {debtor creditor : ProcId n}
    (hreturn : DependencyReturn s debtor creditor) :
    returnedDebt s d debtor creditor = d.debt debtor creditor := by
  simp [returnedDebt, hreturn]

theorem taking_work_increases_shared_conversion {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hcan : CanConvertQty s j q) :
    wholeConversion (applyAction s (Action.route i j q)) = q := by
  simp [wholeConversion, applyAction, actionWhole, hcan]

theorem taking_work_reduces_other_burden {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hq : 0 < q)
    (hcan : CanConvertQty s j q)
    (hreturn : DependencyReturn s i j) :
    ownConversion i (applyAction s (Action.route i j q)) >
      ownConversion i (applyAction s (Action.release i q)) := by
  unfold ownConversion applyAction actionOwn
  simp [hcan, hreturn]
  exact hq

theorem taking_work_is_generous {n m : Nat}
    {s : CoreState n m} {i j : ProcId n} {q : Qty}
    (hstranded : StrandedClaim s i q)
    (hcan : CanConvertQty s j q) :
    GenerousBestInClaimSet s i j q ClaimChoice.route :=
  route_generous_optimal_in_claim_set hstranded hcan

end
end TheoremOne
end IsoConserve
