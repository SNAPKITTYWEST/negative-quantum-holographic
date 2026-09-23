%% SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
%% CLONE_GATE:AES256:5a638a128ca67348f1073ba0aed26d85905a29128cbd71b250c9cf4e598c7f0d
%%
% RESONANCE MASONRY — CONNECT layer
% Ties CARE  <->  SUBLEQ PC trajectory  <->  syscall capability check
% Shared vocabulary across Prolog (runtime), Alloy (bounded), Lean (proofs):
%   Care(s,s1)          : Protected preserved; Authority' ⊆ Authority ∪ Granted
%   Transition / PC step : control-flow step (Prolog: PC address moves)
%   syscall_check       : authorized -> god_domain ; unauthorized -> trap_return
%   DarkMasonry         : Transition ∧ Privileged ∧ ¬Care

:- module(connect,
          [ connect_run/0,
            full_dispatch/7
          ]).

:- use_module('../subleq/resonant_subleq').

% ---------------------------------------------------------------------------
% Full dispatch: one machine step connecting SUBLEQ, syscall, and CARE.
%   S0 = state(Mem, PC)   — Prolog SUBLEQ machine state
%   A0/A1 = mstate(Prot, Auth) — authority edge checked by CARE
%   Instrs / Granted     — program and grant set for this edge
%   Outcome              — dispatch(PC0, PC1, syscall, care_verdict)
% ---------------------------------------------------------------------------
full_dispatch(S0, A0, S1, A1, Instrs, Granted, Outcome) :-
    subleq_step(S0, Instrs, S1),
    S0 = state(_, PC0),
    S1 = state(_, PC1),
    syscall_for_pc(PC0, Cap),
    A0 = mstate(_, Auth0),
    care_edge(A0, A1, Granted, CareVerdict),
    syscall_check(Auth0, Cap, SysOutcome),
    combine_outcome(SysOutcome, CareVerdict, PC0, PC1, Outcome).

% Which capability does this PC's syscall site request?
% Word 0 = load, 3 = gate (requests 'read'), 6 = store (requests 'write').
syscall_for_pc(0, read).
syscall_for_pc(3, read).
syscall_for_pc(6, write).
syscall_for_pc(_, read).

% CARE on a concrete authority edge — delegates to resonant_subleq care_step/4.
care_edge(A0, A1, Granted, Verdict) :-
    care_step(A0, A1, Granted, V0),
    (   V0 == care_ok
    ->  Verdict = care_ok
    ;   Verdict = care_violation
    ).

combine_outcome(god_domain, care_ok, PC0, PC1,
                dispatch(PC0, PC1, god_domain, authorized)) :- !.
combine_outcome(trap_return, _, PC0, PC1,
                dispatch(PC0, PC1, trap_return, trap)) :- !.
combine_outcome(_, care_violation, PC0, PC1,
                dispatch(PC0, PC1, dark_masonry, dark_masonry)) :- !.
combine_outcome(Sys, care_ok, PC0, PC1,
                dispatch(PC0, PC1, Sys, authorized)).

% ---------------------------------------------------------------------------
% CONNECT demo: walk the resonant program under CARE gating
% ---------------------------------------------------------------------------

connect_run :-
    Instrs = [ 0-subleq(1, 2, 6),
               3-subleq(1, 2, 0),
               6-subleq(1, 2, 3)
             ],
    Mem0 = [1-1, 2-1],
    S0 = state(Mem0, 0),
    % authority starts with read; grant write on the store edge
    A0   = mstate([prot], [read]),
    Aok  = mstate([prot], [read, write]),   % grant within authority union granted
    Aviol = mstate([], [read, write]),      % protected cleared -> DarkMasonry
    % authorized CARE edge under a SUBLEQ step
    full_dispatch(S0, A0, S1, Aok, Instrs, [write], OutOk),
    S1 = state(_, PC1),
    format("CONNECT dispatch: PC 0 -> ~w with ~w~n", [PC1, OutOk]),
    % CARE-positive authority edge (same as Lean example)
    dark_masonry(A0, Aok, [write], R1),
    format("CONNECT care edge (grant): ~w~n", [R1]),
    % CARE-negative authority edge
    dark_masonry(A0, Aviol, [write], R2),
    format("CONNECT care edge (violation): ~w~n", [R2]),
    % PC trajectory + resonance still hold on the connected machine
    subleq_run(S0, Instrs, 9, Path),
    resonance_period(Path, K, Wit),
    format("CONNECT PC path: ~w (k=~w, ~w)~n", [Path, K, Wit]),
    true.

% run: swipl -q -g "consult('resonance_masonry/connect/connect.pl'), connect_run, halt(0)" -t "halt(1)"
