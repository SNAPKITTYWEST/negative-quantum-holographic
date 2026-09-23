%% SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
%% CLONE_GATE:AES256:f9a5e41f780778e3c3d288314f3a9540289bba7b936f95200cbbca1f870857c9
%%
%% quantum_holographic.pl — Quantum-Holographic Amplitude Engine
%%
%% Complex-amplitude state store (qh_ket/3) with:
%%   - qh_set_ket/3, qh_amplitude/2, qh_prob/2     : state access
%%   - qh_interfere/2, qh_phase/2, qh_normalize/0  : amplitude ops
%%   - qh_apply/1, qh_unitary_set/4, qh_unitary/4  : unitary maps
%%   - qh_collapse/1                                : projection
%%   - qh_snapshot/1, qh_restore/1                 : state snapshots
%%   - qh_qsign_set/2, qh_qsign/2, qh_negativity/1 : quasi-probability
%%   - qh_born_pairs/1, qh_bind_probs/1            : Born-rule output
%%
%% DSL operators (700, xfx): amps, qsign
%% Intercepted via user:term_expansion/2 so expanded clauses load
%% through the normal file path (old assertz path wiped by PITA's
%% end_of_file zero-clause re-emit).

:- module(quantum_holographic,
          [ qh_reset/0,
            qh_set_ket/3,
            qh_amplitude/2,
            qh_prob/2,
            qh_interfere/2,
            qh_phase/2,
            qh_normalize/0,
            qh_apply/1,
            qh_unitary_set/4,
            qh_unitary/4,
            qh_collapse/1,
            qh_basis/1,
            qh_snapshot/1,
            qh_restore/1,
            qh_qsign_set/2,
            qh_qsign/2,
            qh_negativity/1,
            qh_born_pairs/1,
            qh_bind_probs/1,
            amps/2,
            qsign/2,
            c_add/3,
            c_mul/3,
            c_conj/2,
            c_abs2/2,
            op(700, xfx, amps),
            op(700, xfx, qsign)
          ]).

:- dynamic qh_ket/3.
:- dynamic qh_qweight/2.
:- dynamic qh_basis_item/1.
:- dynamic qh_unitary/4.

:- multifile user:term_expansion/2.

:- op(700, xfx, amps).
:- op(700, xfx, qsign).

user:term_expansion(amps(Term, c(Re, Im)), []) :- !,
    ground(c(Re, Im)),
    quantum_holographic:qh_set_ket(Term, Re, Im).

user:term_expansion(qsign(Term, Q), []) :- !,
    ground(Q),
    quantum_holographic:qh_qsign_set(Term, Q).

user:term_expansion(qh_unitary(Name, In, Out, c(Re, Im)), []) :- !,
    ground(c(Re, Im)),
    quantum_holographic:qh_unitary_set(Name, In, Out, c(Re, Im)).

amps(Term, c(Re, Im)) :-
    qh_set_ket(Term, Re, Im).

qsign(Term, Q) :-
    qh_qsign_set(Term, Q).

c_add(c(A, B), c(C, D), c(X, Y)) :-
    X is A + C,
    Y is B + D.

c_mul(c(A, B), c(C, D), c(X, Y)) :-
    X is A * C - B * D,
    Y is A * D + B * C.

c_conj(c(A, B), c(A, NegB)) :-
    NegB is -B.

c_abs2(c(A, B), P) :-
    P is A * A + B * B.

qh_reset :-
    retractall(qh_ket(_, _, _)),
    retractall(qh_qweight(_, _)),
    retractall(qh_basis_item(_)),
    retractall(qh_unitary(_, _, _, _)).

qh_set_ket(Term, Re, Im) :-
    must_be_compound_or_atom(Term),
    must_be(number, Re),
    must_be(number, Im),
    retractall(qh_ket(Term, _, _)),
    assertz(qh_ket(Term, Re, Im)),
    (   qh_basis_item(Term)
    ->  true
    ;   assertz(qh_basis_item(Term))
    ).

must_be_compound_or_atom(Term) :-
    (   atom(Term)
    ;   compound(Term)
    ),
    !.
must_be_compound_or_atom(Term) :-
    throw(error(type_error(atomic_or_compound, Term), _)).

qh_amplitude(Term, c(Re, Im)) :-
    (   qh_ket(Term, Re, Im)
    ->  true
    ;   Re = 0.0, Im = 0.0
    ).

qh_norm2(Sum) :-
    findall(P, (qh_ket(_, R, I), c_abs2(c(R, I), P)), Ps),
    foldl([P, A, B]>>(B is A + P), Ps, 0.0, Sum).

qh_prob(Term, P) :-
    qh_norm2(Sum),
    (   Sum =:= 0.0
    ->  P = 0.0
    ;   qh_amplitude(Term, c(R, I)),
        c_abs2(c(R, I), A),
        P is A / Sum
    ).

qh_interfere(Term, c(R, I)) :-
    qh_amplitude(Term, c(R0, I0)),
    c_add(c(R0, I0), c(R, I), c(R1, I1)),
    qh_set_ket(Term, R1, I1).

qh_phase(Term, Factor) :-
    qh_amplitude(Term, c(R, I)),
    c_mul(c(R, I), Factor, c(R1, I1)),
    qh_set_ket(Term, R1, I1).

qh_normalize :-
    qh_norm2(Sum),
    (   Sum =:= 0.0
    ->  true
    ;   S is sqrt(Sum),
        findall(T-R-I, qh_ket(T, R, I), Kets),
        retractall(qh_ket(_, _, _)),
        forall(
            member(T-R-I, Kets),
            ( R1 is R / S,
              I1 is I / S,
              assertz(qh_ket(T, R1, I1))
            )
        )
    ).

qh_basis(Basis) :-
    findall(T, qh_basis_item(T), Basis0),
    sort(Basis0, Basis).

qh_unitary_set(Name, In, Out, c(Re, Im)) :-
    retractall(qh_unitary(Name, In, Out, _)),
    assertz(qh_unitary(Name, In, Out, c(Re, Im))).

qh_apply(Name) :-
    qh_basis(Basis),
    forall(
        member(T, Basis),
        (   qh_unitary(Name, T, _, _)
        ->  true
        ;   throw(error(qh_incomplete_map(Name, T), qh_apply/1))
        )
    ),
    findall(
        Out-C,
        ( qh_ket(In, R, I),
          qh_unitary(Name, In, Out, Coef),
          c_mul(Coef, c(R, I), C)
        ),
        Contribs
    ),
    findall(Out, member(Out-_, Contribs), Outs0),
    sort(Outs0, Outs),
    retractall(qh_ket(_, _, _)),
    forall(
        member(Out, Outs),
        (   findall(C, member(Out-C, Contribs), Cs)
        ->  foldl([C, A0, A]>>c_add(A0, C, A), Cs, c(0.0, 0.0), c(R1, I1)),
            assertz(qh_ket(Out, R1, I1))
        ;   assertz(qh_ket(Out, 0.0, 0.0))
        )
    ),
    forall(
        member(T, Outs),
        (   qh_basis_item(T)
        ->  true
        ;   assertz(qh_basis_item(T))
        )
    ),
    qh_normalize.

qh_collapse(Term) :-
    qh_basis_item(Term),
    findall(T-R-I, qh_ket(T, R, I), Kets),
    retractall(qh_ket(_, _, _)),
    (   member(Term-R-I, Kets)
    ->  assertz(qh_ket(Term, R, I))
    ;   assertz(qh_ket(Term, 1.0, 0.0))
    ),
    qh_normalize.

qh_snapshot(qh_snap(Kets, Qs, Basis, Units)) :-
    findall(T-R-I, qh_ket(T, R, I), Kets),
    findall(T-Q, qh_qweight(T, Q), Qs),
    findall(T, qh_basis_item(T), Basis),
    findall(U-In-Out-C, qh_unitary(U, In, Out, C), Units).

qh_restore(qh_snap(Kets, Qs, Basis, Units)) :-
    retractall(qh_ket(_, _, _)),
    retractall(qh_qweight(_, _)),
    retractall(qh_basis_item(_)),
    retractall(qh_unitary(_, _, _, _)),
    forall(member(T-R-I, Kets), assertz(qh_ket(T, R, I))),
    forall(member(T-Q, Qs), assertz(qh_qweight(T, Q))),
    forall(member(T, Basis), assertz(qh_basis_item(T))),
    forall(member(U-In-Out-C, Units), assertz(qh_unitary(U, In, Out, C))).

qh_qsign_set(Term, Q) :-
    must_be(number, Q),
    retractall(qh_qweight(Term, _)),
    assertz(qh_qweight(Term, Q)),
    (   qh_basis_item(Term)
    ->  true
    ;   assertz(qh_basis_item(Term))
    ).

qh_qsign(Term, Q) :-
    (   qh_qweight(Term, Q)
    ->  true
    ;   Q = 0.0
    ).

qh_negativity(N) :-
    findall(Q, (qh_qweight(_, Q), Q < 0.0), Negs),
    foldl([Q, A, B]>>(B is A + Q), Negs, 0.0, S),
    N is -S.

qh_born_pairs(Pairs) :-
    qh_basis(Basis),
    findall(
        T-W,
        ( member(T, Basis),
          qh_amplitude(T, c(R, I)),
          c_abs2(c(R, I), W)
        ),
        Weights
    ),
    foldl([_-W, A, B]>>(B is A + W), Weights, 0.0, Total),
    (   Total =:= 0.0
    ->  length(Weights, N),
        (   N =:= 0
        ->  Pairs = []
        ;   P0 is 1.0 / N,
            findall(T-P0, member(T-_, Weights), Pairs)
        )
    ;   findall(T-P, (member(T-W, Weights), P is W / Total), Pairs)
    ).

qh_bind_probs(Pairs) :-
    qh_born_pairs(Weighted),
    foldl(
        [Pair, Z0, Z1]>>
            (   Pair = Term:Var
            ->  (   member(Term-P, Weighted)
                ->  true
                ;   P = 0.0
                ),
                PC is min(max(P, 0.0), max(Z0, 0.0)),
                Var = PC,
                Z1 is Z0 - PC
            ;   throw(error(qh_bad_pair(Pair), qh_bind_probs/1))
            ),
        Pairs,
        1.0,
        _Z
    ).
