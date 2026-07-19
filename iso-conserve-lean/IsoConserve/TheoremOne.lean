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
