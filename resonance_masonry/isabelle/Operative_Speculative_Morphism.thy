theory Operative_Speculative_Morphism
  imports Main "HOL-Library.FuncSet"
begin

section \<open>Primitive domains\<close>

typedecl Stone
typedecl Agent
typedecl Tool
typedecl Virtue
typedecl Geometry
typedecl Ethic

section \<open>State spaces\<close>

type_synonym OpState = "Stone \<times> Geometry"
type_synonym SpState = "Agent \<times> Ethic"

section \<open>Operative Masonry\<close>

datatype OpTool =
    Square
  | Level
  | Plumb
  | Compass
  | Trowel
  | Mallet
  | Chisel

datatype GeoRel =
    Orthogonal
  | Horizontal
  | Vertical
  | Bounded_Real
  | Symmetric
  | Congruent

section \<open>Speculative Masonry\<close>

datatype SpTool =
    Rectitude
  | Equity
  | Integrity
  | Circumspection
  | Charity
  | Prudence
  | Temperance
  | Fortitude
  | Justice

datatype EthRel =
    Rectitude_Rel
  | Equity_Rel
  | Integrity_Rel
  | Bounded_Eth_Real
  | Self_Consistent
  | Coherent

section \<open>\<Psi> morphism: Operative \<rightarrow> Speculative\<close>

definition \<Psi>_Tool :: "OpTool \<Rightarrow> SpTool" where
  "\<Psi>_Tool t \<equiv> case t of
      Square       \<Rightarrow> Rectitude
    | Level        \<Rightarrow> Equity
    | Plumb        \<Rightarrow> Integrity
    | Compass      \<Rightarrow> Circumspection
    | Trowel       \<Rightarrow> Charity
    | Mallet       \<Rightarrow> Fortitude
    | Chisel       \<Rightarrow> Prudence"

definition \<Psi>_Rel :: "GeoRel \<Rightarrow> EthRel" where
  "\<Psi>_Rel r \<equiv> case r of
      Orthogonal   \<Rightarrow> Rectitude_Rel
    | Horizontal   \<Rightarrow> Equity_Rel
    | Vertical     \<Rightarrow> Integrity_Rel
    | Bounded_Real \<Rightarrow> Bounded_Eth_Real
    | Symmetric    \<Rightarrow> Self_Consistent
    | Congruent    \<Rightarrow> Coherent"

text \<open>
  \<^bold>\<open>Dependency axiom\<close>: \<Psi>_State requires a concrete map Stone \<Rightarrow> Agent.
  The supplied architecture specifies Geometry via \<Psi>_Rel, the identifications
  eth_relations = \<Psi>_Rel ` geo_relations, trust_bearing = load_bearing,
  and measure = proportion, but does not supply Stone \<Rightarrow> Agent.
  That map is an explicit axiom obligation, not an invented definition.
\<close>

consts stone_to_agent :: "Stone \<Rightarrow> Agent"

definition \<Psi>_State :: "(Stone \<Rightarrow> Agent) \<Rightarrow> OpState \<Rightarrow> SpState" where
  "\<Psi>_State f sg \<equiv> (f (fst sg), snd sg)"

consts geo_relations :: "Geometry \<Rightarrow> GeoRel set"
consts load_bearing :: "Geometry \<Rightarrow> bool"
consts trust_bearing :: "Ethic \<Rightarrow> bool"
consts proportion :: "Geometry \<Rightarrow> real"
consts measure :: "Ethic \<Rightarrow> real"

definition eth_relations :: "Ethic \<Rightarrow> EthRel set" where
  "eth_relations e \<equiv> \<Psi>_Rel ` geo_relations undefined"

text \<open>
  \<^bold>\<open>Intended identifications\<close> (once carriers are aligned by \<Psi>_State):
  \<^item> trust_bearing corresponds to load_bearing
  \<^item> measure corresponds to proportion
  \<^item> eth_relations e = \<Psi>_Rel ` geo_relations g when e is the ethic
    component of \<Psi>_State f (s, g)
  These are locale-level obligations below, not silent redefinitions.
\<close>

section \<open>Rough / Perfect ashlar transitions\<close>

consts op_transform :: "OpState \<Rightarrow> OpState"
consts sp_transform :: "SpState \<Rightarrow> SpState"

consts perfect_ashlar :: "OpState"
consts perfect_character :: "SpState"

definition operative_transformation :: "OpState \<Rightarrow> OpState" where
  "operative_transformation \<equiv> op_transform"

definition speculative_transformation :: "SpState \<Rightarrow> SpState" where
  "speculative_transformation \<equiv> sp_transform"

section \<open>Invariants\<close>

definition OpInvariant :: "OpState \<Rightarrow> bool" where
  "OpInvariant sg \<equiv>
     (\<forall>r \<in> geo_relations (snd sg).
        r \<in> {Orthogonal, Horizontal, Vertical, Symmetric})
   \<and> load_bearing (snd sg) = True"

definition SpInvariant :: "SpState \<Rightarrow> bool" where
  "SpInvariant ae \<equiv>
     (\<forall>r \<in> eth_relations (snd ae).
        r \<in> {Rectitude_Rel, Equity_Rel, Integrity_Rel, Self_Consistent})
   \<and> trust_bearing (snd ae) = True"

section \<open>Entropy layer\<close>

definition Op_Entropy :: "OpState \<Rightarrow> real" where
  "Op_Entropy sg \<equiv> 1 / (1 + proportion (snd sg))"

definition Sp_Entropy :: "SpState \<Rightarrow> real" where
  "Sp_Entropy ae \<equiv> 1 / (1 + measure (snd ae))"

section \<open>\<Psi> obligations\<close>

subsection \<open>1. Tool mapping (theorem)\<close>

lemma tool_map_wellformed:
  "\<Psi>_Tool Square = Rectitude
   \<and> \<Psi>_Tool Level = Equity
   \<and> \<Psi>_Tool Plumb = Integrity
   \<and> \<Psi>_Tool Compass = Circumspection
   \<and> \<Psi>_Tool Trowel = Charity
   \<and> \<Psi>_Tool Mallet = Fortitude
   \<and> \<Psi>_Tool Chisel = Prudence"
  by (simp add: \<Psi>_Tool_def)

subsection \<open>2. Relation mapping (theorem)\<close>

lemma rel_map_wellformed:
  "\<Psi>_Rel Orthogonal = Rectitude_Rel
   \<and> \<Psi>_Rel Horizontal = Equity_Rel
   \<and> \<Psi>_Rel Vertical = Integrity_Rel
   \<and> \<Psi>_Rel Bounded_Real = Bounded_Eth_Real
   \<and> \<Psi>_Rel Symmetric = Self_Consistent
   \<and> \<Psi>_Rel Congruent = Coherent"
  by (simp add: \<Psi>_Rel_def)

subsection \<open>3. State mapping\<close>

definition state_map_wellformed :: "(Stone \<Rightarrow> Agent) \<Rightarrow> bool" where
  "state_map_wellformed f \<equiv>
     \<forall>s g. \<Psi>_State f (s, g) = (f s, g)"

subsection \<open>4. Invariant preservation\<close>

definition invariant_preservation :: "(Stone \<Rightarrow> Agent) \<Rightarrow> bool" where
  "invariant_preservation f \<equiv>
     \<forall>sg. OpInvariant sg \<longrightarrow> SpInvariant (\<Psi>_State f sg)"

subsection \<open>5. Transformation commutation (naturality)\<close>

definition naturality :: "(Stone \<Rightarrow> Agent) \<Rightarrow> bool" where
  "naturality f \<equiv>
     \<forall>sg.
       \<Psi>_State f (op_transform sg)
     = sp_transform (\<Psi>_State f sg)"

text \<open>
  \<^bold>\<open>Dependency\<close>: naturality links the independently supplied
  op_transform and sp_transform. It is an axiom obligation, not a
  consequence of the tool/relation maps alone.
\<close>

subsection \<open>6. Fixed-point preservation\<close>

definition fixed_point :: "(Stone \<Rightarrow> Agent) \<Rightarrow> bool" where
  "fixed_point f \<equiv> \<Psi>_State f perfect_ashlar = perfect_character"

text \<open>
  Supplied intention: \<Psi>(Perfect_Ashlar) = Perfect_Character.
\<close>

section \<open>Golden-ratio proportion / measure\<close>

definition golden_ratio :: real where
  "golden_ratio = (1 + sqrt 5) / 2"

definition golden_measure_link :: "(Stone \<Rightarrow> Agent) \<Rightarrow> bool" where
  "golden_measure_link f \<equiv>
     \<forall>s g. proportion g = measure (snd (\<Psi>_State f (s, g)))"

text \<open>
  The golden-ratio proportion/measure relationship is part of the supplied
  conceptual construction. Any stronger numeric claim (e.g. proportion g =
  golden_ratio for a particular geometry) requires an additional supplied axiom.
\<close>

section \<open>Entropy correspondence\<close>

definition entropy_correspondence :: "(Stone \<Rightarrow> Agent) \<Rightarrow> bool" where
  "entropy_correspondence f \<equiv>
     \<forall>sg. Op_Entropy sg = Sp_Entropy (\<Psi>_State f sg)"

section \<open>\<Psi> as category-level mapping\<close>

text \<open>
  Category Op: objects = OpState, morphisms = OpTool sequences.
  Category Sp: objects = SpState, morphisms = SpTool sequences.
  \<Psi> : Op \<rightarrow> Sp at objects is \<Psi>_State f; arrows are induced by \<Psi>_Tool.
\<close>

definition op_hom :: "OpTool list \<Rightarrow> SpTool list" where
  "op_hom ts = map \<Psi>_Tool ts"

text \<open>
  User-supplied raw Functor record is the conceptual prototype for the
  category-level mapping, recorded as locale obligations below.
\<close>

locale Psi_Functor =
  fixes f :: "Stone \<Rightarrow> Agent"
  assumes
    tool_ok: "tool_map_wellformed"
    and rel_ok: "rel_map_wellformed"
    and state_ok: "state_map_wellformed f"
    and inv_ok: "invariant_preservation f"
    and naturality_ok: "naturality f"
    and fixed_ok: "fixed_point f"
    and entropy_ok: "entropy_correspondence f"
    and golden_ok: "golden_measure_link f"
    and trust_load:
      "\<forall>s g. trust_bearing (snd (\<Psi>_State f (s, g))) = load_bearing g"
    and measure_proportion:
      "\<forall>s g. measure (snd (\<Psi>_State f (s, g))) = proportion g"
    and eth_geo:
      "\<forall>s g. eth_relations (snd (\<Psi>_State f (s, g))) = \<Psi>_Rel ` geo_relations g"

theorem psi_tool_square: "\<Psi>_Tool Square = Rectitude"
  by (simp add: \<Psi>_Tool_def)

theorem psi_rel_orthogonal: "\<Psi>_Rel Orthogonal = Rectitude_Rel"
  by (simp add: \<Psi>_Rel_def)

theorem op_entropy_form:
  "Op_Entropy (s, g) = 1 / (1 + proportion g)"
  by (simp add: Op_Entropy_def)

theorem sp_entropy_form:
  "Sp_Entropy (a, e) = 1 / (1 + measure e)"
  by (simp add: Sp_Entropy_def)

end
