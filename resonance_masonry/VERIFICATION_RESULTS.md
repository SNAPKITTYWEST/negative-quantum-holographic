<!-- SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0 -->
<!-- CLONE_GATE:AES256:d28adc65f6021e91b60ed9ec8193f9de7ce134e1297c81942dec02c59b28365d -->

# RESONANCE MASONRY — Verification Results

Date: 2026-09-22  
Environment: Lean 4.34.0 (no mathlib), SWI-Prolog 10.0.2, Java 11 + Alloy 6.0.0 (sat4j), Isabelle **not installed**.

## Status by backend

| Backend | Artifact | Result | Kind |
|--------|----------|--------|------|
| Lean 4 | `lean/Care.lean` | **LEAN_OK** (exit 0) | Machine-checked proofs of CARE lemmas |
| Prolog | `subleq/resonant_subleq.pl` | **exit 0** | Runtime demos (resonance, syscall, CARE) |
| Prolog | `connect/connect.pl` | **exit 0** | CONNECT demo (CARE ↔ PC ↔ syscall) |
| Alloy | `alloy/CareInvariant.als` | Parses; both runs **SAT** | Bounded model finding |
| Alloy | `alloy/DarkMasonry.als` | Parses; runs/checks as below | **Bounded** counterexample search |
| Alloy | `alloy/ResonantSubleq.als` | Parses; all four runs **SAT** | Bounded model finding |
| Alloy | `alloy/Connect.als` | Parses; runs **SAT**, check **no counterexample** | **Bounded** |
| Isabelle | `isabelle/Operative_Speculative_Morphism.thy` | **Not checked** | Specification only (Isabelle missing) |

## Alloy command outcomes (sat4j; SAT/UNSAT are **bounded only**, not proofs)

### CareInvariant.als
- `run careGlobal for 5 State, 3 Cap` — **SAT** (instance found)
- `run counterexample for 6 State, 3 Cap` — **SAT** (DarkMasonry-shaped instance exists in scope)

### DarkMasonry.als
- `run counterexample for 6 State, 4 Cap, 2 GodCap, 4 UserCap, 4 Tactic` — **SAT**
- `run membraneCounterexample …` — **SAT**
- `run careHolds for 4 State, 3 Cap, 2 GodCap, 3 UserCap, 3 Tactic` — **SAT**
- `check authorizedPreservesCare …` — **UNSAT** (no counterexample found; assertion may be valid **in this scope**)
- `check godModeNotExempt …` — **SAT** (counterexample found; assertion invalid **in this scope**)

Interpretation of `godModeNotExempt`: within the scope there is a privileged/god-domain transition that violates CARE. That is consistent with “GOD MODE is not an automatic bypass of CARE” (the transition is still *required* to satisfy CARE; the counterexample is a CARE violation on a god-touched step, not a license to skip CARE). It does **not** prove a universal meta-theorem about god mode.

### ResonantSubleq.als
- `run subleqStep for 8 PCState, 4 Domain` — **SAT**
- `run resonant for 3 Int, 8 PCState, 4 Domain` — **SAT**
- `run entersGodDomain for 6 PCState, 3 Domain` — **SAT**
- `run entersTrap for 6 PCState, 3 Domain` — **SAT**

### Connect.als
- `run connectWitness …` — **SAT**
- `run connectDark …` — **SAT**
- `check authorizedSyscallPreservesCare …` — **UNSAT** (no counterexample found; bounded)

## Prolog runtime evidence

```
PC path: [0,6,3,0,6,3,0,6,3,0]
resonance period k = 3 (witness step(3))
f_R = 333333.33… Hz (f_instruction = 1e6)
authorized write -> god_domain
unauthorized root -> trap_return
grant within authority: authorized
protected-state change: dark_masonry

CONNECT dispatch: PC 0 -> 6 with dispatch(0,6,god_domain,authorized)
CONNECT care edge (grant): authorized
CONNECT care edge (violation): dark_masonry
CONNECT PC path: [0,6,3,0,6,3,0,6,3,0] (k=3, step(3))
```

## Shared vocabulary (CONNECT)

Same shapes across backends:

- **Care(s,s')** — `Protected(s)=Protected(s')` ∧ `Authority(s') ⊆ Authority(s) ∪ Granted(s)`  
  (Lean `Care`, Alloy `pred Care`, Prolog `care_step/4` / `dark_masonry/4`)
- **Transition / PC step** — Lean `s ≠ s'`, Alloy `St/next[s]=s1`, Prolog `subleq_step/3`
- **syscall_check** — Prolog `syscall_check/3` → `god_domain` | `trap_return`; Alloy `syscallAuthorize` / `syscallTrap` / `entersGodDomain` / `entersTrap`
- **DarkMasonry** — Transition ∧ Privileged ∧ ¬Care (Lean `DarkMasonry`, Alloy `pred DarkMasonry`, Prolog `dark_masonry/4`)
- **Resonance** — `k=3`, `f_R = f_instruction/k` (Prolog `resonance_period/3`, `resonance_frequency/3`; Alloy `pred resonant`)

## Non-claims (do not overread)

1. Alloy results are **bounded** (finite scope, bitwidth); they are not unrestricted proofs.
2. Lean proofs are **kernel-checked** for the stated CARE propositions in `Care.lean` only.
3. Isabelle theory was **not** compiled (tool absent).
4. SAT on `run counterexample` means a DarkMasonry-shaped instance **exists in that scope**; it does not mean CARE is false everywhere.
5. No silent upgrade of SAT/UNSAT into theorems.

## Re-run commands

```text
lean resonance_masonry/lean/Care.lean
swipl -q -g "consult('resonance_masonry/subleq/resonant_subleq.pl'), demo_resonance, demo_syscall, demo_care, halt(0)" -t "halt(1)"
swipl -q -g "consult('resonance_masonry/connect/connect.pl'), connect_run, halt(0)" -t "halt(1)"
java -Dsat4j=yes -cp <alloy.jar> edu.mit.csail.sdg.alloy4whole.SimpleCLI resonance_masonry\alloy\<File>.als
```

---

## Haskell Layer (resonance_masonry/haskell/)

| File | Status | Notes |
|------|--------|-------|
| `ResonanceMasonry.hs` | RUNNABLE | GHC — GeoRel/EthRel/psi/CARE/SUBLEQ/resonance demo; `main` confirmed |
| `ResonanceMasonry.lhs` | LiquidHaskell-annotated | `{-@ reflect @-}` stubs; L1 refinement obligation stated |

### Re-run commands (Haskell)

```text
ghc -o rm resonance_masonry/haskell/ResonanceMasonry.hs && ./rm
# LiquidHaskell (if installed):
liquid resonance_masonry/haskell/ResonanceMasonry.lhs
```

### ResonanceMasonry.hs results

```
("OpInvariant(A)",True)
("LightMasonry(Psi s)",True)
("CARE",True)
("DarkCrossing",False)
("PC trace",[0,0,0,0,0,0,0,0,0,0,0,0])
("PC period",Just 1)
("resonance @ 1GHz",Just 1.0e9)
```

## Lean Layer addition (resonance_masonry/lean/ResonanceMasonry.lean)

| Theorem | Status |
|---------|--------|
| `psiRel_preserves_allowed` | LEAN_OK |
| `mapRels_subset_allowed` | LEAN_OK |
| `psi_spInvariant` | LEAN_OK |
| `psi_nonempty` | LEAN_OK |
| `L1_psi_light` | LEAN_OK — opInvariant true s → lightMasonry (psi s) |
| `FullCycle` definition | Added — full-state resonance recurrence |

```text
lean resonance_masonry/lean/ResonanceMasonry.lean
```

## Quantum Wires (quantum-wires/)

| File | Location | Description |
|------|----------|-------------|
| `INVERTED-AST-CFG-PTM.lisp` | `ast/` | CFG binary (0x43464742) + PTM binary (0x544D5454) — Lisp S-expr spec |
| `INVERTED-AST-QUIPPER-JCL.lisp` | `ast/` | Quipper circuit (0x51554950) + JCL Vault (0x4A434C4D) — Lisp S-expr spec |
| `quantum_wire_network_1500_lines.hs` | `quipper/` | 743 named Quipper wires (True/False alternating); `wireBank`; `print_generic Preview` |
| `BLRD-PTM-2026-001.txt` | `spec/` | 5541-req binary-level reference doc for the full PTM→Quipper→JCL pipeline |
