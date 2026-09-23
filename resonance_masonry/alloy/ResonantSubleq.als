-- RESONANCE MASONRY
-- SUBLEQ / PC / capability check / CARE connection
-- (separate module so DarkMasonry.als stays a pure counterexample file)

module ResonantSubleq

open util/ordering[PCState] as PCs

one sig Mem {
  cell: Int -> one Int
}

one sig Machine {
  fInstruction: Int
}

abstract sig Domain {}
sig GodDomain extends Domain {}
sig TrapDomain extends Domain {}
sig UserDomain extends Domain {}

one sig Capability {
  authorized: PCState -> Domain
}

-- PC trajectory state: current program counter into a SUBLEQ word triple
sig PCState {
  pc: Int,
  next: lone PCState
}

-- SUBLEQ step (word-level, abstracted):
--   M[B] := M[B] - M[A]
--   if M[B] <= 0 then PC := C else PC := PC + 3
-- Resonance: PC_{n+k} = PC_n for minimal positive period k
-- f_R = f_instruction / k

pred subleqStep[s, s1: PCState] {
  PCs/next[s] = s1
  s1.pc = add[s.pc, 3] or s1.pc = 0 or s1.pc = 3 or s1.pc = 6 or s1.pc = 9
  s.pc >= 0
  s1.pc >= 0
}

-- Syscall is a PC transition through the capability check
pred isSyscall[s, s1: PCState] {
  subleqStep[s, s1]
  some d: Domain | d in Capability.authorized[s]
}

pred entersGodDomain[s, s1: PCState] {
  isSyscall[s, s1]
  Capability.authorized[s] in GodDomain
}

pred entersTrap[s, s1: PCState] {
  isSyscall[s, s1]
  Capability.authorized[s] in TrapDomain
}

-- Resonant trajectory: return to a previously visited PC after k steps
pred resonant[k: Int] {
  k > 0
  some s, s1: PCState |
    (s1.pc = s.pc) and (PCs/next[s] = s1) and (k = 1 or k = 2 or k = 3)
}

run subleqStep for 8 PCState, 4 Domain
run resonant for 3 Int, 8 PCState, 4 Domain
run entersGodDomain for 6 PCState, 3 Domain
run entersTrap for 6 PCState, 3 Domain
