import IsoConserve.L2Monotone
import IsoConserve.L3Absorbing
import IsoConserve.L4Integral

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

def MixedRel {n : Nat} (s t : Sys n) : Prop :=
  StepRel s t \/ DrainRel s t

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

theorem step_blocked_stock_eq {n : Nat} (i : Fin n)
    (s : Sys n) (plan : FlowPlan s) (hb : s.runnable i = false) :
    ((step s plan).procs i).stock = (s.procs i).stock := by
  unfold step stepProc active activeNat
  simp [hb]
  grind

theorem drainStep_stock_le {n : Nat} (i : Fin n)
    (s : Sys n) (plan : DrainPlan s) :
    ((drainStep s plan).procs i).stock <= (s.procs i).stock := by
  unfold drainStep drainProc
  have hd := plan.drain_nonneg i
  grind

theorem mixed_step_blocked_stock_le {n : Nat} (i : Fin n)
    (s t : Sys n) (hb : s.runnable i = false) (h : MixedRel s t) :
    (t.procs i).stock <= (s.procs i).stock := by
  cases h with
  | inl hstep =>
      rcases hstep with ⟨plan, ht⟩
      subst ht
      rw [step_blocked_stock_eq i s plan hb]
      grind
  | inr hdrain =>
      rcases hdrain with ⟨plan, ht⟩
      subst ht
      exact drainStep_stock_le i s plan

theorem mixed_step_runnable_eq {n : Nat} (i : Fin n)
    {s t : Sys n} (h : MixedRel s t) :
    t.runnable i = s.runnable i := by
  cases h with
  | inl hstep =>
      rcases hstep with ⟨plan, ht⟩
      subst ht
      rfl
  | inr hdrain =>
      rcases hdrain with ⟨plan, ht⟩
      subst ht
      rfl

theorem mixed_reachable_runnable_eq {n : Nat} (i : Fin n)
    {s t : Sys n} (reach : RTC MixedRel s t) :
    t.runnable i = s.runnable i := by
  induction reach with
  | refl => rfl
  | tail reach hstep ih =>
      exact Eq.trans (mixed_step_runnable_eq i hstep) ih

def BlockedMixedRel {n : Nat} (i : Fin n) (s t : Sys n) : Prop :=
  s.runnable i = false /\ MixedRel s t

theorem blocked_stock_monotone_restricted {n : Nat} (i : Fin n)
    (s t : Sys n) (reach : RTC (BlockedMixedRel i) s t) :
    (t.procs i).stock <= (s.procs i).stock := by
  apply monotone_under_adversary
    (le := fun a b : Qty => a <= b)
    (leRefl := fun a => by grind)
    (leTrans := by
      intro a b c hab hbc
      grind)
    (E := BlockedMixedRel i)
    (f := fun s => (s.procs i).stock)
  · intro s t hstep
    exact mixed_step_blocked_stock_le i s t hstep.left hstep.right
  · exact reach

theorem blocked_stock_monotone {n : Nat} (i : Fin n) (s t : Sys n)
    (hb : s.runnable i = false) (reach : RTC MixedRel s t) :
    (t.procs i).stock <= (s.procs i).stock := by
  induction reach with
  | refl => grind
  | tail reach hstep ih =>
      have hb_mid := Eq.trans (mixed_reachable_runnable_eq i reach) hb
      have hstep_le := mixed_step_blocked_stock_le i _ _ hb_mid hstep
      grind

theorem wf_mixed_step {n : Nat} {s t : Sys n}
    (h : MixedRel s t) (hwf : WF s) : WF t := by
  cases h with
  | inl hstep =>
      rcases hstep with ⟨plan, ht⟩
      subst ht
      exact wf_step s plan hwf
  | inr hdrain =>
      rcases hdrain with ⟨plan, ht⟩
      subst ht
      exact wf_drainStep s plan hwf

theorem wf_reachable {n : Nat} {s t : Sys n}
    (hwf : WF s) (reach : RTC MixedRel s t) : WF t := by
  induction reach with
  | refl => exact hwf
  | tail reach hstep ih =>
      exact wf_mixed_step hstep ih

theorem l4_mixed_step {n : Nat} {s t : Sys n}
    (h : MixedRel s t) (hl4 : L4Invariant s) : L4Invariant t := by
  cases h with
  | inl hstep =>
      rcases hstep with ⟨plan, ht⟩
      subst ht
      exact l4_step s plan hl4
  | inr hdrain =>
      rcases hdrain with ⟨plan, ht⟩
      subst ht
      exact l4_drainStep s plan hl4

theorem l4_reachable {n : Nat} {s t : Sys n}
    (hl4 : L4Invariant s) (reach : RTC MixedRel s t) : L4Invariant t := by
  induction reach with
  | refl => exact hl4
  | tail reach hstep ih =>
      exact l4_mixed_step hstep ih

theorem reachable_deadlock_absorbing {n : Nat} (s t : Sys n)
    (hd : deadlocked s) (reach : RTC StepRel s t) :
    t = s := by
  induction reach with
  | refl => rfl
  | tail reach st ih =>
      rcases st with ⟨plan, hstep⟩
      subst hstep
      subst ih
      apply step_deadlocked_fixed
      exact hd.left

end IsoConserve
