-- RESONANCE MASONRY
-- CARE invariant (Lean 4 is the proof-obligation backend; this Alloy
-- fragment mirrors the same statements for bounded counterexample search)

module CareInv

open util/ordering[State] as St

sig Cap {}
sig State {
  protected: set Cap,
  authority: set Cap,
  granted: set Cap
}

one sig Sys {
  godDomain: set Cap
}

-- Care(s,s1) =
--   Protected(s) = Protected(s1)
--   and Authority(s1) subset Authority(s) union Granted(s)
pred Care[s, s1: State] {
  s1.protected = s.protected
  s1.authority in s.authority + s.granted
}

pred Transition[s, s1: State] {
  s != s1
  St/next[s] = s1
}

-- forall s,s1. Transition(s,s1) -> Care(s,s1)
pred careGlobal {
  all s, s1: State | Transition[s, s1] implies Care[s, s1]
}

-- DarkMasonry(s,s1) <=> Transition and Privileged and not Care
pred Privileged[s, s1: State] {
  Transition[s, s1]
  s1.protected != s.protected or
  s1.authority & Sys.godDomain != none or
  s1.authority - s.authority != none
}

pred DarkMasonry[s, s1: State] {
  Transition[s, s1]
  Privileged[s, s1]
  not Care[s, s1]
}

pred counterexample {
  some s, s1: State | DarkMasonry[s, s1]
}

run careGlobal for 5 State, 3 Cap
run counterexample for 6 State, 3 Cap
