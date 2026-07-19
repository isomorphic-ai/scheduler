import IsoConserve.DetectorProgress

namespace IsoConserve
namespace ResolutionYield

open CoreTrace

noncomputable section

local instance propDecidable (p : Prop) : Decidable p :=
  Classical.propDecidable p

def creditUnits {n m : Nat} (s : CoreState n m) (p : ProcId n) : Nat :=
  (s.procs p).convertedSinceRestart

def bankedValue {n m : Nat} (s : CoreState n m) (p : ProcId n) : Qty :=
  s.convertCost * (creditUnits s p : Qty)

def resolutionProc {n m : Nat} (s : CoreState n m)
    (y p : ProcId n) : CoreProc m :=
  if p = y then
    let old := s.procs p
    let units := old.convertedSinceRestart
    { old with
      credit := old.credit + s.convertCost * (units : Qty)
      convertedSinceRestart := 0
      pc := 0
      wants := none
      budget := old.budgetCap + units
      budgetCap := old.budgetCap + units
      done := false }
  else
    s.procs p

def resolutionYield {n m : Nat} (s : CoreState n m)
    (y : ProcId n) : CoreState n m :=
  { s with
    procs := fun p => resolutionProc s y p
    holds := fun p l => if p = y then false else s.holds p l }

theorem resolutionProc_accounted {n m : Nat}
    (s : CoreState n m) (y p : ProcId n) :
    CoreTrace.procAccounted s.convertCost (resolutionProc s y p) =
      CoreTrace.procAccounted s.convertCost (s.procs p) := by
  unfold CoreTrace.procAccounted resolutionProc
  by_cases hp : p = y
  · simp [hp]
    grind
  · simp [hp]

theorem resolution_yield_conserves {n m : Nat}
    (s : CoreState n m) (y : ProcId n) :
    CoreTrace.accounted (resolutionYield s y) = CoreTrace.accounted s := by
  unfold CoreTrace.accounted resolutionYield
  apply congrArg (fun x => s.reserve + x)
  apply sumFin_congr
  intro p
  exact resolutionProc_accounted s y p

theorem resolution_yield_preserves_coreWF {n m : Nat}
    (s : CoreState n m) (y : ProcId n) (hwf : CoreWF s) :
    CoreWF (resolutionYield s y) := by
  constructor
  · exact hwf.cost_pos
  · exact hwf.reserve_nonneg
  · intro p
    by_cases hp : p = y
    · simpa [resolutionYield, resolutionProc, hp] using hwf.stock_nonneg p
    · simpa [resolutionYield, resolutionProc, hp] using hwf.stock_nonneg p
  · intro p
    by_cases hp : p = y
    · have hcredit := hwf.credit_nonneg p
      have hcost : 0 <= s.convertCost := Rat.le_of_lt hwf.cost_pos
      have hunits :
          (0 : Qty) <= ((s.procs p).convertedSinceRestart : Qty) := by
        grind
      have hbank :
          0 <= s.convertCost * ((s.procs p).convertedSinceRestart : Qty) :=
        Rat.mul_nonneg hcost hunits
      simp [resolutionYield, resolutionProc, hp]
      grind
    · simpa [resolutionYield, resolutionProc, hp] using hwf.credit_nonneg p
  · intro p
    by_cases hp : p = y
    · simpa [resolutionYield, resolutionProc, hp] using hwf.rate_nonneg p
    · simpa [resolutionYield, resolutionProc, hp] using hwf.rate_nonneg p
  · intro p
    by_cases hp : p = y
    · simp [resolutionYield, resolutionProc, hp]
    · simpa [resolutionYield, resolutionProc, hp] using hwf.budget_le_cap p
  · intro p
    by_cases hp : p = y
    · simp [resolutionYield, resolutionProc, hp]
    · simpa [resolutionYield, resolutionProc, hp] using hwf.since_le_total p
  · intro p l hdone
    by_cases hp : p = y
    · simp [resolutionYield, resolutionProc, hp] at hdone
    · have hdone_before : (s.procs p).done = true := by
        simpa [resolutionYield, resolutionProc, hp] using hdone
      simpa [resolutionYield, hp] using
        hwf.done_holds_nothing p l hdone_before
  · calc
      CoreTrace.accounted (resolutionYield s y) = CoreTrace.accounted s :=
        resolution_yield_conserves s y
      _ = s.totalQ := hwf.accounted_eq_total
      _ = (resolutionYield s y).totalQ := rfl

def resolutionYieldWFState {n m : Nat}
    (s : WFState n m) (y : ProcId n) : WFState n m :=
  { state := resolutionYield s.state y
    wf := resolution_yield_preserves_coreWF s.state y s.wf }

theorem resolution_yield_loses_no_accounted_work {n m : Nat}
    (s : CoreState n m) (y : ProcId n) :
    CoreTrace.procAccounted (resolutionYield s y).convertCost
        ((resolutionYield s y).procs y) =
      CoreTrace.procAccounted s.convertCost (s.procs y) := by
  unfold resolutionYield
  exact resolutionProc_accounted s y y

theorem no_victim_accounted_progress_preserved {n m : Nat}
    {s s' : CoreState n m} {y : ProcId n}
    (hyield : s' = resolutionYield s y) :
    CoreTrace.procAccounted s'.convertCost (s'.procs y) =
      CoreTrace.procAccounted s.convertCost (s.procs y) := by
  subst hyield
  exact resolution_yield_loses_no_accounted_work s y

theorem accounted_includes_banked_work {n m : Nat}
    (s : CoreState n m) (y : ProcId n) :
    ((resolutionYield s y).procs y).credit =
      (s.procs y).credit + bankedValue s y := by
  unfold resolutionYield resolutionProc bankedValue creditUnits
  simp

theorem converted_total_monotone_under_resolution {n m : Nat}
    (s : CoreState n m) (y p : ProcId n) :
    (s.procs p).convertedTotal <=
      ((resolutionYield s y).procs p).convertedTotal := by
  unfold resolutionYield resolutionProc
  by_cases hp : p = y
  · simp [hp]
  · simp [hp]

theorem credit_monotone {n m : Nat}
    {s : CoreState n m} {y : ProcId n}
    (hbank_nonneg : 0 <= bankedValue s y) :
    (s.procs y).credit <= ((resolutionYield s y).procs y).credit := by
  unfold bankedValue creditUnits at hbank_nonneg
  unfold resolutionYield resolutionProc
  simp
  grind

theorem restart_has_base_plus_credit {n m : Nat}
    (s : CoreState n m) (y : ProcId n) :
    ((resolutionYield s y).procs y).budget =
      (s.procs y).budgetCap + creditUnits s y := by
  unfold resolutionYield resolutionProc creditUnits
  simp

theorem restart_cap_expanded_by_credit {n m : Nat}
    (s : CoreState n m) (y : ProcId n) :
    ((resolutionYield s y).procs y).budgetCap =
      (s.procs y).budgetCap + creditUnits s y := by
  unfold resolutionYield resolutionProc creditUnits
  simp

theorem resolution_yield_resets_restart_progress {n m : Nat}
    (s : CoreState n m) (y : ProcId n) :
    ((resolutionYield s y).procs y).convertedSinceRestart = 0 := by
  unfold resolutionYield resolutionProc
  simp

theorem resolution_yield_releases_held_locks {n m : Nat}
    (s : CoreState n m) (y : ProcId n) (l : LockId m) :
    (resolutionYield s y).holds y l = false := by
  unfold resolutionYield
  simp

theorem resolution_yield_no_instant_regrant {n m : Nat}
    (s : CoreState n m) (y : ProcId n) :
    forall l, (resolutionYield s y).holds y l = false := by
  intro l
  exact resolution_yield_releases_held_locks s y l

structure ReleaseWitness {n m : Nat}
    (s : CoreState n m) (C : ProcId n -> Bool)
    (y w : ProcId n) (l : LockId m) : Prop where
  y_in : C y = true
  w_in : C w = true
  y_holds : s.holds y l = true
  w_wants : (s.procs w).wants = some l
  w_ne_y : w ≠ y

theorem yield_releases_wait_edge {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    {y w : ProcId n} {l : LockId m}
    (_hw : ReleaseWitness s C y w l) :
    ¬ blockedOn (resolutionYield s y) w y := by
  intro hblocked
  rcases hblocked with ⟨k, _hwant, hhold, _hne⟩
  rw [resolution_yield_releases_held_locks s y k] at hhold
  cases hhold

theorem blockedOn_resolutionYield_to_original_of_ne {n m : Nat}
    {s : CoreState n m} {y w q : ProcId n}
    (hw_ne_y : w ≠ y) (hq_ne_y : q ≠ y)
    (hblock : blockedOn (resolutionYield s y) w q) :
    blockedOn s w q := by
  rcases hblock with ⟨l, hwant, hhold, hne⟩
  refine ⟨l, ?_, ?_, hne⟩
  · unfold resolutionYield resolutionProc at hwant
    simp [hw_ne_y] at hwant
    exact hwant
  · unfold resolutionYield at hhold
    simp [hq_ne_y] at hhold
    exact hhold

theorem yield_breaks_closed_component {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    {y w : ProcId n} {l : LockId m}
    (_hC : DetectorProgress.closedWaitSet s C)
    (hw : ReleaseWitness s C y w l)
    (honly : forall q, C q = true -> blockedOn s w q -> q = y) :
    ¬ DetectorProgress.closedWaitSet (resolutionYield s y) C := by
  intro hclosed
  rcases (hclosed w hw.w_in).2 with ⟨q, hqC, hblock_after⟩
  have hq_ne_y : q ≠ y := by
    intro hqy
    subst hqy
    exact yield_releases_wait_edge hw hblock_after
  have hblock_before :
      blockedOn s w q :=
    blockedOn_resolutionYield_to_original_of_ne hw.w_ne_y hq_ne_y hblock_after
  exact hq_ne_y (honly q hqC hblock_before)

def yielderScore {n m : Nat} (s : CoreState n m) (p : ProcId n) : Qty :=
  (s.procs p).credit

def choosesLeastCredit {n m : Nat}
    (s : CoreState n m) (C : ProcId n -> Bool) (y : ProcId n) : Prop :=
  C y = true /\ forall z, C z = true -> yielderScore s y <= yielderScore s z

theorem least_credit_choice_spreads_burden {n m : Nat}
    {s s' : CoreState n m} {C : ProcId n -> Bool} {y : ProcId n}
    (hchoice : choosesLeastCredit s C y)
    (_hyield : s' = resolutionYield s y) :
    forall z, C z = true -> z ≠ y -> yielderScore s y <= yielderScore s z := by
  intro z hz _hzy
  exact hchoice.2 z hz

structure ToyState where
  remaining : Nat
  banked : Nat
  atContention : Bool
deriving DecidableEq, Repr

def toyComplete (s : ToyState) : Prop :=
  s.remaining = 0

def canonicalToy : ToyState :=
  { remaining := 2, banked := 0, atContention := true }

def creditPolicyStep (s : ToyState) : ToyState :=
  if s.remaining = 0 then
    s
  else
    { remaining := s.remaining - 1
      banked := s.banked + 1
      atContention := false }

def discardPolicyStep (s : ToyState) : ToyState :=
  s

def toyStepN (step : ToyState -> ToyState) : Nat -> ToyState -> ToyState
  | 0, s => s
  | k + 1, s => toyStepN step k (step s)

theorem canonical_credit_policy_completes_in_two_yields :
    toyComplete (toyStepN creditPolicyStep 2 canonicalToy) := by
  unfold toyComplete canonicalToy
  simp [toyStepN, creditPolicyStep]

theorem canonical_discard_policy_returns_to_same_contention :
    discardPolicyStep canonicalToy = canonicalToy := rfl

theorem canonical_discard_policy_livelocks_for_all_n (n : Nat) :
    toyStepN discardPolicyStep n canonicalToy = canonicalToy := by
  induction n with
  | zero =>
      rfl
  | succ n ih =>
      simp [toyStepN, discardPolicyStep, ih]

theorem credit_policy_banked_work_strictly_increases
    {s : ToyState} (hremaining : 0 < s.remaining) :
    s.banked < (creditPolicyStep s).banked := by
  unfold creditPolicyStep
  have hnot : ¬ s.remaining = 0 := Nat.ne_of_gt hremaining
  simp [hnot]

theorem creditPolicyStep_remaining (k : Nat) (s : ToyState) :
    (toyStepN creditPolicyStep k s).remaining = s.remaining - k := by
  induction k generalizing s with
  | zero =>
      rfl
  | succ k ih =>
      unfold toyStepN
      rw [ih]
      unfold creditPolicyStep
      by_cases hzero : s.remaining = 0
      · simp [hzero]
      · simp [hzero, Nat.sub_sub, Nat.add_comm]

theorem positive_credit_gain_finite_requirement_eventually_completes
    (s0 : ToyState) :
    exists k, toyComplete (toyStepN creditPolicyStep k s0) := by
  refine ⟨s0.remaining, ?_⟩
  unfold toyComplete
  rw [creditPolicyStep_remaining]
  exact Nat.sub_self s0.remaining

end
end ResolutionYield
end IsoConserve
