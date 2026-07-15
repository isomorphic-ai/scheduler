import IsoConserve.Basic

namespace IsoConserve
namespace WaitGraph

noncomputable section

abbrev Pid (n : Nat) := Fin n
abbrev Lid (m : Nat) := Fin m

structure WGProc (m : Nat) where
  workNeeded : Nat
  converted : Nat
  stock : Qty
  budget : Qty
  wants : Option (Lid m)
  done : Bool

structure WGState (n m : Nat) where
  procs : Pid n -> WGProc m
  holds : Pid n -> Lid m -> Bool
  convertCost : Qty

def unfinished {n m : Nat} (s : WGState n m) (p : Pid n) : Prop :=
  (s.procs p).done = false /\ (s.procs p).converted < (s.procs p).workNeeded

def heldBy {n m : Nat} (s : WGState n m) (l : Lid m) (p : Pid n) : Prop :=
  s.holds p l = true

def heldIn {n m : Nat} (s : WGState n m) (C : Pid n -> Bool)
    (l : Lid m) : Prop :=
  exists p, C p = true /\ heldBy s l p

def blockedOn {n m : Nat} (s : WGState n m) (p q : Pid n) : Prop :=
  exists l, (s.procs p).wants = some l /\ s.holds q l = true /\ q != p

def blocked {n m : Nat} (s : WGState n m) (p : Pid n) : Prop :=
  exists q, blockedOn s p q

def runnable {n m : Nat} (s : WGState n m) (p : Pid n) : Prop :=
  (s.procs p).done = false /\ ¬ blocked s p

def atTableEmpty {n m : Nat} (s : WGState n m) : Prop :=
  forall p, ¬ runnable s p

def closedWaitSet {n m : Nat} (s : WGState n m) (C : Pid n -> Bool) : Prop :=
  forall p, C p = true ->
    unfinished s p /\ exists q, C q = true /\ blockedOn s p q

def floored {n m : Nat} (s : WGState n m) (C : Pid n -> Bool) : Prop :=
  forall p, C p = true -> (s.procs p).budget = 0

structure genuineDeadlock {n m : Nat} (s : WGState n m)
    (C : Pid n -> Bool) : Prop where
  nonempty : exists p, C p = true
  floor : floored s C
  unfinished_all : forall p, C p = true -> unfinished s p
  internally_blocked : forall p, C p = true ->
    exists q, C q = true /\ blockedOn s p q
  not_runnable : forall p, C p = true -> ¬ runnable s p

def canConvert {n m : Nat} (s : WGState n m) (p : Pid n) : Prop :=
  runnable s p /\ s.convertCost <= (s.procs p).stock

local instance canConvertDecidable {n m : Nat}
    (s : WGState n m) (p : Pid n) : Decidable (canConvert s p) :=
  Classical.propDecidable _

def convertedAfter {n m : Nat} (s : WGState n m) (p : Pid n) : Nat :=
  if canConvert s p then (s.procs p).converted + 1 else (s.procs p).converted

def doneAfter {n m : Nat} (s : WGState n m) (p : Pid n) : Bool :=
  if (s.procs p).done then
    true
  else if (s.procs p).workNeeded <= convertedAfter s p then
    true
  else
    false

def holdsAfter {n m : Nat} (s : WGState n m) (p : Pid n) (l : Lid m) : Bool :=
  if doneAfter s p then false else s.holds p l

def stepProc {n m : Nat} (s : WGState n m) (p : Pid n) : WGProc m :=
  let conv := if canConvert s p then 1 else 0
  { workNeeded := (s.procs p).workNeeded
    converted := (s.procs p).converted + conv
    stock := (s.procs p).stock - s.convertCost * (conv : Qty)
    budget := (s.procs p).budget
    wants := (s.procs p).wants
    done := doneAfter s p }

def step {n m : Nat} (s : WGState n m) : WGState n m :=
  { procs := fun p => stepProc s p
    holds := fun p l => holdsAfter s p l
    convertCost := s.convertCost }

theorem convertedAfter_eq_succ_of_canConvert {n m : Nat}
    {s : WGState n m} {p : Pid n} (h : canConvert s p) :
    convertedAfter s p = (s.procs p).converted + 1 := by
  unfold convertedAfter
  simp [h]

theorem doneAfter_true_of_convertedAfter_reaches {n m : Nat}
    {s : WGState n m} {p : Pid n}
    (h : (s.procs p).workNeeded <= convertedAfter s p) :
    doneAfter s p = true := by
  unfold doneAfter
  by_cases hd : (s.procs p).done
  · simp [hd]
  · simp [hd, h]

theorem done_releases_locks {n m : Nat} {s : WGState n m}
    {p : Pid n} {l : Lid m} (h : doneAfter s p = true) :
    (step s).holds p l = false := by
  unfold step holdsAfter
  simp [h]

theorem closedWaitSet_not_runnable {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    ¬ runnable s p := by
  intro hr
  rcases (hC p hp).2 with ⟨q, _hq, hblocked⟩
  exact hr.2 ⟨q, hblocked⟩

theorem canConvert_false_of_closed {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    ¬ canConvert s p := by
  intro hc
  exact closedWaitSet_not_runnable hC hp hc.1

theorem convertedAfter_eq_of_closed {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    convertedAfter s p = (s.procs p).converted := by
  unfold convertedAfter
  have hnot := canConvert_false_of_closed hC hp
  simp [hnot]

theorem doneAfter_eq_false_of_closed {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    doneAfter s p = false := by
  unfold doneAfter
  have hdone : (s.procs p).done = false := (hC p hp).1.1
  have hconv : convertedAfter s p = (s.procs p).converted :=
    convertedAfter_eq_of_closed hC hp
  have hlt : (s.procs p).converted < (s.procs p).workNeeded :=
    (hC p hp).1.2
  simp [hdone, hconv]
  omega

theorem unfinished_step_of_closed {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    unfinished (step s) p := by
  unfold unfinished step stepProc
  have hdone := doneAfter_eq_false_of_closed hC hp
  have hconv := convertedAfter_eq_of_closed hC hp
  have hnot := canConvert_false_of_closed hC hp
  have hlt : (s.procs p).converted < (s.procs p).workNeeded :=
    (hC p hp).1.2
  constructor
  · simp [hdone]
  · have hzero : (if canConvert s p then (1 : Nat) else 0) = 0 := by
      simp [hnot]
    simp [hzero]
    exact hlt

theorem holds_step_of_closed_holder {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {q : Pid n} (hq : C q = true) (l : Lid m) :
    (step s).holds q l = s.holds q l := by
  unfold step holdsAfter
  have hdone := doneAfter_eq_false_of_closed hC hq
  simp [hdone]

theorem blockedOn_step_of_closed {n m : Nat} {s : WGState n m}
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

theorem closedWaitSet_step {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C) :
    closedWaitSet (step s) C := by
  intro p hp
  constructor
  · exact unfinished_step_of_closed hC hp
  · rcases (hC p hp).2 with ⟨q, hq, hblock⟩
    exact ⟨q, hq, blockedOn_step_of_closed hC hq hblock⟩

def totalConvertedIn {n m : Nat} (C : Pid n -> Bool)
    (s : WGState n m) : Qty :=
  sumFin (fun p => if C p then ((s.procs p).converted : Qty) else 0)

theorem converted_step_eq_of_closed {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    {p : Pid n} (hp : C p = true) :
    ((step s).procs p).converted = (s.procs p).converted := by
  unfold step stepProc
  have hnot := canConvert_false_of_closed hC hp
  simp [hnot]

theorem totalConvertedIn_step_eq_of_closed {n m : Nat} {s : WGState n m}
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

def stepN {n m : Nat} : Nat -> WGState n m -> WGState n m
  | 0, s => s
  | k + 1, s => stepN k (step s)

theorem closedWaitSet_iter {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (k : Nat) (hC : closedWaitSet s C) :
    closedWaitSet (stepN k s) C := by
  induction k generalizing s with
  | zero =>
      exact hC
  | succ k ih =>
      exact ih (closedWaitSet_step hC)

theorem totalConvertedIn_iter {n m : Nat} {s : WGState n m}
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

theorem L3_waitComponent_absorbing {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    (_nonempty : exists p, C p = true) :
    (forall p, C p = true -> ¬ runnable (step s) p)
      /\ totalConvertedIn C (step s) = totalConvertedIn C s := by
  constructor
  · intro p hp
    exact closedWaitSet_not_runnable (closedWaitSet_step hC) hp
  · exact totalConvertedIn_step_eq_of_closed hC

theorem L3_waitComponent_absorbing_iter {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (k : Nat) (hC : closedWaitSet s C)
    (_nonempty : exists p, C p = true) :
    (forall p, C p = true -> ¬ runnable (stepN k s) p)
      /\ totalConvertedIn C (stepN k s) = totalConvertedIn C s := by
  constructor
  · intro p hp
    exact closedWaitSet_not_runnable (closedWaitSet_iter k hC) hp
  · exact totalConvertedIn_iter k hC

theorem detection_sound {n m : Nat} {s : WGState n m}
    {C : Pid n -> Bool} (hC : closedWaitSet s C)
    (hf : floored s C) (nonempty : exists p, C p = true) :
    genuineDeadlock s C := by
  constructor
  · exact nonempty
  · exact hf
  · intro p hp
    exact (hC p hp).1
  · intro p hp
    exact (hC p hp).2
  · intro p hp
    exact closedWaitSet_not_runnable hC hp

end
end WaitGraph
end IsoConserve
