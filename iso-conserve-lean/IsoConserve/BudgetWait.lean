import IsoConserve.Basic

namespace IsoConserve
namespace BudgetWait

noncomputable section

abbrev Pid (n : Nat) := Fin n
abbrev Lid (m : Nat) := Fin m

structure BWProc (m : Nat) where
  workNeeded : Nat
  converted : Nat
  stock : Qty
  budget : Nat
  budgetCap : Nat
  wants : Option (Lid m)
  done : Bool

structure BWState (n m : Nat) where
  procs : Pid n -> BWProc m
  holds : Pid n -> Lid m -> Bool
  convertCost : Qty

structure BWWF {n m : Nat} (s : BWState n m) : Prop where
  cost_pos : 0 < s.convertCost
  stock_nonneg : forall p, 0 <= (s.procs p).stock
  budget_le_cap : forall p, (s.procs p).budget <= (s.procs p).budgetCap

def unfinished {n m : Nat} (s : BWState n m) (p : Pid n) : Prop :=
  (s.procs p).done = false /\ (s.procs p).converted < (s.procs p).workNeeded

def blockedOn {n m : Nat} (s : BWState n m) (p q : Pid n) : Prop :=
  exists l, (s.procs p).wants = some l /\ s.holds q l = true /\ q != p

def blocked {n m : Nat} (s : BWState n m) (p : Pid n) : Prop :=
  exists q, blockedOn s p q

def runnable {n m : Nat} (s : BWState n m) (p : Pid n) : Prop :=
  (s.procs p).done = false /\ ¬ blocked s p

def closedWaitSet {n m : Nat} (s : BWState n m) (C : Pid n -> Bool) : Prop :=
  forall p, C p = true ->
    unfinished s p /\ exists q, C q = true /\ blockedOn s p q

def floored {n m : Nat} (s : BWState n m) (C : Pid n -> Bool) : Prop :=
  forall p, C p = true -> (s.procs p).budget = 0

def canConvert {n m : Nat} (s : BWState n m) (p : Pid n) : Prop :=
  runnable s p /\ s.convertCost <= (s.procs p).stock

local instance canConvertDecidable {n m : Nat}
    (s : BWState n m) (p : Pid n) : Decidable (canConvert s p) :=
  Classical.propDecidable _

local instance blockedDecidable {n m : Nat}
    (s : BWState n m) (p : Pid n) : Decidable (blocked s p) :=
  Classical.propDecidable _

def convertedAfter {n m : Nat} (s : BWState n m) (p : Pid n) : Nat :=
  if canConvert s p then (s.procs p).converted + 1 else (s.procs p).converted

def budgetAfter {n m : Nat} (s : BWState n m) (p : Pid n) : Nat :=
  if canConvert s p then
    (s.procs p).budgetCap
  else if blocked s p then
    (s.procs p).budget - 1
  else
    (s.procs p).budget

def doneAfter {n m : Nat} (s : BWState n m) (p : Pid n) : Bool :=
  if (s.procs p).done then
    true
  else if (s.procs p).workNeeded <= convertedAfter s p then
    true
  else
    false

def holdsAfter {n m : Nat} (s : BWState n m) (p : Pid n) (l : Lid m) : Bool :=
  if doneAfter s p then false else s.holds p l

def stepProc {n m : Nat} (s : BWState n m) (p : Pid n) : BWProc m :=
  let conv := if canConvert s p then 1 else 0
  { workNeeded := (s.procs p).workNeeded
    converted := (s.procs p).converted + conv
    stock := (s.procs p).stock - s.convertCost * (conv : Qty)
    budget := budgetAfter s p
    budgetCap := (s.procs p).budgetCap
    wants := (s.procs p).wants
    done := doneAfter s p }

def step {n m : Nat} (s : BWState n m) : BWState n m :=
  { procs := fun p => stepProc s p
    holds := fun p l => holdsAfter s p l
    convertCost := s.convertCost }

def stepN {n m : Nat} : Nat -> BWState n m -> BWState n m
  | 0, s => s
  | k + 1, s => stepN k (step s)

theorem canConvert_false_of_blocked {n m : Nat} {s : BWState n m}
    {p : Pid n} (hb : blocked s p) :
    ¬ canConvert s p := by
  intro hc
  exact hc.1.2 hb

theorem convertedAfter_eq_of_not_canConvert {n m : Nat} {s : BWState n m}
    {p : Pid n} (hnot : ¬ canConvert s p) :
    convertedAfter s p = (s.procs p).converted := by
  unfold convertedAfter
  simp [hnot]

theorem doneAfter_eq_false_of_unfinished_not_canConvert {n m : Nat}
    {s : BWState n m} {p : Pid n}
    (hu : unfinished s p) (hnot : ¬ canConvert s p) :
    doneAfter s p = false := by
  unfold doneAfter
  have hconv := convertedAfter_eq_of_not_canConvert (s := s) (p := p) hnot
  have hnle : ¬ (s.procs p).workNeeded <= (s.procs p).converted :=
    Nat.not_le_of_gt hu.2
  simp [hu.1, hconv, hnle]

theorem bw_wf_step {n m : Nat} {s : BWState n m}
    (hwf : BWWF s) : BWWF (step s) := by
  constructor
  · exact hwf.cost_pos
  · intro p
    unfold step stepProc
    by_cases hc : canConvert s p
    · simp [hc]
      have hcost : s.convertCost <= (s.procs p).stock := hc.2
      grind
    · simp [hc]
      have hs := hwf.stock_nonneg p
      grind
  · intro p
    unfold step stepProc budgetAfter
    by_cases hc : canConvert s p
    · simp [hc]
    · by_cases hb : blocked s p
      · simp [hc, hb]
        have hle := hwf.budget_le_cap p
        omega
      · simp [hc, hb]
        exact hwf.budget_le_cap p

theorem budget_drop_implies_blocked {n m : Nat} {s : BWState n m}
    {p : Pid n} (hwf : BWWF s)
    (hdrop : ((step s).procs p).budget < (s.procs p).budget) :
    blocked s p := by
  unfold step stepProc budgetAfter at hdrop
  by_cases hc : canConvert s p
  · simp [hc] at hdrop
    have hle := hwf.budget_le_cap p
    omega
  · by_cases hb : blocked s p
    · exact hb
    · simp [hc, hb] at hdrop

theorem budget_after_ge_pred {n m : Nat} {s : BWState n m}
    {p : Pid n} (hwf : BWWF s) :
    (s.procs p).budget - 1 <= ((step s).procs p).budget := by
  unfold step stepProc budgetAfter
  by_cases hc : canConvert s p
  · simp [hc]
    have hle := hwf.budget_le_cap p
    omega
  · by_cases hb : blocked s p
    · simp [hc, hb]
    · simp [hc, hb]

theorem budget_iter_ge_sub {n m : Nat} {s : BWState n m}
    (p : Pid n) :
    forall k,
      (forall j, j < k -> BWWF (stepN j s)) ->
      (s.procs p).budget - k <= ((stepN k s).procs p).budget := by
  intro k
  induction k generalizing s with
  | zero =>
      intro _hwf_path
      simp [stepN]
  | succ k ih =>
      intro hwf_path
      have hwf0 : BWWF s := hwf_path 0 (Nat.succ_pos k)
      have hstep := budget_after_ge_pred (s := s) (p := p) hwf0
      have htail_path :
          forall j, j < k -> BWWF (stepN j (step s)) := by
        intro j hj
        exact hwf_path (j + 1) (Nat.succ_lt_succ hj)
      have htail := ih (s := step s) htail_path
      have hsub :
          (s.procs p).budget - (k + 1) <=
            ((step s).procs p).budget - k := by
        have h := Nat.sub_le_sub_right hstep k
        simpa [Nat.sub_sub, Nat.add_comm, Nat.add_left_comm, Nat.add_assoc] using h
      exact Nat.le_trans hsub htail

def blockedThroughout {n m : Nat}
    (s : BWState n m) (k : Nat) (p : Pid n) : Prop :=
  forall j, j < k -> blocked (stepN j s) p

theorem floor_after_budget_window_implies_blockedThroughout_aux {n m : Nat}
    {s : BWState n m} (p : Pid n) :
    forall k,
      (s.procs p).budget = k ->
      ((stepN k s).procs p).budget = 0 ->
      (forall j, j <= k -> BWWF (stepN j s)) ->
      blockedThroughout s k p := by
  intro k
  induction k generalizing s with
  | zero =>
      intro _hbudget _hfloor _hwf_path j hj
      omega
  | succ k ih =>
      intro hbudget hfloor hwf_path
      have hwf0 : BWWF s := hwf_path 0 (Nat.zero_le _)
      have hb : blocked s p := by
        by_cases hb : blocked s p
        · exact hb
        · have hafter_ge :
              k + 1 <= ((step s).procs p).budget := by
            unfold step stepProc budgetAfter
            by_cases hc : canConvert s p
            · simp [hc]
              have hle := hwf0.budget_le_cap p
              omega
            · simp [hc, hb, hbudget]
          have htail_path :
              forall j, j < k -> BWWF (stepN j (step s)) := by
            intro j hj
            exact hwf_path (j + 1) (Nat.succ_le_succ (Nat.le_of_lt hj))
          have htail := budget_iter_ge_sub (s := step s) p k htail_path
          have hone : 1 <= ((step s).procs p).budget - k := by
            omega
          have hfinal_pos : 1 <= ((stepN k (step s)).procs p).budget :=
            Nat.le_trans hone htail
          have hfinal_zero : ((stepN k (step s)).procs p).budget = 0 := hfloor
          omega
      have hnot : ¬ canConvert s p := canConvert_false_of_blocked hb
      have hnext_budget : ((step s).procs p).budget = k := by
        unfold step stepProc budgetAfter
        simp [hnot, hb, hbudget]
      have htail_path_le :
          forall j, j <= k -> BWWF (stepN j (step s)) := by
        intro j hj
        exact hwf_path (j + 1) (Nat.succ_le_succ hj)
      have htail_floor : ((stepN k (step s)).procs p).budget = 0 := hfloor
      have htail_blocked :
          blockedThroughout (step s) k p :=
        ih (s := step s) hnext_budget htail_floor htail_path_le
      intro j hj
      cases j with
      | zero =>
          exact hb
      | succ j =>
          have hj_tail : j < k := by omega
          exact htail_blocked j hj_tail

theorem floor_after_full_drain_window_implies_blockedThroughout {n m : Nat}
    {s : BWState n m} {p : Pid n}
    (hcap : (s.procs p).budget = (s.procs p).budgetCap)
    (_hpos : 0 < (s.procs p).budgetCap)
    (hfloor : ((stepN (s.procs p).budgetCap s).procs p).budget = 0)
    (hwf_path : forall j, j <= (s.procs p).budgetCap -> BWWF (stepN j s)) :
    blockedThroughout s (s.procs p).budgetCap p := by
  exact floor_after_budget_window_implies_blockedThroughout_aux
    (s := s) p (s.procs p).budgetCap hcap hfloor hwf_path

theorem closedWaitSet_not_runnable {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    ¬ runnable s p := by
  intro hr
  rcases (hC p hp).2 with ⟨q, _hq, hblocked⟩
  exact hr.2 ⟨q, hblocked⟩

theorem canConvert_false_of_closed {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    ¬ canConvert s p := by
  intro hc
  exact closedWaitSet_not_runnable hC hp hc.1

theorem doneAfter_eq_false_of_closed {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    doneAfter s p = false := by
  exact doneAfter_eq_false_of_unfinished_not_canConvert
    (hC p hp).1 (canConvert_false_of_closed hC hp)

theorem unfinished_step_of_closed {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    unfinished (step s) p := by
  unfold unfinished step stepProc
  have hdone := doneAfter_eq_false_of_closed hC hp
  have hnot := canConvert_false_of_closed hC hp
  have hlt : (s.procs p).converted < (s.procs p).workNeeded :=
    (hC p hp).1.2
  constructor
  · simp [hdone]
  · have hzero : (if canConvert s p then (1 : Nat) else 0) = 0 := by
      simp [hnot]
    simp [hzero]
    exact hlt

theorem holds_step_of_closed_holder {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {q : Pid n} (hq : C q = true) (l : Lid m) :
    (step s).holds q l = s.holds q l := by
  unfold step holdsAfter
  have hdone := doneAfter_eq_false_of_closed hC hq
  simp [hdone]

theorem blockedOn_step_of_closed {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p q : Pid n} (hq : C q = true)
    (hblock : blockedOn s p q) :
    blockedOn (step s) p q := by
  rcases hblock with ⟨l, hwant, hhold, hneq⟩
  refine ⟨l, ?_, ?_, hneq⟩
  · unfold step stepProc
    simp [hwant]
  · rw [holds_step_of_closed_holder hC hq l]
    exact hhold

theorem closedWaitSet_step {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C) :
    closedWaitSet (step s) C := by
  intro p hp
  constructor
  · exact unfinished_step_of_closed hC hp
  · rcases (hC p hp).2 with ⟨q, hq, hblock⟩
    exact ⟨q, hq, blockedOn_step_of_closed hC hq hblock⟩

theorem closedWaitSet_iter {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (k : Nat) (hC : closedWaitSet s C) :
    closedWaitSet (stepN k s) C := by
  induction k generalizing s with
  | zero =>
      exact hC
  | succ k ih =>
      exact ih (closedWaitSet_step hC)

def totalConvertedIn {n m : Nat} (C : Pid n -> Bool)
    (s : BWState n m) : Qty :=
  sumFin (fun p => if C p then ((s.procs p).converted : Qty) else 0)

theorem converted_step_eq_of_closed {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    ((step s).procs p).converted = (s.procs p).converted := by
  unfold step stepProc
  have hnot := canConvert_false_of_closed hC hp
  simp [hnot]

theorem totalConvertedIn_step_eq_of_closed {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C) :
    totalConvertedIn C (step s) = totalConvertedIn C s := by
  unfold totalConvertedIn
  apply sumFin_congr
  intro p
  by_cases hp : C p = true
  · simp [hp, converted_step_eq_of_closed hC hp]
  · have hf : C p = false := by
      cases h : C p
      · rfl
      · simp [h] at hp
    simp [hf]

theorem totalConvertedIn_iter {n m : Nat} {s : BWState n m}
    {C : Pid n -> Bool} (k : Nat) (hC : closedWaitSet s C) :
    totalConvertedIn C (stepN k s) = totalConvertedIn C s := by
  induction k generalizing s with
  | zero =>
      rfl
  | succ k ih =>
      calc
        totalConvertedIn C (stepN (k + 1) s) =
            totalConvertedIn C (stepN k (step s)) := rfl
        _ = totalConvertedIn C (step s) := ih (closedWaitSet_step hC)
        _ = totalConvertedIn C s := totalConvertedIn_step_eq_of_closed hC

structure evidencedDeadlock {n m : Nat} (s0 : BWState n m) (k : Nat)
    (C : Pid n -> Bool) : Prop where
  nonempty : exists p, C p = true
  closed_final : closedWaitSet (stepN k s0) C
  floored_final : floored (stepN k s0) C
  blocked_history : forall p, C p = true -> blockedThroughout s0 k p
  no_conversion : totalConvertedIn C (stepN k s0) = totalConvertedIn C s0

theorem detection_sound_with_budget_evidence {n m : Nat}
    {s0 : BWState n m} {C : Pid n -> Bool} {k : Nat}
    (hC0 : closedWaitSet s0 C)
    (hfull : forall p, C p = true ->
      (s0.procs p).budget = (s0.procs p).budgetCap)
    (hpos : forall p, C p = true -> 0 < (s0.procs p).budgetCap)
    (hsameCap : forall p, C p = true -> (s0.procs p).budgetCap = k)
    (hfloor : floored (stepN k s0) C)
    (hwf_path : forall j, j <= k -> BWWF (stepN j s0))
    (nonempty : exists p, C p = true) :
    evidencedDeadlock s0 k C := by
  constructor
  · exact nonempty
  · exact closedWaitSet_iter k hC0
  · exact hfloor
  · intro p hp
    have hcap_eq : (s0.procs p).budgetCap = k := hsameCap p hp
    have hbudget : (s0.procs p).budget = k := by
      rw [hfull p hp, hcap_eq]
    have hfloor_p : ((stepN k s0).procs p).budget = 0 := hfloor p hp
    have hblocked_k :
        blockedThroughout s0 (s0.procs p).budgetCap p :=
      floor_after_full_drain_window_implies_blockedThroughout
        (s := s0) (p := p) (hfull p hp) (hpos p hp) (by
          rw [hcap_eq]
          exact hfloor_p)
        (by
          intro j hj
          exact hwf_path j (by
            rw [hcap_eq] at hj
            exact hj))
    rw [hcap_eq] at hblocked_k
    exact hblocked_k
  · exact totalConvertedIn_iter k hC0

end
end BudgetWait
end IsoConserve
