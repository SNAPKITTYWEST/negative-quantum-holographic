%% SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0
%% CLONE_GATE: qh_cplint_bridge
%%
%% qh_cplint.pl — PITA/cplint Bridge for Quantum-Holographic Measurements
%%
%% Connects the quantum_holographic amplitude engine to the PITA
%% probabilistic reasoning pack. qh_measure intercepted via
%% user:term_expansion/2 so expanded clauses load through the normal
%% file path (the old assertz path was wiped by PITA's end_of_file
%% zero-clause re-emit).
%%
%% Exports: qh_measure/0, qh_measure/1, qh_measure/2
%% Requires: SWI-Prolog pack(pita), pack(cplint)

:- module(qh_cplint,
          [ qh_measure/0,
            qh_measure/1,
            qh_measure/2
          ]).

:- reexport(library(pita)).
:- use_module(quantum_holographic).

:- multifile user:term_expansion/2.

user:term_expansion(:- qh_measure, Out) :- !,
    qh_expand(measure, Out).

user:term_expansion(:- qh_measure(Basis), Out) :- !,
    qh_expand(measure, Basis, Out).

user:term_expansion(:- qh_measure(Pred, Basis), Out) :- !,
    qh_expand(Pred, Basis, Out).

qh_measure :-
    qh_basis(Basis),
    qh_measure(measure, Basis).

qh_measure(Basis) :-
    qh_measure(measure, Basis).

qh_measure(Pred, Basis) :-
    qh_expand(Pred, Basis, Out),
    store_out(user, Out).

qh_expand(Pred, Out) :-
    qh_basis(Basis),
    qh_expand(Pred, Basis, Out).

qh_expand(Pred, Basis, Out) :-
    (   Basis = []
    ->  throw(error(qh_empty_basis, qh_expand/3))
    ;   true
    ),
    (   prolog_load_context(module, M)
    ->  true
    ;   throw(error(qh_load_time_only, qh_expand/3))
    ),
    (   pita:pita_input_mod(M)
    ->  true
    ;   throw(error(qh_pita_not_initialized, qh_expand/3))
    ),
    build_measure_clause(Pred, Basis, Clause),
    (   M:pita_on
    ->  Added = no
    ;   assertz(M:pita_on),
        Added = yes
    ),
    setup_call_cleanup(
        true,
        (   user:term_expansion(Clause, Out)
        ->  true
        ;   throw(error(qh_expansion_failed(Clause), qh_expand/3))
        ),
        (   Added = yes
        ->  retract(M:pita_on)
        ;   true
        )
    ).

build_measure_clause(Pred, Basis, (Head :- db(qh_bind_probs(Pairs)))) :-
    measure_parts(Pred, Basis, Heads, Pairs),
    heads_disj(Heads, Head).

measure_parts(_, [], [], []).
measure_parts(Pred, [Term|Rest], [H|Heads], [Term:V|Pairs]) :-
    annot_head(Pred, Term, V, H),
    measure_parts(Pred, Rest, Heads, Pairs).

annot_head(Pred, Term, V, Head) :-
    H0 =.. [Pred, Term],
    Head = (H0 : V).

heads_disj([H], H) :- !.
heads_disj([H|Rest], (H ; Tail)) :-
    heads_disj(Rest, Tail).

store_out(M, Out) :-
    (   is_list(Out)
    ->  maplist(store_one(M), Out)
    ;   store_one(M, Out)
    ).

store_one(M, Term) :-
    (   Term = (:- Goal)
    ->  ignore(catch(M:Goal, _, true))
    ;   Term = (Head :- Body)
    ->  catch(assertz(M:(Head :- Body)), E,
              throw(error(qh_assert_failed(Term, E), store_one/2)))
    ;   catch(assertz(M:Term), E,
              throw(error(qh_assert_failed(Term, E), store_one/2)))
    ).
