-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:32520e7860daf1e5a7c5282d5434dfeafcedc52c025be0f87c249af7e6e3c02a
--
import Std.Data.Set.Basic

namespace ResonanceMasonry

inductive GeoRel
  | orthogonal | horizontal | vertical | symmetric | congruent
  deriving DecidableEq, Repr

inductive EthRel
  | rectitude | equity | integrity | selfConsistent | coherent
  deriving DecidableEq, Repr

structure Geometry where
  geoRels : List GeoRel
  loadBearing : Bool
  deriving Repr

structure Ethic where
  ethRels : List EthRel
  trustBearing : Bool
  deriving Repr

structure OpState where
  stone : Nat
  geometry : Geometry
  deriving Repr

structure SpState where
  agent : Nat
  ethic : Ethic
  deriving Repr

abbrev allowedGeo : List GeoRel :=
  [.orthogonal, .horizontal, .vertical, .symmetric]

abbrev allowedEth : List EthRel :=
  [.rectitude, .equity, .integrity, .selfConsistent]

def psiRel : GeoRel → EthRel
  | .orthogonal => .rectitude
  | .horizontal => .equity
  | .vertical => .integrity
  | .symmetric => .selfConsistent
  | .congruent => .coherent

def memGeo (r : GeoRel) (xs : List GeoRel) : Prop := r ∈ xs
def memEth (r : EthRel) (xs : List EthRel) : Prop := r ∈ xs

def subsetGeo (xs : List GeoRel) : Prop := ∀ r, memGeo r xs → memGeo r allowedGeo

def subsetEth (xs : List EthRel) : Prop := ∀ r, memEth r xs → memEth r allowedEth

def opInvariant (nonEmpty : Bool) (s : OpState) : Prop :=
  subsetGeo s.geometry.geoRels ∧
  (nonEmpty = false ∨ s.geometry.geoRels ≠ []) ∧
  s.geometry.loadBearing = true

def mapRels (xs : List GeoRel) : List EthRel := xs.map psiRel

def psiGeometry (g : Geometry) : Ethic :=
  { ethRels := mapRels g.geoRels
    trustBearing := g.loadBearing }

def psiAgent (stone : Nat) : Nat := stone

def psi (s : OpState) : SpState :=
  { agent := psiAgent s.stone
    ethic := psiGeometry s.geometry }

def spInvariant (s : SpState) : Prop :=
  subsetEth s.ethic.ethRels ∧ s.ethic.trustBearing = true

def lightMasonry (s : SpState) : Prop :=
  spInvariant s ∧ s.ethic.ethRels ≠ []

lemma psiRel_preserves_allowed :
    ∀ r, memGeo r allowedGeo → memEth (psiRel r) allowedEth := by
  intro r hr
  simp [allowedGeo, allowedEth, memGeo, memEth] at hr ⊢
  cases r <;> simp_all [psiRel]

lemma mapRels_subset_allowed :
    ∀ xs, subsetGeo xs → subsetEth (mapRels xs) := by
  intro xs h
  induction xs with
  | nil => simp [subsetEth]
  | cons x xs ih =>
      intro r hr
      simp [mapRels] at hr
      rcases hr with rfl | hr
      · exact psiRel_preserves_allowed x (h x (by simp))
      · exact ih (fun q hq => h q (by simp [hq])) hr

lemma psi_spInvariant :
    ∀ s, opInvariant true s → spInvariant (psi s) := by
  intro s hs
  rcases hs with ⟨hsub, _, hload⟩
  constructor
  · exact mapRels_subset_allowed s.geometry.geoRels hsub
  · simp [psi, psiGeometry, hload]

lemma psi_nonempty :
    ∀ s, s.geometry.geoRels ≠ [] → (mapRels s.geometry.geoRels) ≠ [] := by
  intro s h
  cases s.geometry.geoRels with
  | nil => contradiction
  | cons x xs => simp [mapRels]

theorem L1_psi_light :
    ∀ s, opInvariant true s → lightMasonry (psi s) := by
  intro s hs
  rcases hs with ⟨hsub, hnonempty, hload⟩
  constructor
  · exact psi_spInvariant s ⟨hsub, hnonempty, hload⟩
  · exact psi_nonempty s hnonempty

-- SUBLEQ branch semantics
structure Machine where
  pc : Nat
  mem : Nat → Int

def subleqStep (m : Machine) (a b c : Nat) : Machine :=
  let v := m.mem b - m.mem a
  { pc := if v ≤ 0 then c else m.pc + 3
    mem := fun x => if x = b then v else m.mem x }

-- Full-state resonance, rather than PC-only recurrence.
def FullCycle (k : Nat) (start : Machine) (next : Machine → Machine) : Prop :=
  k > 0 ∧ (Function.iterate next k) start = start

end ResonanceMasonry
