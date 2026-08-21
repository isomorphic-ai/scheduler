import IsoConserve.Basic

namespace IsoConserve

theorem L1_conservation {n : Nat} (s : Sys n) (plan : FlowPlan s) :
    accounted (step s plan) = accounted s := by
  unfold accounted step
  have hsum :
      sumFin (fun i =>
        procAccounted s.convertCost (stepProc s plan i)) =
        sumFin (fun i =>
          procAccounted s.convertCost (s.procs i)) +
          sumFin (fun i => active s plan.share i) := by
    calc
      sumFin (fun i =>
          procAccounted s.convertCost (stepProc s plan i)) =
          sumFin (fun i =>
            procAccounted s.convertCost (s.procs i) +
              active s plan.share i) := by
            apply sumFin_congr
            intro i
            exact procAccounted_stepProc s plan i
      _ = sumFin (fun i => procAccounted s.convertCost (s.procs i)) +
            sumFin (fun i => active s plan.share i) := by
            exact sumFin_add
              (fun i => procAccounted s.convertCost (s.procs i))
              (fun i => active s plan.share i)
  grind

theorem drain_conservation {n : Nat} (s : Sys n) (plan : DrainPlan s) :
    accounted (drainStep s plan) = accounted s := by
  unfold accounted drainStep
  have hsum :
      sumFin (fun i =>
        procAccounted s.convertCost (drainProc s plan i)) =
        sumFin (fun i =>
          procAccounted s.convertCost (s.procs i)) -
          sumFin plan.drain := by
    calc
      sumFin (fun i =>
          procAccounted s.convertCost (drainProc s plan i)) =
          sumFin (fun i =>
            procAccounted s.convertCost (s.procs i) - plan.drain i) := by
            apply sumFin_congr
            intro i
            exact procAccounted_drainProc s plan i
      _ = sumFin (fun i => procAccounted s.convertCost (s.procs i)) -
            sumFin plan.drain := by
            exact sumFin_sub
              (fun i => procAccounted s.convertCost (s.procs i))
              plan.drain
  grind

theorem yield_conservation {n : Nat} (s : Sys n) (plan : YieldPlan s) :
    accounted (yieldStep s plan) = accounted s := by
  unfold accounted yieldStep
  have hsum :
      sumFin (fun i =>
        procAccounted s.convertCost (yieldProc s plan i)) =
        sumFin (fun i =>
          procAccounted s.convertCost (s.procs i)) := by
    apply sumFin_congr
    intro i
    exact procAccounted_yieldProc s plan i
  grind

theorem wf_step {n : Nat} (s : Sys n) (plan : FlowPlan s)
    (h : WF s) : WF (step s plan) := by
  constructor
  · exact h.cost_pos
  · exact plan.reservoir_after_nonneg
  · intro i
    exact plan.stock_after_nonneg i
  · intro i
    exact h.credit_nonneg i
  · intro i
    exact h.rate_nonneg i
  · calc
      accounted (step s plan) = accounted s := L1_conservation s plan
      _ = s.totalQ := h.accounted_eq_total

theorem wf_drainStep {n : Nat} (s : Sys n) (plan : DrainPlan s)
    (h : WF s) : WF (drainStep s plan) := by
  constructor
  · exact h.cost_pos
  · have hr := h.reservoir_nonneg
    have hd : 0 <= sumFin plan.drain := sumFin_nonneg plan.drain plan.drain_nonneg
    unfold drainStep
    grind
  · intro i
    exact plan.stock_after_nonneg i
  · intro i
    exact h.credit_nonneg i
  · intro i
    exact h.rate_nonneg i
  · calc
      accounted (drainStep s plan) = accounted s := drain_conservation s plan
      _ = s.totalQ := h.accounted_eq_total

theorem wf_yieldStep {n : Nat} (s : Sys n) (plan : YieldPlan s)
    (h : WF s) : WF (yieldStep s plan) := by
  constructor
  · exact h.cost_pos
  · exact h.reservoir_nonneg
  · intro i
    exact plan.stock_after_nonneg i
  · intro i
    unfold yieldStep yieldProc
    have hc := h.credit_nonneg i
    have hy := plan.amount_nonneg i
    grind
  · intro i
    exact h.rate_nonneg i
  · calc
      accounted (yieldStep s plan) = accounted s := yield_conservation s plan
      _ = s.totalQ := h.accounted_eq_total

end IsoConserve
