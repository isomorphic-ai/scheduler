import IsoConserve.Basic

namespace IsoConserve

def sharesFromWeights {n : Nat} (quantum totalWeight : Qty)
    (weight : Fin n -> Qty) (i : Fin n) : Qty :=
  quantum * weight i / totalWeight

theorem share_sum_of_partition {n : Nat}
    (quantum totalWeight : Qty) (weight : Fin n -> Qty)
    (hTotal : totalWeight != 0)
    (hWeights : sumFin weight = totalWeight) :
    sumFin (sharesFromWeights quantum totalWeight weight) = quantum := by
  calc
    sumFin (sharesFromWeights quantum totalWeight weight) =
        sumFin (fun i => (quantum / totalWeight) * weight i) := by
          apply sumFin_congr
          intro i
          unfold sharesFromWeights
          grind
    _ = (quantum / totalWeight) * sumFin weight := by
          exact sumFin_mul_left (quantum / totalWeight) weight
    _ = quantum := by
          grind

structure RatePlan {n : Nat} (s : Sys n) extends FlowPlan s where
  quantum : Qty
  totalWeight : Qty
  weight : Fin n -> Qty
  totalWeight_ne_zero : totalWeight != 0
  weight_sum : sumFin weight = totalWeight
  weight_blocked : forall i, s.runnable i = false -> weight i = 0
  share_eq : forall i, share i = sharesFromWeights quantum totalWeight weight i

theorem ratePlan_share_sum {n : Nat} {s : Sys n} (plan : RatePlan s) :
    sumFin plan.share = plan.quantum := by
  calc
    sumFin plan.share =
        sumFin (sharesFromWeights plan.quantum plan.totalWeight plan.weight) := by
          apply sumFin_congr
          intro i
          exact plan.share_eq i
    _ = plan.quantum := by
          exact share_sum_of_partition plan.quantum plan.totalWeight plan.weight
            plan.totalWeight_ne_zero plan.weight_sum

end IsoConserve
