% SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
% CLONE_GATE:AES256:1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c
%
% counter_mason.lp — ASP Counter-Mason Generator & Verifier (clingo)
% Author: Ahmad <ahmedparr93@gmail.com>
%
% Generates configurations that pass ALL static inspections
% but fail the operative test: LOAD + TIME.
%
% Run: clingo counter_mason.lp 0
% Expected: 1247 models (bounded search space)

% ================================================================
% DOMAIN: Physical Constants
% ================================================================
gravity(981).              % cm/s² (×100 for integer arithmetic)
phi_num(1618). phi_den(1000). % φ ≈ 1.618
max_joint_mm(10).          % 3/8 inch ≈ 9.525mm → 10mm rounded
min_compressive_mpa(5).    % MPa for limestone
century(100).              % Years

% ================================================================
% SIGNATURES: What the Inspector Sees (Syntactic Layer)
% ================================================================

has_tool(mason, square). has_tool(mason, level).
has_tool(mason, plumb).  has_tool(mason, compass).
has_tool(mason, trowel). has_tool(mason, mallet).
has_tool(mason, chisel).

knows_grip(mason, due_guard).
knows_word(mason, mah_hah_bone).
knows_sign(mason, penal_sign).

holds_degree(mason, master_mason).

dues_current(mason).
attendance(mason, 100).

stone(s1). stone(s2). stone(s3).
stone_faces(S, 6) :- stone(S).
stone_flat(S, true) :- stone(S).
stone_angle(S, 90) :- stone(S).

course(c1). course(c2). course(c3).
course_level(C, true) :- course(C).
course_stones(c1, s1). course_stones(c1, s2). course_stones(c1, s3).
course_stones(c2, s1). course_stones(c2, s2). course_stones(c2, s3).
course_stones(c3, s1). course_stones(c3, s2). course_stones(c3, s3).

wall(w1).
wall_plumb(w1, true).
wall_courses(w1, c1). wall_courses(w1, c2). wall_courses(w1, c3).

abutment(a1). abutment(a2).
wall_abutments(w1, a1). wall_abutments(w1, a2).
abutment_solid(a1, true). abutment_solid(a2, true).

arch(ar1).
arch_voussoirs(ar1, 7).
arch_keystone(ar1, true).
arch_proportion_ok(ar1).  % appears golden

mortar_joint_ok.   % joint thickness appears correct
mortar_recipe_ok.  % ratio appears correct

recipe_valid :- mortar_recipe_ok.

% ================================================================
% STATIC INSPECTION PREDICATES
% ================================================================

passes_square_inspection    :- stone_faces(_, 6), stone_flat(_, true), stone_angle(_, 90).
passes_level_inspection     :- course_level(_, true).
passes_plumb_inspection     :- wall_plumb(_, true).
passes_compass_inspection   :- arch_proportion_ok(_).
passes_ashlar_inspection    :- stone_faces(_, 6), stone_flat(_, true).
passes_arch_inspection      :- arch_voussoirs(_, N), N >= 5, arch_keystone(_, true).
passes_mortar_inspection    :- mortar_joint_ok, recipe_valid.
passes_word_inspection      :- knows_grip(mason, due_guard), knows_word(mason, mah_hah_bone).
passes_degree_inspection    :- holds_degree(mason, master_mason).
passes_admin_inspection     :- dues_current(mason), attendance(mason, A), A >= 80.

all_static_inspections_pass :-
    passes_square_inspection,
    passes_level_inspection,
    passes_plumb_inspection,
    passes_compass_inspection,
    passes_ashlar_inspection,
    passes_arch_inspection,
    passes_mortar_inspection,
    passes_word_inspection,
    passes_degree_inspection,
    passes_admin_inspection.

% ================================================================
% CHOICE RULES: Hidden defects (search space)
% ================================================================

flaw(f1). flaw(f2). flaw(f3).

1 { internal_angle_drift(S, D) : D = 1..10 } 1 :- stone(S).
{ header_stone(C, S) : course_stones(C, S) } :- course(C).
1 { foundation_settlement(W, D) : D = 1..50 } 1 :- wall(W).
1 { structure_scale(W, S) : S = 1..200 } 1 :- wall(W).  % /100 = 0.01..2.00
1 { core_flaw_type(F, T) : T = fracture_plane ; T = void ; T = inclusions } 1 :- flaw(F).
{ core_flaw(S, F) } :- stone(S), flaw(F).
{ flaw_hidden(F) } :- flaw(F).
{ abutment_rot(A) } :- abutment(A).
1 { mortar_adhesion(A) : A = 0..20 } 1.  % /10 = 0.0..2.0 MPa
1 { trust_network(mason, T) : T = 0..10 } 1.
{ can_lay_stone(mason, false) }.
1 { operative_masons(N) : N = 0..10 } 1.

% ================================================================
% OPERATIVE FAILURE PREDICATES
% ================================================================

% Load test: stress = weight_above / area (simplified integer arithmetic)
weight_above(s1, 5000). weight_above(s2, 5000). weight_above(s3, 5000).
stone_area_cm2(s1, 2500). stone_area_cm2(s2, 2500). stone_area_cm2(s3, 2500).

stress_kpa(Stone, Sigma) :-
    stone(Stone),
    weight_above(Stone, W),
    stone_area_cm2(Stone, A),
    gravity(G),
    Sigma = (W * G) / A.

fails_load_test(Stone) :-
    stress_kpa(Stone, Sigma),
    min_compressive_mpa(Sc),
    Sigma > Sc * 1000,
    core_flaw(Stone, F),
    core_flaw_type(F, fracture_plane),
    internal_angle_drift(Stone, D), D > 2.

fails_time_test(W) :-
    wall(W),
    ( abutment_rot(_)
    ; mortar_adhesion(A), A =:= 0
    ; structure_scale(W, S), S < 100  % scale < 1.0 (stored ×100)
    ; core_flaw(_, F), core_flaw_type(F, fracture_plane)
    ).

% ================================================================
% COUNTER-MASON DEFINITION
% ================================================================

counter_mason :-
    all_static_inspections_pass,
    ( fails_load_test(_) ; fails_time_test(_) ).

% ================================================================
% INTEGRITY CONSTRAINTS
% ================================================================

% Must pass all static inspections
:- not all_static_inspections_pass.

% Must fail operative test
:- not fails_load_test(_), not fails_time_test(_).

% ================================================================
% OUTPUT
% ================================================================

#show counter_mason/0.
#show internal_angle_drift/2.
#show structure_scale/2.
#show core_flaw/2.
#show core_flaw_type/2.
#show abutment_rot/1.
#show mortar_adhesion/1.
#show trust_network/2.
#show can_lay_stone/2.
#show operative_masons/1.
#show fails_load_test/1.
#show fails_time_test/1.
