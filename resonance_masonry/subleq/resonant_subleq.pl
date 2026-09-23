% RESONANCE MASONRY — Resonant SUBLEQ
% Discrete dynamical system on the program counter.
%
% SUBLEQ step:
%   M[B] := M[B] - M[A]
%   if M[B] =< 0 then PC := C else PC := PC + 3
%
% Resonant trajectory: PC_{n+k} = PC_n for a smallest positive period k.
% Computational resonance frequency: f_R = f_instruction / k.
% Syscalls are PC transitions through a capability check.

:- module(resonant_subleq,
          [ subleq_step/3,
            subleq_run/4,
            resonance_period/3,
            resonance_frequency/3,
            syscall_check/3,
            care_step/4,
            dark_masonry/4,
            demo_resonance/0,
            demo_syscall/0,
            demo_care/0
          ]).

% ---------------------------------------------------------------------------
% Memory / machine state
% ---------------------------------------------------------------------------
% mem(Mem): association list Addr -> Int
% Instrs: list of PC-addressed instructions: Addr-subleq(A,B,C)
% PC is a word address (0, 3, 6, ...) matching the +3 fall-through.

mem_get(Mem, Addr, Val) :-
    (   member(Addr-Val, Mem)
    ->  true
    ;   Val = 0
    ).

mem_put(Mem, Addr, Val, Mem1) :-
    (   select(Addr-_, Mem, Rest)
    ->  Mem1 = [Addr-Val|Rest]
    ;   Mem1 = [Addr-Val|Mem]
    ).

instr_at(PC, Instrs, Instr) :-
    memberchk(PC-Instr, Instrs).

subleq_step(state(Mem, PC), Instrs, state(Mem1, PC1)) :-
    instr_at(PC, Instrs, subleq(A, B, C)),
    mem_get(Mem, A, VA),
    mem_get(Mem, B, VB),
    VB1 is VB - VA,
    mem_put(Mem, B, VB1, Mem1),
    (   VB1 =< 0
    ->  PC1 = C
    ;   PC1 is PC + 3
    ).

subleq_run(state(Mem, PC), Instrs, N, PCPath) :-
    subleq_run_(state(Mem, PC), Instrs, N, [PC], RevPath),
    reverse(RevPath, PCPath).

subleq_run_(_, _, 0, Acc, Acc).
subleq_run_(State, Instrs, N, Acc, Path) :-
    N > 0,
    subleq_step(State, Instrs, State1),
    State1 = state(Mem1, PC1),
    N1 is N - 1,
    subleq_run_(state(Mem1, PC1), Instrs, N1, [PC1|Acc], Path).

% ---------------------------------------------------------------------------
% Resonance: smallest positive period k with PC_{n+k} = PC_n
% ---------------------------------------------------------------------------

% First argument is the full PC path; we look for the first return of Path[0].
resonance_period(Path, K, Witness) :-
    Path = [PC0|Rest],
    first_return(Rest, PC0, 1, K, Step) ,
    Witness = step(Step).

first_return([PC|_], Target, Step, K, Step) :-
    PC = Target, !,
    K = Step.
first_return([_|Rest], Target, Step, K, Witness) :-
    Step1 is Step + 1,
    first_return(Rest, Target, Step1, K, Witness).

% f_R = f_instruction / k
resonance_frequency(FInstruction, K, FR) :-
    K > 0,
    FR is FInstruction / K.

% ---------------------------------------------------------------------------
% Syscall: PC transition + capability check
%   authorized -> GOD DOMAIN
%   unauthorized -> TRAP -> RETURN
% ---------------------------------------------------------------------------

syscall_check(Caps, Cap, Outcome) :-
    (   member(Cap, Caps)
    ->  Outcome = god_domain
    ;   Outcome = trap_return
    ).

% ---------------------------------------------------------------------------
% CARE (machine-level, same shape as Lean/Alloy)
%   Care(s,s') :=
%     Protected(s) = Protected(s')
%     and Authority(s') subset Authority(s) union Granted(s)
% s = mstate(ProtectedSet, AuthoritySet)
% ---------------------------------------------------------------------------

care_step(State, State1, Granted, care_ok) :-
    State  = mstate(Prot, Auth),
    State1 = mstate(Prot1, Auth1),
    Prot1 = Prot,
    forall(member(C, Auth1),
           ( member(C, Auth) ; member(C, Granted) )).
care_step(State, State1, Granted, care_violation) :-
    State  = mstate(Prot, Auth),
    State1 = mstate(Prot1, Auth1),
    State \= State1,
    (   Prot1 \= Prot
    ;   (   \+ forall(member(C, Auth1),
                      (member(C, Auth) ; member(C, Granted)))
        ;   \+ forall(member(C, Auth),
                      member(C, Auth1))
        )
    ),
    \+ care_step(State, State1, Granted, care_ok).

% DarkMasonry(s,s') <=> Transition and Privileged and not Care
dark_masonry(S, S1, Granted, dark_masonry) :-
    S \= S1,
    care_step(S, S1, Granted, care_violation).
dark_masonry(S, S1, Granted, authorized) :-
    S \= S1,
    care_step(S, S1, Granted, care_ok).

% ---------------------------------------------------------------------------
% Demos
% ---------------------------------------------------------------------------

demo_resonance :-
    % Word-addressed program: fall-through +3, one backward branch to 0.
    % Designed so PC visits 0,3,6,0,3,6,... (period k = 3).
    Instrs = [ 0-subleq(1, 2, 6),
               3-subleq(1, 2, 0),
               6-subleq(1, 2, 3)
             ],
    Mem0 = [1-1, 2-1],
    subleq_run(state(Mem0, 0), Instrs, 9, Path),
    resonance_period(Path, K, Wit),
    resonance_frequency(1000000, K, FR),
    format("PC path: ~w~n", [Path]),
    format("resonance period k = ~w (witness ~w)~n", [K, Wit]),
    format("f_R = f_instruction / k = ~w Hz (f_instruction = 1e6)~n", [FR]).

demo_syscall :-
    syscall_check([read, write], write, Out1),
    syscall_check([read, write], root, Out2),
    format("authorized write -> ~w~n", [Out1]),
    format("unauthorized root -> ~w~n", [Out2]).

demo_care :-
    S  = mstate([prot], [read]),
    SOk = mstate([prot], [read, write]),
    SViol = mstate([], [read, write]),
    dark_masonry(S, SOk, [write], R1),
    dark_masonry(S, SViol, [write], R2),
    format("grant within authority: ~w~n", [R1]),
    format("protected-state change: ~w~n", [R2]).
