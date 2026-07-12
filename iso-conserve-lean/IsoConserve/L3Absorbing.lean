import IsoConserve.Basic
import IsoConserve.L1Conservation

namespace IsoConserve

theorem inactive_active_eq_zero {n : Nat} (s : Sys n) (x : Fin n -> Qty)
    (h : atTableEmpty s) (i : Fin n) :
    active s x i = 0 := by
  unfold active
  simp [h i]

theorem inactive_activeNat_eq_zero {n : Nat} (s : Sys n) (x : Fin n -> Nat)
    (h : atTableEmpty s) (i : Fin n) :
    activeNat s x i = 0 := by
  unfold activeNat
  simp [h i]

theorem stepProc_deadlocked_eq {n : Nat} (s : Sys n) (plan : FlowPlan s)
    (h : atTableEmpty s) (i : Fin n) :
    stepProc s plan i = s.procs i := by
  unfold stepProc
  have hs : active s plan.share i = 0 := inactive_active_eq_zero s plan.share h i
  have hc : activeNat s plan.convert i = 0 := inactive_activeNat_eq_zero s plan.convert h i
  cases s.procs i
  simp [hs, hc]
  grind

theorem totalConverted_deadlocked_step_eq {n : Nat} (s : Sys n)
    (plan : FlowPlan s) (h : atTableEmpty s) :
    totalConverted (step s plan) = totalConverted s := by
  unfold totalConverted step stepProc
  apply sumFin_congr
  intro i
  have hc : activeNat s plan.convert i = 0 := inactive_activeNat_eq_zero s plan.convert h i
  simp [hc]

theorem accounted_deadlocked_step_eq {n : Nat} (s : Sys n) (plan : FlowPlan s)
    (h : atTableEmpty s) :
    step s plan = s := by
  cases s with
  | mk procs runnable reservoir convertCost totalQ =>
      unfold step
      simp
      constructor
      · funext i
        exact stepProc_deadlocked_eq
          { procs := procs, runnable := runnable, reservoir := reservoir,
            convertCost := convertCost, totalQ := totalQ } plan h i
      · have hs :
            sumFin (fun i =>
              active
                { procs := procs, runnable := runnable, reservoir := reservoir,
                  convertCost := convertCost, totalQ := totalQ }
                plan.share i) = 0 := by
          calc
            sumFin (fun i =>
              active
                { procs := procs, runnable := runnable, reservoir := reservoir,
                  convertCost := convertCost, totalQ := totalQ }
                plan.share i) =
                sumFin (fun _ : Fin n => (0 : Qty)) := by
                  apply sumFin_congr
                  intro i
                  exact inactive_active_eq_zero _ plan.share h i
            _ = 0 := sumFin_zero
        grind

theorem L3_absorbing {n : Nat} (s : Sys n) (plan : FlowPlan s)
    (_h : WF s) (hd : deadlocked s) :
    deadlocked (step s plan) /\ totalConverted (step s plan) = totalConverted s := by
  constructor
  · constructor
    · unfold atTableEmpty step
      exact hd.left
    · intro hall
      apply hd.right
      intro i
      have hi := hall i
      unfold allDone step stepProc at hi
      simpa using hi
  · exact totalConverted_deadlocked_step_eq s plan hd.left

end IsoConserve
