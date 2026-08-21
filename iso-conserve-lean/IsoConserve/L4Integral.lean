import IsoConserve.Basic

namespace IsoConserve

theorem l4_step {n : Nat} (s : Sys n) (plan : FlowPlan s)
    (h : L4Invariant s) : L4Invariant (step s plan) := by
  intro i
  unfold L4Invariant at h
  unfold step stepProc
  have hi := h i
  grind

theorem l4_drainStep {n : Nat} (s : Sys n) (plan : DrainPlan s)
    (h : L4Invariant s) : L4Invariant (drainStep s plan) := by
  intro i
  unfold L4Invariant at h
  unfold drainStep drainProc
  have hi := h i
  grind

theorem l4_yield {n : Nat} (s : Sys n) (plan : YieldPlan s)
    (h : L4Invariant s) : L4Invariant (yieldStep s plan) := by
  intro i
  unfold L4Invariant at h
  unfold yieldStep yieldProc
  have hi := h i
  grind

theorem l4_yieldStep {n : Nat} (s : Sys n) (plan : YieldPlan s)
    (h : L4Invariant s) : L4Invariant (yieldStep s plan) :=
  l4_yield s plan h

theorem L4_stock_is_integral {n : Nat} (s : Sys n)
    (h : L4Invariant s) (i : Fin n) :
    (s.procs i).stock + (s.procs i).credit =
      (s.procs i).netFlowIntegral := by
  exact h i

end IsoConserve
