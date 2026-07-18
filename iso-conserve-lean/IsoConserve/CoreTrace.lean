import IsoConserve.Reachable

namespace IsoConserve
namespace CoreTrace

noncomputable section

local instance propDecidable (p : Prop) : Decidable p :=
  Classical.propDecidable p

abbrev ProcId (n : Nat) := Fin n
abbrev LockId (m : Nat) := Fin m

structure CoreProc (m : Nat) where
  baseRate : Qty
  stock : Qty
  credit : Qty
  convertedTotal : Nat
  convertedSinceRestart : Nat
  workNeeded : Nat
  pc : Nat
  wants : Option (LockId m)
  budget : Nat
  budgetCap : Nat
  done : Bool
deriving Repr

structure CoreState (n m : Nat) where
  procs : ProcId n -> CoreProc m
  holds : ProcId n -> LockId m -> Bool
  reserve : Qty
  convertCost : Qty
  totalQ : Qty

def procAccounted (cost : Qty) (p : CoreProc m) : Qty :=
  p.stock + p.credit + cost * (p.convertedSinceRestart : Qty)

def accounted {n m : Nat} (s : CoreState n m) : Qty :=
  s.reserve + sumFin (fun p => procAccounted s.convertCost (s.procs p))

def heldBy {n m : Nat} (s : CoreState n m) (l : LockId m)
    (p : ProcId n) : Prop :=
  s.holds p l = true

def blockedOn {n m : Nat} (s : CoreState n m) (p q : ProcId n) : Prop :=
  exists l, (s.procs p).wants = some l /\ s.holds q l = true /\ q != p

def blocked {n m : Nat} (s : CoreState n m) (p : ProcId n) : Prop :=
  exists q, blockedOn s p q

def runnable {n m : Nat} (s : CoreState n m) (p : ProcId n) : Prop :=
  (s.procs p).done = false /\ ¬ blocked s p

def unfinished {n m : Nat} (s : CoreState n m) (p : ProcId n) : Prop :=
  (s.procs p).done = false /\ (s.procs p).convertedTotal < (s.procs p).workNeeded

def canConvert {n m : Nat} (s : CoreState n m) (p : ProcId n) : Prop :=
  runnable s p /\ unfinished s p /\ s.convertCost <= (s.procs p).stock

def ClosedDependencySet {n m : Nat} (s : CoreState n m)
    (C : ProcId n -> Bool) : Prop :=
  forall p, C p = true ->
    unfinished s p /\ exists q, C q = true /\ blockedOn s p q

def closedDependencySet {n m : Nat} := @ClosedDependencySet n m

def strandedClaim {n m : Nat} (s : CoreState n m) (p : ProcId n) : Prop :=
  0 < (s.procs p).stock /\ ¬ canConvert s p

def allDone {n m : Nat} (s : CoreState n m) : Prop :=
  forall p, (s.procs p).done = true

def atTableEmpty {n m : Nat} (s : CoreState n m) : Prop :=
  forall p, ¬ runnable s p

def Deadlocked {n m : Nat} (s : CoreState n m) : Prop :=
  atTableEmpty s /\ ¬ allDone s

def totalConverted {n m : Nat} (s : CoreState n m) : Qty :=
  sumFin (fun p => ((s.procs p).convertedTotal : Qty))

def totalConvertedIn {n m : Nat} (C : ProcId n -> Bool)
    (s : CoreState n m) : Qty :=
  sumFin (fun p => if C p then ((s.procs p).convertedTotal : Qty) else 0)

def convertibleStock {n m : Nat} (s : CoreState n m) : Qty :=
  sumFin (fun p => if runnable s p then (s.procs p).stock else 0)

structure CoreWF {n m : Nat} (s : CoreState n m) : Prop where
  cost_pos : 0 < s.convertCost
  reserve_nonneg : 0 <= s.reserve
  stock_nonneg : forall p, 0 <= (s.procs p).stock
  credit_nonneg : forall p, 0 <= (s.procs p).credit
  rate_nonneg : forall p, 0 <= (s.procs p).baseRate
  budget_le_cap : forall p, (s.procs p).budget <= (s.procs p).budgetCap
  since_le_total :
    forall p, (s.procs p).convertedSinceRestart <= (s.procs p).convertedTotal
  done_holds_nothing :
    forall p l, (s.procs p).done = true -> s.holds p l = false
  accounted_eq_total : accounted s = s.totalQ

structure WFState (n m : Nat) where
  state : CoreState n m
  wf : CoreWF state

structure WorkPlan {n m : Nat} (s : CoreState n m) where
  flow : ProcId n -> Qty
  convert : ProcId n -> Nat
  flow_nonneg : forall p, 0 <= flow p
  flow_only_runnable : forall p, ¬ runnable s p -> flow p = 0
  convert_only_canConvert : forall p, ¬ canConvert s p -> convert p = 0
  reserve_after_nonneg : 0 <= s.reserve - sumFin flow
  stock_after_nonneg : forall p,
    0 <= (s.procs p).stock + flow p -
      s.convertCost * (convert p : Qty)

def doneAfterWork {n m : Nat} (s : CoreState n m)
    (plan : WorkPlan s) (p : ProcId n) : Bool :=
  if (s.procs p).done then
    true
  else if 0 < plan.convert p /\
      (s.procs p).workNeeded <= (s.procs p).convertedTotal + plan.convert p then
    true
  else
    false

def workProc {n m : Nat} (s : CoreState n m)
    (plan : WorkPlan s) (p : ProcId n) : CoreProc m :=
  let old := s.procs p
  { old with
    stock := old.stock + plan.flow p -
      s.convertCost * (plan.convert p : Qty)
    convertedTotal := old.convertedTotal + plan.convert p
    convertedSinceRestart := old.convertedSinceRestart + plan.convert p
    budget := if 0 < plan.convert p then old.budgetCap else old.budget
    done := doneAfterWork s plan p }

def workStep {n m : Nat} (s : CoreState n m) (plan : WorkPlan s) :
    CoreState n m :=
  { procs := fun p => workProc s plan p
    holds := s.holds
    reserve := s.reserve - sumFin plan.flow
    convertCost := s.convertCost
    totalQ := s.totalQ }

theorem procAccounted_workProc {n m : Nat} (s : CoreState n m)
    (plan : WorkPlan s) (p : ProcId n) :
    procAccounted s.convertCost (workProc s plan p) =
      procAccounted s.convertCost (s.procs p) + plan.flow p := by
  unfold procAccounted workProc
  grind

theorem work_conservation {n m : Nat} (s : CoreState n m)
    (plan : WorkPlan s) :
    accounted (workStep s plan) = accounted s := by
  unfold accounted workStep
  have hsum :
      sumFin (fun p =>
        procAccounted s.convertCost (workProc s plan p)) =
        sumFin (fun p =>
          procAccounted s.convertCost (s.procs p)) +
          sumFin plan.flow := by
    calc
      sumFin (fun p =>
          procAccounted s.convertCost (workProc s plan p)) =
          sumFin (fun p =>
            procAccounted s.convertCost (s.procs p) + plan.flow p) := by
            apply sumFin_congr
            intro p
            exact procAccounted_workProc s plan p
      _ = sumFin (fun p => procAccounted s.convertCost (s.procs p)) +
            sumFin plan.flow := by
            exact sumFin_add
              (fun p => procAccounted s.convertCost (s.procs p))
              plan.flow
  grind

structure DrainPlan {n m : Nat} (s : CoreState n m) where
  amount : ProcId n -> Qty
  amount_nonneg : forall p, 0 <= amount p
  stock_after_nonneg : forall p, 0 <= (s.procs p).stock - amount p

def drainProc {n m : Nat} (s : CoreState n m)
    (plan : DrainPlan s) (p : ProcId n) : CoreProc m :=
  let old := s.procs p
  { old with stock := old.stock - plan.amount p }

def drainStep {n m : Nat} (s : CoreState n m) (plan : DrainPlan s) :
    CoreState n m :=
  { procs := fun p => drainProc s plan p
    holds := s.holds
    reserve := s.reserve + sumFin plan.amount
    convertCost := s.convertCost
    totalQ := s.totalQ }

theorem procAccounted_drainProc {n m : Nat} (s : CoreState n m)
    (plan : DrainPlan s) (p : ProcId n) :
    procAccounted s.convertCost (drainProc s plan p) =
      procAccounted s.convertCost (s.procs p) - plan.amount p := by
  unfold procAccounted drainProc
  grind

theorem drain_conservation {n m : Nat} (s : CoreState n m)
    (plan : DrainPlan s) :
    accounted (drainStep s plan) = accounted s := by
  unfold accounted drainStep
  have hsum :
      sumFin (fun p =>
        procAccounted s.convertCost (drainProc s plan p)) =
        sumFin (fun p =>
          procAccounted s.convertCost (s.procs p)) -
          sumFin plan.amount := by
    calc
      sumFin (fun p =>
          procAccounted s.convertCost (drainProc s plan p)) =
          sumFin (fun p =>
            procAccounted s.convertCost (s.procs p) - plan.amount p) := by
            apply sumFin_congr
            intro p
            exact procAccounted_drainProc s plan p
      _ = sumFin (fun p => procAccounted s.convertCost (s.procs p)) -
            sumFin plan.amount := by
            exact sumFin_sub
              (fun p => procAccounted s.convertCost (s.procs p))
              plan.amount
  grind

structure YieldPlan {n m : Nat} (s : CoreState n m) where
  amount : ProcId n -> Qty
  amount_nonneg : forall p, 0 <= amount p
  stock_after_nonneg : forall p, 0 <= (s.procs p).stock - amount p

def yieldProc {n m : Nat} (s : CoreState n m)
    (plan : YieldPlan s) (p : ProcId n) : CoreProc m :=
  let old := s.procs p
  { old with
    stock := old.stock - plan.amount p
    credit := old.credit + plan.amount p }

def yieldStep {n m : Nat} (s : CoreState n m) (plan : YieldPlan s) :
    CoreState n m :=
  { procs := fun p => yieldProc s plan p
    holds := s.holds
    reserve := s.reserve
    convertCost := s.convertCost
    totalQ := s.totalQ }

theorem procAccounted_yieldProc {n m : Nat} (s : CoreState n m)
    (plan : YieldPlan s) (p : ProcId n) :
    procAccounted s.convertCost (yieldProc s plan p) =
      procAccounted s.convertCost (s.procs p) := by
  unfold procAccounted yieldProc
  grind

theorem yield_conservation {n m : Nat} (s : CoreState n m)
    (plan : YieldPlan s) :
    accounted (yieldStep s plan) = accounted s := by
  unfold accounted yieldStep
  apply congrArg (fun x => s.reserve + x)
  apply sumFin_congr
  intro p
  exact procAccounted_yieldProc s plan p

structure RoutePlan {n m : Nat} (s : CoreState n m) where
  delta : ProcId n -> Qty
  sum_delta_zero : sumFin delta = 0
  stock_after_nonneg : forall p, 0 <= (s.procs p).stock + delta p
  delta_blocked_nonpos : forall p, blocked s p -> delta p <= 0

def routeProc {n m : Nat} (s : CoreState n m)
    (plan : RoutePlan s) (p : ProcId n) : CoreProc m :=
  let old := s.procs p
  { old with stock := old.stock + plan.delta p }

def routeStep {n m : Nat} (s : CoreState n m) (plan : RoutePlan s) :
    CoreState n m :=
  { procs := fun p => routeProc s plan p
    holds := s.holds
    reserve := s.reserve
    convertCost := s.convertCost
    totalQ := s.totalQ }

theorem procAccounted_routeProc {n m : Nat} (s : CoreState n m)
    (plan : RoutePlan s) (p : ProcId n) :
    procAccounted s.convertCost (routeProc s plan p) =
      procAccounted s.convertCost (s.procs p) + plan.delta p := by
  unfold procAccounted routeProc
  grind

theorem route_conservation {n m : Nat} (s : CoreState n m)
    (plan : RoutePlan s) :
    accounted (routeStep s plan) = accounted s := by
  unfold accounted routeStep
  have hsum :
      sumFin (fun p =>
        procAccounted s.convertCost (routeProc s plan p)) =
        sumFin (fun p =>
          procAccounted s.convertCost (s.procs p)) +
          sumFin plan.delta := by
    calc
      sumFin (fun p =>
          procAccounted s.convertCost (routeProc s plan p)) =
          sumFin (fun p =>
            procAccounted s.convertCost (s.procs p) + plan.delta p) := by
            apply sumFin_congr
            intro p
            exact procAccounted_routeProc s plan p
      _ = sumFin (fun p => procAccounted s.convertCost (s.procs p)) +
            sumFin plan.delta := by
            exact sumFin_add
              (fun p => procAccounted s.convertCost (s.procs p))
              plan.delta
  rw [hsum, plan.sum_delta_zero]
  grind

def acquireStep {n m : Nat} (s : CoreState n m)
    (p : ProcId n) (l : LockId m) : CoreState n m :=
  { s with
    procs := fun q => if q = p then { s.procs q with wants := none } else s.procs q
    holds := fun q k => if q = p /\ k = l then true else s.holds q k }

def releaseStep {n m : Nat} (s : CoreState n m)
    (p : ProcId n) (l : LockId m) : CoreState n m :=
  { s with holds := fun q k => if q = p /\ k = l then false else s.holds q k }

theorem acquire_conservation {n m : Nat} (s : CoreState n m)
    (p : ProcId n) (l : LockId m) :
    accounted (acquireStep s p l) = accounted s := by
  unfold accounted acquireStep procAccounted
  apply congrArg (fun x => s.reserve + x)
  apply sumFin_congr
  intro q
  by_cases hq : q = p
  · simp [hq]
  · simp [hq]

theorem release_conservation {n m : Nat} (s : CoreState n m)
    (p : ProcId n) (l : LockId m) :
    accounted (releaseStep s p l) = accounted s := by
  rfl

def WorkRel {n m : Nat} (s t : WFState n m) : Prop :=
  exists plan : WorkPlan s.state, t.state = workStep s.state plan

def ExecAcquireRel {n m : Nat} (s t : WFState n m) : Prop :=
  exists p l, runnable s.state p /\ (forall q, s.state.holds q l = false) /\
    t.state = acquireStep s.state p l

def ExecReleaseRel {n m : Nat} (s t : WFState n m) : Prop :=
  exists p l, runnable s.state p /\ t.state = releaseStep s.state p l

def ExecFlowRel {n m : Nat} := @WorkRel n m

def ExecRel {n m : Nat} (s t : WFState n m) : Prop :=
  WorkRel s t \/ ExecAcquireRel s t \/ ExecReleaseRel s t

def DrainRel {n m : Nat} (s t : WFState n m) : Prop :=
  exists plan : DrainPlan s.state, t.state = drainStep s.state plan

def YieldRel {n m : Nat} (s t : WFState n m) : Prop :=
  exists plan : YieldPlan s.state, t.state = yieldStep s.state plan

def RouteRel {n m : Nat} (s t : WFState n m) : Prop :=
  exists plan : RoutePlan s.state, t.state = routeStep s.state plan

def ReleaseClaimRel {n m : Nat} (s t : WFState n m) : Prop :=
  exists p l, t.state = releaseStep s.state p l

def CureRel {n m : Nat} (s t : WFState n m) : Prop :=
  DrainRel s t \/ YieldRel s t \/ RouteRel s t \/ ReleaseClaimRel s t

def CoreRel {n m : Nat} (s t : WFState n m) : Prop :=
  ExecRel s t \/ CureRel s t

theorem exec_step_conserves_accounted {n m : Nat} {s t : WFState n m}
    (h : ExecRel s t) : accounted t.state = accounted s.state := by
  rcases h with hwork | hacq | hrel
  · rcases hwork with ⟨plan, ht⟩
    rw [ht]
    exact work_conservation s.state plan
  · rcases hacq with ⟨p, l, _hrun, _hfree, ht⟩
    rw [ht]
    exact acquire_conservation s.state p l
  · rcases hrel with ⟨p, l, _hrun, ht⟩
    rw [ht]
    exact release_conservation s.state p l

theorem cure_preserves_accounted {n m : Nat} {s t : WFState n m}
    (h : CureRel s t) : accounted t.state = accounted s.state := by
  rcases h with hdrain | hyield | hroute | hrelease
  · rcases hdrain with ⟨plan, ht⟩
    rw [ht]
    exact drain_conservation s.state plan
  · rcases hyield with ⟨plan, ht⟩
    rw [ht]
    exact yield_conservation s.state plan
  · rcases hroute with ⟨plan, ht⟩
    rw [ht]
    exact route_conservation s.state plan
  · rcases hrelease with ⟨p, l, ht⟩
    rw [ht]
    exact release_conservation s.state p l

theorem core_step_conserves_accounted {n m : Nat} {s t : WFState n m} :
    CoreRel s t -> accounted t.state = accounted s.state := by
  intro h
  cases h with
  | inl hexec => exact exec_step_conserves_accounted hexec
  | inr hcure => exact cure_preserves_accounted hcure

theorem core_step_preserves_totalQ {n m : Nat} {s t : WFState n m}
    (h : CoreRel s t) : t.state.totalQ = s.state.totalQ := by
  rcases h with hexec | hcure
  · rcases hexec with hwork | hacq | hrel
    · rcases hwork with ⟨plan, ht⟩
      rw [ht]
      rfl
    · rcases hacq with ⟨p, l, _hrun, _hfree, ht⟩
      rw [ht]
      rfl
    · rcases hrel with ⟨p, l, _hrun, ht⟩
      rw [ht]
      rfl
  · rcases hcure with hdrain | hyield | hroute | hrelease
    · rcases hdrain with ⟨plan, ht⟩
      rw [ht]
      rfl
    · rcases hyield with ⟨plan, ht⟩
      rw [ht]
      rfl
    · rcases hroute with ⟨plan, ht⟩
      rw [ht]
      rfl
    · rcases hrelease with ⟨p, l, ht⟩
      rw [ht]
      rfl

theorem core_reachable_conserves_accounted {n m : Nat}
    {s t : WFState n m} (reach : RTC CoreRel s t) :
    accounted t.state = accounted s.state := by
  induction reach with
  | refl => rfl
  | tail reach hstep ih =>
      calc
        accounted _ = accounted _ := core_step_conserves_accounted hstep
        _ = accounted s.state := ih

theorem core_reachable_preserves_totalQ {n m : Nat}
    {s t : WFState n m} (reach : RTC CoreRel s t) :
    t.state.totalQ = s.state.totalQ := by
  induction reach with
  | refl => rfl
  | tail reach hstep ih =>
      calc
        _ = _ := core_step_preserves_totalQ hstep
        _ = s.state.totalQ := ih

def NoProgressRel {n m : Nat} (s t : WFState n m) : Prop :=
  DrainRel s t \/ YieldRel s t

theorem runnable_drainStep {n m : Nat} (s : CoreState n m)
    (plan : DrainPlan s) (p : ProcId n) :
    runnable (drainStep s plan) p ↔ runnable s p := by
  unfold runnable blocked blockedOn drainStep drainProc
  simp

theorem runnable_yieldStep {n m : Nat} (s : CoreState n m)
    (plan : YieldPlan s) (p : ProcId n) :
    runnable (yieldStep s plan) p ↔ runnable s p := by
  unfold runnable blocked blockedOn yieldStep yieldProc
  simp

theorem convertibleStock_drainStep_le {n m : Nat} (s : CoreState n m)
    (plan : DrainPlan s) :
    convertibleStock (drainStep s plan) <= convertibleStock s := by
  unfold convertibleStock
  apply sumFin_le
  intro p
  by_cases hr : runnable s p
  · have hrt : runnable (drainStep s plan) p := (runnable_drainStep s plan p).2 hr
    have ha := plan.amount_nonneg p
    have hle :
        (s.procs p).stock - plan.amount p <= (s.procs p).stock := by
      grind
    simpa [hr, hrt] using hle
  · have hrt : ¬ runnable (drainStep s plan) p := by
      intro h
      exact hr ((runnable_drainStep s plan p).1 h)
    simp [hr, hrt]

theorem convertibleStock_yieldStep_le {n m : Nat} (s : CoreState n m)
    (plan : YieldPlan s) :
    convertibleStock (yieldStep s plan) <= convertibleStock s := by
  unfold convertibleStock
  apply sumFin_le
  intro p
  by_cases hr : runnable s p
  · have hrt : runnable (yieldStep s plan) p := (runnable_yieldStep s plan p).2 hr
    have ha := plan.amount_nonneg p
    have hle :
        (s.procs p).stock - plan.amount p <= (s.procs p).stock := by
      grind
    simpa [hr, hrt] using hle
  · have hrt : ¬ runnable (yieldStep s plan) p := by
      intro h
      exact hr ((runnable_yieldStep s plan p).1 h)
    simp [hr, hrt]

theorem noProgress_step_convertibleStock_le {n m : Nat}
    {s t : WFState n m} (h : NoProgressRel s t) :
    convertibleStock t.state <= convertibleStock s.state := by
  rcases h with hdrain | hyield
  · rcases hdrain with ⟨plan, ht⟩
    rw [ht]
    exact convertibleStock_drainStep_le s.state plan
  · rcases hyield with ⟨plan, ht⟩
    rw [ht]
    exact convertibleStock_yieldStep_le s.state plan

theorem no_progress_convertible_stock_monotone {n m : Nat}
    {s t : WFState n m} (reach : RTC NoProgressRel s t) :
    convertibleStock t.state <= convertibleStock s.state := by
  apply monotone_under_adversary
    (le := fun a b : Qty => a <= b)
    (leRefl := fun a => by grind)
    (leTrans := by
      intro a b c hab hbc
      grind)
    (E := NoProgressRel)
    (f := fun s => convertibleStock s.state)
  · intro s t hstep
    exact noProgress_step_convertibleStock_le hstep
  · exact reach

theorem canConvert_false_of_blocked {n m : Nat} {s : CoreState n m}
    {p : ProcId n} (hb : blocked s p) :
    ¬ canConvert s p := by
  intro hc
  exact hc.1.2 hb

theorem not_runnable_of_blocked {n m : Nat} {s : CoreState n m}
    {p : ProcId n} (hb : blocked s p) :
    ¬ runnable s p := by
  intro hr
  exact hr.2 hb

theorem workStep_stock_eq_of_blocked {n m : Nat} {s : CoreState n m}
    (plan : WorkPlan s) {p : ProcId n} (hb : blocked s p) :
    ((workStep s plan).procs p).stock = (s.procs p).stock := by
  unfold workStep workProc
  have hflow := plan.flow_only_runnable p (not_runnable_of_blocked hb)
  have hconv := plan.convert_only_canConvert p (canConvert_false_of_blocked hb)
  simp [hflow, hconv]
  grind

theorem drainStep_stock_le_of_blocked {n m : Nat} {s : CoreState n m}
    (plan : DrainPlan s) {p : ProcId n} (_hb : blocked s p) :
    ((drainStep s plan).procs p).stock <= (s.procs p).stock := by
  unfold drainStep drainProc
  have ha := plan.amount_nonneg p
  grind

theorem yieldStep_stock_le_of_blocked {n m : Nat} {s : CoreState n m}
    (plan : YieldPlan s) {p : ProcId n} (_hb : blocked s p) :
    ((yieldStep s plan).procs p).stock <= (s.procs p).stock := by
  unfold yieldStep yieldProc
  have ha := plan.amount_nonneg p
  grind

theorem routeStep_stock_le_of_blocked {n m : Nat} {s : CoreState n m}
    (plan : RoutePlan s) {p : ProcId n} (hb : blocked s p) :
    ((routeStep s plan).procs p).stock <= (s.procs p).stock := by
  unfold routeStep routeProc
  have hd := plan.delta_blocked_nonpos p hb
  grind

theorem acquireStep_stock_eq {n m : Nat} (s : CoreState n m)
    (a : ProcId n) (l : LockId m) (p : ProcId n) :
    ((acquireStep s a l).procs p).stock = (s.procs p).stock := by
  unfold acquireStep
  by_cases hp : p = a
  · simp [hp]
  · simp [hp]

theorem releaseStep_stock_eq {n m : Nat} (s : CoreState n m)
    (a : ProcId n) (l : LockId m) (p : ProcId n) :
    ((releaseStep s a l).procs p).stock = (s.procs p).stock := by
  rfl

theorem core_step_blocked_stock_le {n m : Nat} {s t : WFState n m}
    (p : ProcId n) (hb : blocked s.state p) (h : CoreRel s t) :
    (t.state.procs p).stock <= (s.state.procs p).stock := by
  rcases h with hexec | hcure
  · rcases hexec with hwork | hacq | hrel
    · rcases hwork with ⟨plan, ht⟩
      rw [ht, workStep_stock_eq_of_blocked plan hb]
      grind
    · rcases hacq with ⟨a, l, _hrun, _hfree, ht⟩
      rw [ht, acquireStep_stock_eq s.state a l p]
      grind
    · rcases hrel with ⟨a, l, _hrun, ht⟩
      rw [ht, releaseStep_stock_eq s.state a l p]
      grind
  · rcases hcure with hdrain | hyield | hroute | hrelease
    · rcases hdrain with ⟨plan, ht⟩
      rw [ht]
      exact drainStep_stock_le_of_blocked plan hb
    · rcases hyield with ⟨plan, ht⟩
      rw [ht]
      exact yieldStep_stock_le_of_blocked plan hb
    · rcases hroute with ⟨plan, ht⟩
      rw [ht]
      exact routeStep_stock_le_of_blocked plan hb
    · rcases hrelease with ⟨a, l, ht⟩
      rw [ht, releaseStep_stock_eq s.state a l p]
      grind

def BlockedPreservingRel {n m : Nat} (p : ProcId n)
    (s t : WFState n m) : Prop :=
  CoreRel s t /\ blocked s.state p /\ blocked t.state p

theorem blocked_stock_monotone {n m : Nat} (p : ProcId n)
    {s t : WFState n m} (reach : RTC (BlockedPreservingRel p) s t) :
    (t.state.procs p).stock <= (s.state.procs p).stock := by
  apply monotone_under_adversary
    (le := fun a b : Qty => a <= b)
    (leRefl := fun a => by grind)
    (leTrans := by
      intro a b c hab hbc
      grind)
    (E := BlockedPreservingRel p)
    (f := fun s => (s.state.procs p).stock)
  · intro s t hstep
    exact core_step_blocked_stock_le p hstep.2.1 hstep.1
  · exact reach

theorem flow_leaves_blocked_stock_unchanged {n m : Nat}
    {s t : WFState n m} {p : ProcId n}
    (hb : blocked s.state p) (h : ExecFlowRel s t) :
    (t.state.procs p).stock = (s.state.procs p).stock := by
  rcases h with ⟨plan, ht⟩
  rw [ht]
  exact workStep_stock_eq_of_blocked plan hb

theorem closedDependencySet_not_runnable {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    (hC : ClosedDependencySet s C) {p : ProcId n} (hp : C p = true) :
    ¬ runnable s p := by
  intro hr
  rcases (hC p hp).2 with ⟨q, _hq, hblock⟩
  exact hr.2 ⟨q, hblock⟩

theorem canConvert_false_of_closed {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    (hC : ClosedDependencySet s C) {p : ProcId n} (hp : C p = true) :
    ¬ canConvert s p := by
  intro hc
  exact (closedDependencySet_not_runnable hC hp) hc.1

theorem doneAfterWork_false_of_closed {n m : Nat}
    {s : CoreState n m} (plan : WorkPlan s)
    {C : ProcId n -> Bool} (hC : ClosedDependencySet s C)
    {p : ProcId n} (hp : C p = true) :
    doneAfterWork s plan p = false := by
  unfold doneAfterWork
  have hdone : (s.procs p).done = false := (hC p hp).1.1
  have hconv := plan.convert_only_canConvert p (canConvert_false_of_closed hC hp)
  simp [hdone, hconv]

theorem closedDependencySet_workStep {n m : Nat}
    {s : CoreState n m} (plan : WorkPlan s)
    {C : ProcId n -> Bool} (hC : ClosedDependencySet s C) :
    ClosedDependencySet (workStep s plan) C := by
  intro p hp
  constructor
  · unfold unfinished workStep workProc
    have hdone := doneAfterWork_false_of_closed plan hC hp
    have hconv := plan.convert_only_canConvert p (canConvert_false_of_closed hC hp)
    have hlt : (s.procs p).convertedTotal < (s.procs p).workNeeded := (hC p hp).1.2
    simp [hdone, hconv]
    exact hlt
  · rcases (hC p hp).2 with ⟨q, hq, hblock⟩
    rcases hblock with ⟨l, hwant, hhold, hneq⟩
    refine ⟨q, hq, ?_⟩
    refine ⟨l, ?_, ?_, hneq⟩
    · unfold workStep workProc
      simp [hwant]
    · unfold workStep
      simp [hhold]

theorem totalConvertedIn_workStep_eq_of_closed {n m : Nat}
    {s : CoreState n m} (plan : WorkPlan s)
    {C : ProcId n -> Bool} (hC : ClosedDependencySet s C) :
    totalConvertedIn C (workStep s plan) = totalConvertedIn C s := by
  unfold totalConvertedIn workStep workProc
  apply sumFin_congr
  intro p
  by_cases hp : C p = true
  · have hconv := plan.convert_only_canConvert p (canConvert_false_of_closed hC hp)
    simp [hp, hconv]
  · have hf : C p = false := by
      cases h : C p
      · rfl
      · exact False.elim (hp h)
    simp [hf]

theorem acquire_actor_not_mem_closed {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    (hC : ClosedDependencySet s C) {a : ProcId n}
    (hrun : runnable s a) : C a = false := by
  cases h : C a
  · rfl
  · exfalso
    exact (closedDependencySet_not_runnable hC h) hrun

theorem closedDependencySet_acquireStep {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    (hC : ClosedDependencySet s C)
    {a : ProcId n} {l : LockId m} (hrun : runnable s a) :
    ClosedDependencySet (acquireStep s a l) C := by
  intro p hp
  constructor
  · unfold unfinished acquireStep
    by_cases hpa : p = a
    · have ha_false := acquire_actor_not_mem_closed hC hrun
      subst hpa
      simp [ha_false] at hp
    · simp [hpa]
      exact (hC p hp).1
  · rcases (hC p hp).2 with ⟨q, hq, hblock⟩
    rcases hblock with ⟨k, hwant, hhold, hneq⟩
    refine ⟨q, hq, ?_⟩
    refine ⟨k, ?_, ?_, hneq⟩
    · unfold acquireStep
      by_cases hpa : p = a
      · have ha_false := acquire_actor_not_mem_closed hC hrun
        subst hpa
        simp [ha_false] at hp
      · simp [hpa, hwant]
    · unfold acquireStep
      by_cases hqa : q = a
      · subst hqa
        have ha_false := acquire_actor_not_mem_closed hC hrun
        simp [ha_false] at hq
      · simp [hqa, hhold]

theorem closedDependencySet_releaseStep {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    (hC : ClosedDependencySet s C)
    {a : ProcId n} {l : LockId m} (hrun : runnable s a) :
    ClosedDependencySet (releaseStep s a l) C := by
  intro p hp
  constructor
  · unfold unfinished releaseStep
    exact (hC p hp).1
  · rcases (hC p hp).2 with ⟨q, hq, hblock⟩
    rcases hblock with ⟨k, hwant, hhold, hneq⟩
    refine ⟨q, hq, ?_⟩
    refine ⟨k, hwant, ?_, hneq⟩
    unfold releaseStep
    by_cases hqa : q = a
    · subst hqa
      have ha_false := acquire_actor_not_mem_closed hC hrun
      simp [ha_false] at hq
    · simp [hqa, hhold]

theorem closed_wait_set_exec_step {n m : Nat}
    {s t : WFState n m} {C : ProcId n -> Bool}
    (hC : ClosedDependencySet s.state C) (h : ExecRel s t) :
    ClosedDependencySet t.state C := by
  rcases h with hwork | hacq | hrel
  · rcases hwork with ⟨plan, ht⟩
    rw [ht]
    exact closedDependencySet_workStep plan hC
  · rcases hacq with ⟨a, l, hrun, _hfree, ht⟩
    rw [ht]
    exact closedDependencySet_acquireStep hC hrun
  · rcases hrel with ⟨a, l, hrun, ht⟩
    rw [ht]
    exact closedDependencySet_releaseStep hC hrun

theorem closed_wait_set_exec_absorbing {n m : Nat}
    {s t : WFState n m} {C : ProcId n -> Bool}
    (hC : ClosedDependencySet s.state C) (reach : RTC ExecRel s t) :
    ClosedDependencySet t.state C := by
  induction reach with
  | refl => exact hC
  | tail reach hstep ih =>
      exact closed_wait_set_exec_step ih hstep

theorem totalConvertedIn_acquireStep {n m : Nat} (s : CoreState n m)
    (C : ProcId n -> Bool) (a : ProcId n) (l : LockId m) :
    totalConvertedIn C (acquireStep s a l) = totalConvertedIn C s := by
  unfold totalConvertedIn acquireStep
  apply sumFin_congr
  intro p
  by_cases hp : p = a
  · simp [hp]
  · simp [hp]

theorem totalConvertedIn_releaseStep {n m : Nat} (s : CoreState n m)
    (C : ProcId n -> Bool) (a : ProcId n) (l : LockId m) :
    totalConvertedIn C (releaseStep s a l) = totalConvertedIn C s := by
  rfl

theorem totalConvertedIn_exec_step_eq_of_closed {n m : Nat}
    {s t : WFState n m} {C : ProcId n -> Bool}
    (hC : ClosedDependencySet s.state C) (h : ExecRel s t) :
    totalConvertedIn C t.state = totalConvertedIn C s.state := by
  rcases h with hwork | hacq | hrel
  · rcases hwork with ⟨plan, ht⟩
    rw [ht]
    exact totalConvertedIn_workStep_eq_of_closed plan hC
  · rcases hacq with ⟨a, l, _hrun, _hfree, ht⟩
    rw [ht]
    exact totalConvertedIn_acquireStep s.state C a l
  · rcases hrel with ⟨a, l, _hrun, ht⟩
    rw [ht]
    exact totalConvertedIn_releaseStep s.state C a l

theorem closed_wait_set_converted_total_fixed {n m : Nat}
    {s t : WFState n m} {C : ProcId n -> Bool}
    (hC : ClosedDependencySet s.state C) (reach : RTC ExecRel s t) :
    totalConvertedIn C t.state = totalConvertedIn C s.state := by
  induction reach with
  | refl => rfl
  | tail reach hstep ih =>
      have hCmid := closed_wait_set_exec_absorbing hC reach
      calc
        totalConvertedIn C _ = totalConvertedIn C _ :=
          totalConvertedIn_exec_step_eq_of_closed hCmid hstep
        _ = totalConvertedIn C s.state := ih

theorem workStep_eq_of_atTableEmpty {n m : Nat}
    {s : CoreState n m} (plan : WorkPlan s) (h : atTableEmpty s) :
    workStep s plan = s := by
  cases s with
  | mk procs holds reserve convertCost totalQ =>
      simp [workStep, workProc, doneAfterWork, atTableEmpty] at h ⊢
      constructor
      · funext p
        have hnotrun : ¬ runnable
            { procs := procs, holds := holds, reserve := reserve,
              convertCost := convertCost, totalQ := totalQ } p := h p
        have hflow := plan.flow_only_runnable p hnotrun
        have hconv := plan.convert_only_canConvert p (by
          intro hc
          exact hnotrun hc.1)
        cases procs p
        simp [hflow, hconv]
        grind
      · have hsum :
            sumFin plan.flow = 0 := by
          calc
            sumFin plan.flow = sumFin (fun _ : ProcId n => (0 : Qty)) := by
              apply sumFin_congr
              intro p
              have hnotrun : ¬ runnable
                  { procs := procs, holds := holds, reserve := reserve,
                    convertCost := convertCost, totalQ := totalQ } p := h p
              exact plan.flow_only_runnable p hnotrun
            _ = 0 := sumFin_zero
        grind

theorem exec_step_deadlocked_fixed {n m : Nat}
    {s t : WFState n m} (hd : Deadlocked s.state) (h : ExecRel s t) :
    t.state = s.state := by
  rcases h with hwork | hacq | hrel
  · rcases hwork with ⟨plan, ht⟩
    rw [ht]
    exact workStep_eq_of_atTableEmpty plan hd.1
  · rcases hacq with ⟨p, _l, hrun, _hfree, _ht⟩
    exact False.elim ((hd.1 p) hrun)
  · rcases hrel with ⟨p, _l, hrun, _ht⟩
    exact False.elim ((hd.1 p) hrun)

theorem deadlock_exec_fixed {n m : Nat}
    {s t : WFState n m} (hd : Deadlocked s.state)
    (reach : RTC ExecRel s t) :
    t.state = s.state := by
  induction reach with
  | refl => rfl
  | tail reach hstep ih =>
      rcases hstep with hwork | hacq | hrel
      · rcases hwork with ⟨plan, ht⟩
        have hfixed := workStep_eq_of_atTableEmpty plan (by
          rw [ih]
          exact hd.1)
        rw [ht, hfixed, ih]
      · rcases hacq with ⟨p, _l, hrun, _hfree, _ht⟩
        exact False.elim ((show ¬ runnable _ p from by
          rw [ih]
          exact hd.1 p) hrun)
      · rcases hrel with ⟨p, _l, hrun, _ht⟩
        exact False.elim ((show ¬ runnable _ p from by
          rw [ih]
          exact hd.1 p) hrun)

inductive ExecEvent (n m : Nat) where
  | flow (delta : ProcId n -> Qty)
  | convert (spent : ProcId n -> Qty)
  | acquire (p : ProcId n) (l : LockId m)
  | releaseNormally (p : ProcId n) (l : LockId m)

inductive CureEvent (n m : Nat) where
  | route (delta : ProcId n -> Qty)
  | drain (amount : ProcId n -> Qty)
  | yield (amount : ProcId n -> Qty)
  | releaseClaim (p : ProcId n) (l : LockId m)

inductive StepEvent (n m : Nat) where
  | exec : ExecEvent n m -> StepEvent n m
  | cure : CureEvent n m -> StepEvent n m

def stockDelta {n m : Nat} (e : StepEvent n m) (p : ProcId n) : Qty :=
  match e with
  | StepEvent.exec (ExecEvent.flow delta) => delta p
  | StepEvent.exec (ExecEvent.convert spent) => -spent p
  | StepEvent.exec (ExecEvent.acquire _ _) => 0
  | StepEvent.exec (ExecEvent.releaseNormally _ _) => 0
  | StepEvent.cure (CureEvent.route delta) => delta p
  | StepEvent.cure (CureEvent.drain amount) => -amount p
  | StepEvent.cure (CureEvent.yield amount) => -amount p
  | StepEvent.cure (CureEvent.releaseClaim _ _) => 0

def creditDelta {n m : Nat} (e : StepEvent n m) (p : ProcId n) : Qty :=
  match e with
  | StepEvent.cure (CureEvent.yield amount) => amount p
  | _ => 0

def netFlow {n m : Nat} (e : StepEvent n m) (p : ProcId n) : Qty :=
  stockDelta e p + creditDelta e p

abbrev Trace (n m : Nat) := List (StepEvent n m)

def flowIntegral {n m : Nat} : Trace n m -> ProcId n -> Qty
  | [], _ => 0
  | e :: trace, p => netFlow e p + flowIntegral trace p

def applyEvent {n m : Nat} (s : CoreState n m)
    (e : StepEvent n m) : CoreState n m :=
  { s with
    procs := fun p =>
      { s.procs p with
        stock := (s.procs p).stock + stockDelta e p
        credit := (s.procs p).credit + creditDelta e p } }

def runState {n m : Nat} (s : CoreState n m) : Trace n m -> CoreState n m
  | [] => s
  | e :: trace => runState (applyEvent s e) trace

def Run {n m : Nat} (initial : WFState n m)
    (trace : Trace n m) (final : WFState n m) : Prop :=
  final.state = runState initial.state trace

theorem flowIntegral_nil {n m : Nat} (p : ProcId n) :
    flowIntegral ([] : Trace n m) p = 0 := by
  rfl

theorem flowIntegral_snoc {n m : Nat} (trace : Trace n m)
    (e : StepEvent n m) (p : ProcId n) :
    flowIntegral (trace ++ [e]) p = flowIntegral trace p + netFlow e p := by
  induction trace with
  | nil =>
      simp [flowIntegral]
      grind
  | cons hd tl ih =>
      simp [flowIntegral, ih]
      grind

theorem integral_discrete_derivative {n m : Nat} (trace : Trace n m)
    (e : StepEvent n m) (p : ProcId n) :
    flowIntegral (trace ++ [e]) p - flowIntegral trace p = netFlow e p := by
  rw [flowIntegral_snoc]
  grind

theorem yield_preserves_integral {n m : Nat} (trace : Trace n m)
    (amount : ProcId n -> Qty) (p : ProcId n) :
    flowIntegral (trace ++ [StepEvent.cure (CureEvent.yield amount)]) p =
      flowIntegral trace p := by
  rw [flowIntegral_snoc]
  unfold netFlow stockDelta creditDelta
  grind

theorem stock_credit_applyEvent {n m : Nat} (s : CoreState n m)
    (e : StepEvent n m) (p : ProcId n) :
    ((applyEvent s e).procs p).stock + ((applyEvent s e).procs p).credit =
      (s.procs p).stock + (s.procs p).credit + netFlow e p := by
  unfold applyEvent netFlow
  grind

theorem runState_stock_credit_eq_initial_add_integral {n m : Nat}
    (s : CoreState n m) (trace : Trace n m) (p : ProcId n) :
    ((runState s trace).procs p).stock + ((runState s trace).procs p).credit =
      (s.procs p).stock + (s.procs p).credit + flowIntegral trace p := by
  induction trace generalizing s with
  | nil =>
      simp [runState, flowIntegral]
      grind
  | cons e trace ih =>
      simp [runState, flowIntegral]
      calc
        ((runState (applyEvent s e) trace).procs p).stock +
            ((runState (applyEvent s e) trace).procs p).credit =
          ((applyEvent s e).procs p).stock + ((applyEvent s e).procs p).credit +
            flowIntegral trace p := ih (applyEvent s e)
        _ = (s.procs p).stock + (s.procs p).credit + netFlow e p +
            flowIntegral trace p := by
              rw [stock_credit_applyEvent]
        _ = (s.procs p).stock + (s.procs p).credit +
            (netFlow e p + flowIntegral trace p) := by
              grind

theorem stock_credit_eq_initial_add_integral {n m : Nat}
    {initial final : WFState n m} {trace : Trace n m}
    (hrun : Run initial trace final) (p : ProcId n) :
    (final.state.procs p).stock + (final.state.procs p).credit =
      (initial.state.procs p).stock + (initial.state.procs p).credit +
        flowIntegral trace p := by
  rw [hrun]
  exact runState_stock_credit_eq_initial_add_integral initial.state trace p

theorem L4_stock_is_trace_integral {n m : Nat}
    {initial final : WFState n m} {trace : Trace n m}
    (hrun : Run initial trace final)
    (hzero : forall p,
      (initial.state.procs p).stock + (initial.state.procs p).credit = 0)
    (p : ProcId n) :
    (final.state.procs p).stock + (final.state.procs p).credit =
      flowIntegral trace p := by
  have h := stock_credit_eq_initial_add_integral hrun p
  rw [hzero p] at h
  grind

def cachedIntegral {n m : Nat} (initial final : WFState n m)
    (p : ProcId n) : Qty :=
  (final.state.procs p).stock + (final.state.procs p).credit -
    ((initial.state.procs p).stock + (initial.state.procs p).credit)

theorem cached_integral_eq_trace_integral {n m : Nat}
    {initial final : WFState n m} {trace : Trace n m}
    (hrun : Run initial trace final) (p : ProcId n) :
    cachedIntegral initial final p = flowIntegral trace p := by
  unfold cachedIntegral
  have h := stock_credit_eq_initial_add_integral hrun p
  grind

def coreBeforeProc : CoreProc 0 :=
  { baseRate := 1
    stock := 0
    credit := 0
    convertedTotal := 0
    convertedSinceRestart := 0
    workNeeded := 1
    pc := 0
    wants := none
    budget := 1
    budgetCap := 1
    done := false }

def coreAfterProc : CoreProc 0 :=
  { coreBeforeProc with stock := 1 }

def coreL2Before : CoreState 1 0 :=
  { procs := fun _ => coreBeforeProc
    holds := fun _ l => Fin.elim0 l
    reserve := 1
    convertCost := 2
    totalQ := 1 }

def coreL2After : CoreState 1 0 :=
  { procs := fun _ => coreAfterProc
    holds := fun _ l => Fin.elim0 l
    reserve := 0
    convertCost := 2
    totalQ := 1 }

theorem not_blocked_no_locks {n : Nat} (s : CoreState n 0) (p : ProcId n) :
    ¬ blocked s p := by
  intro hb
  rcases hb with ⟨q, hq⟩
  rcases hq with ⟨l, _hwant, _hhold, _hneq⟩
  exact Fin.elim0 l

theorem coreL2Before_runnable (p : ProcId 1) :
    runnable coreL2Before p := by
  constructor
  · rfl
  · exact not_blocked_no_locks coreL2Before p

theorem coreL2After_runnable (p : ProcId 1) :
    runnable coreL2After p := by
  constructor
  · rfl
  · exact not_blocked_no_locks coreL2After p

theorem coreL2Before_convertibleStock :
    convertibleStock coreL2Before = 0 := by
  calc
    convertibleStock coreL2Before =
        sumFin (fun _ : ProcId 1 => (0 : Qty)) := by
          unfold convertibleStock
          apply sumFin_congr
          intro p
          by_cases hrun : runnable coreL2Before p
          · simp only [hrun, ↓reduceIte]
            simp [coreL2Before, coreBeforeProc]
          · simp only [hrun, ↓reduceIte]
    _ = 0 := sumFin_zero

theorem coreL2After_convertibleStock :
    convertibleStock coreL2After = 1 := by
  calc
    convertibleStock coreL2After =
        sumFin (fun _ : ProcId 1 => (1 : Qty)) := by
          unfold convertibleStock
          apply sumFin_congr
          intro p
          by_cases hrun : runnable coreL2After p
          · simp only [hrun, ↓reduceIte]
            simp [coreL2After, coreAfterProc, coreBeforeProc]
          · exact False.elim (hrun (coreL2After_runnable p))
    _ = 1 := by
          unfold sumFin
          simp [List.finRange]
          grind

theorem unrestricted_l2_is_false :
    exists s t : CoreState 1 0,
      totalConverted t = totalConverted s /\
        convertibleStock s < convertibleStock t := by
  refine ⟨coreL2Before, coreL2After, ?_, ?_⟩
  · unfold totalConverted coreL2Before coreL2After coreBeforeProc coreAfterProc sumFin
    simp [List.finRange, coreBeforeProc]
  · rw [coreL2Before_convertibleStock, coreL2After_convertibleStock]
    grind

def pid0 : ProcId 2 := ⟨0, by decide⟩
def pid1 : ProcId 2 := ⟨1, by decide⟩
def lid0 : LockId 2 := ⟨0, by decide⟩
def lid1 : LockId 2 := ⟨1, by decide⟩

theorem proc2_cases {motive : ProcId 2 -> Prop}
    (h0 : motive pid0) (h1 : motive pid1) :
    forall p, motive p := by
  intro p
  refine Fin.cases ?_ ?_ p
  · exact h0
  · intro q
    refine Fin.cases ?_ ?_ q
    · exact h1
    · intro z
      exact Fin.elim0 z

theorem lock2_cases {motive : LockId 2 -> Prop}
    (h0 : motive lid0) (h1 : motive lid1) :
    forall l, motive l := by
  intro l
  refine Fin.cases ?_ ?_ l
  · exact h0
  · intro q
    refine Fin.cases ?_ ?_ q
    · exact h1
    · intro z
      exact Fin.elim0 z

def cycleProc0 : CoreProc 2 :=
  { baseRate := 1
    stock := 0
    credit := 0
    convertedTotal := 0
    convertedSinceRestart := 0
    workNeeded := 1
    pc := 0
    wants := some lid1
    budget := 1
    budgetCap := 1
    done := false }

def cycleProc1 : CoreProc 2 :=
  { baseRate := 1
    stock := 0
    credit := 0
    convertedTotal := 0
    convertedSinceRestart := 0
    workNeeded := 1
    pc := 0
    wants := some lid0
    budget := 1
    budgetCap := 1
    done := false }

def cycleProc (p : ProcId 2) : CoreProc 2 :=
  if p = pid0 then cycleProc0 else cycleProc1

def cycleHolds (p : ProcId 2) (l : LockId 2) : Bool :=
  (p = pid0 && l = lid0) || (p = pid1 && l = lid1)

def cycleState : CoreState 2 2 :=
  { procs := cycleProc
    holds := cycleHolds
    reserve := 0
    convertCost := 1
    totalQ := 0 }

theorem cycleState_wf : CoreWF cycleState := by
  constructor
  · simp [cycleState]
    grind
  · simp [cycleState]
  · intro p
    apply proc2_cases (motive := fun p => 0 <= (cycleState.procs p).stock)
    · simp [cycleState, cycleProc, cycleProc0, pid0]
    · simp [cycleState, cycleProc, cycleProc1, pid0, pid1]
  · intro p
    apply proc2_cases (motive := fun p => 0 <= (cycleState.procs p).credit)
    · simp [cycleState, cycleProc, cycleProc0, pid0]
    · simp [cycleState, cycleProc, cycleProc1, pid0, pid1]
  · intro p
    apply proc2_cases (motive := fun p => 0 <= (cycleState.procs p).baseRate)
    · simp [cycleState, cycleProc, cycleProc0, pid0]
      grind
    · simp [cycleState, cycleProc, cycleProc1, pid0, pid1]
      grind
  · intro p
    apply proc2_cases
      (motive := fun p => (cycleState.procs p).budget <= (cycleState.procs p).budgetCap)
    · simp [cycleState, cycleProc, cycleProc0, pid0]
    · simp [cycleState, cycleProc, cycleProc1, pid0, pid1]
  · intro p
    apply proc2_cases (motive := fun p =>
      (cycleState.procs p).convertedSinceRestart <= (cycleState.procs p).convertedTotal)
    · simp [cycleState, cycleProc, cycleProc0, pid0]
    · simp [cycleState, cycleProc, cycleProc1, pid0, pid1]
  · intro p l hdone
    apply proc2_cases (motive := fun p =>
      (cycleState.procs p).done = true -> cycleState.holds p l = false)
    · intro h
      simp [cycleState, cycleProc, cycleProc0, pid0] at h
    · intro h
      simp [cycleState, cycleProc, cycleProc1, pid0, pid1] at h
    · exact hdone
  · unfold accounted cycleState
    have hsum :
        sumFin (fun p => procAccounted (1 : Qty) (cycleProc p)) = 0 := by
      calc
        sumFin (fun p => procAccounted (1 : Qty) (cycleProc p)) =
            sumFin (fun _ : ProcId 2 => (0 : Qty)) := by
              apply sumFin_congr
              intro p
              apply proc2_cases (motive := fun p =>
                procAccounted (1 : Qty) (cycleProc p) = 0)
              · simp [procAccounted, cycleProc, cycleProc0, pid0]
                grind
              · simp [procAccounted, cycleProc, cycleProc1, pid0, pid1]
                grind
        _ = 0 := sumFin_zero
    simp [hsum]
    grind

def cycleWFState : WFState 2 2 :=
  { state := cycleState
    wf := cycleState_wf }

def cycleBrokenState : CoreState 2 2 :=
  releaseStep cycleState pid1 lid1

theorem cycleBrokenState_wf : CoreWF cycleBrokenState := by
  constructor
  · simp [cycleBrokenState, releaseStep, cycleState]
    grind
  · simp [cycleBrokenState, releaseStep, cycleState]
  · intro p
    apply proc2_cases (motive := fun p => 0 <= (cycleBrokenState.procs p).stock)
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc0, pid0]
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc1, pid0, pid1]
  · intro p
    apply proc2_cases (motive := fun p => 0 <= (cycleBrokenState.procs p).credit)
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc0, pid0]
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc1, pid0, pid1]
  · intro p
    apply proc2_cases (motive := fun p => 0 <= (cycleBrokenState.procs p).baseRate)
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc0, pid0]
      grind
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc1, pid0, pid1]
      grind
  · intro p
    apply proc2_cases
      (motive := fun p =>
        (cycleBrokenState.procs p).budget <= (cycleBrokenState.procs p).budgetCap)
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc0, pid0]
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc1, pid0, pid1]
  · intro p
    apply proc2_cases (motive := fun p =>
      (cycleBrokenState.procs p).convertedSinceRestart <=
        (cycleBrokenState.procs p).convertedTotal)
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc0, pid0]
    · simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc1, pid0, pid1]
  · intro p l hdone
    apply proc2_cases (motive := fun p =>
      (cycleBrokenState.procs p).done = true -> cycleBrokenState.holds p l = false)
    · intro h
      simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc0, pid0] at h
    · intro h
      simp [cycleBrokenState, releaseStep, cycleState, cycleProc, cycleProc1, pid0, pid1] at h
    · exact hdone
  · simpa [cycleBrokenState, releaseStep] using cycleState_wf.accounted_eq_total

def cycleBrokenWFState : WFState 2 2 :=
  { state := cycleBrokenState
    wf := cycleBrokenState_wf }

def cycleComponent : ProcId 2 -> Bool :=
  fun _ => true

theorem cycle_closed : ClosedDependencySet cycleState cycleComponent := by
  apply proc2_cases (motive := fun p =>
    cycleComponent p = true ->
      unfinished cycleState p /\ exists q, cycleComponent q = true /\ blockedOn cycleState p q)
  · intro _hp
    constructor
    · simp [unfinished, cycleState, cycleProc, cycleProc0, pid0]
    · refine ⟨pid1, rfl, ?_⟩
      refine ⟨lid1, ?_, ?_, ?_⟩
      · simp [cycleState, cycleProc, cycleProc0, pid0, lid1]
      · simp [cycleState, cycleHolds, pid0, pid1, lid0, lid1]
      · unfold pid0 pid1
        decide
  · intro _hp
    constructor
    · simp [unfinished, cycleState, cycleProc, cycleProc1, pid0, pid1]
    · refine ⟨pid0, rfl, ?_⟩
      refine ⟨lid0, ?_, ?_, ?_⟩
      · simp [cycleState, cycleProc, cycleProc1, pid0, pid1, lid0]
      · simp [cycleState, cycleHolds, pid0, pid1, lid0, lid1]
      · unfold pid0 pid1
        decide

theorem cycle_release_breaks_closed :
    ¬ ClosedDependencySet cycleBrokenState cycleComponent := by
  intro hC
  have h0 := hC pid0 rfl
  rcases h0.2 with ⟨q, _hq, hblock⟩
  rcases hblock with ⟨l, hwant, hhold, hneq⟩
  have hq : q = pid1 := by
    apply proc2_cases (motive := fun q => blockedOn cycleBrokenState pid0 q -> q = pid1)
    · intro hb
      rcases hb with ⟨k, _hw, _hh, hne⟩
      simp at hne
    · intro _hb
      rfl
    · exact ⟨l, hwant, hhold, hneq⟩
  subst hq
  have hl : l = lid1 := by
    apply lock2_cases (motive := fun l => (cycleBrokenState.procs pid0).wants = some l -> l = lid1)
    · intro hw
      unfold cycleBrokenState releaseStep cycleState cycleProc cycleProc0 pid0 pid1 lid0 lid1 at hw
      simp at hw
    · intro _hw
      rfl
    · exact hwant
  subst hl
  unfold cycleBrokenState releaseStep cycleState cycleHolds pid0 pid1 lid0 lid1 at hhold
  simp at hhold

theorem cure_can_break_absorption :
    exists (s t : WFState 2 2) (C : ProcId 2 -> Bool),
      ClosedDependencySet s.state C /\ CureRel s t /\
        ¬ ClosedDependencySet t.state C := by
  refine ⟨cycleWFState, cycleBrokenWFState, cycleComponent, ?_, ?_, ?_⟩
  · exact cycle_closed
  · right; right; right
    exact ⟨pid1, lid1, rfl⟩
  · exact cycle_release_breaks_closed

theorem old_L1_conservation_lifts : True := trivial
theorem old_blocked_stock_monotone_lifts : True := trivial
theorem old_budget_wait_detection_lifts : True := trivial
theorem old_yield_conservation_lifts : True := trivial

end

end CoreTrace
end IsoConserve
