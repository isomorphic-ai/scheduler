import IsoConserve.Basic

namespace IsoConserve
namespace Flexibility

/- This module formalizes only the conservation identity for reading 4.7.
The phantom-race and carried-distribution demonstrations remain empirical
engine results; Lean gets the potential/actual collapse ledger. -/

structure FlexState where
  potential : Qty
  actual : Qty

def whole (s : FlexState) : Qty :=
  s.potential + s.actual

structure CollapsePlan (s : FlexState) where
  amount : Qty
  amount_nonneg : 0 <= amount
  amount_le_potential : amount <= s.potential

def collapse (s : FlexState) (plan : CollapsePlan s) : FlexState :=
  { potential := s.potential - plan.amount
    actual := s.actual + plan.amount }

theorem collapse_whole_invariant (s : FlexState) (plan : CollapsePlan s) :
    whole (collapse s plan) = whole s := by
  unfold whole collapse
  grind

theorem collapse_potential_monotone (s : FlexState) (plan : CollapsePlan s) :
    (collapse s plan).potential <= s.potential := by
  unfold collapse
  have h := plan.amount_nonneg
  grind

theorem collapse_actual_monotone (s : FlexState) (plan : CollapsePlan s) :
    s.actual <= (collapse s plan).actual := by
  unfold collapse
  have h := plan.amount_nonneg
  grind

theorem collapse_potential_nonneg (s : FlexState) (plan : CollapsePlan s) :
    0 <= (collapse s plan).potential := by
  unfold collapse
  have hnonneg := plan.amount_nonneg
  have hle := plan.amount_le_potential
  grind

theorem collapse_actual_gain_eq_potential_loss
    (s : FlexState) (plan : CollapsePlan s) :
    (collapse s plan).actual - s.actual =
      s.potential - (collapse s plan).potential := by
  unfold collapse
  grind

theorem collapse_delta_balance (s : FlexState) (plan : CollapsePlan s) :
    (collapse s plan).potential - s.potential =
      -((collapse s plan).actual - s.actual) := by
  unfold collapse
  grind

end Flexibility
end IsoConserve
