import IsoConserve.Reachable

namespace IsoConserve
namespace Noether

def ConservedBy {State : Sort u} {Charge : Type v}
    (R : State -> State -> Prop) (charge : State -> Charge) : Prop :=
  forall {s t}, R s t -> charge t = charge s

def StutterRel {State : Sort u} (R : State -> State -> Prop) :
    State -> State -> Prop :=
  fun s t => s = t \/ R s t

def ClockFreeInvariant {State : Sort u} {Charge : Type v}
    (R : State -> State -> Prop) (charge : State -> Charge) : Prop :=
  forall {s t}, RTC (StutterRel R) s t -> charge t = charge s

theorem conservedBy_rtc {State : Sort u} {Charge : Type v}
    {R : State -> State -> Prop} {charge : State -> Charge}
    (h : ConservedBy R charge) :
    forall {s t}, RTC R s t -> charge t = charge s := by
  intro s t reach
  induction reach with
  | refl =>
      rfl
  | tail reach step ih =>
      exact Eq.trans (h step) ih

theorem conservedBy_stutter {State : Sort u} {Charge : Type v}
    {R : State -> State -> Prop} {charge : State -> Charge}
    (h : ConservedBy R charge) :
    ConservedBy (StutterRel R) charge := by
  intro s t step
  cases step with
  | inl hsame =>
      cases hsame
      rfl
  | inr hstep =>
      exact h hstep

theorem conservedBy_comp {State : Sort u} {Charge : Type v} {Other : Type w}
    {R : State -> State -> Prop} {charge : State -> Charge}
    (h : ConservedBy R charge) (f : Charge -> Other) :
    ConservedBy R (fun s => f (charge s)) := by
  intro s t step
  exact congrArg f (h step)

theorem constant_conservedBy {State : Sort u} {Charge : Type v}
    (R : State -> State -> Prop) (c : Charge) :
    ConservedBy R (fun _ : State => c) := by
  intro _s _t _step
  rfl

theorem clockFreeInvariant_iff_conservedBy {State : Sort u} {Charge : Type v}
    (R : State -> State -> Prop) (charge : State -> Charge) :
    ClockFreeInvariant R charge <-> ConservedBy R charge := by
  constructor
  · intro h s t step
    exact h (RTC.tail (RTC.refl s) (Or.inr step))
  · intro h
    intro s t reach
    exact
      conservedBy_rtc
        (R := StutterRel R)
        (charge := charge)
        (conservedBy_stutter (R := R) (charge := charge) h)
        reach

theorem clockFreeInvariant_comp {State : Sort u} {Charge : Type v}
    {Other : Type w} {R : State -> State -> Prop} {charge : State -> Charge}
    (h : ClockFreeInvariant R charge) (f : Charge -> Other) :
    ClockFreeInvariant R (fun s => f (charge s)) := by
  have hc : ConservedBy R charge :=
    (clockFreeInvariant_iff_conservedBy R charge).1 h
  have hcomp : ConservedBy R (fun s => f (charge s)) :=
    conservedBy_comp (R := R) (charge := charge) hc f
  intro s t reach
  exact
    ((clockFreeInvariant_iff_conservedBy R (fun s => f (charge s))).2
      hcomp) reach

theorem constant_clockFreeInvariant {State : Sort u} {Charge : Type v}
    (R : State -> State -> Prop) (c : Charge) :
    ClockFreeInvariant R (fun _ : State => c) := by
  exact
    (clockFreeInvariant_iff_conservedBy R (fun _ : State => c)).2
      (constant_conservedBy R c)

theorem mixedRel_accounted_conserved {n : Nat} :
    ConservedBy (@MixedRel n) (fun s : Sys n => accounted s) := by
  intro s t h
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

theorem mixedRel_accounted_clockFree {n : Nat} :
    ClockFreeInvariant (@MixedRel n) (fun s : Sys n => accounted s) := by
  exact
    (clockFreeInvariant_iff_conservedBy
      (@MixedRel n) (fun s : Sys n => accounted s)).2
      mixedRel_accounted_conserved

theorem mixedRel_accounted_eq_totalQ_under_clockFree {n : Nat}
    {s t : Sys n} (hwf : WF s)
    (reach : RTC (StutterRel (@MixedRel n)) s t) :
    accounted t = s.totalQ := by
  calc
    accounted t = accounted s := mixedRel_accounted_clockFree reach
    _ = s.totalQ := hwf.accounted_eq_total

theorem mixedRel_accounted_postcompose_clockFree {n : Nat} {Other : Type v}
    (f : Qty -> Other) :
    ClockFreeInvariant (@MixedRel n) (fun s : Sys n => f (accounted s)) := by
  exact clockFreeInvariant_comp mixedRel_accounted_clockFree f

theorem mixedRel_constant_clockFree {n : Nat} {Charge : Type v} (c : Charge) :
    ClockFreeInvariant (@MixedRel n) (fun _ : Sys n => c) := by
  exact constant_clockFreeInvariant (@MixedRel n) c

end Noether
end IsoConserve
