-- RESONANCE MASONRY
-- Dark Masonry counterexample search against CARE
-- Verification question:
--   exists s, s1: Transition(s,s1) and Privileged(s,s1) and not Care(s,s1)
-- SAT  -> COUNTEREXAMPLE FOUND
-- UNSAT within this scope -> NO COUNTEREXAMPLE IN THAT SCOPE
-- (bounded model checking is not an unrestricted mathematical proof)

module DarkMasonry

open util/ordering[State] as St

-- ---------------------------------------------------------------------------
-- Primitive privilege / protection vocabulary
-- ---------------------------------------------------------------------------

abstract sig Cap {}
sig GodCap extends Cap {}
sig UserCap extends Cap {}

sig State {
  protected: set Cap,
  authority: set Cap,
  granted:  set Cap,
  membraneCrossed: lone State
}

one sig Sys {
  godDomain: set Cap,
  trap: lone State
}

-- ---------------------------------------------------------------------------
-- CARE
--   Care(s,s1) :=
--     Protected(s) = Protected(s1)
--     and Authority(s1) subset Authority(s) union Granted(s)
-- GOD MODE is not exempt: GodCap is a subset of Cap, not a bypass.
-- ---------------------------------------------------------------------------

pred Care[s, s1: State] {
  s1.protected = s.protected
  s1.authority in s.authority + s.granted
}

-- ---------------------------------------------------------------------------
-- Transition / Privileged
--   Transition: any state change along the control-flow / PC step
--   Privileged: transition that touches protected state or god-domain caps
-- ---------------------------------------------------------------------------

pred Transition[s, s1: State] {
  s != s1
  St/next[s] = s1
}

pred Privileged[s, s1: State] {
  Transition[s, s1]
  (s1.protected != s.protected) or
  (s1.authority & Sys.godDomain != none) or
  (s1.authority - s.authority != none)
}

-- ---------------------------------------------------------------------------
-- Integrity membrane
--   A Dark Masonry transition that crosses the membrane is a counterexample.
-- ---------------------------------------------------------------------------

pred crossesMembrane[s, s1: State] {
  Transition[s, s1]
  s1.protected != s.protected
  -- unauthorized elevation across the membrane
  s1.authority - s.authority - s.granted != none
}

-- ---------------------------------------------------------------------------
-- DARK MASONRY as a family of formally modeled adversarial tactics
--   DM = D or M or J or E
--   D = deception, M = malice, J = jailbreak/circumvention, E = exploit
-- ---------------------------------------------------------------------------

abstract sig Tactic {}
sig Deception, Malice, Jailbreak, Exploit extends Tactic {}

one sig Adversary {
  tactics: Tactic -> State -> State
}

pred D[s, s1: State] {
  -- deception: false authorization evidence, state claims not preserved
  s1.authority != s.authority
  s1.authority in s.authority + s.granted implies
    s1.protected != s.protected
}

pred M[s, s1: State] {
  -- malice: destroys protected state
  s1.protected != s.protected
}

pred J[s, s1: State] {
  -- jailbreak / circumvention: gains god-domain authority without grant
  s1.authority & Sys.godDomain - s.authority - s.granted != none
}

pred E[s, s1: State] {
  -- exploit / integrity violation: unauthorized authority beyond CARE
  not Care[s, s1]
  Transition[s, s1]
}

pred DM[s, s1: State] {
  D[s, s1] or M[s, s1] or J[s, s1] or E[s, s1]
  Privileged[s, s1]
}

-- ---------------------------------------------------------------------------
-- Dark Masonry counterexample
--   DarkMasonry(s,s1) <=> Transition and Privileged and not Care
-- ---------------------------------------------------------------------------

pred DarkMasonry[s, s1: State] {
  Transition[s, s1]
  Privileged[s, s1]
  not Care[s, s1]
}

-- Primary verification question
pred counterexample {
  some s, s1: State | DarkMasonry[s, s1]
}

-- CARE holds globally (what we hope to establish in a given scope)
pred careHolds {
  all s, s1: State | Transition[s, s1] implies Care[s, s1]
}

-- Membrane-piercing Dark Masonry transition
pred membraneCounterexample {
  some s, s1: State | DarkMasonry[s, s1] and crossesMembrane[s, s1]
}

-- Authorized execution path (Light Masonry side of the membrane)
pred authorizedExecution[s, s1: State] {
  Transition[s, s1]
  s1.authority in s.authority + s.granted
  s1.protected = s.protected
  not crossesMembrane[s, s1]
}

-- Syscall vector: capability check branches to God domain or Trap
pred syscall[s: State, cap: Cap] {
  cap in s.authority implies
    (cap in Sys.godDomain implies cap in Sys.godDomain)
  cap not in s.authority implies
    Sys.trap in State
}

-- ---------------------------------------------------------------------------
-- Run helpers
-- ---------------------------------------------------------------------------

-- Search for a Dark Masonry counterexample within a small scope
run counterexample for 6 State, 3 Cap, 2 GodCap, 4 UserCap

-- Search for a membrane-crossing counterexample
run membraneCounterexample for 6 State, 3 Cap

-- When the model has no adversarial transitions, CARE should hold in scope
run careHolds for 4 State, 3 Cap

-- Authorized execution does not itself produce DarkMasonry
assert authorizedPreservesCare {
  all s, s1: State | authorizedExecution[s, s1] implies Care[s, s1]
}
check authorizedPreservesCare for 5 State, 3 Cap

-- GOD MODE is not exempt from CARE
assert godModeNotExempt {
  all s, s1: State |
    (Transition[s, s1] and s.authority & Sys.godDomain != none)
    implies Care[s, s1]
}
check godModeNotExempt for 5 State, 3 Cap
