import IsoConserve.L2Monotone
import IsoConserve.L3Absorbing

namespace IsoConserve

inductive RTC {State : Sort u} (E : State -> State -> Prop) :
    State -> State -> Prop where
  | refl (s : State) : RTC E s s
  | tail {s t u : State} : RTC E s t -> E t u -> RTC E s u

theorem monotone_under_adversary {State : Sort u} {alpha : Type v}
    (le : alpha -> alpha -> Prop)
    (leRefl : forall a, le a a)
    (leTrans : forall {a b c}, le a b -> le b c -> le a c)
    (E : State -> State -> Prop) (f : State -> alpha)
    (h : forall s t, E s t -> le (f t) (f s)) :
    forall s t, RTC E s t -> le (f t) (f s) := by
  intro s t reach
  induction reach with
  | refl => exact leRefl (f s)
  | tail reach step ih =>
      exact leTrans (h _ _ step) ih

def StepRel {n : Nat} (s t : Sys n) : Prop :=
  exists plan : FlowPlan s, t = step s plan

def DrainRel {n : Nat} (s t : Sys n) : Prop :=
  exists plan : DrainPlan s, t = drainStep s plan

theorem L2_monotone_under_drain_reachable {n : Nat} (s t : Sys n)
    (reach : RTC DrainRel s t) :
    convertibleStock t <= convertibleStock s := by
  apply monotone_under_adversary
    (le := fun a b : Qty => a <= b)
    (leRefl := fun a => by grind)
    (leTrans := by
      intro a b c hab hbc
      grind)
    (E := DrainRel)
    (f := convertibleStock)
  · intro s t hstep
    rcases hstep with ⟨plan, ht⟩
    subst ht
    exact convertibleStock_drainStep_le s plan
  · exact reach

theorem reachable_deadlock_absorbing {n : Nat} (s t : Sys n)
    (hd : deadlocked s) (reach : RTC StepRel s t) :
    t = s := by
  induction reach with
  | refl => rfl
  | tail reach st ih =>
      rcases st with ⟨plan, hstep⟩
      subst hstep
      subst ih
      apply accounted_deadlocked_step_eq
      exact hd.left

end IsoConserve
