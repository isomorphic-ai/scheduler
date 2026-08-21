import IsoConserve.CoreTrace

namespace IsoConserve
namespace DetectorProgress

open CoreTrace

noncomputable section

local instance propDecidable (p : Prop) : Decidable p :=
  Classical.propDecidable p

def budget {n m : Nat} (s : CoreState n m) (p : ProcId n) : Nat :=
  (s.procs p).budget

def budgetCap {n m : Nat} (s : CoreState n m) (p : ProcId n) : Nat :=
  (s.procs p).budgetCap

def converted {n m : Nat} (s : CoreState n m) (p : ProcId n) : Nat :=
  (s.procs p).convertedTotal

def doneAfterAttempt {n m : Nat} (s : CoreState n m) (p : ProcId n) : Bool :=
  if (s.procs p).done then
    true
  else if (s.procs p).workNeeded <= (s.procs p).convertedTotal + 1 then
    true
  else
    false

def attemptProc {n m : Nat} (s : CoreState n m)
    (actor q : ProcId n) : CoreProc m :=
  if q = actor then
    let old := s.procs q
    if canConvert s q then
      { old with
        stock := old.stock - s.convertCost
        convertedTotal := old.convertedTotal + 1
        convertedSinceRestart := old.convertedSinceRestart + 1
        budget := old.budgetCap
        done := doneAfterAttempt s q }
    else if blocked s q then
      { old with budget := old.budget - 1 }
    else
      old
  else
    s.procs q

def observeAttempt {n m : Nat} (s : CoreState n m)
    (p : ProcId n) : CoreState n m :=
  { s with procs := fun q => attemptProc s p q }

def runSchedule {n m : Nat} :
    List (ProcId n) -> CoreState n m -> CoreState n m
  | [], s => s
  | p :: rest, s => runSchedule rest (observeAttempt s p)

def PrefixOf {α : Type} (pref schedule : List α) : Prop :=
  exists suffix, pref ++ suffix = schedule

theorem prefix_self {α : Type} (xs : List α) : PrefixOf xs xs := by
  exact ⟨[], by simp⟩

def closedWaitSet {n m : Nat} (s : CoreState n m)
    (C : ProcId n -> Bool) : Prop :=
  ClosedDependencySet s C

def floored {n m : Nat} (s : CoreState n m) (C : ProcId n -> Bool) : Prop :=
  forall p, C p = true -> budget s p = 0

structure GenuineDeadlock {n m : Nat}
    (s : CoreState n m) (C : ProcId n -> Bool) : Prop where
  nonempty : exists p, C p = true
  unfinished_all : forall p, C p = true -> unfinished s p
  internally_blocked :
    forall p, C p = true -> exists q, C q = true /\ blockedOn s p q
  not_runnable : forall p, C p = true -> ¬ runnable s p

def detectorFires {n m : Nat} (s : CoreState n m)
    (C : ProcId n -> Bool) : Prop :=
  closedWaitSet s C /\ floored s C /\ exists p, C p = true

theorem budget_observe_self {n m : Nat} (s : CoreState n m)
    (p : ProcId n) :
    budget (observeAttempt s p) p =
      if canConvert s p then
        budgetCap s p
      else if blocked s p then
        budget s p - 1
      else
        budget s p := by
  unfold budget budgetCap observeAttempt attemptProc
  by_cases hc : canConvert s p
  · simp [hc]
  · by_cases hb : blocked s p
    · simp [hc, hb]
    · simp [hc, hb]

theorem budget_observe_ne {n m : Nat} (s : CoreState n m)
    {actor p : ProcId n} (hne : p ≠ actor) :
    budget (observeAttempt s actor) p = budget s p := by
  unfold budget observeAttempt attemptProc
  simp [hne]

theorem budgetCap_observe {n m : Nat} (s : CoreState n m)
    (actor p : ProcId n) :
    budgetCap (observeAttempt s actor) p = budgetCap s p := by
  unfold budgetCap observeAttempt attemptProc
  by_cases h : p = actor
  · subst actor
    by_cases hc : canConvert s p
    · simp [hc]
    · by_cases hb : blocked s p
      · simp [hc, hb]
      · simp [hc, hb]
  · simp [h]

theorem converted_observe_self {n m : Nat} (s : CoreState n m)
    (p : ProcId n) :
    converted (observeAttempt s p) p =
      if canConvert s p then converted s p + 1 else converted s p := by
  unfold converted observeAttempt attemptProc
  by_cases hc : canConvert s p
  · simp [hc]
  · by_cases hb : blocked s p
    · simp [hc, hb]
    · simp [hc, hb]

theorem conversion_refills_budget {n m : Nat} {s : CoreState n m}
    {p : ProcId n} (hc : canConvert s p) :
    budget (observeAttempt s p) p = budgetCap s p := by
  rw [budget_observe_self]
  simp [hc]

theorem blocked_nonconversion_drains_budget {n m : Nat}
    {s : CoreState n m} {p : ProcId n} (hb : blocked s p) :
    budget (observeAttempt s p) p = budget s p - 1 := by
  rw [budget_observe_self]
  have hnot := CoreTrace.canConvert_false_of_blocked hb
  simp [hnot, hb]

theorem budget_drop_implies_blocked {n m : Nat}
    {s : CoreState n m} {p : ProcId n} (hwf : CoreWF s)
    (hdrop : budget (observeAttempt s p) p < budget s p) :
    blocked s p := by
  rw [budget_observe_self] at hdrop
  by_cases hc : canConvert s p
  · simp [hc] at hdrop
    have hle := hwf.budget_le_cap p
    unfold budget budgetCap at hdrop
    omega
  · by_cases hb : blocked s p
    · exact hb
    · simp [hc, hb] at hdrop

theorem budget_after_ge_pred {n m : Nat}
    {s : CoreState n m} {p : ProcId n} (hwf : CoreWF s) :
    budget s p - 1 <= budget (observeAttempt s p) p := by
  rw [budget_observe_self]
  by_cases hc : canConvert s p
  · simp [hc]
    have hle := hwf.budget_le_cap p
    unfold budget budgetCap
    omega
  · by_cases hb : blocked s p
    · simp [hc, hb]
    · simp [hc, hb]

theorem blockedOn_observeAttempt_iff {n m : Nat}
    (s : CoreState n m) (actor p q : ProcId n) :
    blockedOn (observeAttempt s actor) p q ↔ blockedOn s p q := by
  unfold blockedOn observeAttempt attemptProc
  by_cases hp : p = actor
  · subst actor
    by_cases hc : canConvert s p
    · simp [hc]
    · by_cases hb : blocked s p
      · simp [hc, hb]
      · simp [hc, hb]
  · simp [hp]

theorem blocked_observeAttempt_iff {n m : Nat}
    (s : CoreState n m) (actor p : ProcId n) :
    blocked (observeAttempt s actor) p ↔ blocked s p := by
  constructor
  · intro h
    rcases h with ⟨q, hq⟩
    exact ⟨q, (blockedOn_observeAttempt_iff s actor p q).1 hq⟩
  · intro h
    rcases h with ⟨q, hq⟩
    exact ⟨q, (blockedOn_observeAttempt_iff s actor p q).2 hq⟩

theorem blocked_of_closed {n m : Nat} {s : CoreState n m}
    {C : ProcId n -> Bool} (hC : closedWaitSet s C)
    {p : ProcId n} (hp : C p = true) :
    blocked s p := by
  rcases (hC p hp).2 with ⟨q, _hq, hblocked⟩
  exact ⟨q, hblocked⟩

theorem closedWaitSet_not_runnable {n m : Nat} {s : CoreState n m}
    {C : ProcId n -> Bool} (hC : closedWaitSet s C)
    {p : ProcId n} (hp : C p = true) :
    ¬ runnable s p := by
  intro hr
  exact hr.2 (blocked_of_closed hC hp)

theorem detector_sound {n m : Nat} {s : CoreState n m}
    {C : ProcId n -> Bool} :
    detectorFires s C -> GenuineDeadlock s C := by
  intro hfire
  rcases hfire with ⟨hC, _hfloor, hnonempty⟩
  constructor
  · exact hnonempty
  · intro p hp
    exact (hC p hp).1
  · intro p hp
    exact (hC p hp).2
  · intro p hp
    exact closedWaitSet_not_runnable hC hp

theorem closedWaitSet_observeAttempt {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    (actor : ProcId n) (hC : closedWaitSet s C) :
    closedWaitSet (observeAttempt s actor) C := by
  intro p hp
  constructor
  · unfold closedWaitSet at hC
    unfold unfinished observeAttempt attemptProc
    by_cases hpa : p = actor
    · subst hpa
      have hb := blocked_of_closed hC hp
      have hnot := CoreTrace.canConvert_false_of_blocked hb
      have hu := (hC p hp).1
      simp [hnot, hb, hu.1, hu.2]
    · have hu := (hC p hp).1
      simpa [hpa] using hu
  · rcases (hC p hp).2 with ⟨q, hq, hblock⟩
    exact ⟨q, hq, (blockedOn_observeAttempt_iff s actor p q).2 hblock⟩

theorem closedWaitSet_runSchedule {n m : Nat}
    (schedule : List (ProcId n)) {s : CoreState n m}
    {C : ProcId n -> Bool} (hC : closedWaitSet s C) :
    closedWaitSet (runSchedule schedule s) C := by
  induction schedule generalizing s with
  | nil =>
      exact hC
  | cons actor rest ih =>
      exact ih (s := observeAttempt s actor)
        (closedWaitSet_observeAttempt actor hC)

theorem closed_wait_set_exec_absorbing {n m : Nat}
    {s t : WFState n m} {C : ProcId n -> Bool}
    (hC : closedWaitSet s.state C) (reach : RTC ExecRel s t) :
    closedWaitSet t.state C :=
  CoreTrace.closed_wait_set_exec_absorbing hC reach

theorem closed_wait_set_no_conversion {n m : Nat}
    {s t : WFState n m} {C : ProcId n -> Bool}
    (hC : closedWaitSet s.state C) (reach : RTC ExecRel s t) :
    totalConvertedIn C t.state = totalConvertedIn C s.state :=
  CoreTrace.closed_wait_set_converted_total_fixed hC reach

theorem closed_member_budget_observe_self {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    (hC : closedWaitSet s C) {p : ProcId n} (hp : C p = true) :
    budget (observeAttempt s p) p = budget s p - 1 :=
  blocked_nonconversion_drains_budget (blocked_of_closed hC hp)

def selectedCount {n : Nat} :
    List (ProcId n) -> ProcId n -> Nat
  | [], _p => 0
  | actor :: rest, p =>
      (if actor = p then 1 else 0) + selectedCount rest p

def memberSelectedAtLeast {n : Nat}
    (schedule : List (ProcId n)) (C : ProcId n -> Bool) (k : Nat) : Prop :=
  forall p, C p = true -> k <= selectedCount schedule p

theorem closed_member_budget_after_schedule {n m : Nat}
    (schedule : List (ProcId n)) {s : CoreState n m}
    {C : ProcId n -> Bool} (hC : closedWaitSet s C)
    {p : ProcId n} (hp : C p = true) :
    budget (runSchedule schedule s) p =
      budget s p - selectedCount schedule p := by
  induction schedule generalizing s with
  | nil =>
      simp [runSchedule, selectedCount]
  | cons actor rest ih =>
      have hCnext : closedWaitSet (observeAttempt s actor) C :=
        closedWaitSet_observeAttempt actor hC
      calc
        budget (runSchedule (actor :: rest) s) p =
            budget (runSchedule rest (observeAttempt s actor)) p := rfl
        _ = budget (observeAttempt s actor) p - selectedCount rest p :=
            ih (s := observeAttempt s actor) hCnext
        _ = budget s p - selectedCount (actor :: rest) p := by
            by_cases hactor : actor = p
            · subst hactor
              rw [closed_member_budget_observe_self hC hp]
              simp [selectedCount, Nat.sub_sub]
            · have hne : p ≠ actor := Ne.symm hactor
              rw [budget_observe_ne s hne]
              simp [selectedCount, hactor]

theorem closed_deadlock_eventually_floors {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    {schedule : List (ProcId n)} {k : Nat}
    (hC : closedWaitSet s C)
    (hfair : memberSelectedAtLeast schedule C k)
    (hcap : forall p, C p = true -> budget s p <= k) :
    floored (runSchedule schedule s) C := by
  intro p hp
  rw [closed_member_budget_after_schedule schedule hC hp]
  have hle : budget s p <= selectedCount schedule p :=
    Nat.le_trans (hcap p hp) (hfair p hp)
  exact Nat.sub_eq_zero_of_le hle

theorem deadlock_eventually_detected {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    {schedule : List (ProcId n)} {k : Nat}
    (hC : closedWaitSet s C)
    (hnonempty : exists p, C p = true)
    (hfair : memberSelectedAtLeast schedule C k)
    (hcap : forall p, C p = true -> budget s p <= k) :
    detectorFires (runSchedule schedule s) C := by
  exact ⟨closedWaitSet_runSchedule schedule hC,
    closed_deadlock_eventually_floors hC hfair hcap, hnonempty⟩

theorem detection_latency_le_budget {n m : Nat}
    {s : CoreState n m} {C : ProcId n -> Bool}
    {schedule : List (ProcId n)} {k : Nat}
    (hC : closedWaitSet s C)
    (hnonempty : exists p, C p = true)
    (hfair : memberSelectedAtLeast schedule C k)
    (hcap : forall p, C p = true -> budget s p <= k) :
    exists pref,
      PrefixOf pref schedule /\
      detectorFires (runSchedule pref s) C := by
  exact ⟨schedule, prefix_self schedule,
    deadlock_eventually_detected hC hnonempty hfair hcap⟩

def convertsOnEverySelection {n m : Nat} :
    CoreState n m -> List (ProcId n) -> ProcId n -> Prop
  | _s, [], _p => True
  | s, actor :: rest, p =>
      (actor = p -> canConvert s p) /\
        convertsOnEverySelection (observeAttempt s actor) rest p

def selectionWindowSafe {n m : Nat} (window : Nat) :
    CoreState n m -> List (ProcId n) -> ProcId n -> Nat -> Prop
  | _s, [], _p, _remaining => True
  | s, actor :: rest, p, remaining =>
      if actor = p then
        if canConvert s p then
          selectionWindowSafe window (observeAttempt s actor) rest p window
        else
          1 < remaining /\
            selectionWindowSafe window (observeAttempt s actor) rest p
              (remaining - 1)
      else
        selectionWindowSafe window (observeAttempt s actor) rest p remaining

def convertsWithinEverySelectionWindow {n m : Nat}
    (s : CoreState n m) (schedule : List (ProcId n))
    (p : ProcId n) (window : Nat) : Prop :=
  selectionWindowSafe window s schedule p window

theorem selectionWindowSafe_append_left {n m : Nat}
    (left right : List (ProcId n)) {s : CoreState n m} {p : ProcId n}
    {window remaining : Nat}
    (hlive : selectionWindowSafe window s (left ++ right) p remaining) :
    selectionWindowSafe window s left p remaining := by
  induction left generalizing s remaining with
  | nil =>
      simp [selectionWindowSafe]
  | cons actor rest ih =>
      by_cases hactor : actor = p
      · subst actor
        by_cases hc : canConvert s p
        · simp only [List.cons_append, selectionWindowSafe, ↓reduceIte, hc] at hlive ⊢
          exact ih (s := observeAttempt s p) (remaining := window) hlive
        · simp only [List.cons_append, selectionWindowSafe, ↓reduceIte, hc] at hlive ⊢
          exact ⟨hlive.1,
            ih (s := observeAttempt s p) (remaining := remaining - 1) hlive.2⟩
      · simp only [List.cons_append, selectionWindowSafe, hactor, ↓reduceIte] at hlive ⊢
        exact ih (s := observeAttempt s actor) (remaining := remaining) hlive

theorem budget_ne_zero_of_convertsOnEverySelection {n m : Nat}
    (schedule : List (ProcId n)) {s : CoreState n m} {p : ProcId n}
    (hcap_pos : 0 < budgetCap s p)
    (hbudget0 : budget s p = budgetCap s p)
    (hlive : convertsOnEverySelection s schedule p) :
    budget (runSchedule schedule s) p ≠ 0 := by
  induction schedule generalizing s with
  | nil =>
      simpa [runSchedule, hbudget0] using Nat.ne_of_gt hcap_pos
  | cons actor rest ih =>
      rcases hlive with ⟨hlive_head, hlive_tail⟩
      have hcap_next :
          0 < budgetCap (observeAttempt s actor) p := by
        rw [budgetCap_observe]
        exact hcap_pos
      have hbudget_next :
          budget (observeAttempt s actor) p =
            budgetCap (observeAttempt s actor) p := by
        by_cases hactor : actor = p
        · subst actor
          have hc : canConvert s p := hlive_head rfl
          rw [conversion_refills_budget hc, budgetCap_observe]
        · have hne : p ≠ actor := Ne.symm hactor
          rw [budget_observe_ne s hne, budgetCap_observe, hbudget0]
      exact ih (s := observeAttempt s actor) hcap_next hbudget_next hlive_tail

theorem budget_ne_zero_of_selectionWindowSafe {n m : Nat}
    (schedule : List (ProcId n)) {s : CoreState n m} {p : ProcId n}
    {window remaining : Nat}
    (hwindow_pos : 0 < window)
    (hremaining_pos : 0 < remaining)
    (hwindow_le_cap : window <= budgetCap s p)
    (hremaining_le_budget : remaining <= budget s p)
    (hlive : selectionWindowSafe window s schedule p remaining) :
    budget (runSchedule schedule s) p ≠ 0 := by
  induction schedule generalizing s remaining with
  | nil =>
      simp only [runSchedule]
      omega
  | cons actor rest ih =>
      have hwindow_next :
          window <= budgetCap (observeAttempt s actor) p := by
        rw [budgetCap_observe]
        exact hwindow_le_cap
      by_cases hactor : actor = p
      · subst actor
        by_cases hc : canConvert s p
        · simp only [selectionWindowSafe, ↓reduceIte, hc] at hlive
          have hbudget_next :
              window <= budget (observeAttempt s p) p := by
            rw [conversion_refills_budget hc]
            exact hwindow_le_cap
          exact ih (s := observeAttempt s p) (remaining := window)
            hwindow_pos hwindow_next hbudget_next hlive
        · simp only [selectionWindowSafe, ↓reduceIte, hc] at hlive
          have hremaining_next_pos : 0 < remaining - 1 := by
            omega
          have hbudget_next :
              remaining - 1 <= budget (observeAttempt s p) p := by
            rw [budget_observe_self]
            by_cases hb : blocked s p
            · simp [hc, hb]
              omega
            · simp [hc, hb]
              omega
          exact ih (s := observeAttempt s p) (remaining := remaining - 1)
            hremaining_next_pos hwindow_next hbudget_next hlive.2
      · simp only [selectionWindowSafe, hactor, ↓reduceIte] at hlive
        have hbudget_next :
            remaining <= budget (observeAttempt s actor) p := by
          rw [budget_observe_ne s (Ne.symm hactor)]
          exact hremaining_le_budget
        exact ih (s := observeAttempt s actor) (remaining := remaining)
          hremaining_pos hwindow_next hbudget_next hlive

theorem periodic_conversion_never_floors_every_selection {n m : Nat}
    {s : CoreState n m} {schedule : List (ProcId n)} {p : ProcId n}
    (hcap_pos : 0 < budgetCap s p)
    (hbudget0 : budget s p = budgetCap s p)
    (hlive : forall pref, PrefixOf pref schedule ->
      convertsOnEverySelection s pref p) :
    forall pref,
      PrefixOf pref schedule ->
      budget (runSchedule pref s) p ≠ 0 := by
  intro pref hpref
  exact budget_ne_zero_of_convertsOnEverySelection pref hcap_pos hbudget0
    (hlive pref hpref)

theorem live_process_not_detected_every_selection {n m : Nat}
    {s : CoreState n m} {schedule : List (ProcId n)}
    {p : ProcId n} {C : ProcId n -> Bool}
    (hcap_pos : 0 < budgetCap s p)
    (hbudget0 : budget s p = budgetCap s p)
    (hlive : forall pref, PrefixOf pref schedule ->
      convertsOnEverySelection s pref p)
    (hp : C p = true) :
    forall pref,
      PrefixOf pref schedule ->
      ¬ detectorFires (runSchedule pref s) C := by
  intro pref hpref hfire
  have hnz :=
    periodic_conversion_never_floors_every_selection
      hcap_pos hbudget0 hlive pref hpref
  exact hnz (hfire.2.1 p hp)

theorem periodic_conversion_never_floors {n m : Nat}
    {s : CoreState n m} {schedule : List (ProcId n)} {p : ProcId n}
    (hcap_pos : 0 < budgetCap s p)
    (hbudget0 : budget s p = budgetCap s p)
    (hlive :
      convertsWithinEverySelectionWindow s schedule p (budgetCap s p)) :
    forall pref,
      PrefixOf pref schedule ->
      budget (runSchedule pref s) p ≠ 0 := by
  intro pref hpref
  rcases hpref with ⟨suffix, hschedule⟩
  have hpref_live :
      selectionWindowSafe (budgetCap s p) s pref p (budgetCap s p) := by
    apply selectionWindowSafe_append_left (right := suffix)
    rw [hschedule]
    exact hlive
  have hcap_le_budget : budgetCap s p <= budget s p := by
    rw [hbudget0]
    exact Nat.le_refl _
  exact budget_ne_zero_of_selectionWindowSafe pref hcap_pos hcap_pos
    (Nat.le_refl _) hcap_le_budget hpref_live

theorem live_process_not_detected {n m : Nat}
    {s : CoreState n m} {schedule : List (ProcId n)}
    {p : ProcId n} {C : ProcId n -> Bool}
    (hcap_pos : 0 < budgetCap s p)
    (hbudget0 : budget s p = budgetCap s p)
    (hlive :
      convertsWithinEverySelectionWindow s schedule p (budgetCap s p))
    (hp : C p = true) :
    forall pref,
      PrefixOf pref schedule ->
      ¬ detectorFires (runSchedule pref s) C := by
  intro pref hpref hfire
  have hnz :=
    periodic_conversion_never_floors hcap_pos hbudget0 hlive pref hpref
  exact hnz (hfire.2.1 p hp)

abbrev windowWitnessProc : ProcId 1 := 0

def windowWitnessState : CoreState 1 0 :=
  { procs := fun _ =>
      { coreBeforeProc with
        stock := 1
        workNeeded := 2
        budget := 2
        budgetCap := 2 }
    holds := fun _ l => Fin.elim0 l
    reserve := 0
    convertCost := 1
    totalQ := 1 }

def oncePerWindowSchedule : List (ProcId 1) :=
  [windowWitnessProc, windowWitnessProc]

@[simp] theorem windowWitness_canConvert :
    canConvert windowWitnessState windowWitnessProc := by
  unfold canConvert runnable unfinished windowWitnessState windowWitnessProc
  simp [coreBeforeProc, not_blocked_no_locks]

@[simp] theorem windowWitness_cannotConvert_after_one :
    ¬ canConvert (observeAttempt windowWitnessState windowWitnessProc)
      windowWitnessProc := by
  intro hc
  have hstock := hc.2.2
  have hstock_zero :
      ((observeAttempt windowWitnessState windowWitnessProc).procs
        windowWitnessProc).stock = 0 := by
    unfold observeAttempt attemptProc
    simp only [if_pos windowWitness_canConvert]
    simp [windowWitnessState, coreBeforeProc]
    grind
  have hcost_one :
      (observeAttempt windowWitnessState windowWitnessProc).convertCost = 1 := rfl
  rw [hstock_zero] at hstock
  rw [hcost_one] at hstock
  grind

theorem once_per_selection_window_never_floors :
    selectedCount oncePerWindowSchedule windowWitnessProc = 2 /\
    convertsWithinEverySelectionWindow windowWitnessState
      oncePerWindowSchedule windowWitnessProc 2 /\
    ¬ convertsOnEverySelection windowWitnessState oncePerWindowSchedule
      windowWitnessProc /\
    converted (runSchedule oncePerWindowSchedule windowWitnessState)
      windowWitnessProc = 1 /\
    budget (runSchedule oncePerWindowSchedule windowWitnessState)
      windowWitnessProc = 2 := by
  constructor
  · simp [oncePerWindowSchedule, selectedCount]
  constructor
  · simp [convertsWithinEverySelectionWindow, selectionWindowSafe,
      oncePerWindowSchedule]
  constructor
  · simp [convertsOnEverySelection, oncePerWindowSchedule]
  constructor
  · change converted
      (observeAttempt (observeAttempt windowWitnessState windowWitnessProc)
        windowWitnessProc) windowWitnessProc = 1
    rw [converted_observe_self]
    rw [if_neg windowWitness_cannotConvert_after_one]
    rw [converted_observe_self]
    rw [if_pos windowWitness_canConvert]
    rfl
  · change budget
      (observeAttempt (observeAttempt windowWitnessState windowWitnessProc)
        windowWitnessProc) windowWitnessProc = 2
    rw [budget_observe_self]
    have hnot_blocked :
        ¬ blocked (observeAttempt windowWitnessState windowWitnessProc)
          windowWitnessProc :=
      not_blocked_no_locks _ _
    simp [windowWitness_cannotConvert_after_one, hnot_blocked]
    rw [conversion_refills_budget windowWitness_canConvert]
    rfl

def missedWindowSchedule : List (ProcId 2) :=
  [pid0]

theorem missed_selection_window_floors :
    selectedCount missedWindowSchedule pid0 = 1 /\
    ¬ convertsWithinEverySelectionWindow cycleState missedWindowSchedule pid0 1 /\
    budget (runSchedule missedWindowSchedule cycleState) pid0 = 0 := by
  have hblocked : blocked cycleState pid0 :=
    blocked_of_closed cycle_closed rfl
  have hcannot : ¬ canConvert cycleState pid0 :=
    CoreTrace.canConvert_false_of_blocked hblocked
  constructor
  · simp [missedWindowSchedule, selectedCount]
  constructor
  · simp [convertsWithinEverySelectionWindow, selectionWindowSafe,
      missedWindowSchedule, hcannot]
  · change budget (observeAttempt cycleState pid0) pid0 = 0
    rw [blocked_nonconversion_drains_budget hblocked]
    rfl

structure ProgressProc where
  budget : Nat
  budgetCap : Nat
  reported : Nat
  delivered : Nat
  reclaimed : Bool
deriving Repr

def sigProgressStep (p : ProgressProc) (reply : Nat) : ProgressProc :=
  let newBudget := if p.reported < reply then p.budgetCap else p.budget - 1
  { p with
    budget := newBudget
    reported := max p.reported reply
    reclaimed := if newBudget = 0 then true else false }

def honest (p : ProgressProc) : Prop :=
  p.reported = p.delivered

def reputationConsistent (p : ProgressProc) : Prop :=
  p.reported <= p.delivered

theorem rising_progress_refills_budget {p : ProgressProc} {reply : Nat}
    (hrise : p.reported < reply) :
    (sigProgressStep p reply).budget = p.budgetCap := by
  unfold sigProgressStep
  simp [hrise]

theorem flat_progress_drains_budget {p : ProgressProc} {reply : Nat}
    (hflat : reply <= p.reported) :
    (sigProgressStep p reply).budget = p.budget - 1 := by
  unfold sigProgressStep
  have hnot : ¬ p.reported < reply := by omega
  simp [hnot]

theorem reported_counter_monotone (p : ProgressProc) (reply : Nat) :
    p.reported <= (sigProgressStep p reply).reported := by
  unfold sigProgressStep
  simp
  exact Nat.le_max_left p.reported reply

theorem useful_reporter_never_reclaimed {p : ProgressProc} {reply : Nat}
    (hrise : p.reported < reply) (hcap : 0 < p.budgetCap) :
    (sigProgressStep p reply).reclaimed = false := by
  unfold sigProgressStep
  have hne : ¬ p.budgetCap = 0 := Nat.ne_of_gt hcap
  simp [hrise, hne]

def flatProgressN : Nat -> ProgressProc -> ProgressProc
  | 0, p => p
  | k + 1, p =>
      let current := flatProgressN k p
      sigProgressStep current current.reported

theorem flatProgressN_budget (k : Nat) (p : ProgressProc) :
    (flatProgressN k p).budget = p.budget - k := by
  induction k with
  | zero =>
      rfl
  | succ k ih =>
      unfold flatProgressN
      rw [flat_progress_drains_budget (p := flatProgressN k p)
        (reply := (flatProgressN k p).reported) (Nat.le_refl _), ih]
      simp [Nat.sub_sub]

theorem spinner_eventually_reclaimed (p : ProgressProc) :
    (flatProgressN (p.budget + 1) p).reclaimed = true := by
  unfold flatProgressN
  have hbudget := flatProgressN_budget p.budget p
  have hnot : ¬ (flatProgressN p.budget p).reported <
      (flatProgressN p.budget p).reported := by omega
  have hzero : (flatProgressN p.budget p).budget - 1 = 0 := by
    rw [hbudget]
    omega
  simp [sigProgressStep, hnot, hzero]

theorem liar_survives_in_loop_if_it_reports_progress
    {p : ProgressProc} {reply : Nat}
    (hrise : p.reported < reply) (hcap : 0 < p.budgetCap) :
    (sigProgressStep p reply).reclaimed = false :=
  useful_reporter_never_reclaimed hrise hcap

theorem liar_fails_reputation_check {p : ProgressProc} {reply : Nat}
    (hdelivered : p.delivered < reply) :
    ¬ reputationConsistent (sigProgressStep p reply) := by
  intro hrep
  unfold reputationConsistent sigProgressStep at hrep
  simp at hrep
  have hle : reply <= max p.reported reply := Nat.le_max_right p.reported reply
  omega

end
end DetectorProgress
end IsoConserve
