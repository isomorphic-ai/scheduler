import IsoConserve.Basic
import IsoConserve.L1Conservation

namespace IsoConserve

def noProgress {n : Nat} (s t : Sys n) : Prop :=
  totalConverted t = totalConverted s

theorem drainStep_noProgress {n : Nat} (s : Sys n) (plan : DrainPlan s) :
    noProgress s (drainStep s plan) := by
  unfold noProgress totalConverted drainStep drainProc
  rfl

theorem convertibleStock_drainStep_le {n : Nat} (s : Sys n)
    (plan : DrainPlan s) :
    convertibleStock (drainStep s plan) <= convertibleStock s := by
  unfold convertibleStock drainStep drainProc
  apply sumFin_le
  intro i
  unfold active
  split
  · have hd := plan.drain_nonneg i
    grind
  · grind

theorem L2_monotone {n : Nat} (s : Sys n) (plan : DrainPlan s) :
    convertibleStock (drainStep s plan) <= convertibleStock s :=
  convertibleStock_drainStep_le s plan

end IsoConserve
