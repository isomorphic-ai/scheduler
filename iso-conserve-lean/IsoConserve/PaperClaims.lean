import IsoConserve.BudgetWait
import IsoConserve.Canonical
import IsoConserve.Flexibility
import IsoConserve.Noether
import IsoConserve.PaperInvariants
import IsoConserve.Polarity
import IsoConserve.WaitGraph

namespace IsoConserve
namespace PaperClaims

/-!
Current compiled paper-facing claim surface.

This module exports only aliases or thin corollaries of theorems that already exist
in the checked tree. Review-gated future claims from `04d` through `04j` should be
added here only after their source modules land; no placeholders live in this file.
-/

theorem L1_conservation {n : Nat} (s : Sys n) (plan : FlowPlan s) :
    accounted (step s plan) = accounted s :=
  IsoConserve.L1_conservation s plan

theorem L2_monotonicity {n : Nat} (i : Fin n) (s t : Sys n)
    (hb : s.runnable i = false) (reach : RTC MixedRel s t) :
    (t.procs i).stock <= (s.procs i).stock :=
  IsoConserve.blocked_stock_monotone i s t hb reach

theorem L2_drain_monotonicity {n : Nat} (s : Sys n) (plan : DrainPlan s) :
    convertibleStock (drainStep s plan) <= convertibleStock s :=
  IsoConserve.L2_drain_monotone s plan

theorem L3_absorption {n : Nat} (s : Sys n) (plan : FlowPlan s)
    (hwf : WF s) (h : deadlocked s) :
    deadlocked (step s plan) /\
      totalConverted (step s plan) = totalConverted s :=
  IsoConserve.L3_absorbing s plan hwf h

theorem L3_wait_component_absorption {n m : Nat} {s : WaitGraph.WGState n m}
    {C : WaitGraph.Pid n -> Bool} (k : Nat)
    (hC : WaitGraph.closedWaitSet s C)
    (nonempty : exists p, C p = true) :
    (forall p, C p = true -> ¬ WaitGraph.runnable (WaitGraph.stepN k s) p) /\
      WaitGraph.totalConvertedIn C (WaitGraph.stepN k s) =
        WaitGraph.totalConvertedIn C s :=
  WaitGraph.L3_waitComponent_absorbing_iter k hC nonempty

theorem L4_stock_integral {n : Nat} (s : Sys n)
    (h : L4Invariant s) :
    forall i, (s.procs i).stock + (s.procs i).credit =
      (s.procs i).netFlowIntegral :=
  IsoConserve.L4_stock_is_integral s h

theorem detection_sound {n m : Nat}
    {s0 : BudgetWait.BWState n m} {C : BudgetWait.Pid n -> Bool} {k : Nat}
    (hC0 : BudgetWait.closedWaitSet s0 C)
    (hstart : forall p, C p = true -> (s0.procs p).budget = k)
    (hfloor : BudgetWait.floored (BudgetWait.stepN k s0) C)
    (hwf : BudgetWait.BWWF s0)
    (nonempty : exists p, C p = true) :
    BudgetWait.evidencedDeadlock s0 k C :=
  BudgetWait.detection_sound_with_budget_evidence hC0 hstart hfloor hwf nonempty

theorem detection_complete_bounded {n m : Nat}
    {s0 : BudgetWait.BWState n m} {C : BudgetWait.Pid n -> Bool} {k : Nat}
    (hC0 : BudgetWait.closedWaitSet s0 C)
    (hbound : forall p, C p = true -> (s0.procs p).budget <= k)
    (nonempty : exists p, C p = true) :
    BudgetWait.evidencedDeadlock s0 k C :=
  BudgetWait.closed_wait_set_detected_within_budget hC0 hbound nonempty

theorem resolution_credit_core {n : Nat}
    {s t : Sys n} (reach : RTC YieldRel s t) :
    totalCredit s <= totalCredit t :=
  IsoConserve.credit_monotone_under_yield_reachable reach

theorem canonical_python_step_verified {n : Nat} {s t : Sys n}
    (h : CanonicalPythonStepRel s t) :
    MixedRel s t :=
  IsoConserve.canonicalPythonStepRel_is_mixedRel h

theorem positive_trust_survives_loss {Key Proof : Type}
    (s t : CacheState Key Proof) (reach : RTC (@LossRel Key Proof) s t) :
    trustSubset (trusted t) (trusted s) :=
  IsoConserve.polarity_claim_one s t reach

theorem absence_is_not_evidence :
    exists s t : CacheState Unit Unit,
      LossRel s t /\ negTrusted t () /\ ¬ negTrusted s () :=
  IsoConserve.trust_on_absence_loss_counterexample

theorem clock_free_accounted {n : Nat} :
    Noether.ClockFreeInvariant (@MixedRel n) (fun s : Sys n => accounted s) :=
  Noether.mixedRel_accounted_clockFree

theorem epistemic_invariant {n : Nat} {s t : Sys n}
    (hwf : WF s) (reach : RTC MixedRel s t) :
    accounted t = s.totalQ :=
  IsoConserve.epistemic_invariant hwf reach

theorem alignment_invariant {n : Nat} {s t : Sys n}
    (h : MixedRel s t) (i : Fin n) :
    localAccount s i - localAccount t i =
      outsideAccount t i - outsideAccount s i :=
  IsoConserve.alignment_invariant h i

theorem agency_invariant {n : Nat} {s t : Sys n}
    (h : MixedRel s t) {i : Fin n}
    (hgain : localAccount s i < localAccount t i) :
    outsideAccount t i < outsideAccount s i :=
  IsoConserve.agency_invariant h hgain

theorem flexibility_collapse_whole_invariant
    (s : Flexibility.FlexState) (plan : Flexibility.CollapsePlan s) :
    Flexibility.whole (Flexibility.collapse s plan) = Flexibility.whole s :=
  Flexibility.collapse_whole_invariant s plan

end PaperClaims
end IsoConserve
