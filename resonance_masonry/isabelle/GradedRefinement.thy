(* SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0 *)
(* CLONE_GATE:AES256:7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c *)
(*
   GradedRefinement.thy — Isabelle/HOL Graded Refinement Monad
   Author: Ahmad <ahmedparr93@gmail.com>

   The soft attention of the SupremeKernel is not merely a formula.
   It is a graded monad in the sense that [0,1]-valued predicates compose
   with a *-tensor, and the hard kernel is the {0,1}-submonad.

   Status: specified, not yet proved. Lemmas are stated as targets.
   Run: isabelle build -D . GradedRefinement
*)

theory GradedRefinement
imports Main "HOL-Library.FuncSet"
begin

section ‹Graded refinement monad›

text ‹
  A graded refinement is a function from a state space to the unit interval.
  The grading is the strength of the assertion: 1 = holds, 0 = fails.
›

type_synonym 's grade = "'s ⇒ real"

definition valid_grade :: "'s grade ⇒ bool" where
  "valid_grade f ≡ ∀s. 0 ≤ f s ∧ f s ≤ 1"

text ‹Return: the always-1 predicate.›
definition greturn :: "'s grade" where
  "greturn ≡ λ_. 1"

text ‹Bind: weighted conjunction in the graded monad.›
definition gbind :: "'s grade ⇒ ('s ⇒ 's grade) ⇒ 's grade" where
  "gbind f g ≡ λs. f s * g s s"

text ‹Soft conjunction as the monoidal tensor.›
definition gtensor :: "'s grade ⇒ 's grade ⇒ 's grade" where
  "gtensor f g ≡ λs. (f s + g s) / 2"

lemma greturn_unit_left:
  assumes "valid_grade f"
  shows "gbind greturn (λ_. f) = f"
  unfolding gbind_def greturn_def by auto

lemma greturn_unit_right:
  assumes "valid_grade f"
  shows "gbind f (λs. greturn) = f"
  unfolding gbind_def greturn_def by (auto simp: fun_eq_iff)

lemma gbind_preserves_valid:
  assumes "valid_grade f"
      and "⋀s. valid_grade (g s)"
    shows "valid_grade (gbind f g)"
  unfolding valid_grade_def gbind_def
  using assms(1) assms(2)
  by (auto intro!: mult_nonneg_nonneg mult_le_one)

lemma gtensor_preserves_valid:
  assumes "valid_grade f" and "valid_grade g"
    shows "valid_grade (gtensor f g)"
  unfolding valid_grade_def gtensor_def
  using assms unfolding valid_grade_def
  by (auto intro!: divide_nonneg_nonneg)

section ‹Hard submonad embedding›

text ‹The Boolean predicate embeds as a {0,1}-grade.›
definition hard :: "('s ⇒ bool) ⇒ 's grade" where
  "hard P ≡ λs. if P s then 1 else 0"

lemma hard_valid:
  "valid_grade (hard P)"
  unfolding valid_grade_def hard_def by auto

lemma hard_tensor_and:
  "gtensor (hard P) (hard Q) = hard (λs. P s ∧ Q s)"
  unfolding gtensor_def hard_def by (auto simp: fun_eq_iff)

section ‹Ψ preservation as a graded refinement obligation›

text ‹
  Assume: Ψ :: OpState ⇒ SpState
          OpInvariant :: Bool ⇒ OpState ⇒ bool (parametric on nonEmpty)
          LightMasonry :: SpState ⇒ bool
›

consts Ψ           :: "'o ⇒ 's"
consts OpInvariant :: "bool ⇒ 'o ⇒ bool"
consts LightMasonry :: "'s ⇒ bool"

text ‹Hard form of L1 (Branch A: nonEmpty = True).›
definition L1_hard :: bool where
  "L1_hard ≡ ∀s. OpInvariant True s ⟶ LightMasonry (Ψ s)"

text ‹Graded form of L1.›
definition L1_graded :: "bool ⇒ 'o grade" where
  "L1_graded nonEmpty ≡
     λs. if OpInvariant nonEmpty s
         then if LightMasonry (Ψ s) then 1 else 0
         else 1"

lemma L1_hard_iff_graded_one:
  "L1_hard ⟷ (∀s. L1_graded True s = 1)"
  unfolding L1_hard_def L1_graded_def by auto

lemma L1_graded_discharges_L1_hard:
  assumes "∀s. L1_graded True s = 1"
  shows "L1_hard"
  using assms unfolding L1_hard_def L1_graded_def by auto

text ‹
  Branch B (nonEmpty = False): the graded form is strictly weaker.
  A state where OpInvariant False s holds but LightMasonry (Ψ s) fails
  contributes grade 0. This is the counterexample surface C₁.
›

section ‹Attention as graded conjunction over a predicate family›

consts Preds :: "nat ⇒ 'o ⇒ real"

definition attention :: "'o ⇒ real" where
  "attention s ≡ (∑i∈{0..4}. Preds i s) / 5"

lemma attention_in_unit:
  assumes "⋀i s. 0 ≤ Preds i s ∧ Preds i s ≤ 1"
  shows "0 ≤ attention s ∧ attention s ≤ 1"
  unfolding attention_def
  using assms by (auto intro!: divide_nonneg_nonneg divide_le_eq)

section ‹Double-double recursion as a strength-indexed fixpoint›

text ‹
  rDouble n grades the joint kernel at depth n.
  Each level squares the predicate (AND with itself).
  Termination is witnessed by the depth index, not by the state.
›

fun rDouble :: "nat ⇒ 'o grade" where
  "rDouble 0 = hard (OpInvariant True)"
| "rDouble (Suc n) =
     gtensor (gtensor (rDouble n) (rDouble n))
             (hard (λs. LightMasonry (Ψ s)))"

lemma rDouble_valid:
  "valid_grade (rDouble n)"
proof (induction n)
  case 0
  show ?case using hard_valid[of "OpInvariant True"] by simp
next
  case (Suc n)
  show ?case
    using gtensor_preserves_valid
      [OF gtensor_preserves_valid[OF Suc Suc]
          hard_valid[of "λs. LightMasonry (Ψ s)"]]
    by simp
qed

section ‹Euclidean well-foundedness›

fun euclid :: "nat ⇒ nat ⇒ nat" where
  "euclid a 0 = a"
| "euclid a b = euclid b (a mod b)"

termination euclid
  by (relation "measure (λ(a,b). b)") auto

section ‹Supreme kernel — hard gated by attention›

definition supremeKernel :: "bool ⇒ 'o ⇒ real" where
  "supremeKernel nonEmpty s ≡
     attention s * (if L1_graded nonEmpty s = 1 then 1 else 0)"

lemma supremeKernel_in_unit:
  assumes "⋀i. 0 ≤ Preds i s ∧ Preds i s ≤ 1"
  shows "0 ≤ supremeKernel nonEmpty s ∧ supremeKernel nonEmpty s ≤ 1"
  unfolding supremeKernel_def
  using attention_in_unit[OF assms] by auto

section ‹CARE invariant as a graded predicate›

text ‹
  CARE is a {0,1}-hard predicate. Its graded embedding is hard(care).
  DarkCrossing is hard(dark ∧ ¬care).
  The supremeKernel gates on L1 ∧ CARE simultaneously via gtensor.
›

consts care :: "'t ⇒ bool"
consts dark :: "'t ⇒ bool"

definition care_graded :: "'t grade" where
  "care_graded ≡ hard care"

definition dark_crossing_graded :: "'t grade" where
  "dark_crossing_graded ≡ hard (λt. dark t ∧ ¬ care t)"

lemma care_dark_crossing_disjoint:
  "gtensor care_graded dark_crossing_graded = hard (λt. False)"
  unfolding care_graded_def dark_crossing_graded_def gtensor_def hard_def
  by (auto simp: fun_eq_iff)

end
