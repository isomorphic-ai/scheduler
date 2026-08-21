import IsoConserve.CoreTrace

namespace IsoConserve
namespace RateRouting

open CoreTrace

noncomputable section

local instance propDecidable (p : Prop) : Decidable p :=
  Classical.propDecidable p

def baseRate {n m : Nat} (s : CoreState n m) (p : ProcId n) : Qty :=
  (s.procs p).baseRate

def firstHolder {n m : Nat} (s : CoreState n m) (l : LockId m) :
    Option (ProcId n) :=
  (List.finRange n).find? (fun q => s.holds q l)

def waitsOn {n m : Nat} (s : CoreState n m) (p : ProcId n) :
    Option (ProcId n) :=
  match (s.procs p).wants with
  | none => none
  | some l =>
      match firstHolder s l with
      | none => none
      | some q => if q = p then none else some q

def destination {n m : Nat} (s : CoreState n m) :
    Nat -> ProcId n -> Option (ProcId n)
  | 0, _p => none
  | fuel + 1, p =>
      if unfinished s p then
        if runnable s p then
          some p
        else
          match waitsOn s p with
          | none => none
          | some q => destination s fuel q
      else
        none

def finalDestination {n m : Nat} (s : CoreState n m) (p : ProcId n) :
    Option (ProcId n) :=
  destination s n p

def routesTo {n m : Nat} (s : CoreState n m) (p r : ProcId n) : Prop :=
  finalDestination s p = some r

def trapped {n m : Nat} (s : CoreState n m) (p : ProcId n) : Prop :=
  finalDestination s p = none

def liveRoutesTo {n m : Nat} (s : CoreState n m)
    (p r : ProcId n) : Prop :=
  unfinished s p /\ routesTo s p r

def liveTrapped {n m : Nat} (s : CoreState n m) (p : ProcId n) : Prop :=
  unfinished s p /\ trapped s p

def routedRate {n m : Nat} (s : CoreState n m) (r : ProcId n) : Qty :=
  sumFin (fun p => if liveRoutesTo s p r then baseRate s p else 0)

def strandedRate {n m : Nat} (s : CoreState n m) : Qty :=
  sumFin (fun p => if liveTrapped s p then baseRate s p else 0)

def liveBaseRate {n m : Nat} (s : CoreState n m) : Qty :=
  sumFin (fun p => if unfinished s p then baseRate s p else 0)

theorem destination_some_runnable {n m : Nat} (s : CoreState n m)
    {fuel : Nat} {p r : ProcId n}
    (hdest : destination s fuel p = some r) :
    runnable s r := by
  induction fuel generalizing p with
  | zero =>
      simp [destination] at hdest
  | succ fuel ih =>
      unfold destination at hdest
      by_cases hu : unfinished s p
      · simp [hu] at hdest
        by_cases hr : runnable s p
        · simp [hr] at hdest
          exact hdest ▸ hr
        · simp [hr] at hdest
          cases hw : waitsOn s p with
          | none =>
              simp [hw] at hdest
          | some q =>
              simp [hw] at hdest
              exact ih hdest
      · simp [hu] at hdest

theorem sumFin_succ {n : Nat} (g : Fin (n + 1) -> Qty) :
    sumFin g = g 0 + sumFin (fun i : Fin n => g (Fin.succ i)) := by
  unfold sumFin
  rw [List.finRange_succ]
  simp
  change g 0 + (List.map (fun i : Fin n => g (Fin.succ i))
      (List.finRange n)).sum =
    g 0 + (List.map (fun i : Fin n => g (Fin.succ i))
      (List.finRange n)).sum
  rfl

theorem sumFin_swap {n m : Nat} (f : Fin n -> Fin m -> Qty) :
    sumFin (fun i => sumFin (fun j => f i j)) =
      sumFin (fun j => sumFin (fun i => f i j)) := by
  induction n with
  | zero =>
      change 0 = sumFin (fun _ : Fin m => (0 : Qty))
      rw [sumFin_zero]
  | succ n ih =>
      calc
        sumFin (fun i : Fin (n + 1) => sumFin (fun j : Fin m => f i j)) =
            sumFin (fun j : Fin m => f 0 j) +
              sumFin (fun i : Fin n =>
                sumFin (fun j : Fin m => f (Fin.succ i) j)) := by
                rw [sumFin_succ]
        _ = sumFin (fun j : Fin m => f 0 j) +
              sumFin (fun j : Fin m =>
                sumFin (fun i : Fin n => f (Fin.succ i) j)) := by
                rw [ih]
        _ = sumFin (fun j : Fin m =>
              f 0 j + sumFin (fun i : Fin n => f (Fin.succ i) j)) := by
                rw [sumFin_add]
        _ = sumFin (fun j : Fin m =>
              sumFin (fun i : Fin (n + 1) => f i j)) := by
                apply sumFin_congr
                intro j
                rw [sumFin_succ]

theorem sumFin_single {n : Nat} (x : Fin n) (a : Qty) :
    sumFin (fun r => if r = x then a else 0) = a := by
  induction n with
  | zero => exact Fin.elim0 x
  | succ n ih =>
      cases x using Fin.cases with
      | zero =>
          unfold sumFin
          rw [List.finRange_succ]
          have htail :
              (List.map
                ((fun r : Fin (n + 1) => if r = 0 then a else 0) ∘
                  Fin.succ) (List.finRange n)).sum = 0 := by
            induction (List.finRange n) with
            | nil => rfl
            | cons r rs ihl =>
                simp [Function.comp_apply, Fin.succ_ne_zero r, ihl]
                grind
          simp [htail]
          grind
      | succ x =>
          unfold sumFin
          rw [List.finRange_succ]
          have hfirst : ¬ ((0 : Fin (n + 1)) = Fin.succ x) := by
            intro h
            exact Fin.succ_ne_zero x h.symm
          have htail :
              (List.map
                ((fun r : Fin (n + 1) => if r = Fin.succ x then a else 0) ∘
                  Fin.succ) (List.finRange n)).sum =
                (List.map (fun r : Fin n => if r = x then a else 0)
                  (List.finRange n)).sum := by
            apply congrArg List.sum
            apply List.map_congr_left
            intro r
            by_cases h : r = x
            · simp [Function.comp_apply, h]
            · have hs : ¬ Fin.succ r = Fin.succ x := by
                intro heq
                apply h
                apply Fin.ext
                have hv := congrArg Fin.val heq
                simp at hv
                omega
              simp [Function.comp_apply, h, hs]
          simp [hfirst, htail]
          change 0 + sumFin (fun r : Fin n => if r = x then a else 0) = a
          rw [ih x]
          grind

theorem sumFin_pair {n : Nat} {x y : Fin n} (hxy : x ≠ y)
    (a b : Qty) :
    sumFin (fun r => if r = x then a else if r = y then b else 0) =
      a + b := by
  have hsplit :
      sumFin (fun r => if r = x then a else if r = y then b else 0) =
        sumFin (fun r => if r = x then a else 0) +
          sumFin (fun r => if r = y then b else 0) := by
    rw [← sumFin_add]
    apply sumFin_congr
    intro r
    by_cases hx : r = x
    · have hy : ¬ r = y := by
        intro hry
        exact hxy (hx.symm.trans hry)
      simp [hx, hxy]
      grind
    · by_cases hy : r = y
      · have hyx : ¬ y = x := Ne.symm hxy
        simp [hy, hyx]
        grind
      · simp [hx, hy]
        grind
  rw [hsplit, sumFin_single x a, sumFin_single y b]

theorem sumFin_option {n : Nat} (d : Option (Fin n)) (a : Qty) :
    sumFin (fun r => if d = some r then a else 0) =
      match d with | some _ => a | none => 0 := by
  cases d with
  | none =>
      calc
        sumFin (fun r : Fin n => if none = some r then a else 0) =
            sumFin (fun _ : Fin n => (0 : Qty)) := by
              apply sumFin_congr
              intro r
              simp
        _ = 0 := sumFin_zero
  | some x =>
      calc
        sumFin (fun r : Fin n => if some x = some r then a else 0) =
            sumFin (fun r : Fin n => if r = x then a else 0) := by
              apply sumFin_congr
              intro r
              by_cases h : r = x
              · simp [h]
              · have hopt : ¬ some x = some r := by
                  intro heq
                  apply h
                  cases heq
                  rfl
                simp [h, hopt]
        _ = a := sumFin_single x a

def routedContribution {n m : Nat} (s : CoreState n m) (p : ProcId n) : Qty :=
  sumFin (fun r => if liveRoutesTo s p r then baseRate s p else 0)

theorem routedContribution_eq {n m : Nat}
    (s : CoreState n m) (p : ProcId n) :
    routedContribution s p =
      if unfinished s p then
        match finalDestination s p with | some _ => baseRate s p | none => 0
      else
        0 := by
  unfold routedContribution
  by_cases hu : unfinished s p
  · simp [liveRoutesTo, routesTo, hu]
    cases hd : finalDestination s p with
    | none =>
      calc
          sumFin (fun r : ProcId n =>
              if (none : Option (ProcId n)) = some r then baseRate s p else 0) =
              sumFin (fun _ : ProcId n => (0 : Qty)) := by
                apply sumFin_congr
                intro r
                simp
          _ = 0 := sumFin_zero
    | some r =>
        calc
          sumFin (fun x : ProcId n =>
              if (some r : Option (ProcId n)) = some x then baseRate s p else 0) =
              sumFin (fun x : ProcId n => if x = r then baseRate s p else 0) := by
                apply sumFin_congr
                intro x
                by_cases hx : x = r
                · subst hx
                  simp
                · have hnot : ¬ finalDestination s p = some x := by
                    intro heq
                    rw [hd] at heq
                    cases heq
                    exact hx rfl
                  have hopt : ¬ (some r : Option (ProcId n)) = some x := by
                    intro heq
                    cases heq
                    exact hx rfl
                  simp [hopt, hx]
          _ = baseRate s p := sumFin_single r (baseRate s p)
  · have hzero :
        sumFin (fun r : ProcId n =>
          if liveRoutesTo s p r then baseRate s p else 0) = 0 := by
        calc
          sumFin (fun r : ProcId n =>
              if liveRoutesTo s p r then baseRate s p else 0) =
              sumFin (fun _ : ProcId n => (0 : Qty)) := by
                apply sumFin_congr
                intro r
                simp [liveRoutesTo, hu]
          _ = 0 := sumFin_zero
    rw [hzero]
    simp [hu]

theorem routed_sum_eq_contributions {n m : Nat} (s : CoreState n m) :
    sumFin (fun r => routedRate s r) =
      sumFin (fun p => routedContribution s p) := by
  unfold routedRate routedContribution
  exact sumFin_swap (fun r p : ProcId n =>
    if liveRoutesTo s p r then baseRate s p else 0)

theorem routedRate_eq_zero_of_not_runnable {n m : Nat}
    {s : CoreState n m} {r : ProcId n} (hr : ¬ runnable s r) :
    routedRate s r = 0 := by
  unfold routedRate
  calc
    sumFin (fun p : ProcId n =>
        if liveRoutesTo s p r then baseRate s p else 0) =
        sumFin (fun _ : ProcId n => (0 : Qty)) := by
          apply sumFin_congr
          intro p
          by_cases h : liveRoutesTo s p r
          · have hrun := destination_some_runnable s (fuel := n)
                (p := p) (r := r) h.2
            exact False.elim (hr hrun)
          · simp [h]
    _ = 0 := sumFin_zero

theorem routed_rate_conserved {n m : Nat}
    (s : CoreState n m) (_hwf : CoreWF s) :
    sumFin (fun r =>
      if runnable s r then routedRate s r else 0) + strandedRate s =
    liveBaseRate s := by
  have hfilter :
      sumFin (fun r : ProcId n =>
        if runnable s r then routedRate s r else 0) =
      sumFin (fun r : ProcId n => routedRate s r) := by
    apply sumFin_congr
    intro r
    by_cases hr : runnable s r
    · simp [hr]
    · simp [hr, routedRate_eq_zero_of_not_runnable hr]
  rw [hfilter, routed_sum_eq_contributions]
  unfold strandedRate liveBaseRate liveTrapped
  rw [← sumFin_add]
  apply sumFin_congr
  intro p
  rw [routedContribution_eq]
  by_cases hu : unfinished s p
  · cases hd : finalDestination s p with
    | none =>
        unfold trapped at *
        simp [hu, hd]
        grind
    | some r =>
        unfold trapped at *
        simp [hu, hd]
        grind
  · simp [hu]
    grind

theorem routedRate_nonneg {n m : Nat}
    {s : CoreState n m} (hwf : CoreWF s) (r : ProcId n) :
    0 <= routedRate s r := by
  unfold routedRate
  apply sumFin_nonneg
  intro p
  by_cases h : liveRoutesTo s p r
  · simp [h]
    exact hwf.rate_nonneg p
  · simp [h]

theorem strandedRate_nonneg {n m : Nat}
    {s : CoreState n m} (hwf : CoreWF s) :
    0 <= strandedRate s := by
  unfold strandedRate
  apply sumFin_nonneg
  intro p
  by_cases h : liveTrapped s p
  · simp [h]
    exact hwf.rate_nonneg p
  · simp [h]

theorem base_rate_goes_to_destination {n m : Nat}
    {s : CoreState n m} {p r : ProcId n}
    (hlive : unfinished s p) (hdest : routesTo s p r) (hwf : CoreWF s) :
    baseRate s p <= routedRate s r := by
  unfold routedRate
  let f : ProcId n -> Qty :=
    fun x => if liveRoutesTo s x r then baseRate s x else 0
  have hle :
      sumFin (fun x : ProcId n => if x = p then f p else 0) <=
        sumFin f := by
    apply sumFin_le
    intro x
    by_cases hx : x = p
    · simp [hx]
    · have hnonneg : 0 <= f x := by
        unfold f
        by_cases hf : liveRoutesTo s x r
        · simp [hf]
          exact hwf.rate_nonneg x
        · simp [hf]
      simp [hx, hnonneg]
  have hsingle :
      sumFin (fun x : ProcId n => if x = p then f p else 0) = f p :=
    sumFin_single p (f p)
  have hp : f p = baseRate s p := by
    unfold f liveRoutesTo
    simp [hlive, hdest]
  rw [hsingle, hp] at hle
  simpa [f] using hle

theorem trapped_rate_goes_to_stranded {n m : Nat}
    {s : CoreState n m} {p : ProcId n}
    (hlive : unfinished s p) (htrap : trapped s p) (hwf : CoreWF s) :
    baseRate s p <= strandedRate s := by
  unfold strandedRate
  let f : ProcId n -> Qty :=
    fun x => if liveTrapped s x then baseRate s x else 0
  have hle :
      sumFin (fun x : ProcId n => if x = p then f p else 0) <=
        sumFin f := by
    apply sumFin_le
    intro x
    by_cases hx : x = p
    · simp [hx]
    · have hnonneg : 0 <= f x := by
        unfold f
        by_cases hf : liveTrapped s x
        · simp [hf]
          exact hwf.rate_nonneg x
        · simp [hf]
      simp [hx, hnonneg]
  have hsingle :
      sumFin (fun x : ProcId n => if x = p then f p else 0) = f p :=
    sumFin_single p (f p)
  have hp : f p = baseRate s p := by
    unfold f liveTrapped
    simp [hlive, htrap]
  rw [hsingle, hp] at hle
  simpa [f] using hle

def reachesFuel {n m : Nat} (s : CoreState n m) :
    Nat -> ProcId n -> ProcId n -> Prop
  | 0, src, dst => src = dst
  | fuel + 1, src, dst =>
      src = dst \/ exists q, waitsOn s src = some q /\ reachesFuel s fuel q dst

def reaches {n m : Nat} (s : CoreState n m) (src dst : ProcId n) : Prop :=
  reachesFuel s n src dst

theorem reachesFuel_refl {n m : Nat} (s : CoreState n m)
    (fuel : Nat) (p : ProcId n) :
    reachesFuel s fuel p p := by
  cases fuel with
  | zero =>
      rfl
  | succ fuel =>
      unfold reachesFuel
      exact Or.inl rfl

def effectiveRate {n m : Nat} (s : CoreState n m) (p : ProcId n) : Qty :=
  sumFin (fun w =>
    if unfinished s w /\ reaches s w p then baseRate s w else 0)

theorem reaches_refl {n m : Nat} (s : CoreState n m) (p : ProcId n) :
    reaches s p p :=
  reachesFuel_refl s n p

theorem reaches_waitsOn {n m : Nat}
    {s : CoreState n m} {w h : ProcId n}
    (hwait : waitsOn s w = some h) :
    reaches s w h := by
  unfold reaches
  cases n with
  | zero =>
      exact Fin.elim0 w
  | succ n =>
      unfold reachesFuel
      exact Or.inr ⟨h, hwait, reachesFuel_refl s n h⟩

def immediateWaiter {n m : Nat} (s : CoreState n m)
    (w p : ProcId n) : Prop :=
  waitsOn s w = some p

def waitsTransitivelyOn {n m : Nat} (s : CoreState n m)
    (w p : ProcId n) : Prop :=
  reaches s w p /\ w ≠ p

theorem transitive_rate_routing {n m : Nat}
    {s : CoreState n m} {w p r : ProcId n} {fuel : Nat}
    (hwait : waitsOn s w = some p)
    (hlive : unfinished s w)
    (hnotrun : ¬ runnable s w)
    (hdest : destination s fuel p = some r) :
    destination s (fuel + 1) w = some r := by
  unfold destination
  simp [hlive, hnotrun, hwait, hdest]

structure WaiterPartitionAt {n m : Nat}
    (s : CoreState n m) (p : ProcId n) : Prop where
  split : forall x,
    unfinished s x /\ reaches s x p <->
      x = p \/
        exists w,
          immediateWaiter s w p /\ unfinished s x /\ reaches s x w
  root_not_in_waiter_subtree :
    forall w, immediateWaiter s w p -> ¬ reaches s p w
  unique_waiter :
    forall x w1 w2,
      immediateWaiter s w1 p ->
      immediateWaiter s w2 p ->
      reaches s x w1 ->
      reaches s x w2 ->
      w1 = w2

/-- The fuel-bounded acyclic hypothesis needed by the recursive equation.
It packages the exact partition property for the upstream tree rooted at `p`.
Cycles and over-fuel paths intentionally stay outside this recursive reading and
are accounted by `strandedRate` in `routed_rate_conserved`. -/
def acyclicFrom {n m : Nat} (s : CoreState n m) (p : ProcId n) : Prop :=
  WaiterPartitionAt s p

theorem effective_rate_contribution_eq_base_plus_waiters {n m : Nat}
    {s : CoreState n m} {p x : ProcId n}
    (hlivep : unfinished s p)
    (hpart : WaiterPartitionAt s p) :
    (if unfinished s x /\ reaches s x p then baseRate s x else 0) =
      (if x = p then baseRate s p else 0) +
        sumFin (fun w =>
          if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
            baseRate s x
          else
            0) := by
  by_cases hxp : x = p
  · subst x
    have hp_reaches : reaches s p p := reaches_refl s p
    have hleft : unfinished s p /\ reaches s p p := ⟨hlivep, hp_reaches⟩
    have hsum0 :
        sumFin (fun w : ProcId n =>
          if immediateWaiter s w p /\ unfinished s p /\ reaches s p w then
            baseRate s p
          else
            0) = 0 := by
      calc
        sumFin (fun w : ProcId n =>
          if immediateWaiter s w p /\ unfinished s p /\ reaches s p w then
            baseRate s p
          else
            0) =
            sumFin (fun _ : ProcId n => (0 : Qty)) := by
              apply sumFin_congr
              intro w
              by_cases hw :
                  immediateWaiter s w p /\ unfinished s p /\ reaches s p w
              · exact False.elim
                  ((hpart.root_not_in_waiter_subtree w hw.1) hw.2.2)
              · simp [hw]
        _ = 0 := sumFin_zero
    rw [hsum0]
    simp [hlivep, reaches_refl]
    grind
  · by_cases hreach : unfinished s x /\ reaches s x p
    · have hsplit := (hpart.split x).1 hreach
      rcases hsplit with hx_eq | hwitness
      · exact False.elim (hxp hx_eq)
      · rcases hwitness with ⟨w0, hi0, _hu0, hr0⟩
        have hsum :
            sumFin (fun w : ProcId n =>
              if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
                baseRate s x
              else
                0) = baseRate s x := by
          calc
            sumFin (fun w : ProcId n =>
              if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
                baseRate s x
              else
                0) =
                sumFin (fun w : ProcId n =>
                  if w = w0 then baseRate s x else 0) := by
                  apply sumFin_congr
                  intro w
                  by_cases hw : w = w0
                  · subst hw
                    simp [hi0, hreach.1, hr0]
                  · have hno :
                        ¬ (immediateWaiter s w p /\
                          unfinished s x /\ reaches s x w) := by
                      intro hbad
                      exact hw
                        (hpart.unique_waiter x w w0 hbad.1 hi0 hbad.2.2 hr0)
                    simp [hw, hno]
            _ = baseRate s x := sumFin_single w0 (baseRate s x)
        rw [hsum]
        simp [hxp, hreach]
        grind
    · have hsum0 :
        sumFin (fun w : ProcId n =>
          if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
            baseRate s x
          else
            0) = 0 := by
        calc
          sumFin (fun w : ProcId n =>
            if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
              baseRate s x
            else
              0) =
              sumFin (fun _ : ProcId n => (0 : Qty)) := by
                apply sumFin_congr
                intro w
                by_cases hw :
                    immediateWaiter s w p /\ unfinished s x /\ reaches s x w
                · have hreach' : unfinished s x /\ reaches s x p :=
                    (hpart.split x).2
                      (Or.inr ⟨w, hw.1, hw.2.1, hw.2.2⟩)
                  exact False.elim (hreach hreach')
                · simp [hw]
          _ = 0 := sumFin_zero
      rw [hsum0]
      simp [hxp, hreach]
      grind

theorem effective_rate_eq_base_plus_waiters {n m : Nat}
    {s : CoreState n m} {p : ProcId n}
    (hlivep : unfinished s p)
    (hacyclic : acyclicFrom s p) :
    effectiveRate s p =
      baseRate s p +
        sumFin (fun w =>
          if immediateWaiter s w p then effectiveRate s w else 0) := by
  unfold acyclicFrom at hacyclic
  unfold effectiveRate
  calc
    sumFin (fun x : ProcId n =>
        if unfinished s x /\ reaches s x p then baseRate s x else 0) =
        sumFin (fun x : ProcId n =>
          (if x = p then baseRate s p else 0) +
            sumFin (fun w : ProcId n =>
              if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
                baseRate s x
              else
                0)) := by
          apply sumFin_congr
          intro x
          exact effective_rate_contribution_eq_base_plus_waiters
            hlivep hacyclic
    _ =
        sumFin (fun x : ProcId n => if x = p then baseRate s p else 0) +
          sumFin (fun x : ProcId n =>
            sumFin (fun w : ProcId n =>
              if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
                baseRate s x
              else
                0)) := by
          rw [sumFin_add]
    _ =
        baseRate s p +
          sumFin (fun x : ProcId n =>
            sumFin (fun w : ProcId n =>
              if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
                baseRate s x
              else
                0)) := by
          rw [sumFin_single p (baseRate s p)]
    _ =
        baseRate s p +
          sumFin (fun w : ProcId n =>
            sumFin (fun x : ProcId n =>
              if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
                baseRate s x
              else
                0)) := by
          rw [sumFin_swap]
    _ =
        baseRate s p +
          sumFin (fun w : ProcId n =>
            if immediateWaiter s w p then
              sumFin (fun x : ProcId n =>
                if unfinished s x /\ reaches s x w then baseRate s x else 0)
            else
              0) := by
          apply congrArg (fun z => baseRate s p + z)
          apply sumFin_congr
          intro w
          by_cases hi : immediateWaiter s w p
          · simp [hi]
          · have hsum0 :
              sumFin (fun x : ProcId n =>
                if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
                  baseRate s x
                else
                  0) = 0 := by
              calc
                sumFin (fun x : ProcId n =>
                  if immediateWaiter s w p /\ unfinished s x /\ reaches s x w then
                    baseRate s x
                  else
                    0) =
                    sumFin (fun _ : ProcId n => (0 : Qty)) := by
                      apply sumFin_congr
                      intro x
                      simp [hi]
                _ = 0 := sumFin_zero
            simpa [hi] using hsum0

theorem blocked_rate_reaches_holder {n m : Nat}
    {s : CoreState n m} {w h : ProcId n}
    (hwait : waitsOn s w = some h)
    (hlive : unfinished s w)
    (hwf : CoreWF s) :
    baseRate s w <= effectiveRate s h := by
  unfold effectiveRate
  have hterm :
      baseRate s w <=
        (if unfinished s w /\ reaches s w h then baseRate s w else 0) := by
    have hr : reaches s w h := reaches_waitsOn hwait
    simp [hlive, hr]
  have hsum :
      (if unfinished s w /\ reaches s w h then baseRate s w else 0) <=
        sumFin (fun x : ProcId n =>
          if unfinished s x /\ reaches s x h then baseRate s x else 0) := by
    let f : ProcId n -> Qty :=
      fun x => if unfinished s x /\ reaches s x h then baseRate s x else 0
    have hle :
        sumFin (fun x : ProcId n => if x = w then f w else 0) <=
          sumFin f := by
      apply sumFin_le
      intro x
      by_cases hx : x = w
      · simp [hx]
      · have hnonneg : 0 <= f x := by
          unfold f
          by_cases hf : unfinished s x /\ reaches s x h
          · simp [hf]
            exact hwf.rate_nonneg x
          · simp [hf]
        simp [hx, hnonneg]
    have hsingle :
        sumFin (fun x : ProcId n => if x = w then f w else 0) = f w :=
      sumFin_single w (f w)
    rw [hsingle] at hle
    simpa [f] using hle
  calc
    baseRate s w <=
        (if unfinished s w /\ reaches s w h then baseRate s w else 0) := hterm
    _ <= sumFin (fun x : ProcId n =>
          if unfinished s x /\ reaches s x h then baseRate s x else 0) := hsum

theorem blocked_rate_reaches_root {n m : Nat}
    {s : CoreState n m} {w r : ProcId n}
    (hroute : routesTo s w r)
    (hlive : unfinished s w)
    (hwf : CoreWF s) :
    baseRate s w <= routedRate s r :=
  base_rate_goes_to_destination hlive hroute hwf

theorem multiple_waiters_sum_not_max {n m : Nat}
    {s : CoreState n m} {w1 w2 h : ProcId n}
    (hw1 : waitsOn s w1 = some h)
    (hw2 : waitsOn s w2 = some h)
    (hlive1 : unfinished s w1)
    (hlive2 : unfinished s w2)
    (hne : w1 ≠ w2)
    (hwf : CoreWF s) :
    baseRate s w1 + baseRate s w2 <= effectiveRate s h := by
  unfold effectiveRate
  let f : ProcId n -> Qty :=
    fun x => if unfinished s x /\ reaches s x h then baseRate s x else 0
  have hle :
      sumFin (fun x : ProcId n =>
        if x = w1 then baseRate s w1
        else if x = w2 then baseRate s w2
        else 0) <=
        sumFin f := by
    apply sumFin_le
    intro x
    by_cases hx1 : x = w1
    · subst x
      have hr : reaches s w1 h := reaches_waitsOn hw1
      simp [f, hlive1, hr]
    · by_cases hx2 : x = w2
      · subst x
        have hr : reaches s w2 h := reaches_waitsOn hw2
        simp [f, hx1, hlive2, hr]
      · have hnonneg : 0 <= f x := by
          unfold f
          by_cases hx : unfinished s x /\ reaches s x h
          · simp [hx]
            exact hwf.rate_nonneg x
          · simp [hx]
        simp [hx1, hx2, hnonneg]
  have hpair :
      sumFin (fun x : ProcId n =>
        if x = w1 then baseRate s w1
        else if x = w2 then baseRate s w2
        else 0) =
        baseRate s w1 + baseRate s w2 :=
    sumFin_pair hne (baseRate s w1) (baseRate s w2)
  calc
    baseRate s w1 + baseRate s w2 =
        sumFin (fun x : ProcId n =>
          if x = w1 then baseRate s w1
          else if x = w2 then baseRate s w2
          else 0) := hpair.symm
    _ <= sumFin f := hle

def removeWaitEdge {n m : Nat}
    (s : CoreState n m) (w _h : ProcId n) : CoreState n m :=
  { s with procs := fun p =>
      if p = w then { s.procs p with wants := none } else s.procs p }

def noOtherWaiters {n m : Nat}
    (s : CoreState n m) (h : ProcId n) : Prop :=
  forall p, liveRoutesTo s p h -> p = h

theorem finalDestination_eq_self_of_runnable {n m : Nat}
    {s : CoreState n m} {p : ProcId n}
    (hlive : unfinished s p) (hrun : runnable s p) :
    finalDestination s p = some p := by
  unfold finalDestination
  cases n with
  | zero => exact Fin.elim0 p
  | succ n =>
      unfold destination
      simp [hlive, hrun]

theorem remove_wait_edge_restores_base_rate {n m : Nat}
    {s : CoreState n m} {w h : ProcId n}
    (honly : noOtherWaiters (removeWaitEdge s w h) h)
    (_hwait : waitsOn s w = some h)
    (hlive : unfinished (removeWaitEdge s w h) h)
    (hrunnable : runnable (removeWaitEdge s w h) h) :
    routedRate (removeWaitEdge s w h) h =
      baseRate (removeWaitEdge s w h) h := by
  let t := removeWaitEdge s w h
  have hself : liveRoutesTo t h h := by
    unfold liveRoutesTo routesTo
    exact ⟨hlive, finalDestination_eq_self_of_runnable hlive hrunnable⟩
  unfold routedRate
  calc
    sumFin (fun p : ProcId n =>
        if liveRoutesTo t p h then baseRate t p else 0) =
        sumFin (fun p : ProcId n =>
          if p = h then baseRate t h else 0) := by
          apply sumFin_congr
          intro p
          by_cases hp : p = h
          · subst hp
            simp [hself]
          · have hnot : ¬ liveRoutesTo t p h := by
              intro hroute
              exact hp (honly p hroute)
            simp [hp, hnot]
    _ = baseRate t h := sumFin_single h (baseRate t h)

def sameWaitGraph {n m : Nat} (s t : CoreState n m) : Prop :=
  (forall p q, blockedOn s p q ↔ blockedOn t p q) /\
  (forall p, waitsOn s p = waitsOn t p) /\
  (forall p, runnable s p ↔ runnable t p) /\
  (forall p, unfinished s p ↔ unfinished t p)

theorem no_stored_boost_state {n m : Nat}
    {s t : CoreState n m}
    (hgraph : sameWaitGraph s t)
    (hdest : forall p, finalDestination s p = finalDestination t p)
    (hrate : forall p, baseRate s p = baseRate t p) :
    forall p, routedRate s p = routedRate t p := by
  intro r
  unfold routedRate liveRoutesTo routesTo
  apply sumFin_congr
  intro p
  have hu : unfinished s p ↔ unfinished t p := hgraph.2.2.2 p
  rw [← hrate p, ← hdest p]
  by_cases hs : unfinished s p /\ finalDestination s p = some r
  · have ht : unfinished t p /\ finalDestination s p = some r :=
      ⟨hu.1 hs.1, hs.2⟩
    simp [hs, ht]
  · have ht : ¬ (unfinished t p /\ finalDestination s p = some r) := by
      intro h
      exact hs ⟨hu.2 h.1, h.2⟩
    simp [hs, ht]

def share {n m : Nat}
    (s : CoreState n m) (quantum : Qty) (p : ProcId n) : Qty :=
  quantum * routedRate s p /
    sumFin (fun r => if runnable s r then routedRate s r else 0)

theorem shares_sum_quantum {n m : Nat}
    (s : CoreState n m) (quantum : Qty)
    (hpos : 0 < sumFin (fun r => if runnable s r then routedRate s r else 0)) :
    sumFin (fun r => if runnable s r then share s quantum r else 0) =
      quantum := by
  let denom : Qty :=
    sumFin (fun r => if runnable s r then routedRate s r else 0)
  have hdenom_ne : denom ≠ 0 := by
    intro hz
    rw [← hz] at hpos
    grind
  calc
    sumFin (fun r => if runnable s r then share s quantum r else 0) =
        sumFin (fun r =>
          (quantum / denom) *
            (if runnable s r then routedRate s r else 0)) := by
          apply sumFin_congr
          intro r
          unfold share
          by_cases hr : runnable s r
          · simp [hr, denom]
            grind
          · simp [hr]
    _ = (quantum / denom) *
        sumFin (fun r => if runnable s r then routedRate s r else 0) := by
          exact sumFin_mul_left (quantum / denom)
            (fun r => if runnable s r then routedRate s r else 0)
    _ = quantum := by
          unfold denom at hdenom_ne ⊢
          grind

abbrev high : ProcId 3 := 0
abbrev low : ProcId 3 := 1
abbrev medium : ProcId 3 := 2
abbrev pathLock : LockId 1 := 0

def pathfinderProc (rate : Qty) (want : Option (LockId 1)) : CoreProc 1 :=
  { baseRate := rate
    stock := 0
    credit := 0
    convertedTotal := 0
    convertedSinceRestart := 0
    workNeeded := 1
    pc := 0
    wants := want
    budget := 1
    budgetCap := 1
    done := false }

def pathfinderState : CoreState 3 1 :=
  { procs := fun p =>
      if p = high then pathfinderProc 9 (some pathLock)
      else if p = low then pathfinderProc 1 none
      else pathfinderProc 3 none
    holds := fun p l => decide (p = low) && decide (l = pathLock)
    reserve := 0
    convertCost := 1
    totalQ := 0 }

@[simp] theorem pathfinder_high_unfinished : unfinished pathfinderState high := by
  unfold unfinished pathfinderState pathfinderProc high low
  simp

@[simp] theorem pathfinder_low_unfinished : unfinished pathfinderState low := by
  unfold unfinished pathfinderState pathfinderProc high low
  simp

@[simp] theorem pathfinder_medium_unfinished :
    unfinished pathfinderState medium := by
  unfold unfinished pathfinderState pathfinderProc high low medium
  simp

@[simp] theorem pathfinder_low_runnable : runnable pathfinderState low := by
  constructor
  · unfold pathfinderState pathfinderProc high low
    simp
  · intro hb
    rcases hb with ⟨q, l, hwants, _hholds, _hne⟩
    unfold pathfinderState pathfinderProc high low at hwants
    simp at hwants

@[simp] theorem pathfinder_medium_runnable :
    runnable pathfinderState medium := by
  constructor
  · unfold pathfinderState pathfinderProc high low medium
    simp
  · intro hb
    rcases hb with ⟨q, l, hwants, _hholds, _hne⟩
    unfold pathfinderState pathfinderProc high low medium at hwants
    simp at hwants

@[simp] theorem pathfinder_low_holds_lock :
    pathfinderState.holds low pathLock = true := by
  unfold pathfinderState low pathLock
  simp

@[simp] theorem pathfinder_high_blocked : blocked pathfinderState high := by
  unfold blocked blockedOn
  exact ⟨low, pathLock, by
    constructor
    · unfold pathfinderState pathfinderProc high
      simp
    constructor
    · exact pathfinder_low_holds_lock
    · decide⟩

@[simp] theorem pathfinder_high_not_runnable :
    ¬ runnable pathfinderState high := by
  intro hrun
  exact hrun.2 pathfinder_high_blocked

@[simp] theorem pathfinder_firstHolder :
    firstHolder pathfinderState pathLock = some low := by
  unfold firstHolder pathfinderState low high pathLock
  simp [List.finRange_succ]

theorem pathfinder_high_waits_on_low : waitsOn pathfinderState high = some low := by
  unfold waitsOn
  have hwants : (pathfinderState.procs high).wants = some pathLock := by
    unfold pathfinderState pathfinderProc high low
    simp
  rw [hwants]
  simp [high, low]

theorem pathfinder_high_routes_to_low :
    routesTo pathfinderState high low := by
  unfold routesTo finalDestination
  change destination pathfinderState 3 high = some low
  unfold destination
  rw [if_pos pathfinder_high_unfinished]
  rw [if_neg pathfinder_high_not_runnable]
  rw [pathfinder_high_waits_on_low]
  change destination pathfinderState 2 low = some low
  unfold destination
  rw [if_pos pathfinder_low_unfinished]
  rw [if_pos pathfinder_low_runnable]

theorem pathfinder_low_routes_to_low :
    routesTo pathfinderState low low := by
  unfold routesTo finalDestination
  change destination pathfinderState 3 low = some low
  unfold destination
  rw [if_pos pathfinder_low_unfinished]
  rw [if_pos pathfinder_low_runnable]

theorem pathfinder_medium_routes_to_medium :
    routesTo pathfinderState medium medium := by
  unfold routesTo finalDestination
  change destination pathfinderState 3 medium = some medium
  unfold destination
  rw [if_pos pathfinder_medium_unfinished]
  rw [if_pos pathfinder_medium_runnable]

@[simp] theorem pathfinder_high_finalDestination :
    finalDestination pathfinderState high = some low :=
  pathfinder_high_routes_to_low

@[simp] theorem pathfinder_low_finalDestination :
    finalDestination pathfinderState low = some low :=
  pathfinder_low_routes_to_low

@[simp] theorem pathfinder_medium_finalDestination :
    finalDestination pathfinderState medium = some medium :=
  pathfinder_medium_routes_to_medium

@[simp] theorem pathfinder_high_baseRate :
    baseRate pathfinderState high = 9 := by
  unfold baseRate pathfinderState pathfinderProc high low
  simp

@[simp] theorem pathfinder_low_baseRate :
    baseRate pathfinderState low = 1 := by
  unfold baseRate pathfinderState pathfinderProc high low
  simp

@[simp] theorem pathfinder_medium_baseRate :
    baseRate pathfinderState medium = 3 := by
  unfold baseRate pathfinderState pathfinderProc high low medium
  simp

theorem pathfinder_low_routedRate :
    routedRate pathfinderState low = 10 := by
  unfold routedRate sumFin liveRoutesTo routesTo
  simp [List.finRange_succ, low, medium]
  grind

theorem pathfinder_medium_routedRate :
    routedRate pathfinderState medium = 3 := by
  unfold routedRate sumFin liveRoutesTo routesTo
  simp [List.finRange_succ, low, medium]
  grind

theorem pathfinder_denominator :
    sumFin (fun r => if runnable pathfinderState r then
      routedRate pathfinderState r else 0) = 13 := by
  unfold sumFin
  simp [List.finRange_succ, pathfinder_low_routedRate,
    pathfinder_medium_routedRate]
  grind

theorem pathfinder_low_share_eq_ten_thirteenths :
    share pathfinderState 1 low = (10 : Qty) / 13 := by
  unfold share
  rw [pathfinder_low_routedRate, pathfinder_denominator]
  grind

theorem pathfinder_medium_share_eq_three_thirteenths :
    share pathfinderState 1 medium = (3 : Qty) / 13 := by
  unfold share
  rw [pathfinder_medium_routedRate, pathfinder_denominator]
  grind

theorem pathfinder_low_share_gt_medium :
    share pathfinderState 1 low > share pathfinderState 1 medium := by
  rw [pathfinder_low_share_eq_ten_thirteenths,
    pathfinder_medium_share_eq_three_thirteenths]
  grind

theorem canonical_priority_inversion_cannot_form :
    share pathfinderState 1 low >= share pathfinderState 1 medium := by
  have hgt := pathfinder_low_share_gt_medium
  grind

end
end RateRouting
end IsoConserve
