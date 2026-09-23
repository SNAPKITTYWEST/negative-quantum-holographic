%% SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
%% CLONE_GATE:AES256:9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b
%%
%% operative_masonry.pl — Operative Invariants (I1–I10) + Ψ Morphism + Counter-Mason
%% Author: Ahmad <ahmedparr93@gmail.com>
%%
%% The Operative Invariant is Geometric Proportion / Structural Equilibrium.
%% The Ψ morphism maps Operative → Speculative:
%%   Geometric Right Angle → Moral Rectitude
%%   Horizontal Level     → Equality / Equity
%%   Vertical Plumb       → Integrity / Uprightness
%%   Golden Ratio φ       → Harmony / Proportion

:- module(operative_masonry,
          [ invariant/1,
            counter_square/1, counter_plumb/1, counter_level/1,
            counter_compass/1, counter_ashlar/1, counter_arch/1,
            counter_mortar/1, counter_word/2, counter_degree/1,
            counter_secret/1, counter_mason/1, detect_counter_mason/1,
            true_operative/1,
            morphism/2, operative_invariant/1, speculative_invariant/1,
            holds_invariant/1
          ]).

%% ─── CORE INVARIANTS I1–I10 ──────────────────────────────────────────────────

%% I1: Geometric Truth (The Square)
invariant(right_angle(Stone)) :-
    dressed(Stone, Face1), dressed(Stone, Face2),
    angle(Face1, Face2, 90).

%% I2: Gravitational Alignment (The Plumb)
invariant(vertical_axis(Wall)) :-
    course(Wall, _), plumb_line(Wall, Center),
    load_path(Wall, Center).

%% I3: Horizontal Equilibrium (The Level)
invariant(level_course(Course)) :-
    stones(Course, Stones),
    forall(member(S, Stones), (top_plane(S, Z), Z =:= 0)).

%% I4: Proportional Boundary (The Compasses)
invariant(golden_proportion(Structure)) :-
    width(Structure, W), height(Structure, H),
    Phi is (1 + sqrt(5)) / 2,
    Ratio is W / H,
    abs(Ratio - Phi) < 0.001.

%% I5: Material Integrity (The Ashlar)
invariant(perfect_ashlar(Stone)) :-
    six_faces(Stone, Faces),
    forall(member(F, Faces), flat(F)),
    forall((member(F1, Faces), member(F2, Faces), F1 \= F2),
           angle(F1, F2, 90)).

%% I6: Load Transmission (The Arch)
invariant(thrust_resolution(Arch)) :-
    voussoirs(Arch, Vlist), keystone(Arch, _),
    forall(member(V, Vlist), thrust_vector(V, _, _)),
    findall(L, (member(V, Vlist), thrust_vector(V, _, L)), Laterals),
    sumlist(Laterals, Total),
    abs(Total) < 0.001.

%% I7: Binding Fidelity (The Mortar)
invariant(mortar_bond(Wall)) :-
    joints(Wall, Jlist),
    forall(member(J, Jlist), (thickness(J, T), T =< 0.009525)),
    forall(member(J, Jlist), composition(J, [lime, sand, water], _)).

%% I8: Oral Transmission (The Word)
invariant(mode_recognition(Mason1, Mason2)) :-
    grip(Mason1, G), grip(Mason2, G),
    word(Mason1, W), word(Mason2, W),
    G = due_guard, W = mah_hah_bone.

%% I9: Hierarchical Progression (The Degrees)
invariant(degree_progression(Mason)) :-
    (entered_apprentice(Mason) ; fellowcraft(Mason) ; master_mason(Mason)),
    \+ (entered_apprentice(Mason), fellowcraft(Mason)),
    \+ (fellowcraft(Mason), master_mason(Mason)).

%% I10: Secrecy of Geometry (The Trade)
invariant(trade_secret(Geometry)) :-
    operative(Mason), knows(Mason, Geometry),
    \+ public(Geometry).

%% ─── Ψ MORPHISM: Operative → Speculative ─────────────────────────────────────

%% Physical tools → Cognitive virtues
morphism(square, rectitude).
morphism(level, equity).
morphism(plumb, integrity).
morphism(compass, circumspection).
morphism(trowel, charity).

%% Invariant domains
operative_invariant(geometric_congruence).
speculative_invariant(moral_coherence).

%% Structural isomorphism test
holds_invariant(Domain) :-
    constraint_graph(Domain, Graph),
    isomorphic(Graph, universal_constraint_template).

universal_constraint_template([
    orthogonal(a, b),
    parallel(a, c),
    symmetric(a, a),
    bounded(a, r)
]).

%% ─── COUNTER-MASON PREDICATES ─────────────────────────────────────────────────
%% Each mirrors an invariant syntactically but violates its teleology.

%% C1: False Square — looks 90°, bears no load
counter_square(Stone) :-
    dressed(Stone, Face1), dressed(Stone, Face2),
    angle(Face1, Face2, 90),
    \+ load_bearing(Stone).

%% C2: False Plumb — vertical line, no load path
counter_plumb(Wall) :-
    course(Wall, _), plumb_line(Wall, Center),
    \+ load_path(Wall, Center).

%% C3: False Level — plane exists, stones float
counter_level(Course) :-
    stones(Course, Stones),
    forall(member(S, Stones), (top_plane(S, Z), Z =:= 0)),
    member(S2, Stones), \+ supported(S2).

%% C4: False Compass — proportion without function
counter_compass(Structure) :-
    width(Structure, W), height(Structure, H),
    Phi is (1 + sqrt(5)) / 2,
    Ratio is W / H,
    abs(Ratio - Phi) < 0.001,
    \+ habitable(Structure).

%% C5: False Ashlar — perfect faces, fractured heart
counter_ashlar(Stone) :-
    six_faces(Stone, Faces),
    forall(member(F, Faces), flat(F)),
    forall((member(F1, Faces), member(F2, Faces), F1 \= F2),
           angle(F1, F2, 90)),
    flaw(Stone, Core), hidden(Core).

%% C6: False Arch — thrusts resolve, abutments yield
counter_arch(Arch) :-
    voussoirs(Arch, Vlist), keystone(Arch, _),
    forall(member(V, Vlist), thrust_vector(V, _, _)),
    findall(L, (member(V, Vlist), thrust_vector(V, _, L)), Laterals),
    sumlist(Laterals, Total), abs(Total) < 0.001,
    abutment(Arch, A), yields(A).

%% C7: False Mortar — joint perfect, bond absent
counter_mortar(Wall) :-
    joints(Wall, Jlist),
    forall(member(J, Jlist), (thickness(J, T), T =< 0.009525)),
    forall(member(J, Jlist), composition(J, [lime, sand, water], _)),
    member(J2, Jlist), \+ adhesion(J2).

%% C8: False Word — grip and word correct, no trust
counter_word(Mason1, Mason2) :-
    grip(Mason1, G), grip(Mason2, G),
    word(Mason1, W), word(Mason2, W),
    G = due_guard, W = mah_hah_bone,
    \+ trust(Mason1, Mason2).

%% C9: False Degree — title held, work unknown
counter_degree(Mason) :-
    (entered_apprentice(Mason) ; fellowcraft(Mason) ; master_mason(Mason)),
    \+ can_lay_stone(Mason).

%% C10: False Secret — geometry public, craft lost
counter_secret(Geometry) :-
    public(Geometry),
    \+ operative(_).

%% ─── COUNTER-MASON AGENT ──────────────────────────────────────────────────────

counter_mason(Agent) :-
    has_tools(Agent, [square, level, plumb, compass, trowel]),
    knows_ritual(Agent),
    pays_dues(Agent),
    attends_stated(Agent),
    work_of(Agent, Work),
    counter_square(Work),
    counter_plumb(Work),
    counter_level(Work),
    counter_compass(Work),
    counter_ashlar(Work),
    counter_arch(Work),
    counter_mortar(Work),
    counter_word(Agent, _),
    counter_degree(Agent),
    counter_secret(_).

%% Detection: indistinguishable by inspection, only by test (load + time)
detect_counter_mason(Agent) :-
    counter_mason(Agent),
    work_of(Agent, Work),
    test_load(Work, Failure),
    Failure \= 0.

%% Meta-invariant: only time + gravity cannot be bribed
true_operative(Agent) :-
    work_of(Agent, Work),
    stands(Work, Time),
    Time > 100.

%% ─── DETECTION COMPLEXITY NOTE ───────────────────────────────────────────────
%% Static inspection: O(1) — 10 predicate checks
%% Operative test:    O(Years × Load_cycles)
%% Invariant:         THE WORK STANDS OR IT FALLS.
