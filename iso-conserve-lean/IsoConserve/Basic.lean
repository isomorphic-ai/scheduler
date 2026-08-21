import Std

namespace IsoConserve

abbrev Qty := Rat

def sumFin {n : Nat} (f : Fin n -> Qty) : Qty :=
  (List.finRange n).map f |>.sum

theorem sumFin_congr {n : Nat} {f g : Fin n -> Qty}
    (h : forall i, f i = g i) :
    sumFin f = sumFin g := by
  unfold sumFin
  induction List.finRange n with
  | nil => rfl
  | cons a as ih => simp [h a, ih]

theorem sumFin_add {n : Nat} (f g : Fin n -> Qty) :
    sumFin (fun i => f i + g i) = sumFin f + sumFin g := by
  unfold sumFin
  induction List.finRange n with
  | nil => grind
  | cons a as ih => simp [ih]; grind

theorem sumFin_sub {n : Nat} (f g : Fin n -> Qty) :
    sumFin (fun i => f i - g i) = sumFin f - sumFin g := by
  unfold sumFin
  induction List.finRange n with
  | nil => grind
  | cons a as ih => simp [ih]; grind

theorem sumFin_mul_left {n : Nat} (c : Qty) (f : Fin n -> Qty) :
    sumFin (fun i => c * f i) = c * sumFin f := by
  unfold sumFin
  induction List.finRange n with
  | nil => grind
  | cons a as ih => simp [ih]; grind

theorem sumFin_zero {n : Nat} :
    sumFin (fun _ : Fin n => (0 : Qty)) = 0 := by
  unfold sumFin
  induction List.finRange n with
  | nil => rfl
  | cons a as ih => simp [ih]; grind

theorem sumFin_nonneg {n : Nat} (f : Fin n -> Qty)
    (h : forall i, 0 <= f i) :
    0 <= sumFin f := by
  unfold sumFin
  induction List.finRange n with
  | nil => grind
  | cons a as ih =>
      simp
      have ha : 0 <= f a := h a
      grind

theorem sumFin_le {n : Nat} (f g : Fin n -> Qty)
    (h : forall i, f i <= g i) :
    sumFin f <= sumFin g := by
  unfold sumFin
  induction List.finRange n with
  | nil => grind
  | cons a as ih =>
      simp
      have ha : f a <= g a := h a
      grind

structure Proc where
  rate : Qty
  workNeeded : Nat
  stock : Qty
  credit : Qty
  converted : Nat
  done : Bool
  netFlowIntegral : Qty
deriving Repr

structure Sys (n : Nat) where
  procs : Fin n -> Proc
  runnable : Fin n -> Bool
  reservoir : Qty
  convertCost : Qty
  totalQ : Qty

def procAccounted (cost : Qty) (p : Proc) : Qty :=
  p.stock + p.credit + cost * (p.converted : Qty)

def totalHeld {n : Nat} (s : Sys n) : Qty :=
  sumFin (fun i => (s.procs i).stock + (s.procs i).credit)

def totalCredit {n : Nat} (s : Sys n) : Qty :=
  sumFin (fun i => (s.procs i).credit)

def totalConverted {n : Nat} (s : Sys n) : Qty :=
  sumFin (fun i => ((s.procs i).converted : Qty))

def accounted {n : Nat} (s : Sys n) : Qty :=
  s.reservoir + sumFin (fun i => procAccounted s.convertCost (s.procs i))

def allDone {n : Nat} (s : Sys n) : Prop :=
  forall i, (s.procs i).done = true

def atTableEmpty {n : Nat} (s : Sys n) : Prop :=
  forall i, s.runnable i = false

def deadlocked {n : Nat} (s : Sys n) : Prop :=
  atTableEmpty s /\ ¬ allDone s

def active {n : Nat} (s : Sys n) (x : Fin n -> Qty) (i : Fin n) : Qty :=
  if s.runnable i then x i else 0

def activeNat {n : Nat} (s : Sys n) (x : Fin n -> Nat) (i : Fin n) : Nat :=
  if s.runnable i then x i else 0

def convertibleStock {n : Nat} (s : Sys n) : Qty :=
  sumFin (fun i => active s (fun j => (s.procs j).stock) i)

def L4Invariant {n : Nat} (s : Sys n) : Prop :=
  forall i, (s.procs i).stock + (s.procs i).credit =
    (s.procs i).netFlowIntegral

structure WF {n : Nat} (s : Sys n) : Prop where
  cost_pos : 0 < s.convertCost
  reservoir_nonneg : 0 <= s.reservoir
  stock_nonneg : forall i, 0 <= (s.procs i).stock
  credit_nonneg : forall i, 0 <= (s.procs i).credit
  rate_nonneg : forall i, 0 <= (s.procs i).rate
  accounted_eq_total : accounted s = s.totalQ

structure FlowPlan {n : Nat} (s : Sys n) where
  share : Fin n -> Qty
  convert : Fin n -> Nat
  reservoir_after_nonneg :
    0 <= s.reservoir - sumFin (fun i => active s share i)
  stock_after_nonneg : forall i,
    0 <= (s.procs i).stock + active s share i -
      s.convertCost * (activeNat s convert i : Qty)

def stepProc {n : Nat} (s : Sys n) (plan : FlowPlan s) (i : Fin n) : Proc :=
  let p := s.procs i
  let flow := active s plan.share i
  let conv := activeNat s plan.convert i
  { p with
    stock := p.stock + flow - s.convertCost * conv
    converted := p.converted + conv
    netFlowIntegral := p.netFlowIntegral + flow - s.convertCost * conv }

def step {n : Nat} (s : Sys n) (plan : FlowPlan s) : Sys n :=
  { procs := fun i => stepProc s plan i
    runnable := s.runnable
    reservoir := s.reservoir - sumFin (fun i => active s plan.share i)
    convertCost := s.convertCost
    totalQ := s.totalQ }

theorem procAccounted_stepProc {n : Nat} (s : Sys n)
    (plan : FlowPlan s) (i : Fin n) :
    procAccounted s.convertCost (stepProc s plan i) =
      procAccounted s.convertCost (s.procs i) + active s plan.share i := by
  unfold procAccounted stepProc
  grind

structure DrainPlan {n : Nat} (s : Sys n) where
  drain : Fin n -> Qty
  drain_nonneg : forall i, 0 <= drain i
  drain_blocked : forall i, s.runnable i = true -> drain i = 0
  stock_after_nonneg : forall i, 0 <= (s.procs i).stock - drain i

def drainProc {n : Nat} (s : Sys n) (plan : DrainPlan s) (i : Fin n) : Proc :=
  let p := s.procs i
  { p with
    stock := p.stock - plan.drain i
    netFlowIntegral := p.netFlowIntegral - plan.drain i }

def drainStep {n : Nat} (s : Sys n) (plan : DrainPlan s) : Sys n :=
  { procs := fun i => drainProc s plan i
    runnable := s.runnable
    reservoir := s.reservoir + sumFin plan.drain
    convertCost := s.convertCost
    totalQ := s.totalQ }

theorem procAccounted_drainProc {n : Nat} (s : Sys n)
    (plan : DrainPlan s) (i : Fin n) :
    procAccounted s.convertCost (drainProc s plan i) =
      procAccounted s.convertCost (s.procs i) - plan.drain i := by
  unfold procAccounted drainProc
  grind

structure YieldPlan {n : Nat} (s : Sys n) where
  amount : Fin n -> Qty
  amount_nonneg : forall i, 0 <= amount i
  stock_after_nonneg : forall i, 0 <= (s.procs i).stock - amount i

def yieldProc {n : Nat} (s : Sys n) (plan : YieldPlan s) (i : Fin n) : Proc :=
  let p := s.procs i
  { p with
    stock := p.stock - plan.amount i
    credit := p.credit + plan.amount i }

def yieldStep {n : Nat} (s : Sys n) (plan : YieldPlan s) : Sys n :=
  { procs := fun i => yieldProc s plan i
    runnable := s.runnable
    reservoir := s.reservoir
    convertCost := s.convertCost
    totalQ := s.totalQ }

theorem procAccounted_yieldProc {n : Nat} (s : Sys n)
    (plan : YieldPlan s) (i : Fin n) :
    procAccounted s.convertCost (yieldProc s plan i) =
      procAccounted s.convertCost (s.procs i) := by
  unfold procAccounted yieldProc
  grind

end IsoConserve
