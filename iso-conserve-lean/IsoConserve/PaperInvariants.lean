import IsoConserve.Reachable

namespace IsoConserve

def localAccount {n : Nat} (s : Sys n) (i : Fin n) : Qty :=
  procAccounted s.convertCost (s.procs i)

def outsideAccount {n : Nat} (s : Sys n) (i : Fin n) : Qty :=
  accounted s - localAccount s i

theorem mixed_step_accounted_eq {n : Nat} {s t : Sys n}
    (h : MixedRel s t) :
    accounted t = accounted s := by
  cases h with
  | inl hstep =>
      rcases hstep with ⟨plan, ht⟩
      subst ht
      exact L1_conservation s plan
  | inr hrest =>
      cases hrest with
      | inl hdrain =>
          rcases hdrain with ⟨plan, ht⟩
          subst ht
          exact drain_conservation s plan
      | inr hyield =>
          rcases hyield with ⟨plan, ht⟩
          subst ht
          exact yield_conservation s plan

theorem mixed_reachable_accounted_eq {n : Nat} {s t : Sys n}
    (reach : RTC MixedRel s t) :
    accounted t = accounted s := by
  induction reach with
  | refl =>
      rfl
  | tail reach hstep ih =>
      exact Eq.trans (mixed_step_accounted_eq hstep) ih

theorem mixed_step_totalQ_eq {n : Nat} {s t : Sys n}
    (h : MixedRel s t) :
    t.totalQ = s.totalQ := by
  cases h with
  | inl hstep =>
      rcases hstep with ⟨plan, ht⟩
      subst ht
      rfl
  | inr hrest =>
      cases hrest with
      | inl hdrain =>
          rcases hdrain with ⟨plan, ht⟩
          subst ht
          rfl
      | inr hyield =>
          rcases hyield with ⟨plan, ht⟩
          subst ht
          rfl

theorem mixed_reachable_totalQ_eq {n : Nat} {s t : Sys n}
    (reach : RTC MixedRel s t) :
    t.totalQ = s.totalQ := by
  induction reach with
  | refl =>
      rfl
  | tail reach hstep ih =>
      exact Eq.trans (mixed_step_totalQ_eq hstep) ih

theorem epistemic_invariant {n : Nat} {s t : Sys n}
    (hwf : WF s) (reach : RTC MixedRel s t) :
    accounted t = s.totalQ := by
  calc
    accounted t = t.totalQ := (wf_reachable hwf reach).accounted_eq_total
    _ = s.totalQ := mixed_reachable_totalQ_eq reach

theorem alignment_invariant {n : Nat} {s t : Sys n}
    (h : MixedRel s t) (i : Fin n) :
    localAccount s i - localAccount t i =
      outsideAccount t i - outsideAccount s i := by
  have hc := mixed_step_accounted_eq h
  unfold outsideAccount
  grind

theorem agency_invariant {n : Nat} {s t : Sys n}
    (h : MixedRel s t) {i : Fin n}
    (hgain : localAccount s i < localAccount t i) :
    outsideAccount t i < outsideAccount s i := by
  have halign := alignment_invariant h i
  grind

end IsoConserve
