-- RESONANCE MASONRY
-- CARE machine-level invariant as Lean 4 proof obligations.
-- Verified with: lean resonance_masonry/lean/Care.lean

namespace ResonanceMasonry

/-- Capability / authority token. -/
structure Cap where
  id : Nat
  deriving Repr, DecidableEq

/-- Machine state.
    Field names avoid the Lean keyword `protected`; the predicate
    `Protected` below is the master-prompt name. -/
structure State where
  shield     : List Cap
  authority  : List Cap
  granted    : List Cap
  deriving Repr

/-- GOD domain caps are ordinary caps tagged into the highest formally
    defined privilege domain. GOD MODE is not an unbounded bypass. -/
def godDomain : List Cap := [⟨0⟩]

def Protected (s : State) : List Cap := s.shield
def Authority (s : State) : List Cap := s.authority
def Granted   (s : State) : List Cap := s.granted

def subset (xs ys : List Cap) : Prop := ∀ c, c ∈ xs → c ∈ ys

/-- CARE:
    Care(s,s') :=
      Protected(s) = Protected(s')
      ∧ Authority(s') ⊆ Authority(s) ∪ Granted(s) -/
def Care (s s' : State) : Prop :=
  Protected s = Protected s' ∧
  subset (Authority s') (Authority s ++ Granted s)

/-- Any state change along the control-flow / PC step. -/
def Transition (s s' : State) : Prop := s ≠ s'

/-- Privileged transition: touches protected state or god-domain authority. -/
def Privileged (s s' : State) : Prop :=
  Transition s s' ∧
  (Protected s ≠ Protected s' ∨
   (∃ c ∈ Authority s', c ∈ godDomain) ∨
   ∃ c ∈ Authority s', c ∉ Authority s)

/-- DARK MASONRY counterexample predicate:
    DarkMasonry(s,s') ⇔ Transition ∧ Privileged ∧ ¬Care -/
def DarkMasonry (s s' : State) : Prop :=
  Transition s s' ∧ Privileged s s' ∧ ¬ Care s s'

/-- Global CARE. -/
def CareGlobal : Prop :=
  ∀ s s' : State, Transition s s' → Care s s'

/-- Existence question (the Alloy dual). -/
def DarkMasonryExists : Prop :=
  ∃ s s' : State, DarkMasonry s s'

-- ---------------------------------------------------------------------------
-- Proof obligations
-- ---------------------------------------------------------------------------

/-- CARE preserves protected state (left conjunct). -/
theorem care_protected (s s' : State) (h : Care s s') :
    Protected s = Protected s' :=
  h.1

/-- CARE bounds authority increase by Granted (right conjunct). -/
theorem care_authority (s s' : State) (h : Care s s') :
    subset (Authority s') (Authority s ++ Granted s) :=
  h.2

/-- GOD MODE is not exempt from CARE. -/
theorem god_mode_not_exempt (s s' : State)
    (_t : Transition s s')
    (_god : ∃ c ∈ Authority s', c ∈ godDomain)
    (h : Care s s') :
    Protected s = Protected s' ∧
    subset (Authority s') (Authority s ++ Granted s) :=
  ⟨h.1, h.2⟩

/-- A Dark Masonry transition violates CARE. -/
theorem dark_masonry_violates_care (s s' : State)
    (h : DarkMasonry s s') :
    ¬ Care s s' :=
  h.2.2

/-- If CARE holds for all transitions, no Dark Masonry transition exists. -/
theorem care_global_no_dark_masonry
    (h : CareGlobal) :
    ∀ s s' : State, ¬ DarkMasonry s s' := by
  intro s s' hd
  cases hd with
  | intro t hp =>
    cases hp with
    | intro _p nc =>
      exact nc (h s s' t)

/-- DarkMasonryExists unfolds to a single privileged CARE violation. -/
theorem dark_masonry_iff_violation :
    DarkMasonryExists ↔
      ∃ s s' : State, Transition s s' ∧ Privileged s s' ∧ ¬ Care s s' :=
  Iff.rfl

/-- Classical witness from negated subset. -/
theorem not_subset_exists (xs ys : List Cap)
    (h : ¬ subset xs ys) :
    ∃ c, c ∈ xs ∧ c ∉ ys := by
  apply Classical.byContradiction
  intro hc
  apply h
  intro c cin
  apply Classical.byContradiction
  intro cnotin
  exact hc ⟨c, cin, cnotin⟩

/-- Trap branch: authority beyond Authority ∪ Granted violates CARE. -/
theorem trap_rejects (s s' : State)
    (unauth : ¬ subset (Authority s') (Authority s ++ Granted s)) :
    ¬ Care s s' := by
  intro h
  exact unauth (care_authority s s' h)

/-- Example well-formed CARE step: authority grows only by grant. -/
example : Care
  { shield := [⟨1⟩], authority := [⟨1⟩], granted := [⟨2⟩] }
  { shield := [⟨1⟩], authority := [⟨1⟩, ⟨2⟩], granted := [] } := by
  refine ⟨rfl, ?_⟩
  intro c hc
  cases hc with
  | head =>
    exact List.Mem.head _
  | tail _ hc2 =>
    cases hc2 with
    | head =>
      simp [Authority, Granted]
    | tail => contradiction

/-- Protected-set change violates CARE. -/
example : ¬ Care
  { shield := [⟨1⟩], authority := [], granted := [] }
  { shield := [], authority := [], granted := [] } := by
  intro h
  have e := h.1
  simp [Protected] at e

/-- Global CARE implies protected-state equality on every transition. -/
theorem care_global_protected (h : CareGlobal)
    (s s' : State) (t : Transition s s') :
    Protected s = Protected s' :=
  care_protected s s' (h s s' t)

/-- Protected-state change on a transition is Dark Masonry when CARE fails. -/
theorem privileged_protected_change_dark
    (s s' : State)
    (t : Transition s s')
    (pchange : Protected s ≠ Protected s')
    (nc : ¬ Care s s') :
    DarkMasonry s s' :=
  ⟨t, ⟨t, Or.inl pchange⟩, nc⟩

end ResonanceMasonry
