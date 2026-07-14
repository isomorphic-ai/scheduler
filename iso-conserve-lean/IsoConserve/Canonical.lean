import IsoConserve.L1Conservation
import IsoConserve.L4Integral
import IsoConserve.Reachable
import IsoConserve.ShareSum

namespace IsoConserve

def initProc (rate : Qty) (workNeeded : Nat) : Proc :=
  { rate := rate
    workNeeded := workNeeded
    stock := 0
    credit := 0
    converted := 0
    done := false
    netFlowIntegral := 0 }

def Init {n : Nat} (rate : Fin n -> Qty) (workNeeded : Fin n -> Nat)
    (runnable : Fin n -> Bool) (reservoir convertCost : Qty) : Sys n :=
  { procs := fun i => initProc (rate i) (workNeeded i)
    runnable := runnable
    reservoir := reservoir
    convertCost := convertCost
    totalQ := reservoir }

theorem Init_WF {n : Nat} (rate : Fin n -> Qty)
    (workNeeded : Fin n -> Nat) (runnable : Fin n -> Bool)
    {reservoir convertCost : Qty}
    (hcost : 0 < convertCost) (hreservoir : 0 <= reservoir)
    (hrate : forall i, 0 <= rate i) :
    WF (Init rate workNeeded runnable reservoir convertCost) := by
  constructor
  · exact hcost
  · exact hreservoir
  · intro i
    unfold Init initProc
    grind
  · intro i
    unfold Init initProc
    grind
  · intro i
    exact hrate i
  · unfold accounted Init initProc procAccounted
    change reservoir +
        sumFin (fun _ : Fin n => (0 : Qty) + 0 + convertCost * (0 : Qty)) =
      reservoir
    have hsum :
        sumFin (fun _ : Fin n => (0 : Qty) + 0 + convertCost * (0 : Qty)) = 0 := by
      calc
        sumFin (fun _ : Fin n => (0 : Qty) + 0 + convertCost * (0 : Qty)) =
            sumFin (fun _ : Fin n => (0 : Qty)) := by
              apply sumFin_congr
              intro i
              grind
        _ = 0 := sumFin_zero
    rw [hsum]
    grind

theorem Init_L4Invariant {n : Nat} (rate : Fin n -> Qty)
    (workNeeded : Fin n -> Nat) (runnable : Fin n -> Bool)
    (reservoir convertCost : Qty) :
    L4Invariant (Init rate workNeeded runnable reservoir convertCost) := by
  intro i
  unfold Init initProc
  grind

def tableSize {n : Nat} (s : Sys n) : Qty :=
  sumFin (fun i => if s.runnable i then (1 : Qty) else 0)

theorem tableSize_nonneg {n : Nat} (s : Sys n) :
    0 <= tableSize s := by
  unfold tableSize
  apply sumFin_nonneg
  intro i
  by_cases h : s.runnable i
  · simp [h]
    grind
  · simp [h]

def pythonQuantum {n : Nat} (s : Sys n) : Qty :=
  if s.reservoir <= tableSize s then s.reservoir else tableSize s

theorem pythonQuantum_nonneg {n : Nat} (s : Sys n)
    (hreservoir : 0 <= s.reservoir) :
    0 <= pythonQuantum s := by
  unfold pythonQuantum
  by_cases h : s.reservoir <= tableSize s
  · simp [h, hreservoir]
  · simp [h, tableSize_nonneg s]

theorem pythonQuantum_reservoir_after_nonneg {n : Nat} (s : Sys n) :
    0 <= s.reservoir - pythonQuantum s := by
  unfold pythonQuantum
  by_cases h : s.reservoir <= tableSize s
  · simp [h]
    grind
  · simp [h]
    grind

def canonicalWeight {n : Nat} (s : Sys n) (eff : Fin n -> Qty)
    (i : Fin n) : Qty :=
  active s eff i

def canonicalTotalWeight {n : Nat} (s : Sys n) (eff : Fin n -> Qty) : Qty :=
  sumFin (canonicalWeight s eff)

def canonicalShare {n : Nat} (s : Sys n) (eff : Fin n -> Qty)
    (i : Fin n) : Qty :=
  sharesFromWeights (pythonQuantum s) (canonicalTotalWeight s eff)
    (canonicalWeight s eff) i

theorem canonicalWeight_blocked {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (i : Fin n)
    (h : s.runnable i = false) :
    canonicalWeight s eff i = 0 := by
  unfold canonicalWeight active
  simp [h]

theorem canonicalWeight_nonneg {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (heff : forall i, 0 <= eff i) :
    forall i, 0 <= canonicalWeight s eff i := by
  intro i
  unfold canonicalWeight active
  by_cases h : s.runnable i
  · simp [h, heff i]
  · simp [h]

theorem canonicalShare_blocked {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty)
    (i : Fin n) (h : s.runnable i = false) :
    canonicalShare s eff i = 0 := by
  unfold canonicalShare sharesFromWeights
  have hw : canonicalWeight s eff i = 0 :=
    canonicalWeight_blocked s eff i h
  grind

theorem canonicalShare_sum_active {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) :
    sumFin (fun i => active s (canonicalShare s eff) i) =
      sumFin (canonicalShare s eff) := by
  apply sumFin_congr
  intro i
  unfold active
  by_cases h : s.runnable i
  · simp [h]
  · have hf : s.runnable i = false := by
      cases hb : s.runnable i
      · rfl
      · simp [hb] at h
    simp [h, canonicalShare_blocked s eff i hf]

theorem canonicalShare_nonneg {n : Nat} (s : Sys n) (eff : Fin n -> Qty)
    (hreservoir : 0 <= s.reservoir)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (hweight : forall i, 0 <= canonicalWeight s eff i)
    (i : Fin n) :
    0 <= canonicalShare s eff i := by
  unfold canonicalShare sharesFromWeights
  have hq : 0 <= pythonQuantum s := pythonQuantum_nonneg s hreservoir
  have hw : 0 <= canonicalWeight s eff i := hweight i
  have hqw : 0 <= pythonQuantum s * canonicalWeight s eff i :=
    Rat.mul_nonneg hq hw
  have hit : 0 < (canonicalTotalWeight s eff)⁻¹ :=
    (Rat.inv_pos).2 hTotalPos
  have hitn : 0 <= (canonicalTotalWeight s eff)⁻¹ := Rat.le_of_lt hit
  exact Rat.mul_nonneg hqw hitn

def remainingWork (p : Proc) : Nat :=
  if p.done then 0 else p.workNeeded - p.converted

def forcedConvert (cost stock : Qty) : Nat -> Nat
  | 0 => 0
  | fuel + 1 =>
      if cost <= stock then 1 + forcedConvert cost (stock - cost) fuel else 0

theorem forcedConvert_stock_after_nonneg (cost : Qty) :
    forall fuel stock, 0 <= stock ->
      0 <= stock - cost * (forcedConvert cost stock fuel : Qty) := by
  intro fuel
  induction fuel with
  | zero =>
      intro stock hs
      unfold forcedConvert
      grind
  | succ fuel ih =>
      intro stock hs
      unfold forcedConvert
      by_cases hle : cost <= stock
      · simp [hle]
        have hs' : 0 <= stock - cost := by grind
        have ih' := ih (stock - cost) hs'
        grind
      · simp [hle]
        grind

theorem forcedConvert_residual_lt_cost_of_lt (cost : Qty) :
    forall fuel stock, 0 <= stock ->
      forcedConvert cost stock fuel < fuel ->
      stock - cost * (forcedConvert cost stock fuel : Qty) < cost := by
  intro fuel
  induction fuel with
  | zero =>
      intro stock hs hlt
      omega
  | succ fuel ih =>
      intro stock hs hlt
      unfold forcedConvert at hlt ⊢
      by_cases hle : cost <= stock
      · simp [hle] at hlt ⊢
        have hs' : 0 <= stock - cost := by grind
        have hlt' : forcedConvert cost (stock - cost) fuel < fuel := by omega
        have ih' := ih (stock - cost) hs' hlt'
        grind
      · simp [hle] at hlt ⊢
        grind

def pythonConvert {n : Nat} (s : Sys n) (eff : Fin n -> Qty)
    (i : Fin n) : Nat :=
  forcedConvert s.convertCost
    ((s.procs i).stock + active s (canonicalShare s eff) i)
    (remainingWork (s.procs i))

theorem pythonConvert_stock_after_nonneg {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty)
    (hreservoir : 0 <= s.reservoir)
    (hstock : forall i, 0 <= (s.procs i).stock)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (hweight : forall i, 0 <= canonicalWeight s eff i)
    (i : Fin n) :
    0 <= (s.procs i).stock + active s (canonicalShare s eff) i -
      s.convertCost * (activeNat s (pythonConvert s eff) i : Qty) := by
  by_cases hr : s.runnable i
  · unfold pythonConvert activeNat
    simp [hr]
    have hs : 0 <= (s.procs i).stock + active s (canonicalShare s eff) i := by
      have hsh := canonicalShare_nonneg s eff hreservoir hTotalPos hweight i
      unfold active
      simp [hr]
      exact Rat.add_nonneg (hstock i) hsh
    exact forcedConvert_stock_after_nonneg s.convertCost
      (remainingWork (s.procs i))
      ((s.procs i).stock + active s (canonicalShare s eff) i) hs
  · unfold active activeNat
    simp [hr]
    have hs := hstock i
    grind

def pythonRatePlan {n : Nat} (s : Sys n) (eff : Fin n -> Qty)
    (hreservoir : 0 <= s.reservoir)
    (hstock : forall i, 0 <= (s.procs i).stock)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (hweight : forall i, 0 <= canonicalWeight s eff i) :
    RatePlan s :=
  { share := canonicalShare s eff
    convert := pythonConvert s eff
    reservoir_after_nonneg := by
      have hTotal : canonicalTotalWeight s eff != 0 := by grind
      have hactive :=
        canonicalShare_sum_active s eff
      have hsum :
          sumFin (canonicalShare s eff) = pythonQuantum s := by
        exact share_sum_of_partition (pythonQuantum s)
          (canonicalTotalWeight s eff) (canonicalWeight s eff)
          hTotal rfl
      grind [pythonQuantum_reservoir_after_nonneg s]
    stock_after_nonneg :=
      pythonConvert_stock_after_nonneg s eff hreservoir hstock hTotalPos hweight
    quantum := pythonQuantum s
    totalWeight := canonicalTotalWeight s eff
    weight := canonicalWeight s eff
    totalWeight_ne_zero := by grind
    weight_sum := rfl
    weight_blocked := canonicalWeight_blocked s eff
    share_eq := by
      intro i
      rfl }

def pythonRatePlanOfWF {n : Nat} (s : Sys n) (eff : Fin n -> Qty)
    (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i) :
    RatePlan s :=
  pythonRatePlan s eff hwf.reservoir_nonneg hwf.stock_nonneg hTotalPos
    (canonicalWeight_nonneg s eff heff)

def pythonStepOfWF {n : Nat} (s : Sys n) (eff : Fin n -> Qty)
    (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i) : Sys n :=
  step s (pythonRatePlanOfWF s eff hwf hTotalPos heff).toFlowPlan

def CanonicalPythonStepRel {n : Nat} (s t : Sys n) : Prop :=
  exists (eff : Fin n -> Qty)
    (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i),
    t = pythonStepOfWF s eff hwf hTotalPos heff

theorem pythonRatePlanOfWF_share_sum {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i) :
    sumFin (pythonRatePlanOfWF s eff hwf hTotalPos heff).share =
      pythonQuantum s := by
  exact ratePlan_share_sum (pythonRatePlanOfWF s eff hwf hTotalPos heff)

theorem pythonRatePlanOfWF_active_share_sum {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i) :
    sumFin (fun i =>
        active s (pythonRatePlanOfWF s eff hwf hTotalPos heff).share i) =
      pythonQuantum s := by
  calc
    sumFin (fun i =>
        active s (pythonRatePlanOfWF s eff hwf hTotalPos heff).share i) =
        sumFin (fun i => active s (canonicalShare s eff) i) := by
          rfl
    _ = sumFin (canonicalShare s eff) := canonicalShare_sum_active s eff
    _ = pythonQuantum s := by
          have hTotal : canonicalTotalWeight s eff != 0 := by grind
          exact share_sum_of_partition (pythonQuantum s)
            (canonicalTotalWeight s eff) (canonicalWeight s eff) hTotal rfl

theorem pythonStepOfWF_is_verified_step {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i) :
    StepRel s (pythonStepOfWF s eff hwf hTotalPos heff) := by
  exact ⟨(pythonRatePlanOfWF s eff hwf hTotalPos heff).toFlowPlan, rfl⟩

theorem pythonStepOfWF_is_verified_mixed_step {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i) :
    MixedRel s (pythonStepOfWF s eff hwf hTotalPos heff) := by
  exact Or.inl (pythonStepOfWF_is_verified_step s eff hwf hTotalPos heff)

theorem canonicalPythonStepRel_is_stepRel {n : Nat} {s t : Sys n}
    (h : CanonicalPythonStepRel s t) :
    StepRel s t := by
  rcases h with ⟨eff, hwf, hTotalPos, heff, ht⟩
  subst ht
  exact pythonStepOfWF_is_verified_step s eff hwf hTotalPos heff

theorem canonicalPythonStepRel_is_mixedRel {n : Nat} {s t : Sys n}
    (h : CanonicalPythonStepRel s t) :
    MixedRel s t := by
  exact Or.inl (canonicalPythonStepRel_is_stepRel h)

theorem pythonStepOfWF_reachable {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i) :
    RTC MixedRel s (pythonStepOfWF s eff hwf hTotalPos heff) := by
  exact RTC.tail (RTC.refl s)
    (pythonStepOfWF_is_verified_mixed_step s eff hwf hTotalPos heff)

theorem wf_pythonStepOfWF {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i) :
    WF (pythonStepOfWF s eff hwf hTotalPos heff) := by
  exact wf_reachable hwf
    (pythonStepOfWF_reachable s eff hwf hTotalPos heff)

theorem l4_pythonStepOfWF {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i)
    (hl4 : L4Invariant s) :
    L4Invariant (pythonStepOfWF s eff hwf hTotalPos heff) := by
  exact l4_reachable hl4
    (pythonStepOfWF_reachable s eff hwf hTotalPos heff)

theorem pythonStepOfWF_conservation {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty) (hwf : WF s)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (heff : forall i, 0 <= eff i) :
    accounted (pythonStepOfWF s eff hwf hTotalPos heff) = accounted s := by
  unfold pythonStepOfWF
  exact L1_conservation s
    (pythonRatePlanOfWF s eff hwf hTotalPos heff).toFlowPlan

theorem pythonRatePlan_conservation {n : Nat} (s : Sys n) (eff : Fin n -> Qty)
    (hreservoir : 0 <= s.reservoir)
    (hstock : forall i, 0 <= (s.procs i).stock)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (hweight : forall i, 0 <= canonicalWeight s eff i) :
    accounted (step s (pythonRatePlan s eff hreservoir hstock hTotalPos hweight).toFlowPlan) =
      accounted s := by
  exact L1_conservation s
    (pythonRatePlan s eff hreservoir hstock hTotalPos hweight).toFlowPlan

theorem pythonConvert_forced_maximal {n : Nat} (s : Sys n)
    (eff : Fin n -> Qty)
    (hreservoir : 0 <= s.reservoir)
    (hstock : forall i, 0 <= (s.procs i).stock)
    (hTotalPos : 0 < canonicalTotalWeight s eff)
    (hweight : forall i, 0 <= canonicalWeight s eff i)
    (i : Fin n)
    (hlt : pythonConvert s eff i < remainingWork (s.procs i)) :
    (s.procs i).stock + active s (canonicalShare s eff) i -
      s.convertCost * (pythonConvert s eff i : Qty) < s.convertCost := by
  have hs : 0 <= (s.procs i).stock + active s (canonicalShare s eff) i := by
    by_cases hr : s.runnable i
    · have hsh := canonicalShare_nonneg s eff hreservoir hTotalPos hweight i
      unfold active
      simp [hr]
      exact Rat.add_nonneg (hstock i) hsh
    · unfold active
      simp [hr]
      have hs0 := hstock i
      grind
  exact forcedConvert_residual_lt_cost_of_lt s.convertCost
    (remainingWork (s.procs i))
    ((s.procs i).stock + active s (canonicalShare s eff) i) hs hlt

def subthresholdProc : Proc :=
  { rate := 1
    workNeeded := 1
    stock := 0
    credit := 0
    converted := 0
    done := false
    netFlowIntegral := 0 }

def subthresholdSys : Sys 1 :=
  { procs := fun _ => subthresholdProc
    runnable := fun _ => true
    reservoir := (1 : Qty) / 2
    convertCost := 1
    totalQ := (1 : Qty) / 2 }

def subthresholdEff : Fin 1 -> Qty := fun _ => 1

def subthresholdPlan : RatePlan subthresholdSys :=
  pythonRatePlan subthresholdSys subthresholdEff
    (by native_decide)
    (by
      intro i
      unfold subthresholdSys subthresholdProc
      grind)
    (by native_decide)
    (by
      intro i
      unfold canonicalWeight active subthresholdSys subthresholdEff
      simp
      grind)

theorem subthreshold_python_noProgress :
    totalConverted (step subthresholdSys subthresholdPlan.toFlowPlan) =
      totalConverted subthresholdSys := by
  native_decide

theorem subthreshold_python_convertibleStock_increases :
    convertibleStock subthresholdSys <
      convertibleStock (step subthresholdSys subthresholdPlan.toFlowPlan) := by
  native_decide

end IsoConserve
