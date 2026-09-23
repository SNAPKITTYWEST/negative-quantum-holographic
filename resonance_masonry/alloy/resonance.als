-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
-- CLONE_GATE:AES256:3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e
--
-- resonance.als — Full Resonance Masonry Alloy model
-- Author: Ahmad <ahmedparr93@gmail.com>
--
-- Includes: parametric OpInvariant, Ψ morphism, LightMasonry,
--           CARE/DarkMasonry/DarkCrossing, β′ branch check.
-- Run: ALLOY_JAR=... ./run-alloy.sh resonance.als

module ResonanceMasonry

sig Atom {}
abstract sig Bool {}
one sig True, False extends Bool {}

abstract sig GeoRel {}
one sig Orthogonal, Horizontal, Vertical, Symmetric, Congruent extends GeoRel {}

abstract sig EthRel {}
one sig Rectitude_Rel, Equity_Rel, Integrity_Rel,
         Self_Consistent, Coherent extends EthRel {}

sig Stone {}
sig Agent {}

sig Geometry {
    geoRels: set GeoRel,
    loadBearing: one Bool
}

sig Ethic {
    ethRels: set EthRel,
    trustBearing: one Bool
}

sig OpState { stone: one Stone, geometry: one Geometry }
sig SpState { agent: one Agent, ethic: one Ethic }

-- ── Ψ morphism (total on GeoRel) ─────────────────────────────────────────────

fun PsiRel : GeoRel -> EthRel {
    Orthogonal -> Rectitude_Rel +
    Horizontal -> Equity_Rel +
    Vertical   -> Integrity_Rel +
    Symmetric  -> Self_Consistent +
    Congruent  -> Coherent
}

fun PsiAgent : Stone -> Agent {}

fun PsiGeometry : Geometry -> Ethic {
    { g: Geometry, e: Ethic |
        e.ethRels     = PsiRel[g.geoRels]
        and e.trustBearing = g.loadBearing
    }
}

fun Psi : OpState -> SpState {
    { s: OpState, t: SpState |
        t.agent  = PsiAgent[s.stone]
        and t.ethic = PsiGeometry[s.geometry]
    }
}

-- ── Parametric OpInvariant (β′ decision: nonEmpty :: Bool) ────────────────────

pred OpInvariant[s: OpState, nonEmpty: Bool] {
    s.geometry.geoRels in
        Orthogonal + Horizontal + Vertical + Symmetric
    and
    (nonEmpty = False or some s.geometry.geoRels)
    and
    s.geometry.loadBearing = True
}

pred SpInvariant[s: SpState] {
    s.ethic.ethRels in
        Rectitude_Rel + Equity_Rel + Integrity_Rel + Self_Consistent
    and
    s.ethic.trustBearing = True
}

pred Provenance[s: SpState]     { some s.agent }
pred Authorization[s: SpState]  { some s.ethic }
pred Verification[s: SpState]   { SpInvariant[s] }
pred Containment[s: SpState]    { some s.ethic.ethRels }

pred LightMasonry[s: SpState] {
    SpInvariant[s] and Provenance[s] and Authorization[s]
    and Verification[s] and Containment[s]
}

-- ── C1: counterexample surface (Branch B: nonEmpty = False) ──────────────────
-- Run this: expect SAT (witness exists when geoRels may be empty)
pred PsiLightCounterexample {
    some s: OpState |
        OpInvariant[s, False] and not LightMasonry[Psi[s]]
}
run PsiLightCounterexample for 4

-- ── L1: preservation obligation (Branch A: nonEmpty = True) ──────────────────
-- Check this: expect UNSAT (no counterexample when geoRels must be non-empty)
assert L1_PsiPreservesLight_NonEmpty {
    all s: OpState |
        OpInvariant[s, True] implies LightMasonry[Psi[s]]
}
check L1_PsiPreservesLight_NonEmpty for 4

-- L1 under Branch B: expect SAT (counterexample exists)
assert L1_PsiPreservesLight_AnyGeo {
    all s: OpState |
        OpInvariant[s, False] implies LightMasonry[Psi[s]]
}
check L1_PsiPreservesLight_AnyGeo for 4

-- ── Transition / CARE layer ───────────────────────────────────────────────────

sig State { protected: set Atom, auth: set Atom }

sig Transition {
    from, to:   one State,
    granted:    set Atom,
    privileged: one Bool,
    dark:       one Bool,
    authorized: one Bool
}

pred Care[t: Transition] {
    t.to.protected = t.from.protected
    and t.to.auth in (t.from.auth + t.granted)
}

pred DarkMasonry[t: Transition]  { t.dark = True }

pred DarkCrossing[t: Transition] {
    DarkMasonry[t] and not Care[t]
}

assert NoDarkCrossing {
    all t: Transition |
        (DarkMasonry[t] and Care[t]) implies not DarkCrossing[t]
}
check NoDarkCrossing for 4

-- God mode is not an automatic CARE bypass
assert GodModeNotExempt {
    some t: Transition |
        t.privileged = True and not Care[t]
}
check GodModeNotExempt for 4

-- Authorized syscall preserves CARE
assert AuthorizedSyscallPreservesCare {
    all t: Transition |
        (t.authorized = True and not DarkMasonry[t]) implies Care[t]
}
check AuthorizedSyscallPreservesCare for 4
