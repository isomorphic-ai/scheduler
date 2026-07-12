import IsoConserve.Reachable

namespace IsoConserve

/-!
The caching-series polarity instance of `monotone_under_adversary`.

A store is represented as a characteristic set of `(key, proof)` records. This is
finite whenever the key/proof universes are finite; the proof itself only needs the
subset order induced by storage loss.
-/

structure CacheRecord (Key Proof : Type) where
  key : Key
  proof : Proof

abbrev Store (Key Proof : Type) := CacheRecord Key Proof -> Bool

def storeSubset {Key Proof : Type} (small big : Store Key Proof) : Prop :=
  forall record, small record = true -> big record = true

structure CacheState (Key Proof : Type) where
  store : Store Key Proof
  authority : Store Key Proof

abbrev TrustSet (Key : Type) := Key -> Prop

def trusted {Key Proof : Type} (s : CacheState Key Proof) : TrustSet Key :=
  fun key =>
    exists proof,
      s.store { key := key, proof := proof } = true /\
        s.authority { key := key, proof := proof } = true

def trustSubset {Key : Type} (small big : TrustSet Key) : Prop :=
  forall key, small key -> big key

theorem trustSubset_refl {Key : Type} (s : TrustSet Key) : trustSubset s s := by
  intro key h
  exact h

theorem trustSubset_trans {Key : Type} {a b c : TrustSet Key}
    (hab : trustSubset a b) (hbc : trustSubset b c) : trustSubset a c := by
  intro key ha
  exact hbc key (hab key ha)

def LossRel {Key Proof : Type} (s t : CacheState Key Proof) : Prop :=
  t.authority = s.authority /\ storeSubset t.store s.store

theorem positive_trust_loss_step {Key Proof : Type}
    (s t : CacheState Key Proof) (h : LossRel s t) :
    trustSubset (trusted t) (trusted s) := by
  intro key ht
  rcases ht with ⟨proof, hstore, hauth⟩
  exact ⟨proof, h.2 { key := key, proof := proof } hstore,
    by simpa [h.1] using hauth⟩

theorem polarity_claim_one {Key Proof : Type}
    (s t : CacheState Key Proof) (reach : RTC (@LossRel Key Proof) s t) :
    trustSubset (trusted t) (trusted s) := by
  apply monotone_under_adversary
    (le := @trustSubset Key)
    (leRefl := @trustSubset_refl Key)
    (leTrans := by
      intro a b c hab hbc
      exact trustSubset_trans hab hbc)
    (E := @LossRel Key Proof)
    (f := trusted)
  · intro s t h
    exact positive_trust_loss_step s t h
  · exact reach

end IsoConserve
