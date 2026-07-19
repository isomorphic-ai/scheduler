import IsoConserve.BudgetWait
import IsoConserve.Canonical
import IsoConserve.CoreTrace
import IsoConserve.DetectorProgress
import IsoConserve.Flexibility
import IsoConserve.Noether
import IsoConserve.PaperInvariants
import IsoConserve.PNCounter
import IsoConserve.Polarity
import IsoConserve.RateRouting
import IsoConserve.ResolutionYield
import IsoConserve.TheoremOne
import IsoConserve.WaitGraph

namespace IsoConserve
namespace PaperClaims

noncomputable section

local instance propDecidable (p : Prop) : Decidable p :=
  Classical.propDecidable p

/-!
Compiled paper-facing claim surface.

This module exports only aliases or thin corollaries of theorems that already exist
in the checked tree. The names here are citation-facing; the source theorem remains
the authority for each scope boundary.
-/

theorem L1_conservation {n : Nat} (s : Sys n) (plan : FlowPlan s) :
    accounted (step s plan) = accounted s :=
  IsoConserve.L1_conservation s plan

theorem core_conservation {n m : Nat}
    {s t : CoreTrace.WFState n m} (reach : RTC CoreTrace.CoreRel s t) :
    CoreTrace.accounted t.state = CoreTrace.accounted s.state :=
  CoreTrace.core_reachable_conserves_accounted reach

/- The paper-facing L2 name uses the repaired/restricted reading:
   stock is monotone only along traces that preserve the chosen process's
   blockedness. The unrestricted no-progress statement is false and exported
   below as `unrestricted_l2_is_false`. -/
theorem L2_monotonicity {n m : Nat} (p : CoreTrace.ProcId n)
    {s t : CoreTrace.WFState n m}
    (reach : RTC (CoreTrace.BlockedPreservingRel p) s t) :
    (t.state.procs p).stock <= (s.state.procs p).stock :=
  CoreTrace.blocked_stock_monotone p reach

theorem legacy_blocked_stock_monotonicity {n : Nat} (i : Fin n) (s t : Sys n)
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

theorem core_deadlock_exec_fixed {n m : Nat}
    {s t : CoreTrace.WFState n m} (hd : CoreTrace.Deadlocked s.state)
    (reach : RTC CoreTrace.ExecRel s t) :
    t.state = s.state :=
  CoreTrace.deadlock_exec_fixed hd reach

theorem core_closed_wait_set_absorbing {n m : Nat}
    {s t : CoreTrace.WFState n m} {C : CoreTrace.ProcId n -> Bool}
    (hC : CoreTrace.ClosedDependencySet s.state C)
    (reach : RTC CoreTrace.ExecRel s t) :
    CoreTrace.ClosedDependencySet t.state C :=
  CoreTrace.closed_wait_set_exec_absorbing hC reach

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

theorem core_trace_integral {n m : Nat}
    {initial final : CoreTrace.WFState n m} {trace : CoreTrace.Trace n m}
    (hrun : CoreTrace.Run initial trace final)
    (hzero : forall p,
      (initial.state.procs p).stock + (initial.state.procs p).credit = 0)
    (p : CoreTrace.ProcId n) :
    (final.state.procs p).stock + (final.state.procs p).credit =
      CoreTrace.flowIntegral trace p :=
  CoreTrace.L4_stock_is_trace_integral hrun hzero p

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

theorem detector_sound {n m : Nat} {s : CoreTrace.CoreState n m}
    {C : CoreTrace.ProcId n -> Bool}
    (hfire : DetectorProgress.detectorFires s C) :
    DetectorProgress.GenuineDeadlock s C :=
  DetectorProgress.detector_sound hfire

theorem detection_latency_le_budget {n m : Nat}
    {s : CoreTrace.CoreState n m} {C : CoreTrace.ProcId n -> Bool}
    {schedule : List (CoreTrace.ProcId n)} {k : Nat}
    (hC : DetectorProgress.closedWaitSet s C)
    (hnonempty : exists p, C p = true)
    (hfair : DetectorProgress.memberSelectedAtLeast schedule C k)
    (hcap : forall p, C p = true -> DetectorProgress.budget s p <= k) :
    exists pref,
      DetectorProgress.PrefixOf pref schedule /\
      DetectorProgress.detectorFires
        (DetectorProgress.runSchedule pref s) C :=
  DetectorProgress.detection_latency_le_budget hC hnonempty hfair hcap

theorem live_process_not_detected {n m : Nat}
    {s : CoreTrace.CoreState n m} {schedule : List (CoreTrace.ProcId n)}
    {p : CoreTrace.ProcId n} {C : CoreTrace.ProcId n -> Bool}
    (hcap_pos : 0 < DetectorProgress.budgetCap s p)
    (hbudget0 : DetectorProgress.budget s p = DetectorProgress.budgetCap s p)
    (hlive :
      DetectorProgress.convertsWithinEverySelectionWindow
        s schedule p (DetectorProgress.budgetCap s p))
    (hp : C p = true) :
    forall pref,
      DetectorProgress.PrefixOf pref schedule ->
      ¬ DetectorProgress.detectorFires
        (DetectorProgress.runSchedule pref s) C :=
  DetectorProgress.live_process_not_detected hcap_pos hbudget0 hlive hp

theorem progress_signal_useful_kept
    {p : DetectorProgress.ProgressProc} {reply : Nat}
    (hrise : p.reported < reply) (hcap : 0 < p.budgetCap) :
    (DetectorProgress.sigProgressStep p reply).reclaimed = false :=
  DetectorProgress.useful_reporter_never_reclaimed hrise hcap

theorem progress_signal_spinner_reclaimed
    (p : DetectorProgress.ProgressProc) :
    (DetectorProgress.flatProgressN (p.budget + 1) p).reclaimed = true :=
  DetectorProgress.spinner_eventually_reclaimed p

theorem resolution_credit_core {n : Nat}
    {s t : Sys n} (reach : RTC YieldRel s t) :
    totalCredit s <= totalCredit t :=
  IsoConserve.credit_monotone_under_yield_reachable reach

theorem resolution_yield_conserves {n m : Nat}
    (s : CoreTrace.CoreState n m) (y : CoreTrace.ProcId n) :
    CoreTrace.accounted (ResolutionYield.resolutionYield s y) =
      CoreTrace.accounted s :=
  ResolutionYield.resolution_yield_conserves s y

theorem resolution_yield_loses_no_work {n m : Nat}
    (s : CoreTrace.CoreState n m) (y : CoreTrace.ProcId n) :
    CoreTrace.procAccounted (ResolutionYield.resolutionYield s y).convertCost
        ((ResolutionYield.resolutionYield s y).procs y) =
      CoreTrace.procAccounted s.convertCost (s.procs y) :=
  ResolutionYield.resolution_yield_loses_no_accounted_work s y

theorem resolution_yield_breaks_closed_component {n m : Nat}
    {s : CoreTrace.CoreState n m} {C : CoreTrace.ProcId n -> Bool}
    {y w : CoreTrace.ProcId n} {l : CoreTrace.LockId m}
    (hC : DetectorProgress.closedWaitSet s C)
    (hw : ResolutionYield.ReleaseWitness s C y w l)
    (honly : forall q, C q = true -> CoreTrace.blockedOn s w q -> q = y) :
    ¬ DetectorProgress.closedWaitSet (ResolutionYield.resolutionYield s y) C :=
  ResolutionYield.yield_breaks_closed_component hC hw honly

theorem canonical_python_step_verified {n : Nat} {s t : Sys n}
    (h : CanonicalPythonStepRel s t) :
    MixedRel s t :=
  IsoConserve.canonicalPythonStepRel_is_mixedRel h

theorem routed_rate_conserved {n m : Nat}
    (s : CoreTrace.CoreState n m) (hwf : CoreTrace.CoreWF s) :
    sumFin (fun r =>
      if CoreTrace.runnable s r then RateRouting.routedRate s r else 0) +
        RateRouting.strandedRate s =
      RateRouting.liveBaseRate s :=
  RateRouting.routed_rate_conserved s hwf

theorem effective_rate_eq_base_plus_waiters {n m : Nat}
    {s : CoreTrace.CoreState n m} {p : CoreTrace.ProcId n}
    (hlivep : CoreTrace.unfinished s p)
    (hacyclic : RateRouting.acyclicFrom s p) :
    RateRouting.effectiveRate s p =
      RateRouting.baseRate s p +
        sumFin (fun w =>
          if RateRouting.immediateWaiter s w p then
            RateRouting.effectiveRate s w
          else
            0) :=
  RateRouting.effective_rate_eq_base_plus_waiters hlivep hacyclic

theorem transitive_rate_routing {n m : Nat}
    {s : CoreTrace.CoreState n m} {w p r : CoreTrace.ProcId n}
    {fuel : Nat}
    (hwait : RateRouting.waitsOn s w = some p)
    (hlive : CoreTrace.unfinished s w)
    (hnotrun : ¬ CoreTrace.runnable s w)
    (hdest : RateRouting.destination s fuel p = some r) :
    RateRouting.destination s (fuel + 1) w = some r :=
  RateRouting.transitive_rate_routing hwait hlive hnotrun hdest

theorem multiple_waiters_sum_not_max {n m : Nat}
    {s : CoreTrace.CoreState n m} {w1 w2 h : CoreTrace.ProcId n}
    (hw1 : RateRouting.waitsOn s w1 = some h)
    (hw2 : RateRouting.waitsOn s w2 = some h)
    (hlive1 : CoreTrace.unfinished s w1)
    (hlive2 : CoreTrace.unfinished s w2)
    (hne : w1 ≠ w2)
    (hwf : CoreTrace.CoreWF s) :
    RateRouting.baseRate s w1 + RateRouting.baseRate s w2 <=
      RateRouting.effectiveRate s h :=
  RateRouting.multiple_waiters_sum_not_max hw1 hw2 hlive1 hlive2 hne hwf

theorem priority_inversion_cannot_form :
    RateRouting.share RateRouting.pathfinderState 1 RateRouting.low >=
      RateRouting.share RateRouting.pathfinderState 1 RateRouting.medium :=
  RateRouting.canonical_priority_inversion_cannot_form

theorem pathfinder_low_share_eq_ten_thirteenths :
    RateRouting.share RateRouting.pathfinderState 1 RateRouting.low =
      (10 : Qty) / 13 :=
  RateRouting.pathfinder_low_share_eq_ten_thirteenths

theorem pathfinder_medium_share_eq_three_thirteenths :
    RateRouting.share RateRouting.pathfinderState 1 RateRouting.medium =
      (3 : Qty) / 13 :=
  RateRouting.pathfinder_medium_share_eq_three_thirteenths

theorem no_stored_boost_state {n m : Nat}
    {s t : CoreTrace.CoreState n m}
    (hgraph : RateRouting.sameWaitGraph s t)
    (hdest : forall p,
      RateRouting.finalDestination s p = RateRouting.finalDestination t p)
    (hrate : forall p, RateRouting.baseRate s p = RateRouting.baseRate t p) :
    forall p, RateRouting.routedRate s p = RateRouting.routedRate t p :=
  RateRouting.no_stored_boost_state hgraph hdest hrate

theorem pn_counter_merge_converges {n : Nat} (t : PNCounter.MergeTree n) :
    PNCounter.eval t = PNCounter.globalRecorded (PNCounter.leaves t) :=
  PNCounter.eval_eq_globalRecorded t

theorem pn_counter_debt_surfaces {n : Nat}
    {xs : List (PNCounter.Counter n)} {x : PNCounter.Counter n}
    {i : PNCounter.Node n} {amount : Nat}
    (hmem : x ∈ xs) (hdebt : amount <= x.neg i) :
    amount <= (PNCounter.globalRecorded xs).neg i :=
  PNCounter.off_partition_decrement_surfaces hmem hdebt

theorem pn_counter_merge_assoc {n : Nat}
    (a b c : PNCounter.Counter n) :
    PNCounter.merge (PNCounter.merge a b) c =
      PNCounter.merge a (PNCounter.merge b c) :=
  PNCounter.merge_assoc a b c

theorem positive_trust_survives_loss {Key Proof : Type}
    (s t : CacheState Key Proof) (reach : RTC (@LossRel Key Proof) s t) :
    trustSubset (trusted t) (trusted s) :=
  IsoConserve.polarity_claim_one s t reach

theorem absence_is_not_evidence :
    exists s t : CacheState Unit Unit,
      LossRel s t /\ negTrusted t () /\ ¬ negTrusted s () :=
  IsoConserve.trust_on_absence_loss_counterexample

theorem unrestricted_l2_is_false :
    exists s t : CoreTrace.CoreState 1 0,
      CoreTrace.totalConverted t = CoreTrace.totalConverted s /\
        CoreTrace.convertibleStock s < CoreTrace.convertibleStock t :=
  CoreTrace.unrestricted_l2_is_false

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

theorem collapse_whole_invariant
    (s : Flexibility.FlexState) (plan : Flexibility.CollapsePlan s) :
    Flexibility.whole (Flexibility.collapse s plan) = Flexibility.whole s :=
  Flexibility.collapse_whole_invariant s plan

theorem flexibility_collapse_whole_invariant
    (s : Flexibility.FlexState) (plan : Flexibility.CollapsePlan s) :
    Flexibility.whole (Flexibility.collapse s plan) = Flexibility.whole s :=
  collapse_whole_invariant s plan

theorem hoarding_is_self_defeating {n m : Nat}
    {s : CoreTrace.CoreState n m} {i j : CoreTrace.ProcId n} {q : Qty}
    (hq : 0 < q)
    (hstranded : TheoremOne.StrandedClaim s i q)
    (hcan : TheoremOne.CanConvertQty s j q)
    (hreturn : TheoremOne.DependencyReturn s i j) :
    TheoremOne.ownConversion i
        (TheoremOne.applyAction s (TheoremOne.Action.route i j q)) >
      TheoremOne.ownConversion i
        (TheoremOne.applyAction s (TheoremOne.Action.hoard i q)) :=
  TheoremOne.hoarding_is_self_defeating hq hstranded hcan hreturn

theorem selfish_optima_eq_generous_optima {n m : Nat}
    {s : CoreTrace.CoreState n m} {i j : CoreTrace.ProcId n} {q : Qty}
    (hstranded : TheoremOne.StrandedClaim s i q)
    (hcan : TheoremOne.CanConvertQty s j q)
    (hreturn : TheoremOne.DependencyReturn s i j) :
    TheoremOne.SelfishBestInClaimSet s i j q TheoremOne.ClaimChoice.route /\
      TheoremOne.GenerousBestInClaimSet s i j q TheoremOne.ClaimChoice.route :=
  TheoremOne.selfish_optima_eq_generous_optima hstranded hcan hreturn

theorem debt_sums_to_zero {n : Nat} (d : TheoremOne.DebtLedger n) :
    TheoremOne.globalNetDebt d = 0 :=
  TheoremOne.global_debt_sums_to_zero d

end
end PaperClaims
end IsoConserve
