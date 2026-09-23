%% SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
%% CLONE_GATE:AES256:6362ff27b925ed797e8e5a15523d897ff3406c36b61857d53fbd70c93f4dc95b
%%
%% qh_examples.pl — Interference, Unitary Mix, Quasi-Negativity, Born Rule
%%
%% State: |dark⟩ = 0.6+0i,  |bright⟩ = 0+0.8i
%% qsign: dark=0.75 (positive quasi-weight), bright=-0.25 (negative)
%%
%% Verified results:
%%   destructive interference P = 0.0
%%   after mix:  P(dark)=0.5,  P(bright)=0.5
%%   quasi-negativity = 0.25
%%   Born rule:  P(dark)=0.36, P(bright)=0.64
%%   P(measure dark)=0.36,  P(measure bright)=0.64
%%   P(readout bright) = 0.612
%%
%% Only remaining noise: three cosmetic bddem export warnings from the
%% cplint pack itself (not from this module).
%%
%% Requires: quantum_holographic, qh_cplint, pack(pita)

:- use_module('quantum_holographic').

mode(dark)   amps c(0.6, 0.0).
mode(bright) amps c(0.0, 0.8).

mode(dark)   qsign 0.75.
mode(bright) qsign -0.25.

:- use_module('qh_cplint').

:- pita.

:- qh_measure.

:- begin_lpad.

readout(dark)   : 0.9 ; readout(bright) : 0.1 :- measure(mode(dark)).
readout(dark)   : 0.1 ; readout(bright) : 0.9 :- measure(mode(bright)).

:- end_lpad.

demo_interference :-
    qh_snapshot(S0),
    qh_reset,
    path(a, b) amps c(0.5, 0.0),
    qh_interfere(path(a, b), c(-0.5, 0.0)),
    qh_prob(path(a, b), P),
    format("destructive interference prob = ~w~n", [P]),
    qh_restore(S0).

demo_unitary :-
    qh_snapshot(S0),
    qh_reset,
    qh_set_ket(mode(dark), 1.0, 0.0),
    qh_unitary_set(mix, mode(dark),  mode(dark),   c(0.7071067811865475, 0.0)),
    qh_unitary_set(mix, mode(dark),   mode(bright), c(0.7071067811865475, 0.0)),
    qh_unitary_set(mix, mode(bright), mode(dark),   c(0.7071067811865475, 0.0)),
    qh_unitary_set(mix, mode(bright), mode(bright), c(-0.7071067811865475, 0.0)),
    qh_apply(mix),
    qh_prob(mode(dark), P0),
    qh_prob(mode(bright), P1),
    format("after mix: P(dark) = ~w, P(bright) = ~w~n", [P0, P1]),
    qh_restore(S0).

demo_negativity :-
    qh_negativity(N),
    format("quasi-negativity = ~w~n", [N]).

demo_born :-
    qh_prob(mode(dark), P0),
    qh_prob(mode(bright), P1),
    format("born: P(dark) = ~w, P(bright) = ~w~n", [P0, P1]).

demo_cplint :-
    prob(measure(mode(dark)), PM0),
    prob(measure(mode(bright)), PM1),
    prob(readout(bright), PR),
    format("cplint: P(measure dark) = ~w, P(measure bright) = ~w~n", [PM0, PM1]),
    format("cplint: P(readout bright) = ~w~n", [PR]).

/** <examples>
?- demo_interference.
?- demo_unitary.
?- demo_negativity.
?- demo_born.
?- demo_cplint.
*/
