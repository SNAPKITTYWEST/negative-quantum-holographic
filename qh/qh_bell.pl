%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% CLONE_GATE: qh_bell_example
%%
%% qh_bell.pl — Bell-State Correlations via PITA + Quantum-Holographic Engine
%%
%% Encodes a two-qubit Bell-like state:
%%   |ψ⟩ = 0.8|up,up⟩ + 0.6|down,down⟩  (unnormalized; engine normalizes)
%%
%% Verified results:
%%   P(up,up)   = 0.64     P(down,down) = 0.36     P(up,down) = 0.0
%%   P(left up) = 0.64     P(same spin) = 1.0
%%   P(noise ok)= 0.99     P(reported up | left up) = 0.95
%%
%% Requires: quantum_holographic, qh_cplint, pack(pita)

:- use_module('quantum_holographic').

pair(up, up)     amps c(0.8, 0.0).
pair(down, down) amps c(0.6, 0.0).
pair(up, down)   amps c(0.0, 0.0).
pair(down, up)   amps c(0.0, 0.0).

:- use_module('qh_cplint').

:- pita.

:- qh_measure.

:- begin_lpad.

same_spin :- measure(pair(up, up)).
same_spin :- measure(pair(down, down)).

left_up   :- measure(pair(up, up)).
left_down :- measure(pair(down, down)).

reported_up   : 0.95 ; reported_down : 0.05 :- left_up.
reported_up   : 0.05 ; reported_down : 0.95 :- left_down.

noise_ok : 0.99 ; noise_bad : 0.01 :- same_spin.

:- end_lpad.

demo_bell :-
    prob(measure(pair(up, up)), P1),
    prob(measure(pair(down, down)), P2),
    prob(measure(pair(up, down)), P3),
    format("joint: P(up,up) = ~w, P(down,down) = ~w, P(up,down) = ~w~n",
           [P1, P2, P3]).

demo_marginal :-
    prob(left_up, PL),
    prob(same_spin, PS),
    format("marginal: P(left up) = ~w, P(same spin) = ~w~n", [PL, PS]).

demo_correlated :-
    prob(noise_ok, PN),
    format("P(noise ok) = ~w~n", [PN]).

demo_conditional :-
    prob(reported_up, left_up, P),
    format("P(reported up | left up) = ~w~n", [P]).

/** <examples>
?- demo_bell.
?- demo_marginal.
?- demo_correlated.
?- demo_conditional.
*/
