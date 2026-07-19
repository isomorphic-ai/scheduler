import Std

namespace IsoConserve
namespace PNCounter

abbrev Node (n : Nat) := Fin n

structure Counter (n : Nat) where
  pos : Node n -> Nat
  neg : Node n -> Nat

def sumFinNat {n : Nat} (f : Node n -> Nat) : Nat :=
  (List.finRange n).map f |>.sum

def sumFinInt {n : Nat} (f : Node n -> Nat) : Int :=
  (sumFinNat f : Int)

def value {n : Nat} (c : Counter n) : Int :=
  sumFinInt c.pos - sumFinInt c.neg

def le {n : Nat} (a b : Counter n) : Prop :=
  (forall i, a.pos i <= b.pos i) /\
    (forall i, a.neg i <= b.neg i)

def merge {n : Nat} (a b : Counter n) : Counter n :=
  { pos := fun i => max (a.pos i) (b.pos i)
    neg := fun i => max (a.neg i) (b.neg i) }

def zero (n : Nat) : Counter n :=
  { pos := fun _ => 0, neg := fun _ => 0 }

def inc {n : Nat} (c : Counter n) (i : Node n) (amount : Nat) :
    Counter n :=
  { c with pos := fun j => if j = i then c.pos j + amount else c.pos j }

def dec {n : Nat} (c : Counter n) (i : Node n) (amount : Nat) :
    Counter n :=
  { c with neg := fun j => if j = i then c.neg j + amount else c.neg j }

theorem le_refl {n : Nat} (a : Counter n) : le a a := by
  constructor <;> intro i <;> exact Nat.le_refl _

theorem le_trans {n : Nat} {a b c : Counter n}
    (hab : le a b) (hbc : le b c) : le a c := by
  constructor
  · intro i
    exact Nat.le_trans (hab.1 i) (hbc.1 i)
  · intro i
    exact Nat.le_trans (hab.2 i) (hbc.2 i)

theorem le_antisymm {n : Nat} {a b : Counter n}
    (hab : le a b) (hba : le b a) : a = b := by
  cases a with
  | mk apos aneg =>
    cases b with
    | mk bpos bneg =>
      simp [le] at hab hba
      have hpos : apos = bpos := by
        funext i
        exact Nat.le_antisymm (hab.1 i) (hba.1 i)
      have hneg : aneg = bneg := by
        funext i
        exact Nat.le_antisymm (hab.2 i) (hba.2 i)
      simp [hpos, hneg]

theorem le_merge_left {n : Nat} (a b : Counter n) : le a (merge a b) := by
  constructor <;> intro i <;> simp [merge, Nat.le_max_left]

theorem le_merge_right {n : Nat} (a b : Counter n) : le b (merge a b) := by
  constructor <;> intro i <;> simp [merge, Nat.le_max_right]

theorem merge_least {n : Nat} {a b c : Counter n}
    (hac : le a c) (hbc : le b c) : le (merge a b) c := by
  constructor
  · intro i
    simp [merge]
    exact (Nat.max_le).2 ⟨hac.1 i, hbc.1 i⟩
  · intro i
    simp [merge]
    exact (Nat.max_le).2 ⟨hac.2 i, hbc.2 i⟩

theorem merge_idem {n : Nat} (a : Counter n) : merge a a = a := by
  cases a with
  | mk pos neg =>
    simp [merge]

theorem merge_comm {n : Nat} (a b : Counter n) : merge a b = merge b a := by
  cases a with
  | mk apos aneg =>
    cases b with
    | mk bpos bneg =>
      simp [merge, Nat.max_comm]

theorem merge_assoc {n : Nat} (a b c : Counter n) :
    merge (merge a b) c = merge a (merge b c) := by
  cases a with
  | mk apos aneg =>
    cases b with
    | mk bpos bneg =>
      cases c with
      | mk cpos cneg =>
        simp [merge, Nat.max_assoc]

theorem inc_pos_self {n : Nat} (c : Counter n) (i : Node n)
    (amount : Nat) :
    (inc c i amount).pos i = c.pos i + amount := by
  simp [inc]

theorem dec_neg_self {n : Nat} (c : Counter n) (i : Node n)
    (amount : Nat) :
    (dec c i amount).neg i = c.neg i + amount := by
  simp [dec]

theorem inc_other_components {n : Nat} (c : Counter n) {i j : Node n}
    (amount : Nat) (h : j ≠ i) :
    (inc c i amount).pos j = c.pos j /\
      (inc c i amount).neg j = c.neg j := by
  simp [inc, h]

theorem dec_other_components {n : Nat} (c : Counter n) {i j : Node n}
    (amount : Nat) (h : j ≠ i) :
    (dec c i amount).pos j = c.pos j /\
      (dec c i amount).neg j = c.neg j := by
  simp [dec, h]

theorem inc_le {n : Nat} (c : Counter n) (i : Node n) (amount : Nat) :
    le c (inc c i amount) := by
  constructor
  · intro j
    by_cases h : j = i
    · simp [inc, h]
    · simp [inc, h]
  · intro j
    simp [inc]

theorem dec_le {n : Nat} (c : Counter n) (i : Node n) (amount : Nat) :
    le c (dec c i amount) := by
  constructor
  · intro j
    simp [dec]
  · intro j
    by_cases h : j = i
    · simp [dec, h]
    · simp [dec, h]

theorem merge_monotone_left {n : Nat} {a b c : Counter n}
    (hab : le a b) : le (merge a c) (merge b c) := by
  constructor
  · intro i
    simp [merge]
    exact (Nat.max_le).2
      ⟨Nat.le_trans (hab.1 i) (Nat.le_max_left (b.pos i) (c.pos i)),
        Nat.le_max_right (b.pos i) (c.pos i)⟩
  · intro i
    simp [merge]
    exact (Nat.max_le).2
      ⟨Nat.le_trans (hab.2 i) (Nat.le_max_left (b.neg i) (c.neg i)),
        Nat.le_max_right (b.neg i) (c.neg i)⟩

theorem merge_monotone_right {n : Nat} {a b c : Counter n}
    (hab : le a b) : le (merge c a) (merge c b) := by
  constructor
  · intro i
    simp [merge]
    exact (Nat.max_le).2
      ⟨Nat.le_max_left (c.pos i) (b.pos i),
        Nat.le_trans (hab.1 i) (Nat.le_max_right (c.pos i) (b.pos i))⟩
  · intro i
    simp [merge]
    exact (Nat.max_le).2
      ⟨Nat.le_max_left (c.neg i) (b.neg i),
        Nat.le_trans (hab.2 i) (Nat.le_max_right (c.neg i) (b.neg i))⟩

inductive MergeTree (n : Nat) where
  | leaf : Counter n -> MergeTree n
  | fork : MergeTree n -> MergeTree n -> MergeTree n

def eval {n : Nat} : MergeTree n -> Counter n
  | MergeTree.leaf c => c
  | MergeTree.fork l r => merge (eval l) (eval r)

def leaves {n : Nat} : MergeTree n -> List (Counter n)
  | MergeTree.leaf c => [c]
  | MergeTree.fork l r => leaves l ++ leaves r

def maxSeenPos {n : Nat} : List (Counter n) -> Node n -> Nat
  | [], _ => 0
  | c :: xs, i => max (c.pos i) (maxSeenPos xs i)

def maxSeenNeg {n : Nat} : List (Counter n) -> Node n -> Nat
  | [], _ => 0
  | c :: xs, i => max (c.neg i) (maxSeenNeg xs i)

def globalRecorded {n : Nat} (xs : List (Counter n)) : Counter n :=
  { pos := maxSeenPos xs, neg := maxSeenNeg xs }

theorem maxSeenPos_append {n : Nat} (xs ys : List (Counter n))
    (i : Node n) :
    maxSeenPos (xs ++ ys) i =
      max (maxSeenPos xs i) (maxSeenPos ys i) := by
  induction xs with
  | nil =>
      simp [maxSeenPos]
  | cons c xs ih =>
      simp [maxSeenPos, ih, Nat.max_assoc, Nat.max_comm]

theorem maxSeenNeg_append {n : Nat} (xs ys : List (Counter n))
    (i : Node n) :
    maxSeenNeg (xs ++ ys) i =
      max (maxSeenNeg xs i) (maxSeenNeg ys i) := by
  induction xs with
  | nil =>
      simp [maxSeenNeg]
  | cons c xs ih =>
      simp [maxSeenNeg, ih, Nat.max_assoc, Nat.max_comm]

theorem globalRecorded_append {n : Nat} (xs ys : List (Counter n)) :
    globalRecorded (xs ++ ys) =
      merge (globalRecorded xs) (globalRecorded ys) := by
  unfold globalRecorded merge
  have hpos :
      maxSeenPos (xs ++ ys) =
        fun i => max (maxSeenPos xs i) (maxSeenPos ys i) := by
    funext i
    exact maxSeenPos_append xs ys i
  have hneg :
      maxSeenNeg (xs ++ ys) =
        fun i => max (maxSeenNeg xs i) (maxSeenNeg ys i) := by
    funext i
    exact maxSeenNeg_append xs ys i
  rw [hpos, hneg]

theorem globalRecorded_singleton {n : Nat} (c : Counter n) :
    globalRecorded [c] = c := by
  cases c with
  | mk pos neg =>
    simp [globalRecorded, maxSeenPos, maxSeenNeg]

theorem eval_eq_globalRecorded {n : Nat} (t : MergeTree n) :
    eval t = globalRecorded (leaves t) := by
  induction t with
  | leaf c =>
      simp [eval, leaves, globalRecorded_singleton]
  | fork l r ihl ihr =>
      simp [eval, leaves, ihl, ihr, globalRecorded_append]

theorem same_global_record_converges {n : Nat} {xs ys : List (Counter n)}
    (hpos : forall i, maxSeenPos xs i = maxSeenPos ys i)
    (hneg : forall i, maxSeenNeg xs i = maxSeenNeg ys i) :
    globalRecorded xs = globalRecorded ys := by
  unfold globalRecorded
  have hp : maxSeenPos xs = maxSeenPos ys := by
    funext i
    exact hpos i
  have hn : maxSeenNeg xs = maxSeenNeg ys := by
    funext i
    exact hneg i
  rw [hp, hn]

theorem heal_value_eq_global_recorded_ops {n : Nat}
    (xs : List (Counter n)) :
    value (globalRecorded xs) =
      sumFinInt (maxSeenPos xs) - sumFinInt (maxSeenNeg xs) := by
  rfl

theorem replica_le_globalRecorded {n : Nat} {xs : List (Counter n)}
    {x : Counter n} (hmem : x ∈ xs) :
    le x (globalRecorded xs) := by
  induction xs with
  | nil =>
      simp at hmem
  | cons y ys ih =>
      simp at hmem
      cases hmem with
      | inl hxy =>
          subst hxy
          constructor <;> intro i <;>
            simp [globalRecorded, maxSeenPos, maxSeenNeg, Nat.le_max_left]
      | inr htail =>
          have ihle := ih htail
          constructor
          · intro i
            exact Nat.le_trans (ihle.1 i)
              (by simp [globalRecorded, maxSeenPos, Nat.le_max_right])
          · intro i
            exact Nat.le_trans (ihle.2 i)
              (by simp [globalRecorded, maxSeenNeg, Nat.le_max_right])

theorem partition_left_le_heal {n : Nat} (left right : List (Counter n)) :
    le (globalRecorded left) (globalRecorded (left ++ right)) := by
  constructor
  · intro i
    simp [globalRecorded, maxSeenPos_append, Nat.le_max_left]
  · intro i
    simp [globalRecorded, maxSeenNeg_append, Nat.le_max_left]

theorem partition_right_le_heal {n : Nat} (left right : List (Counter n)) :
    le (globalRecorded right) (globalRecorded (left ++ right)) := by
  constructor
  · intro i
    simp [globalRecorded, maxSeenPos_append, Nat.le_max_right]
  · intro i
    simp [globalRecorded, maxSeenNeg_append, Nat.le_max_right]

theorem off_partition_decrement_surfaces {n : Nat}
    {xs : List (Counter n)} {x : Counter n} {i : Node n} {amount : Nat}
    (hmem : x ∈ xs) (hdebt : amount <= x.neg i) :
    amount <= (globalRecorded xs).neg i := by
  exact Nat.le_trans hdebt ((replica_le_globalRecorded hmem).2 i)

theorem off_partition_increment_surfaces {n : Nat}
    {xs : List (Counter n)} {x : Counter n} {i : Node n} {amount : Nat}
    (hmem : x ∈ xs) (hcredit : amount <= x.pos i) :
    amount <= (globalRecorded xs).pos i := by
  exact Nat.le_trans hcredit ((replica_le_globalRecorded hmem).1 i)

end PNCounter
end IsoConserve
