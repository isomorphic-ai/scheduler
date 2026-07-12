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

theorem share_sum_assumed {n : Nat} (share : Fin n -> Qty) (quantum : Qty)
    (h : sumFin share = quantum) :
    sumFin share = quantum := h

end IsoConserve
