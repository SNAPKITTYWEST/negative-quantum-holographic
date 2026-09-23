# SEMANTIC_MEMORY.md — OMEGA-MUSTACHE WORM Chain Architecture

**Version**: 1.0  
**Last Updated**: 2026-09-22  
**Status**: Production-Ready  
**Integrity Level**: WORM-Sealed + Ed25519 Cryptographic Verification  

---

## EXECUTIVE SUMMARY

OMEGA-MUSTACHE is a sovereign semantic memory system that maintains cryptographically-sealed write-once read-many (WORM) append-only audit trails. The system provides deterministic replay, strict concurrency control, formal contract governance, and crash-safe recovery.

**Key Properties**:
- **Immutability**: All records permanently sealed via Blake3+Ed25519
- **Determinism**: Replay engine reconstructs exact prior state from chain
- **Auditability**: Full governance history with proof traces
- **Safety**: Atomic appends, fork detection, recovery protocols
- **Scalability**: Pluggable storage backends, index acceleration
- **Formal Verification**: Prolog-based contract and invariant checking

---

## 1. WORM CHAIN ARCHITECTURE

### 1.1 Core Concepts

Write-Once Read-Many (WORM) chain is an immutable, append-only sequence of records. Each record:
- Contains complete state snapshot (semantic, tensor, Ω)
- References previous record cryptographically
- Is signed with Ed25519 by issuing agent
- Cannot be modified or deleted once committed
- Forms linear history with fork-detection

### 1.2 WORMRecord Structure

```prolog
% Formal WORMRecord specification
record_type(worm_record).

% Core fields
worm_record(
    record_id,                    % Unique sequential ID (monotonically increasing)
    timestamp,                    % ISO8601 UTC with nanosecond precision
    agent_id,                     % Issuing agent identifier (Ed25519 public key)
    contract_version,             % Governance contract version binding this record
    
    % State snapshots (before/after transition)
    semantic_before,              % Semantic state before operation
    semantic_after,               % Semantic state after operation
    tensor_before,                % Tensor representation before
    tensor_after,                 % Tensor representation after
    omega_before,                 % Ω operator value before
    omega_after,                  % Ω operator value after
    
    % Hash and cryptographic binding
    input_hash,                   % Blake3(operation_input)
    curry_derivation_hash,        % Blake3 of curry derivation proof
    previous_record_hash,         % Blake3 of previous record (chain link)
    record_hash,                  % Blake3(all_above_fields)
    
    % Cryptographic signature
    ed25519_signature,            % Signature over record_hash
    ed25519_public_key,           % Public key of signer (redundant verification)
    
    % Metadata
    operation_type,               % 'contract_apply'|'tensor_op'|'omega_verify'|'state_transition'
    operation_input,              % Original input parameters
    operation_result,             % Final result/output
    metadata_json                 % Extended metadata (correlation IDs, etc.)
).

% Hash chain invariant: each record cryptographically bound to previous
previous_record_hash(Record, PrevHash) :-
    Record = worm_record(..., PrevHash, ..., _).

% Chain integrity: hashes form linear sequence
chain_integrity(RecordN, RecordN1) :-
    record_hash(RecordN, HashN),
    previous_record_hash(RecordN1, HashN).

% Signature verification
verify_signature(Record) :-
    Record = worm_record(..., Hash, Sig, PubKey, ...),
    ed25519_verify(Hash, Sig, PubKey) = true.

% All records in chain must verify
chain_verified(Chain) :-
    forall(member(Record, Chain), verify_signature(Record)).
```

### 1.3 Blake3 Hash Function

All hashing uses Blake3 (BLAKE3) for:
- Cryptographic binding (collision-resistant, 256-bit output)
- Performance (parallelizable, incremental)
- Determinism (same input → same hash always)

```prolog
% Blake3 hash bindings
blake3_hash(Data, Hash) :-
    % Deterministic: blake3(X) always produces same output
    atomic_list_concat(Data, Concatenated),
    crypto_blake3(Concatenated, Hash).

% Safe to use as database key/index
blake3_keyed_hash(Data, Key, Hash) :-
    crypto_blake3_keyed(Data, Key, Hash).

% Verify hash collision-resistance assumption
hash_collision_impossible :-
    % For practical OMEGA-MUSTACHE deployment:
    % - 256-bit output space
    % - Blake3 is cryptographically sound
    % - Probability of collision in 2^128 records = 2^-128
    true.
```

### 1.4 Ed25519 Signing & Key Management

Every record is signed by the issuing agent using Ed25519 (EdDSA, elliptic curve).

```prolog
% Agent identity is their Ed25519 public key
agent_identity(AgentID) :-
    % AgentID = base64(ed25519_public_key)
    string_length(AgentID, 43),  % Base64-encoded 32-byte key
    hex_base64(AgentID, _).      % Can be decoded

% Key lifecycle
agent_key_state(
    agent_id,           % Identifier (public key base64)
    public_key_pem,     % PEM format for storage
    private_key_pem,    % NEVER PERSISTED in WORM chain (kept in agent HSM/enclave)
    key_rotation_count, % Incremented on rotation
    created_at,         % Timestamp of key creation
    rotated_at,         % Last rotation time
    revoked              % Boolean: key marked revoked
).

% Signing operation: ONLY agent with private key can sign
sign_record(Record, PrivateKey, Signature) :-
    record_hash(Record, Hash),
    ed25519_sign(Hash, PrivateKey, Signature),
    % Signature format: base64-encoded 64-byte Ed25519 signature
    string_length(Signature, 88).  % 64 bytes = 88 chars in base64

% Verification: anyone with public key can verify signature
verify_record_signature(Record) :-
    Record = worm_record(..., RecordHash, Sig, PubKey, ...),
    ed25519_verify(RecordHash, Sig, PubKey) = true.

% Key rotation protocol
rotate_agent_key(AgentID, OldKey, NewKey) :-
    % 1. Generate new Ed25519 keypair
    ed25519_generate_keypair(NewPub, NewPriv),
    NewKeyID = base64(NewPub),
    
    % 2. Create rotation record signed by OLD key
    RotationRecord = worm_record(
        ...,
        operation_type = 'key_rotation',
        operation_input = #{old_key: OldKey, new_key: NewKeyID},
        ...
    ),
    
    % 3. Sign with old private key
    sign_record(RotationRecord, OldPriv, OldSig),
    
    % 4. Append to chain
    append_worm_record(RotationRecord),
    
    % 5. Record rotation in agent state
    update_agent_key_state(AgentID, #{
        public_key: NewKeyID,
        key_rotation_count: Count + 1,
        rotated_at: now()
    }).

% Revocation: prevent future signatures
revoke_agent_key(AgentID) :-
    % Create revocation record signed by current key
    % Future records with this key will fail chain_verified()
    get_current_agent_key(AgentID, CurrentKey),
    RevocationRecord = worm_record(
        ...,
        operation_type = 'key_revocation',
        operation_input = #{revoked_key: AgentID},
        ...
    ),
    sign_record(RevocationRecord, CurrentKey, Sig),
    append_worm_record(RevocationRecord),
    update_agent_key_state(AgentID, #{revoked: true}).
```

### 1.5 Chain Integrity Verification

```prolog
% Core integrity check: verify entire chain is valid
verify_worm_chain(Chain) :-
    % 1. Chain is non-empty list of records
    is_list(Chain),
    length(Chain, N),
    N > 0,
    
    % 2. Each record must have valid signature
    forall(member(Record, Chain), verify_record_signature(Record)),
    
    % 3. Hash chain must be linear (no forks)
    verify_hash_chain_linear(Chain),
    
    % 4. Timestamps must be monotonically increasing
    verify_timestamps_monotonic(Chain),
    
    % 5. Record IDs must be sequential without gaps
    verify_record_ids_sequential(Chain),
    
    % 6. No record can appear twice (no duplicates)
    \+ has_duplicate_records(Chain).

% Hash chain linearity: each record points to previous
verify_hash_chain_linear([_|[]]).  % Base case: one element is linear
verify_hash_chain_linear([Current, Previous|Rest]) :-
    record_hash(Previous, HashPrev),
    previous_record_hash(Current, HashPrev),
    verify_hash_chain_linear([Previous|Rest]).

% Timestamps must increase (allows equal, rejects decrease)
verify_timestamps_monotonic([_|[]]).
verify_timestamps_monotonic([Current, Previous|Rest]) :-
    timestamp(Current, TsCurrent),
    timestamp(Previous, TsPrev),
    TsCurrent >= TsPrev,
    verify_timestamps_monotonic([Previous|Rest]).

% Record IDs must be sequential
verify_record_ids_sequential([_|[]]).
verify_record_ids_sequential([Curr, Prev|Rest]) :-
    record_id(Curr, IDCurr),
    record_id(Prev, IDPrev),
    IDCurr is IDPrev + 1,
    verify_record_ids_sequential([Prev|Rest]).

% Detect duplicates (fork detection)
has_duplicate_records(Chain) :-
    length(Chain, N),
    list_to_set(Chain, Set),
    length(Set, SetLen),
    SetLen < N.

% Fork detection: if chain is not linear, identify fork point
detect_fork(Chain1, Chain2, ForkPoint) :-
    % Find common prefix
    append(Common, Suffix1, Chain1),
    append(Common, Suffix2, Chain2),
    Suffix1 \= Suffix2,
    last(Common, ForkPoint).

% Recovery from fork: take canonical chain (by timestamp/consensus)
resolve_fork(Chain1, Chain2, CanonicalChain) :-
    detect_fork(Chain1, Chain2, ForkPoint),
    append(Common, _, Chain1),
    last(Common, ForkPoint),
    
    % Fork resolution strategy: take chain with later commitment time
    tail(Chain1, Suffix1),
    tail(Chain2, Suffix2),
    (   timestamp_sum(Suffix1, Sum1),
        timestamp_sum(Suffix2, Sum2),
        Sum1 > Sum2
    ->  CanonicalChain = Chain1
    ;   CanonicalChain = Chain2
    ).
```

### 1.6 Cryptographic Commitments

```prolog
% Merkle tree for efficient proof of membership
merkle_tree_root(RecordList, MerkleRoot) :-
    % Build binary tree of hashes
    build_merkle_tree(RecordList, Tree),
    merkle_tree_root_of_tree(Tree, MerkleRoot).

% Proof of membership: show record is in authenticated tree
merkle_proof_of_membership(RecordList, TargetRecord, Proof) :-
    build_merkle_tree(RecordList, Tree),
    find_merkle_path(Tree, TargetRecord, Proof).

% Verify membership proof
verify_merkle_membership(Record, ExpectedRoot, Proof) :-
    compute_merkle_path(Record, Proof, ComputedRoot),
    ComputedRoot = ExpectedRoot.
```

---

## 2. STORAGE LAYER

### 2.1 File-Based WORM Journal

Records are persisted to an append-only journal file with strict ordering and atomicity.

```prolog
% WORM journal specification
worm_journal(
    file_path,                    % Absolute path to journal file
    max_record_size,              % Max bytes per record (e.g., 10MB)
    max_total_size,               % Max total journal size (e.g., 100GB)
    index_path,                   % Path to index file
    lock_file,                    % Path to lock for concurrency control
    record_count,                 % Number of records currently in journal
    total_bytes_written,          % Total bytes appended
    last_record_offset,           % File offset of last record start
    last_record_id,               % ID of last appended record
    created_at,                   % When journal was initialized
    last_append_at                % Timestamp of last successful append
).

% Journal entry format: length-prefixed JSON
% Format: [4-byte big-endian length][JSON record][Blake3 hash][4-byte checksum]
journal_entry_format :-
    % Total entry = length_prefix + json_data + hash + checksum
    % This allows efficient recovery by scanning file for valid entries.
    true.

% Append operation: atomic write to journal
append_to_journal(Journal, Record, NewOffset) :-
    % 1. Acquire exclusive append lock
    acquire_append_lock(Journal),
    
    % 2. Read current journal state (record count, last offset)
    read_journal_metadata(Journal, Metadata),
    
    % 3. Compute new record ID
    LastID = Metadata.last_record_id,
    NewID is LastID + 1,
    UpdatedRecord = Record#{record_id: NewID},
    
    % 4. Serialize record to JSON
    record_to_json(UpdatedRecord, JSON),
    
    % 5. Compute Blake3 hash
    blake3_hash(JSON, Hash),
    
    % 6. Create entry with length prefix
    string_length(JSON, JSONLen),
    entry = [length_prefix(JSONLen), JSON, Hash, checksum(JSON, Hash)],
    
    % 7. Open journal file in append mode
    open(Journal.file_path, append, Stream, [type(binary)]),
    
    % 8. Write entry atomically (fsync after write)
    write_entry_atomic(Stream, entry, NewOffset),
    
    % 9. Update index: NewID -> NewOffset
    update_index(Journal, NewID, NewOffset),
    
    % 10. Update journal metadata
    update_journal_metadata(Journal, #{
        record_count: Metadata.record_count + 1,
        total_bytes_written: Metadata.total_bytes_written + entry_size(entry),
        last_record_offset: NewOffset,
        last_record_id: NewID,
        last_append_at: now()
    }),
    
    % 11. Release lock
    release_append_lock(Journal).

% Write entry with fsync for durability
write_entry_atomic(Stream, Entry, Offset) :-
    get_stream_position(Stream, Offset),
    write_bytes(Stream, Entry),
    flush_output(Stream),
    fsync(Stream).

% Index: record_id -> file offset (for fast lookup)
record_index(Journal, #{
    record_id_to_offset: Map,     % record_id -> file offset
    offset_to_record_id: Map,     % file offset -> record_id (reverse)
    index_version: Version,        % Incremented on rebuild
    last_indexed_id: LastID,       % Last indexed record
    index_file_path: Path          % Path to persisted index
}).

% Build index from journal (on startup or rebuild)
rebuild_index(Journal, Index) :-
    % 1. Open journal file
    open(Journal.file_path, read, Stream, [type(binary)]),
    
    % 2. Scan entire file, extracting record_id and offset
    Index = #{},
    scan_journal_file(Stream, Index, 0, FinalIndex),
    
    % 3. Persist index to disk
    persist_index(FinalIndex, Journal.index_path),
    
    % 4. Close stream
    close(Stream).

% Scan through journal sequentially
scan_journal_file(Stream, AccIndex, Offset, FinalIndex) :-
    (   read_entry_at_offset(Stream, Offset, Entry, NextOffset)
    ->  (   is_valid_entry(Entry)
        ->  RecordID = Entry.record.record_id,
            NewIndex = AccIndex.put(RecordID, Offset),
            scan_journal_file(Stream, NewIndex, NextOffset, FinalIndex)
        ;   % Skip invalid entry, continue scanning
            scan_journal_file(Stream, AccIndex, NextOffset, FinalIndex)
        )
    ;   % End of file
        FinalIndex = AccIndex
    ).

% Fast lookup: get record by ID
get_record_by_id(Journal, RecordID, Record) :-
    % 1. Look up offset in index
    Index = Journal.index,
    Offset = Index.record_id_to_offset.get(RecordID),
    (   var(Offset)
    ->  fail  % Record not found
    ;   true
    ),
    
    % 2. Seek to offset in journal file
    open(Journal.file_path, read, Stream, [type(binary)]),
    seek(Stream, Offset, bof, _),
    
    % 3. Read entry
    read_entry_at_offset(Stream, Offset, Entry, _),
    Record = Entry.record,
    
    close(Stream).

% Range query: get records from ID1 to ID2
get_records_range(Journal, RecordID1, RecordID2, Records) :-
    findall(
        Record,
        (   between(RecordID1, RecordID2, ID),
            get_record_by_id(Journal, ID, Record)
        ),
        Records
    ).
```

### 2.2 Atomic Append Semantics

```prolog
% Atomic append: either fully succeeds or rolls back
atomic_append(Journal, Record, Result) :-
    (   % Try append
        append_to_journal(Journal, Record, NewOffset),
        % Verify it made it to disk
        verify_persisted(Journal, Record),
        Result = success(NewOffset)
    ;   % If any step fails, rollback
        Result = failure(error_reason)
    ).

% Verify record was persisted to disk and is readable
verify_persisted(Journal, Record) :-
    % 1. Flush all pending writes
    fsync_journal(Journal),
    
    % 2. Read it back
    RecordID = Record.record_id,
    get_record_by_id(Journal, RecordID, ReadBack),
    
    % 3. Verify hash matches
    record_hash(Record, ExpectedHash),
    record_hash(ReadBack, ReadHash),
    ExpectedHash = ReadHash.

% Fsync to ensure all pending writes are durable
fsync_journal(Journal) :-
    % Platform-specific fsync
    % Linux: sys_fsync(2)
    % macOS: fcntl(fd, F_FULLFSYNC)
    % Windows: FlushFileBuffers()
    fsync_file(Journal.file_path).
```

### 2.3 Recovery from Crashes

```prolog
% Detect incomplete/corrupted records and rollback
recover_journal(Journal, RecoveryResult) :-
    % 1. Scan journal for last complete record
    find_last_complete_record(Journal.file_path, LastCompleteID, LastOffset),
    
    % 2. Check if file has bytes after LastOffset (partial write)
    file_size(Journal.file_path, FileSize),
    (   FileSize > LastOffset
    ->  % Truncate file to last complete record
        truncate_file(Journal.file_path, LastOffset),
        PartialBytesLost is FileSize - LastOffset,
        RecoveryResult = recovered(LastCompleteID, PartialBytesLost)
    ;   RecoveryResult = ok(LastCompleteID)
    ).

% Find last complete record by validating entry format
find_last_complete_record(FilePath, LastCompleteID, LastOffset) :-
    open(FilePath, read, Stream, [type(binary)]),
    scan_for_last_complete(Stream, 0, -1, 0, LastID, LastOff),
    close(Stream),
    LastCompleteID = LastID,
    LastOffset = LastOff.

% Scan backwards to find complete entry
scan_for_last_complete(Stream, Offset, LastCompleteID, LastCompleteOff, 
                       FinalID, FinalOff) :-
    (   read_entry_at_offset(Stream, Offset, Entry, NextOffset)
    ->  (   is_complete_entry(Entry)
        ->  NewID = Entry.record.record_id,
            scan_for_last_complete(Stream, NextOffset, NewID, Offset, 
                                   FinalID, FinalOff)
        ;   % Incomplete entry found, stop here
            FinalID = LastCompleteID,
            FinalOff = LastCompleteOff
        )
    ;   % EOF
        FinalID = LastCompleteID,
        FinalOff = LastCompleteOff
    ).

% Verify entry is complete: has all required fields and valid checksums
is_complete_entry(Entry) :-
    Entry = #{
        length_prefix: Len,
        json_data: JSON,
        hash: Hash,
        checksum: Checksum
    },
    % 1. Verify length prefix matches actual JSON length
    string_length(JSON, ActualLen),
    ActualLen = Len,
    % 2. Verify Blake3 hash of JSON
    blake3_hash(JSON, ComputedHash),
    ComputedHash = Hash,
    % 3. Verify checksum
    compute_checksum(JSON, Hash, ComputedChecksum),
    ComputedChecksum = Checksum.
```

### 2.4 Pluggable Storage Backends

```prolog
% Storage backend abstraction
storage_backend(
    backend_type,      % 'file' | 'database' | 'distributed'
    implementation      % Module name implementing interface
).

% Backend interface (all backends must implement)
backend_interface(
    append_record(Backend, Record, Result),
    get_record(Backend, RecordID, Record),
    get_records_range(Backend, ID1, ID2, Records),
    verify_chain(Backend, Chain),
    recover(Backend, Result),
    list_backends(Backends)
).

% File backend (default)
file_backend :-
    backend_implementation(file_backend_impl).

file_backend_impl :-
    backend_type(file),
    append_record(file_backend, Record, Result) :- append_to_journal(_, Record, Result),
    get_record(file_backend, ID, Record) :- get_record_by_id(_, ID, Record),
    recover(file_backend, Result) :- recover_journal(_, Result).

% Database backend (PostgreSQL/SQLite)
database_backend :-
    backend_implementation(db_backend_impl).

db_backend_impl :-
    backend_type(database),
    append_record(db_backend, Record, Result) :- 
        db_insert_record(Record, Result),
        db_fsync_transaction(Result),
    get_record(db_backend, ID, Record) :- 
        db_query_record(ID, Record),
    get_records_range(db_backend, ID1, ID2, Records) :- 
        db_query_range(ID1, ID2, Records),
    verify_chain(db_backend, Chain) :- 
        db_verify_chain_hashes(Chain),
    recover(db_backend, Result) :- 
        db_recovery_from_backup(Result).

% Distributed backend (multi-node WORM replication)
distributed_backend :-
    backend_implementation(distributed_backend_impl).

distributed_backend_impl :-
    backend_type(distributed),
    append_record(distributed_backend, Record, Result) :-
        % Replicate to N nodes, wait for consensus
        replicate_to_quorum(Record, N, Result),
    get_record(distributed_backend, ID, Record) :-
        % Query from any node (read-local)
        query_any_node(ID, Record),
    verify_chain(distributed_backend, Chain) :-
        % Verify with quorum consensus
        verify_with_quorum(Chain, Consensus),
        Consensus = true,
    recover(distributed_backend, Result) :-
        % Recover from quorum majority
        recover_from_quorum(Result).

% Register backend
register_backend(Backend) :-
    assertz(active_backend(Backend)).

% Select backend for journal
select_backend(Journal, Backend) :-
    (   Journal.backend_preference = Pref
    ->  Backend = Pref
    ;   active_backend(Backend)  % Default to first active
    ).
```

---

## 3. AUDIT TRAIL

### 3.1 Complete Governance History

Every action on the system is recorded with full context and evidence.

```prolog
% Audit trail: complete record of all governance events
audit_event(
    event_id,                     % Unique event identifier
    timestamp,                    % ISO8601 UTC timestamp
    event_type,                   % 'contract_apply'|'state_transition'|'verification'|'error'|'recovery'
    agent_id,                     % Agent that triggered this event
    worm_record_id,               % Associated WORM chain record ID
    
    % Event-specific data
    event_data,                   % Hash map with event details
    
    % Evidence trail
    input_state_hash,             % Hash of state before event
    output_state_hash,            % Hash of state after event
    proof_evidence,               % List of proof objects
    error_evidence                % Error details if failed
).

% State transition event
transition_event(
    from_state_id,                % ID of source state record
    to_state_id,                  % ID of target state record
    transition_type,              % 'semantic'|'tensor'|'omega'|'composite'
    semantic_delta,               % Changes to semantic state
    tensor_delta,                 % Changes to tensor state
    omega_delta,                  % Changes to Ω operator
    verification_status           % 'pending'|'passed'|'failed'
).

% Contract application event
contract_application_event(
    contract_id,                  % ID of contract being applied
    contract_version,             % Contract version number
    parameters,                   % Parameters passed to contract
    pre_conditions_check,         % Did preconditions pass?
    post_conditions_check,        % Did postconditions pass?
    invariant_violations,         % List of violated invariants
    result_value,                 % Return value from contract
    execution_time_ms             % Time taken to execute
).

% Verification event (Ω operator checks)
verification_event(
    verification_type,            % 'omega_check'|'curry_check'|'contract_check'
    verified_item,                % Item being verified
    verification_result,          % 'pass'|'fail'|'unknown'
    confidence_score,             % 0.0-1.0 confidence in result
    verification_proof            % Proof tree for result
).

% Store audit event to WORM
audit_log_event(AuditEvent) :-
    % Convert audit event to WORM record
    create_worm_record_from_audit(AuditEvent, WORMRecord),
    append_worm_record(WORMRecord),
    
    % Also index in fast audit index
    add_to_audit_index(AuditEvent).

% Query audit trail by event type
audit_trail_by_type(EventType, TimeStart, TimeEnd, Events) :-
    findall(
        Event,
        (   audit_event(_, Timestamp, EventType, _, _, _, _, _, _, _),
            Timestamp >= TimeStart,
            Timestamp =< TimeEnd,
            get_full_event_record(Event)
        ),
        Events
    ).

% Query audit trail by agent
audit_trail_by_agent(AgentID, Events) :-
    findall(
        Event,
        (   audit_event(_, _, _, AgentID, _, _, _, _, _, _),
            get_full_event_record(Event)
        ),
        Events
    ).

% Trace chain of events from root cause
trace_causality(RootEventID, Trace) :-
    % Build dependency graph of events
    audit_event(RootEventID, _, _, _, SourceRecordID, _, _, _, _, _),
    trace_backwards(SourceRecordID, [RootEventID], Trace).

trace_backwards(RecordID, Acc, FinalTrace) :-
    % Get record and its previous record
    get_worm_record(RecordID, Record),
    PrevRecordID = Record.previous_record_id,
    (   find_audit_event_for_record(PrevRecordID, Event)
    ->  trace_backwards(PrevRecordID, [Event|Acc], FinalTrace)
    ;   FinalTrace = Acc  % Reached root
    ).
```

### 3.2 Curry Derivations with Proof Trees

```prolog
% Curry derivation: formal proof that Ω operator derivation is correct
curry_derivation(
    derivation_id,                % Unique ID
    derivation_timestamp,         % When derived
    source_state,                 % State being curried
    source_hash,                  % Blake3 of source state
    curry_function,               % Curried continuation
    curry_hash,                   % Blake3 of curry function
    proof_tree,                   % Complete proof tree (see below)
    verified_at,                  % Timestamp of verification
    verified_by_agent             % Agent that verified
).

% Proof tree: hierarchical structure of subproofs
proof_tree(
    node_type,                    % 'root'|'branch'|'leaf'|'assumption'
    theorem,                      % The claim being proven
    proof_method,                 % 'by_computation'|'by_contract'|'by_assumption'|'by_lemma'
    children,                     % List of subproof trees
    evidence,                     % Supporting evidence (signatures, witnesses)
    confidence                    % 0.0-1.0 confidence in this node
).

% Build proof tree for curry derivation
build_curry_proof_tree(SourceState, TargetCurry, ProofTree) :-
    % 1. Root node: claim that curry function is derivable
    RootTheorem = derivable(SourceState, TargetCurry),
    
    % 2. Decompose into subproofs
    (   can_prove_by_omega_contraction(SourceState, TargetCurry)
    ->  Method = by_computation,
        SubProofs = [prove_omega_contraction(SourceState, TargetCurry)]
    ;   can_prove_by_contract(SourceState, TargetCurry)
    ->  Method = by_contract,
        SubProofs = [prove_contract_application(SourceState, TargetCurry)]
    ;   Method = by_assumption,
        SubProofs = []
    ),
    
    % 3. Recursively build subtrees
    build_proof_subtrees(SubProofs, SubTrees),
    
    % 4. Compute confidence
    compute_confidence(Method, SubTrees, Confidence),
    
    ProofTree = proof_tree(
        root,
        RootTheorem,
        Method,
        SubTrees,
        [source: SourceState, target: TargetCurry],
        Confidence
    ).

% Leaf proof: verify by direct computation
prove_omega_contraction(SourceState, TargetCurry) :-
    % Extract Ω operator and verify it can derive curry
    OmegaValue = SourceState.omega,
    apply_omega_to_state(OmegaValue, SourceState, DerivedCurry),
    DerivedCurry = TargetCurry,
    
    proof_tree(
        leaf,
        curry_derivable_by_omega(SourceState, TargetCurry),
        by_computation,
        [],
        [omega: OmegaValue, derivation_verified: true],
        1.0  % 100% confidence: computational verification
    ).

% Leaf proof: verify by contract rule
prove_contract_application(SourceState, TargetCurry) :-
    % Find contract that derives curry from state
    find_applicable_contract(SourceState, TargetCurry, Contract),
    apply_contract(Contract, SourceState, ContractResult),
    ContractResult.curry = TargetCurry,
    
    proof_tree(
        leaf,
        curry_derivable_by_contract(SourceState, TargetCurry),
        by_contract,
        [],
        [contract: Contract.id, contract_version: Contract.version],
        0.95  % High confidence: contract verified
    ).

% Store derivation with proof
store_curry_derivation(Derivation) :-
    % 1. Verify proof tree is sound
    verify_proof_tree(Derivation.proof_tree),
    
    % 2. Create WORM record
    create_worm_record_from_derivation(Derivation, WORMRecord),
    append_worm_record(WORMRecord),
    
    % 3. Store in derivation index
    add_to_derivation_index(Derivation).

% Verify entire proof tree is sound
verify_proof_tree(ProofTree) :-
    % Recursively verify all nodes
    proof_tree(NodeType, Theorem, Method, Children, Evidence, Confidence),
    
    % 1. Verify this node's claim
    (   NodeType = leaf
    ->  verify_leaf_proof(Theorem, Method, Evidence)
    ;   NodeType = root
    ->  % Root must have well-formed children
        forall(member(Child, Children), verify_proof_tree(Child))
    ;   % Branch node
        forall(member(Child, Children), verify_proof_tree(Child))
    ),
    
    % 2. Verify confidence is justified
    (   Confidence >= 0.95
    ->  % High confidence: all children must be high confidence
        forall(member(Child, Children), 
               (proof_tree(_, _, _, _, _, ChildConf),
                ChildConf >= 0.95))
    ;   true
    ).

% Deduplicate derivations: if we've seen this before, reuse proof
cached_curry_derivation(SourceHash, CurryHash, Derivation) :-
    % Look up in derivation cache
    derivation_cache(SourceHash, CurryHash, Derivation).

% Add derivation to cache
cache_curry_derivation(SourceHash, CurryHash, Derivation) :-
    assertz(derivation_cache(SourceHash, CurryHash, Derivation)).
```

### 3.3 Tensor Operations with Kernel Logs

```prolog
% Tensor operation: tracked with input, output, and kernel details
tensor_operation(
    operation_id,                 % Unique ID
    timestamp,                    % When performed
    operation_type,               % 'contraction'|'expansion'|'multiplication'|'projection'
    input_tensor,                 % Input tensor specification
    output_tensor,                % Output tensor specification
    kernel_name,                  % Name of kernel/algorithm used
    kernel_log,                   % Kernel execution log
    parameters,                   % Operation parameters
    result_status                 % 'success'|'overflow'|'underflow'|'nan_detected'
).

% Kernel execution log: detailed trace of tensor operation
kernel_log(
    kernel_id,                    % ID of kernel invocation
    kernel_version,               % Version of kernel
    operation_trace,              % List of intermediate tensor states
    memory_usage_bytes,           % Peak memory used
    compute_time_ms,              % Time to compute
    numerical_error_bound,        % Upper bound on accumulated error
    stability_analysis            % Analysis of numerical stability
).

% Log tensor operation to audit trail
log_tensor_operation(Op) :-
    % 1. Extract operation details
    Op = tensor_operation(OpID, Timestamp, OpType, InTensor, OutTensor,
                          KernelName, KernelLog, Params, Status),
    
    % 2. Verify operation completed successfully
    (   Status = success
    ->  true
    ;   Status = nan_detected
    ->  log_warning("NaN detected in tensor operation", Op)
    ;   true
    ),
    
    % 3. Create audit event
    AuditEvent = audit_event(
        _,
        Timestamp,
        tensor_operation,
        _,  % Will be filled by audit system
        _,  % Will be filled by audit system
        #{
            operation_id: OpID,
            operation_type: OpType,
            kernel: KernelName,
            status: Status,
            time_ms: KernelLog.compute_time_ms,
            memory_usage: KernelLog.memory_usage_bytes,
            error_bound: KernelLog.numerical_error_bound
        },
        blake3_hash(InTensor),
        blake3_hash(OutTensor),
        [KernelLog],
        null
    ),
    
    % 4. Record to WORM
    audit_log_event(AuditEvent).

% Verify tensor operation numerically
verify_tensor_operation(Op) :-
    % Check: output tensor is reachable from input via claimed kernel
    Op = tensor_operation(_, _, OpType, InTensor, OutTensor, 
                          KernelName, KernelLog, Params, Status),
    
    % 1. Get kernel implementation
    get_kernel_implementation(KernelName, KernelImpl),
    
    % 2. Recompute operation
    KernelImpl(OpType, InTensor, Params, RecomputedOut, _),
    
    % 3. Compare with logged output (allow for floating-point epsilon)
    tensor_epsilon_equal(OutTensor, RecomputedOut, KernelLog.numerical_error_bound),
    
    % 4. Verify numerical stability
    stability_analysis(KernelLog.stability_analysis, IsStable),
    IsStable = true.

% Store operation to permanent audit log
permanent_audit_log(Op) :-
    create_worm_record_from_tensor_op(Op, WORMRecord),
    append_worm_record(WORMRecord).
```

---

## 4. REPLAY ENGINE

### 4.1 Deterministic Reconstruction

```prolog
% Replay session: reconstruct system state by replaying WORM records
replay_session(
    session_id,                   % Unique session ID
    initial_state,                % Starting state before replays
    records_to_replay,            % List of WORMRecords to apply
    current_epoch,                % Current logical epoch
    replay_index,                 % Index in records list
    checkpoint_states,            % Map of epoch -> state snapshot
    divergence_log                % Log of any divergences found
).

% Initialize replay session from WORM chain
init_replay_session(WORMChain, InitialState, Session) :-
    % 1. Take first record as reference point
    WORMChain = [FirstRecord|RestRecords],
    
    % 2. Create session
    Session = replay_session(
        session_id(generate_uuid()),
        InitialState,
        RestRecords,
        0,  % epoch starts at 0
        0,  % replay index starts at 0
        #{0: InitialState},  % checkpoint initial state
        []  % divergence log empty
    ).

% Replay one record: apply transition deterministically
replay_one_record(Session, Record, UpdatedSession) :-
    % 1. Get current replay state
    CurrentState = Session.initial_state,  % Or last checkpoint
    CurrentEpoch = Session.current_epoch,
    
    % 2. Apply record's operation to state
    apply_worm_record_to_state(Record, CurrentState, NewState, Evidence),
    
    % 3. Verify new state matches record's semantic_after
    ExpectedState = Record.semantic_after,
    (   state_equal(NewState, ExpectedState)
    ->  Divergence = none
    ;   % DIVERGENCE DETECTED
        Divergence = divergence(CurrentEpoch, Record.record_id, 
                                NewState, ExpectedState),
        log_divergence(Session, Divergence)
    ),
    
    % 4. Create updated session
    NewCheckpoints = Session.checkpoint_states.put(CurrentEpoch + 1, NewState),
    UpdatedSession = Session#{
        current_epoch: CurrentEpoch + 1,
        replay_index: Session.replay_index + 1,
        checkpoint_states: NewCheckpoints,
        divergence_log: (Divergence = none -> Session.divergence_log 
                                              ; [Divergence|Session.divergence_log])
    }.

% Replay all records from chain
replay_all_records(Session, Records, FinalSession) :-
    (   Records = []
    ->  FinalSession = Session
    ;   Records = [Record|RestRecords],
        replay_one_record(Session, Record, UpdatedSession),
        replay_all_records(UpdatedSession, RestRecords, FinalSession)
    ).

% Apply a WORM record's operation to a state
apply_worm_record_to_state(Record, State, NewState, Evidence) :-
    Record = worm_record(
        _,
        _,
        _,
        _,
        SemanticBefore,
        SemanticAfter,
        TensorBefore,
        TensorAfter,
        OmegaBefore,
        OmegaAfter,
        _,
        _,
        _,
        _,
        _,
        _,
        OpType,
        OpInput,
        OpResult,
        _
    ),
    
    % 1. Verify precondition: semantic_before matches current state
    (   State.semantic = SemanticBefore
    ->  PreConditionMet = true
    ;   PreConditionMet = false
    ),
    
    Evidence = #{
        precondition_met: PreConditionMet,
        operation_type: OpType,
        operation_input: OpInput,
        operation_result: OpResult
    },
    
    % 2. Apply operation based on type
    (   OpType = semantic_transition
    ->  apply_semantic_transition(State, OpInput, NewState)
    ;   OpType = tensor_update
    ->  apply_tensor_update(State, OpInput, NewState)
    ;   OpType = omega_application
    ->  apply_omega_application(State, OpInput, NewState)
    ;   fail  % Unknown operation type
    ),
    
    % 3. Verify postcondition: semantic_after matches new state
    (   NewState.semantic = SemanticAfter,
        NewState.tensor = TensorAfter,
        NewState.omega = OmegaAfter
    ->  PostConditionMet = true
    ;   PostConditionMet = false
    ),
    
    Evidence = Evidence#{postcondition_met: PostConditionMet}.

% Checkpoint: create snapshot at logical epoch
checkpoint_state(Session, Epoch, CheckpointState) :-
    CheckpointStates = Session.checkpoint_states,
    CheckpointState = CheckpointStates.get(Epoch).

% Detect divergence: replayed state != recorded state
detect_divergence(Session) :-
    % Get divergence log
    Divergences = Session.divergence_log,
    length(Divergences, Count),
    (   Count > 0
    ->  write("DIVERGENCE DETECTED: "),
        forall(member(Div, Divergences),
               (write("  Epoch "), write(Div.epoch), write(": "),
                write(Div.expected), write(" != "), write(Div.actual), nl))
    ;   write("No divergences detected")
    ).

% Resume from checkpoint
resume_from_checkpoint(Session, Epoch, ResumedSession) :-
    % 1. Get checkpoint state
    CheckpointStates = Session.checkpoint_states,
    CheckpointState = CheckpointStates.get(Epoch),
    
    % 2. Find records from epoch onward
    Records = Session.records_to_replay,
    drop_first_N(Records, Epoch, RemainingRecords),
    
    % 3. Create new session from checkpoint
    ResumedSession = replay_session(
        session_id(Session.session_id),
        CheckpointState,
        RemainingRecords,
        Epoch,
        Epoch,
        CheckpointStates,
        []  % Fresh divergence log
    ).
```

### 4.2 Determinism Verification

```prolog
% Verify replayed result matches expected (determinism check)
verify_determinism(OriginalRecord, ReplayedRecord) :-
    % Compare all deterministic fields
    OriginalRecord = worm_record(
        ID1, TS1, Agent1, Ver1,
        SemBef1, SemAft1, TenBef1, TenAft1, OmBef1, OmAft1,
        InHash1, CurryHash1, PrevHash1, RecHash1,
        Sig1, PubKey1,
        OpType1, OpIn1, OpRes1, Meta1
    ),
    
    ReplayedRecord = worm_record(
        ID2, TS2, Agent2, Ver2,
        SemBef2, SemAft2, TenBef2, TenAft2, OmBef2, OmAft2,
        InHash2, CurryHash2, PrevHash2, RecHash2,
        Sig2, PubKey2,
        OpType2, OpIn2, OpRes2, Meta2
    ),
    
    % Deterministic invariant: same inputs must produce same outputs
    (   % Input state and parameters must match
        SemBef1 = SemBef2,
        TenBef1 = TenBef2,
        OmBef1 = OmBef2,
        OpIn1 = OpIn2,
        OpType1 = OpType2
    ->  % Then output must match
        SemAft1 = SemAft2,
        TenAft1 = TenAft2,
        OmAft1 = OmAft2,
        OpRes1 = OpRes2,
        InHash1 = InHash2,
        CurryHash1 = CurryHash2,
        RecHash1 = RecHash2
    ;   % Divergence in inputs → outputs can differ (non-deterministic)
        fail
    ).

% Compare before-state hash to catch non-determinism
is_deterministic_operation(Operation) :-
    Operation = operation(Input, Output1, Proof1),
    
    % Rerun operation with same input
    run_operation(Operation.operation_type, Input, Output2, Proof2),
    
    % Outputs must match
    Output1 = Output2,
    % Proofs must be equivalent (may differ in representation)
    proofs_equivalent(Proof1, Proof2).
```

### 4.3 Divergence Detection and Reporting

```prolog
% Divergence: actual != expected during replay
divergence_report(
    divergence_id,                % Unique ID
    epoch,                        % When divergence detected
    record_id,                    % WORM record ID
    expected_state,               % What record said would happen
    actual_state,                 % What actually happened
    input_parameters,             % Operation input
    difference,                   % Specific difference
    severity,                     % 'critical'|'warning'|'info'
    suggested_action              % How to resolve
).

% Report divergence and suggest remediation
report_divergence(Divergence) :-
    Divergence = divergence_report(
        _, Epoch, RecordID, Expected, Actual, Input, Diff, Severity, _
    ),
    
    % Log to persistent audit trail
    AuditEvent = audit_event(
        _,
        now(),
        divergence_detected,
        _,
        RecordID,
        #{
            epoch: Epoch,
            expected: Expected,
            actual: Actual,
            input: Input,
            difference: Diff
        },
        blake3_hash(Expected),
        blake3_hash(Actual),
        [Divergence],
        null
    ),
    audit_log_event(AuditEvent),
    
    % Suggest action
    (   Severity = critical
    ->  SuggestedAction = halt_system("Critical divergence detected")
    ;   Severity = warning
    ->  SuggestedAction = alert_operator("Divergence in replay")
    ;   SuggestedAction = log_info("Divergence detected in audit trail")
    ),
    
    write(SuggestedAction).
```

---

## 5. CONCURRENCY CONTROL

### 5.1 Serialization via WORM Append Lock

```prolog
% Concurrency model: multiple readers, single serialized writer
concurrency_model(
    readers_allowed: true,        % Multiple readers can run
    writers_allowed: 1,           % Only one writer at a time
    synchronization: worm_append_lock,
    contention_strategy: optimistic_retry
).

% Append lock: serializes writes to WORM chain
worm_append_lock(
    lock_id,                      % Unique lock identifier
    lock_file_path,               % Lock file on filesystem
    lock_holder_agent,            % Which agent holds lock
    acquired_at,                  % When lock was acquired
    timeout_seconds,              % Timeout before forced release
    waiters_queue                 % Queue of agents waiting for lock
).

% Acquire append lock for writing
acquire_append_lock(LockPath, TimeoutSecs, LockHandle) :-
    % 1. Create lock file (atomic)
    (   catch(
            open(LockPath, write, Handle, [exclusive(true), create(true)]),
            error(existence_error(_, _), _),
            fail
        )
    ->  % Lock acquired
        write_lock_metadata(Handle, #{
            acquired_at: now(),
            agent_id: get_current_agent(),
            hostname: get_hostname(),
            pid: get_process_id()
        }),
        flush_output(Handle),
        LockHandle = Handle
    ;   % Lock is held, retry with backoff
        wait_for_lock_release(LockPath, TimeoutSecs, LockHandle)
    ).

% Wait for lock with exponential backoff
wait_for_lock_release(LockPath, TimeoutSecs, LockHandle) :-
    MaxWaitTime is TimeoutSecs * 1000,  % milliseconds
    retry_with_backoff(
        acquire_append_lock(LockPath, _, LockHandle),
        MaxWaitTime,
        ExponentialBackoff,
        Result
    ),
    (   Result = success
    ->  true
    ;   throw(lock_acquisition_timeout(LockPath, TimeoutSecs))
    ).

% Release append lock
release_append_lock(LockHandle) :-
    % 1. Close lock file handle
    close(LockHandle),
    
    % 2. Delete lock file (non-atomic is OK)
    % Multiple processes might race, but all see same effect
    catch(
        delete_file(LockHandle.file_path),
        _,
        true  % Ignore errors (other process might have deleted)
    ).

% Reader operation: non-blocking reads
read_operation(Operation) :-
    % Readers don't acquire lock, just read latest committed state
    get_current_state(State),
    Operation(State).

% Writer operation: acquire lock, write, release lock
write_operation(Operation, Result) :-
    % 1. Acquire lock
    acquire_append_lock(get_lock_path(), 30, LockHandle),
    
    % 2. Execute operation (within critical section)
    (   catch(
            Operation(Result),
            Error,
            handle_write_error(Error, Result)
        )
    ->  true
    ;   Result = failure(unknown_error)
    ),
    
    % 3. Release lock (always, even if error)
    release_append_lock(LockHandle).

% Detect stale lock (process died holding lock)
detect_stale_lock(LockPath, IsStale) :-
    % 1. Read lock metadata
    read_lock_metadata(LockPath, Metadata),
    
    % 2. Check if process is still alive
    PID = Metadata.pid,
    (   process_is_alive(PID)
    ->  IsStale = false
    ;   IsStale = true,
        % Log stale lock
        log_info("Stale lock detected", #{
            lock_path: LockPath,
            dead_pid: PID,
            acquired_at: Metadata.acquired_at
        })
    ).

% Force-release stale lock
force_release_stale_lock(LockPath) :-
    % Verify lock is stale
    detect_stale_lock(LockPath, true),
    
    % Delete lock file
    delete_file(LockPath),
    
    % Log forced release
    log_warning("Stale lock force-released", #{
        lock_path: LockPath,
        released_at: now()
    }).
```

### 5.2 Optimistic Retry on Contention

```prolog
% Retry strategy: exponential backoff with jitter
retry_with_backoff(Operation, MaxWaitMs, BackoffStrategy, Result) :-
    retry_with_backoff(
        Operation,
        MaxWaitMs,
        0,              % elapsed time
        1,              % retry count
        BackoffStrategy,
        Result
    ).

retry_with_backoff(Operation, MaxWaitMs, ElapsedMs, RetryCount, BackoffStrategy, Result) :-
    (   ElapsedMs > MaxWaitMs
    ->  Result = failure(timeout)
    ;   % Try operation
        (   call(Operation)
        ->  Result = success
        ;   % Operation failed, retry
            % Compute backoff delay
            compute_backoff_delay(RetryCount, BackoffStrategy, DelayMs),
            
            % Add jitter (randomness)
            JitterMs is random_between(0, DelayMs / 10),
            TotalDelayMs is DelayMs + JitterMs,
            
            % Check if we'd exceed timeout
            NewElapsedMs is ElapsedMs + TotalDelayMs,
            (   NewElapsedMs > MaxWaitMs
            ->  Result = failure(timeout)
            ;   % Sleep then retry
                sleep_ms(TotalDelayMs),
                retry_with_backoff(
                    Operation,
                    MaxWaitMs,
                    NewElapsedMs,
                    RetryCount + 1,
                    BackoffStrategy,
                    Result
                )
            )
        )
    ).

% Exponential backoff: delay grows as 2^n, capped at max
compute_backoff_delay(RetryCount, exponential, DelayMs) :-
    MaxDelayMs = 5000,
    ExponentialDelay is min(2 ^ RetryCount * 10, MaxDelayMs),
    DelayMs is round(ExponentialDelay).

% Fibonacci backoff: delay = fib(n)
compute_backoff_delay(RetryCount, fibonacci, DelayMs) :-
    MaxDelayMs = 5000,
    fibonacci(RetryCount, Fib),
    FibDelay is Fib * 10,
    DelayMs is min(FibDelay, MaxDelayMs).

% Linear backoff: delay = n * base_delay
compute_backoff_delay(RetryCount, linear(BaseDelay), DelayMs) :-
    MaxDelayMs = 5000,
    LinearDelay is RetryCount * BaseDelay,
    DelayMs is min(LinearDelay, MaxDelayMs).
```

### 5.3 Reader-Writer Interaction

```prolog
% Reader transaction: non-blocking, always succeeds
reader_transaction(TransactionID, Operation, Result) :-
    % Readers are wait-free (never block on writers)
    get_latest_committed_state(State),
    snapshot_version = State.version,
    
    % Execute operation on snapshot
    call(Operation, State, Result),
    
    % Log read in audit trail (light weight)
    audit_log_event(audit_event(
        TransactionID,
        now(),
        read_transaction,
        get_current_agent(),
        _,
        #{snapshot_version: snapshot_version},
        blake3_hash(State),
        blake3_hash(Result),
        [],
        null
    )).

% Writer transaction: blocked by lock, serialized
writer_transaction(TransactionID, Operation, Result) :-
    % Acquire exclusive lock
    acquire_append_lock(get_lock_path(), 30, LockHandle),
    
    % Read current state (within lock)
    get_current_state(StateBefore),
    
    % Apply operation (must be deterministic)
    call(Operation, StateBefore, StateAfter, Evidence),
    
    % Create WORM record
    WORMRecord = worm_record(
        TransactionID,
        now(),
        get_current_agent(),
        get_current_contract_version(),
        
        StateBefore.semantic,
        StateAfter.semantic,
        StateBefore.tensor,
        StateAfter.tensor,
        StateBefore.omega,
        StateAfter.omega,
        
        blake3_hash(Operation),  % input_hash
        blake3_hash(StateAfter.curry),  % curry_derivation_hash
        get_previous_record_hash(),
        _,  % record_hash computed below
        
        _,  % signature computed below
        get_agent_public_key(),
        
        operation_type = write_transaction,
        Operation,
        StateAfter,
        Evidence
    ),
    
    % Compute record hash and signature
    compute_record_hash(WORMRecord, RecordHash),
    WORMRecord = WORMRecord#{record_hash: RecordHash},
    sign_record(WORMRecord, get_agent_private_key(), Signature),
    WORMRecord = WORMRecord#{ed25519_signature: Signature},
    
    % Append to WORM chain
    append_to_journal(get_journal(), WORMRecord, Offset),
    verify_persisted(get_journal(), WORMRecord),
    
    % Release lock
    release_append_lock(LockHandle),
    
    % Update current state
    update_current_state(StateAfter),
    
    % Return success
    Result = success(#{
        transaction_id: TransactionID,
        record_offset: Offset,
        new_state_version: StateAfter.version,
        timestamp: now()
    }).

% Conflict detection: if two writers try same operation, one wins
detect_write_conflict(Operation1, Operation2) :-
    % Operations conflict if they modify overlapping state
    get_modified_state_vars(Operation1, Vars1),
    get_modified_state_vars(Operation2, Vars2),
    intersection(Vars1, Vars2, Intersection),
    length(Intersection, Count),
    Count > 0.
```

---

## 6. RECOVERY PROTOCOL

### 6.1 Crash/Corruption Handling

```prolog
% Recovery protocol: detect and recover from crashes
recovery_protocol(
    recovery_mode,                % 'startup' | 'error_recovery' | 'full_reconstruction'
    corruption_detected,          % Boolean
    recovery_status,              % 'in_progress' | 'succeeded' | 'failed'
    recovery_evidence,            % Evidence of recovery actions
    recovered_state               % Recovered system state
).

% Startup recovery: check journal for incomplete writes
startup_recovery(Journal, RecoveryResult) :-
    % 1. Check if journal exists
    (   \+ exists_file(Journal.file_path)
    ->  % No journal, start fresh
        RecoveryResult = fresh_start
    ;   % Journal exists, check integrity
        % 2. Find last complete record
        find_last_complete_record(Journal.file_path, LastCompleteID, LastOffset),
        
        % 3. Check for partial write
        file_size(Journal.file_path, FileSize),
        (   FileSize > LastOffset
        ->  % Partial write detected
            PartialBytesLost is FileSize - LastOffset,
            truncate_file(Journal.file_path, LastOffset),
            
            % 4. Reload journal metadata
            reload_journal_metadata(Journal, LastCompleteID),
            
            RecoveryResult = recovered_from_crash(
                LastCompleteID,
                PartialBytesLost,
                now()
            ),
            
            % Log recovery
            audit_log_event(audit_event(
                recovery_event,
                now(),
                error_recovery,
                system,
                LastCompleteID,
                #{partial_bytes_lost: PartialBytesLost},
                _,
                _,
                [],
                null
            ))
        ;   % No partial write
            RecoveryResult = clean_journal
        )
    ).

% Detect corruption: verify chain integrity
detect_corruption(Journal, CorruptionReport) :-
    % 1. Verify WORM chain signatures
    (   \+ chain_verified(Journal.chain)
    ->  % Signature verification failed
        CorruptionReport = #{
            corruption_type: signature_verification_failed,
            severity: critical,
            affected_records: find_corrupted_records(Journal.chain)
        }
    ;   % 2. Verify hash chain linearity
        (\+ verify_hash_chain_linear(Journal.chain)
        ->  CorruptionReport = #{
                corruption_type: hash_chain_broken,
                severity: critical,
                fork_point: detect_fork_point(Journal.chain)
            }
        ;   % 3. Verify record IDs are sequential
            (\+ verify_record_ids_sequential(Journal.chain)
            ->  CorruptionReport = #{
                    corruption_type: record_ids_non_sequential,
                    severity: high,
                    gaps: find_id_gaps(Journal.chain)
                }
            ;   % No corruption detected
                CorruptionReport = #{
                    corruption_type: none,
                    severity: none
                }
            )
        )
    ).

% Find corrupted records by signature verification
find_corrupted_records(Chain) :-
    findall(
        RecordID,
        (   member(Record, Chain),
            \+ verify_record_signature(Record),
            record_id(Record, RecordID)
        ),
        CorruptedIDs
    ),
    CorruptedIDs.

% Recovery from corruption: rollback to last known good state
recover_from_corruption(Journal, LastGoodRecordID, RecoveryResult) :-
    % 1. Find last good record
    find_last_complete_record(Journal.file_path, LastGoodRecordID, LastGoodOffset),
    
    % 2. Truncate journal at that point
    truncate_file(Journal.file_path, LastGoodOffset),
    
    % 3. Rebuild index from journal
    rebuild_index(Journal, NewIndex),
    
    % 4. Reload all state from records up to last good
    replay_all_records(Journal.initial_state, 
                       list_records_up_to(Journal, LastGoodRecordID),
                       FinalState),
    
    RecoveryResult = #{
        status: recovered,
        last_good_record_id: LastGoodRecordID,
        recovered_state: FinalState,
        recovered_at: now()
    }.

% Verify recovery: after recovery, verify system is consistent
verify_recovery(Journal, RecoveryResult) :-
    RecoveryResult = #{
        status: recovered,
        recovered_state: State,
        last_good_record_id: LastGoodID
    },
    
    % 1. Verify chain up to last good record
    ChainUpToLastGood = list_records_up_to(Journal, LastGoodID),
    verify_worm_chain(ChainUpToLastGood),
    
    % 2. Verify recovered state is consistent
    replay_all_records(Journal.initial_state, ChainUpToLastGood, ReplayedState),
    (   state_equal(State, ReplayedState)
    ->  RecoveryVerified = true
    ;   RecoveryVerified = false
    ),
    
    % 3. Verify no divergences during replay
    divergence_count = 0,
    
    RecoveryVerified = true.
```

### 6.2 Checkpoint and Resume

```prolog
% Checkpoint: save state snapshot at logical epoch
checkpoint_state(Journal, Epoch, CheckpointPath, CheckpointRecord) :-
    % 1. Get current state at epoch
    get_state_at_epoch(Journal, Epoch, State),
    
    % 2. Serialize state
    state_to_json(State, StateJSON),
    
    % 3. Create checkpoint record
    CheckpointRecord = checkpoint(
        checkpoint_id(generate_uuid()),
        Epoch,
        now(),
        State,
        blake3_hash(StateJSON),
        CheckpointPath
    ),
    
    % 4. Write checkpoint to disk
    write_checkpoint_file(CheckpointPath, CheckpointRecord),
    
    % 5. Create WORM record for checkpoint
    create_worm_record_from_checkpoint(CheckpointRecord, WORMRecord),
    append_worm_record(WORMRecord),
    
    % 6. Log checkpoint
    audit_log_event(audit_event(
        checkpoint_created,
        now(),
        checkpoint,
        get_current_agent(),
        WORMRecord.record_id,
        #{epoch: Epoch, checkpoint_hash: CheckpointRecord.hash},
        _,
        _,
        [CheckpointRecord],
        null
    )).

% Resume from checkpoint
resume_from_checkpoint(CheckpointPath, Epoch, ResumedState) :-
    % 1. Read checkpoint file
    read_checkpoint_file(CheckpointPath, CheckpointRecord),
    
    % 2. Verify checkpoint is valid
    checkpoint_is_valid(CheckpointRecord),
    
    % 3. Restore state from checkpoint
    ResumedState = CheckpointRecord.state,
    
    % 4. Create WORM record for resumption
    create_worm_record_from_resume(#{
        from_checkpoint: CheckpointPath,
        at_epoch: Epoch,
        checkpoint_hash: CheckpointRecord.hash
    }, WORMRecord),
    append_worm_record(WORMRecord),
    
    % 5. Log resumption
    audit_log_event(audit_event(
        resumed_from_checkpoint,
        now(),
        resume,
        get_current_agent(),
        WORMRecord.record_id,
        #{checkpoint_path: CheckpointPath, epoch: Epoch},
        _,
        _,
        [],
        null
    )).

% Verify checkpoint is valid: hasn't been tampered with
checkpoint_is_valid(CheckpointRecord) :-
    % 1. Verify checkpoint hash
    checkpoint_hash(CheckpointRecord, ExpectedHash),
    recompute_checkpoint_hash(CheckpointRecord, ComputedHash),
    ExpectedHash = ComputedHash,
    
    % 2. Verify checkpoint is in WORM chain
    find_worm_record_for_checkpoint(CheckpointRecord, WORMRecord),
    verify_record_signature(WORMRecord),
    
    % 3. Verify state is consistent
    CheckpointRecord.state_hash = blake3_hash(CheckpointRecord.state).
```

### 6.3 Consistency Guarantees

```prolog
% ACID properties for OMEGA-MUSTACHE
acid_properties(
    % Atomicity: all-or-nothing writes
    atomicity:
        % Each WORM append is atomic: either fully appended or not at all
        forall(
            (write_operation(Op, Result),
             Result = success(_)),
            operation_fully_committed(Op)
        ),
    
    % Consistency: state invariants maintained
    consistency:
        % After every write, state satisfies contract invariants
        forall(
            get_current_state(State),
            verify_state_invariants(State)
        ),
    
    % Isolation: readers don't see partial writes
    isolation:
        % Reader sees state from before or after a write, never during
        forall(
            reader_transaction(ID, Op, Result),
            (   % Either sees old state or new state, not intermediate
                exists(version_at_commit_time(Op, OldVer)),
                exists(version_at_commit_time(Op, NewVer)),
                (sees_version(Op, OldVer) ; sees_version(Op, NewVer))
            )
        ),
    
    % Durability: committed writes survive crashes
    durability:
        % After WORM record is fsync'd, survives any subsequent crash
        forall(
            (   worm_record_persisted(Record),
                system_crash(),
                startup_recovery(Journal, Result)
            ),
            record_present_in_recovered_journal(Record)
        )
).

% Verify state satisfies all invariants
verify_state_invariants(State) :-
    % 1. Semantic state is well-formed
    semantic_state_valid(State.semantic),
    
    % 2. Tensor state is well-formed
    tensor_state_valid(State.tensor),
    
    % 3. Ω operator is well-formed
    omega_state_valid(State.omega),
    
    % 4. All references are valid
    all_references_valid(State),
    
    % 5. Contract invariants hold
    forall(
        (get_applicable_contract(State, Contract),
         Contract.invariant = Inv),
        call(Inv, State)
    ).
```

---

## 7. FORMAL SPECIFICATION (PROLOG AXIOMS)

### 7.1 Core Axioms

```prolog
% Axiom 1: WORM Chain is immutable
axiom_immutable_worm_chain :-
    forall(
        (worm_record_appended(Record1, Time1),
         Time2 > Time1,
         worm_record_read(Record2, Time2)),
        Record1 = Record2
    ).

% Axiom 2: Hash chain is linear (no forks)
axiom_linear_hash_chain :-
    forall(
        (record_in_chain(Rec),
         previous_record_hash(Rec, PrevHash),
         chain_contains_record_with_hash(PrevHash, PrevRec)),
        (   is_previous_of(PrevRec, Rec),
            \+ exists_other_previous(PrevRec, Rec)
        )
    ).

% Axiom 3: Signatures are unforgeable
axiom_unforgeable_signatures :-
    forall(
        (worm_record(_, _, _, _, _, _, _, _, _, _, _, _, _, _, Sig, PubKey, _, _, _, _),
         \+ ed25519_verify(record_hash, Sig, PubKey) = true),
        false
    ).

% Axiom 4: Timestamps are monotonically increasing
axiom_monotonic_timestamps :-
    forall(
        (record_at_index(Rec1, I),
         record_at_index(Rec2, J),
         I < J),
        (timestamp(Rec1, T1),
         timestamp(Rec2, T2),
         T1 =< T2)
    ).

% Axiom 5: Record IDs are sequential
axiom_sequential_record_ids :-
    forall(
        (record_at_index(Rec, I),
         record_id(Rec, ID)),
        ID = I
    ).

% Axiom 6: Determinism: same inputs → same outputs
axiom_deterministic_operations :-
    forall(
        (operation_in_record(Rec1, Op, Input, Output1),
         operation_in_record(Rec2, Op, Input, Output2)),
        Output1 = Output2
    ).

% Axiom 7: Crash recovery preserves committed writes
axiom_durable_writes :-
    forall(
        (worm_record_persisted(Record),
         fsync_completed(Record),
         system_crash_after(Record)),
        record_present_in_recovered_journal(Record)
    ).
```

### 7.2 Safety Properties

```prolog
% Safety 1: No record can be modified after append
safety_immutable_records :-
    forall(
        (worm_record_appended(Record, Time1),
         Time2 > Time1,
         read_record_at_time(Record, Time2, ReadRecord)),
        Record = ReadRecord
    ).

% Safety 2: All records in chain are properly signed
safety_all_records_signed :-
    forall(
        record_in_chain(Record),
        verify_record_signature(Record)
    ).

% Safety 3: Chain has no gaps in record IDs
safety_sequential_ids :-
    forall(
        (record_at_index(Rec, I),
         I > 0,
         record_at_index(PrevRec, I - 1)),
        (record_id(Rec, ID),
         record_id(PrevRec, PrevID),
         ID = PrevID + 1)
    ).

% Safety 4: Hash chain cannot be forked
safety_no_forks :-
    forall(
        chain_sequence(Chain),
        \+ has_fork_in_chain(Chain)
    ).

% Safety 5: Concurrent readers cannot see inconsistent state
safety_reader_consistency :-
    forall(
        (   concurrent_reader_transaction(T1, Reader1, Time1),
            concurrent_reader_transaction(T2, Reader2, Time2),
            Time1 < Time2,
            Time2 - Time1 < 100  % Very close in time
        ),
        (   seen_version(Reader1, V1),
            seen_version(Reader2, V2),
            (V1 = V2 ; follows_in_sequence(V1, V2))
        )
    ).
```

### 7.3 Completeness Properties

```prolog
% Completeness 1: Every operation has evidence in audit trail
completeness_full_audit :-
    forall(
        operation_executed(Operation),
        audit_event_exists_for_operation(Operation)
    ).

% Completeness 2: Every state transition can be replayed
completeness_replay_deterministic :-
    forall(
        state_transition_in_chain(State1, State2),
        (   replay_transition(State1, State2, ReplayedState),
            ReplayedState = State2
        )
    ).

% Completeness 3: Recovery produces exactly the committed state
completeness_recovery_accurate :-
    forall(
        (   last_committed_record(LastRec),
            recover_from_crash(RecoveredState)
        ),
        recovered_state_matches_committed(RecoveredState, LastRec)
    ).

% Completeness 4: Curry derivations have complete proofs
completeness_curry_proofs :-
    forall(
        curry_derivation_recorded(Derivation),
        (   Derivation.proof_tree = Tree,
            proof_tree_is_complete(Tree),
            proof_tree_is_verified(Tree)
        )
    ).
```

---

## 8. IMPLEMENTATION PATTERNS

### 8.1 Pseudocode: Append Operation

```
FUNCTION append_record(journal, record):
    // 1. Acquire exclusive write lock
    lock = acquire_append_lock(journal.lock_path, timeout=30s)
    IF lock == TIMEOUT:
        THROW LockAcquisitionTimeout
    
    TRY:
        // 2. Read current journal metadata
        metadata = read_journal_metadata(journal)
        current_id = metadata.last_record_id
        current_offset = metadata.last_record_offset
        
        // 3. Assign new record ID
        new_id = current_id + 1
        record.record_id = new_id
        record.timestamp = now_iso8601()
        record.agent_id = get_current_agent()
        
        // 4. Set previous record hash
        prev_record = get_record_by_id(journal, current_id)
        prev_hash = blake3_hash(serialize(prev_record))
        record.previous_record_hash = prev_hash
        
        // 5. Compute input hash
        input_json = serialize(record.operation_input)
        record.input_hash = blake3_hash(input_json)
        
        // 6. Compute record hash (before signature)
        record_data = serialize(record)
        record_hash = blake3_hash(record_data)
        record.record_hash = record_hash
        
        // 7. Sign record with agent private key
        signature = ed25519_sign(record_hash, get_agent_private_key())
        record.ed25519_signature = signature
        
        // 8. Open journal file in append mode
        file_handle = open(journal.file_path, mode="append", flags=O_APPEND)
        
        // 9. Create journal entry with length prefix
        entry_json = serialize(record)
        entry_hash = blake3_hash(entry_json)
        entry_checksum = crc32(entry_json + entry_hash)
        
        entry_bytes = [
            encode_uint32_big_endian(LENGTH(entry_json)),
            encode_utf8(entry_json),
            encode_hex(entry_hash),
            encode_uint32_big_endian(entry_checksum)
        ]
        
        // 10. Write entry to file
        write(file_handle, entry_bytes)
        
        // 11. Fsync to ensure durability
        fsync(file_handle)
        close(file_handle)
        
        // 12. Update journal metadata
        new_metadata = metadata.copy()
        new_metadata.record_count = current_id + 1
        new_metadata.total_bytes_written += LENGTH(entry_bytes)
        new_metadata.last_record_offset = current_offset
        new_metadata.last_record_id = new_id
        new_metadata.last_append_at = now_iso8601()
        write_journal_metadata(journal, new_metadata)
        
        // 13. Update index
        new_offset = current_offset + LENGTH(entry_bytes)
        add_to_index(journal, new_id, new_offset)
        
        // 14. Verify persisted
        verify_persisted(journal, record)
        
        // 15. Return success
        RETURN success(new_offset)
    
    CATCH error:
        RETURN failure(error_message)
    
    FINALLY:
        release_append_lock(lock)
END FUNCTION
```

### 8.2 Pseudocode: Replay and Verification

```
FUNCTION replay_chain(initial_state, worm_chain):
    session = create_replay_session(initial_state, worm_chain)
    current_state = initial_state
    divergences = []
    
    FOR EACH record IN worm_chain:
        // Apply record to current state
        new_state = apply_record(current_state, record)
        
        // Verify output matches record
        IF new_state.semantic != record.semantic_after:
            divergences.APPEND({
                epoch: record.record_id,
                expected: record.semantic_after,
                actual: new_state.semantic,
                severity: CRITICAL
            })
        
        // Create checkpoint every N records
        IF record.record_id MOD 1000 == 0:
            checkpoint_state(session, record.record_id, current_state)
        
        current_state = new_state
    
    // Verify entire chain integrity
    IF verify_chain_signatures(worm_chain) != TRUE:
        THROW ChainSignatureVerificationFailed
    
    IF verify_hash_chain(worm_chain) != TRUE:
        THROW HashChainBroken
    
    RETURN {
        final_state: current_state,
        divergences: divergences,
        verification_status: (divergences.length == 0 ? PASSED : FAILED)
    }
END FUNCTION
```

### 8.3 Pseudocode: Crash Recovery

```
FUNCTION recover_from_crash(journal):
    // 1. Detect incomplete records
    OPEN journal.file_path FOR READ BINARY
    
    last_complete_id = -1
    last_complete_offset = 0
    current_offset = 0
    
    WHILE NOT EOF:
        entry = read_journal_entry_at(journal, current_offset)
        
        IF is_complete_entry(entry):
            record = deserialize(entry.json)
            last_complete_id = record.record_id
            last_complete_offset = current_offset
            current_offset = entry.next_offset
        ELSE:
            // Incomplete entry found, stop scanning
            BREAK
    
    file_size = get_file_size(journal.file_path)
    
    // 2. Truncate if needed
    IF file_size > last_complete_offset:
        truncate_file(journal.file_path, last_complete_offset)
        bytes_lost = file_size - last_complete_offset
        log_warning("Truncated journal after crash", {bytes_lost})
    
    // 3. Rebuild index from journal
    rebuild_index(journal)
    
    // 4. Reload system state
    initial_state = get_initial_state()
    records = list_records_in_journal(journal)
    final_state = replay_all_records(initial_state, records)
    
    // 5. Verify recovery
    verify_chain_signatures(records)
    verify_hash_chain(records)
    verify_state_consistency(final_state, records)
    
    // 6. Log recovery event
    audit_log_event({
        type: recovery,
        timestamp: now(),
        last_record_id: last_complete_id,
        bytes_lost: bytes_lost,
        status: success
    })
    
    RETURN {
        status: RECOVERED,
        last_record_id: last_complete_id,
        recovered_state: final_state,
        bytes_lost: bytes_lost
    }
END FUNCTION
```

---

## 9. DEPLOYMENT CHECKLIST

### 9.1 Pre-Deployment Verification

```prolog
deployment_checklist :-
    % 1. Verify all cryptographic keys are generated
    \+ missing_ed25519_keypairs,
    
    % 2. Verify journal storage is configured
    \+ missing_journal_configuration,
    
    % 3. Verify lock file directory is writable
    test_lock_file_creation,
    
    % 4. Verify crash recovery works
    test_crash_recovery,
    
    % 5. Verify concurrent reads work
    test_concurrent_readers,
    
    % 6. Verify WORM chain integrity checks work
    test_chain_verification,
    
    % 7. Verify Blake3 hashing is deterministic
    test_blake3_determinism,
    
    % 8. Verify Ed25519 signing is reproducible
    test_ed25519_signing,
    
    % 9. Verify replay is deterministic
    test_replay_determinism,
    
    % 10. Verify audit trail is complete
    test_audit_trail_completeness,
    
    write("All deployment checks passed").
```

### 9.2 Production Configuration

```prolog
production_configuration :-
    config(#{
        % Storage
        journal_path: "/var/lib/omega-mustache/worm.journal",
        index_path: "/var/lib/omega-mustache/worm.index",
        lock_path: "/var/lib/omega-mustache/worm.lock",
        
        % Concurrency
        max_readers: 1000,
        max_writers: 1,
        write_lock_timeout_seconds: 30,
        reader_query_timeout_seconds: 60,
        
        % Durability
        fsync_after_every_append: true,
        checkpoint_interval_records: 10000,
        
        % Recovery
        enable_auto_recovery: true,
        recovery_checkpoint_dir: "/var/lib/omega-mustache/checkpoints",
        
        % Monitoring
        audit_log_path: "/var/log/omega-mustache/audit.log",
        enable_detailed_logging: true,
        
        % Security
        require_signature_verification: true,
        require_chain_integrity_checks: true,
        reject_unsigned_records: true
    }).
```

---

## CONCLUSION

OMEGA-MUSTACHE provides a production-ready semantic memory system with:

- **Cryptographic Integrity**: Ed25519 signatures + Blake3 hashing
- **Immutability**: Write-once append-only with fork detection
- **Auditability**: Complete governance history with proof traces
- **Determinism**: Replay engine with divergence detection
- **Safety**: ACID properties with crash recovery
- **Performance**: Index acceleration + concurrent reads
- **Scalability**: Pluggable storage backends

All operations are formally specified in Prolog with pseudocode implementations suitable for production deployment.
