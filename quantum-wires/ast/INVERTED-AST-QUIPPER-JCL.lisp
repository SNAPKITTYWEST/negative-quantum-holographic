;; SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
;; CLONE_GATE:AES256:d90d2153a3a4ccb625a6aceb83f0df2596df5b70f8219104101821b6c67f8c4a
;;
;; ============================================================================
;; INVERTED AST: QUIPPER CIRCUIT BINARY + JCL VAULT MANIFEST
;; Sections 0005-0006 (lines 788-1105+)
;; Converted to Lisp S-expression Boolean Tree with Validation Constraints
;; ============================================================================

;; SECTION 0005: QUIPPER CIRCUIT BINARY REPRESENTATION
;; ============================================================================

(defstructure QUIPPER-FILE
  "Root structure: Quipper artifact binary format (magic 0x51554950 'QUIP')"

  :magic #x51554950
  :version "1.0.0"
  :header-size 80  ;; 16 bytes standard + 64 bytes Quipper metadata

  :header (defstruct QUIPPER-HEADER
    :magic-bytes #(#x51 #x55 #x49 #x50)  ;; "QUIP"
    :standard-header-size 16
    :quipper-metadata-size 64

    ;; Header fields (bytes 16-79)
    :qubit-count-offset 16  :qubit-count-size 4  ;; Q
    :classical-bits-offset 20  :classical-bits-size 4  ;; C
    :circuit-gates-offset 24  :circuit-gates-size 4  ;; G
    :subroutines-offset 28  :subroutines-size 4  ;; S
    :wire-declarations-offset 32  :wire-declarations-size 4  ;; W

    :qubit-register-table-offset-offset 36
    :classical-register-table-offset-offset 40
    :gate-sequence-offset-offset 44
    :subroutine-table-offset-offset 48
    :wire-table-offset-offset 52
    :circuit-depth-offset 56
    :total-gate-count-offset 60
    :problem-description-offset 64  :problem-description-size 64

    ;; Validation: header checksum
    :requires-header-checksum-validation T
    :requires-payload-length-validation T)

  ;; String Table (8-byte aligned)
  :string-table (defstruct STRING-TABLE
    :alignment 8
    :contiguous-byte-array T
    :contains '(:register-names :subroutine-names :comment-texts))

  ;; Register Tables
  :qubit-register-table (defstruct QUBIT-REGISTER-TABLE
    :record-size 16  ;; bytes per record
    :record-structure (defstruct QUBIT-REGISTER-RECORD
      :register-index-offset 0  :register-index-size 4
      :register-name-offset-offset 4  :register-name-offset-size 4
      :register-name-length-offset 8  :register-name-length-size 4
      :qubit-count-in-register-offset 12  :qubit-count-in-register-size 4))

  :classical-register-table (defstruct CLASSICAL-REGISTER-TABLE
    :record-size 16
    :record-structure '(identical-to-qubit-register-table)
    :note "Identical structure to qubit register table")

  ;; Wire Table
  :wire-table (defstruct WIRE-TABLE
    :record-size 8  ;; bytes per record
    :record-structure (defstruct WIRE-RECORD
      :wire-index-offset 0  :wire-index-size 4
      :wire-type-offset 4  :wire-type-size 1
      :wire-type-enum {
        :0x01 "QUANTUM"
        :0x02 "CLASSICAL"}
      :wire-direction-offset 5  :wire-direction-size 1
      :wire-direction-enum {
        :0x01 "INPUT"
        :0x02 "OUTPUT"
        :0x03 "INTERNAL"}
      :register-index-owner-offset 6  :register-index-owner-size 2)

    :invariants (list
      (implies wire-type :constraint "wire-type IN {0x01, 0x02}")
      (implies wire-direction :constraint "wire-direction IN {0x01, 0x02, 0x03}")
      (implies register-index-owner :constraint "register-index-owner IN [0, Q-1] OR [0, C-1]")))

  ;; Gate Enumeration
  :gate-type-enumeration (defstruct GATE-TYPES
    :record-size 32  ;; bytes per gate record
    :enumeration {
      :0x01 "GATE_H"
      :0x02 "GATE_X"
      :0x03 "GATE_Y"
      :0x04 "GATE_Z"
      :0x05 "GATE_S"
      :0x06 "GATE_T"
      :0x07 "GATE_S_DAG"
      :0x08 "GATE_T_DAG"
      :0x09 "GATE_CNOT"
      :0x0A "GATE_CZ"
      :0x0B "GATE_SWAP"
      :0x0C "GATE_TOFFOLI"
      :0x0D "GATE_FREDKIN"
      :0x0E "GATE_MEASURE"
      :0x0F "GATE_RESET"
      :0x10 "GATE_INIT"
      :0x11 "GATE_RZ"
      :0x12 "GATE_RX"
      :0x13 "GATE_RY"
      :0x14 "GATE_PHASE"
      :0x15 "GATE_U1"
      :0x16 "GATE_U2"
      :0x17 "GATE_U3"
      :0x18 "GATE_CUSTOM"
      :0x19 "GATE_SUBROUTINE_CALL"
      :0x1A "GATE_COMMENT"
      :0x1B "GATE_BARRIER"
      :0x1C "GATE_CLASSICAL_NOT"
      :0x1D "GATE_CLASSICAL_AND"
      :0x1E "GATE_CLASSICAL_OR"
      :0x1F "GATE_CLASSICAL_XOR"
      :0x20 "GATE_CLASSICAL_COPY"}

    :single-qubit-gates '(:0x01 :0x02 :0x03 :0x04 :0x05 :0x06 :0x07 :0x08)
    :two-qubit-gates '(:0x09 :0x0A :0x0B)
    :three-qubit-gates '(:0x0C :0x0D)
    :measurement-gates '(:0x0E)
    :reset-gates '(:0x0F)
    :init-gates '(:0x10)
    :rotation-gates '(:0x11 :0x12 :0x13 :0x14 :0x15 :0x16 :0x17)
    :custom-gates '(:0x18)
    :control-flow-gates '(:0x19)
    :meta-gates '(:0x1A :0x1B)
    :classical-gates '(:0x1C :0x1D :0x1E :0x1F :0x20))

  ;; Gate Sequence
  :gate-sequence (defstruct GATE-SEQUENCE
    :record-size 32
    :record-structure (defstruct GATE-RECORD
      :gate-index-offset 0  :gate-index-size 4  ;; 0-based, monotonic
      :gate-type-offset 4  :gate-type-size 4
      :target-qubit-count-offset 8  :target-qubit-count-size 4
      :target-qubit-list-offset 12  :target-qubit-list-size 4
      :control-qubit-count-offset 16  :control-qubit-count-size 4
      :control-qubit-list-offset 20  :control-qubit-list-size 4
      :classical-bits-count-offset 24  :classical-bits-count-size 4
      :classical-bits-list-offset 28  :classical-bits-list-size 4)

    :qubit-index-range (implies (qubit-index) (and (>= qubit-index 0) (< qubit-index Q)))
    :classical-bit-index-range (implies (classical-bit-index) (and (>= classical-bit-index 0) (< classical-bit-index C)))

    :constraints (list
      (rule "MEASUREMENT_GATE"
        :antecedent (== gate-type :0x0E)
        :consequent (and (>= target-qubit-count 1) (>= classical-bits-count 1)))

      (rule "MEASUREMENT_MAPPING"
        :antecedent (== gate-type :0x0E)
        :consequent "one-to-one mapping: target_qubit[i] -> classical_bit[i]")

      (rule "RESET_GATE"
        :antecedent (== gate-type :0x0F)
        :consequent (and (>= target-qubit-count 1) (== classical-bits-count 0)))

      (rule "BARRIER_GATE"
        :antecedent (== gate-type :0x1B)
        :consequent (and (== target-qubit-count 0) (== control-qubit-count 0)))

      (rule "COMMENT_GATE"
        :antecedent (== gate-type :0x1A)
        :consequent (and (== target-qubit-count 0) (== classical-bits-count 0)))

      (rule "ROTATION_GATE_PARAMETERS"
        :antecedent (member gate-type '(:0x11 :0x12 :0x13 :0x14 :0x15))
        :consequent "angle parameter follows: IEEE 754 binary64")

      (rule "U2_U3_PARAMETERS"
        :antecedent (member gate-type '(:0x16 :0x17))
        :consequent "multiple angles follow: phi, lambda, theta (IEEE 754 binary64 each)")

      (rule "CUSTOM_UNITARY"
        :antecedent (== gate-type :0x18)
        :consequent (list
          "unitary matrix: 2^k x 2^k where k = target-qubit-count"
          "stored as complex numbers: (real, imaginary) pairs"
          "row-major order"
          "validated: unitarity within 1e-10 tolerance"))

      (rule "GLOBAL_OPERATION"
        :antecedent (and (== target-qubit-count 0) (== control-qubit-count 0))
        :consequent "gate is global operation or annotation"))))

  ;; Subroutine Signature & Validation
  :subroutine-table (defstruct SUBROUTINE-TABLE
    :record-size 32
    :record-structure (defstruct SUBROUTINE-RECORD
      :subroutine-index-offset 0  :subroutine-index-size 4
      :subroutine-name-offset-offset 4  :subroutine-name-offset-size 4
      :subroutine-name-length-offset 8  :subroutine-name-length-size 4
      :input-qubits-offset 12  :input-qubits-size 4
      :output-qubits-offset 16  :output-qubits-size 4
      :input-classical-bits-offset 20  :input-classical-bits-size 4
      :output-classical-bits-offset 24  :output-classical-bits-size 4
      :subroutine-body-gate-sequence-offset-offset 28  :subroutine-body-gate-sequence-offset-size 4)

    :subroutine-signature (defstruct SIGNATURE
      :input-qubits-formal-params [int]
      :output-qubits-formal-params [int]
      :input-classical-bits-formal-params [int]
      :output-classical-bits-formal-params [int])

    :subroutine-body "nested gate sequence with local wire numbering"

    :validation-constraints (list
      (rule "SUBROUTINE_CALL_ARITY"
        :invariant "actual-parameters-count == formal-parameters-count")

      (rule "SUBROUTINE_CALL_TYPE_MATCH"
        :invariant "type(actual-param[i]) == type(formal-param[i]) for quantum/classical")

      (rule "NO_RECURSION"
        :invariant "call graph must be acyclic"
        :method "cyclic call graph check triggers validation failure")))

  ;; Complexity Metrics
  :circuit-metrics (defstruct METRICS
    :circuit-width "Q (number of qubits)"
    :circuit-depth "longest path from input to output in gate dependency DAG"
    :circuit-volume "Q * depth"
    :total-gate-count "sum of gates in main sequence + all subroutine bodies"
    :gate-dependency-graph "DAG where edges represent wire data dependencies"
    :parallel-gates-invariant "gates on disjoint qubit sets can execute in parallel"
    :depth-computation-algorithm "topological sort of dependency DAG"
    :depth-computation-complexity "O(G + E) where E = number of dependency edges")

  ;; Oracle Descriptor
  :oracle-descriptor-table (defstruct ORACLE-TABLE
    :record-size 32
    :record-structure (defstruct ORACLE-RECORD
      :oracle-index-offset 0  :oracle-index-size 4
      :input-qubits-offset 4  :input-qubits-size 4
      :output-qubits-offset 8  :output-qubits-size 4
      :oracle-name-offset 12  :oracle-name-size 20)
    :definition "black-box unitary whose internal structure is not specified")

  ;; Error Handling
  :error-code-table (defstruct ERROR-CODE-TABLE
    :magic #x45525254  ;; "ERRT"
    :record-count 256
    :record-size 32
    :record-structure (defstruct ERROR-RECORD
      :error-code-offset 0  :error-code-size 4
      :error-description-offset 4  :error-description-size 28)  ;; ASCII, space-padded
    :error-codes {
      :0x00000001 "unsupported type"
      :0x00000002 "unsupported control flow"
      :...  "up to 256 codes"})

  ;; Payload Structure & Alignment
  :payload-structure (list
    "header (80 bytes)"
    "string table"
    "qubit register table"
    "classical register table"
    "wire table"
    "gate sequence"
    "subroutine table"
    "oracle descriptor table")

  :alignment-rule "each section 8-byte boundary, zero-padded"

  ;; Validation Constraints (Boolean Tree)
  :validation-rules (defstruct VALIDATION-TREE
    :root (and
      (rule "MAGIC_CHECK" (== magic #x51554950))
      (rule "VERSION_CHECK" (== version "1.0.0"))
      (rule "HEADER_CHECKSUM" T)
      (rule "PAYLOAD_LENGTH" T)
      (rule "QUBIT_INDICES_RANGE" (forall (q qubits) (and (>= q 0) (< q Q))))
      (rule "CLASSICAL_BIT_INDICES_RANGE" (forall (c classical-bits) (and (>= c 0) (< c C))))
      (rule "GATE_TYPES_VALID" (forall (g gates) (member (type g) (range #x01 #x20))))
      (rule "MEASUREMENT_GATE_CONSTRAINTS" T)
      (rule "UNITARY_MATRIX_VALIDATION" (forall (m unitary-matrices) (<= (unitarity-error m) 1e-10)))
      (rule "SUBROUTINE_SIGNATURE_MATCH" T)
      (rule "CALL_GRAPH_ACYCLIC" T)
      (rule "WIRE_CONSISTENCY" T)
      (rule "NO_DANGLING_WIRES"
        :note "Dangling wires reported as warnings but do NOT fail validation")
      (rule "DETERMINISTIC_GENERATION"
        :constraint "identical PTM-IR produces identical Quipper bytes"
        :seed-value 0
        :no-randomness T)))

  ;; Reproducibility & Audit
  :reproducibility (defstruct REPRODUCIBILITY
    :deterministic T
    :seed 0  ;; fixed seed for any pseudo-random values
    :hash-algorithm "SHA-256"
    :hash-computed-over "complete Quipper artifact file"
    :audit-manifest-entry T)

  ;; Security Properties
  :security-properties (list
    "does not access files outside vault boundary"
    "does not execute arbitrary commands"
    "does not request or emit credentials"
    "does not claim quantum supremacy without proof"
    "PTM-IR treated as untrusted input"))


;; SECTION 0006: JCL VAULT MANIFEST BINARY FORMAT
;; ============================================================================

(defstructure JCL-VAULT-MANIFEST
  "Root structure: JCL Vault Manifest for sandboxed batch execution (magic 0x4A434C4D 'JCLM')"

  :magic #x4A434C4D
  :header-size 144  ;; 16 bytes standard + 128 bytes JCL metadata

  :header (defstruct JCL-HEADER
    :magic-bytes #(#x4A #x43 #x4C #x4D)  ;; "JCLM"
    :standard-header-size 16
    :jcl-metadata-size 128

    ;; Header fields (bytes 16-143)
    :manifest-version-offset 16  :manifest-version-size 4  ;; 0x00000001

    ;; Counts
    :job-steps-offset 20  :job-steps-size 4  ;; J
    :datasets-offset 24  :datasets-size 4  ;; D
    :environment-variables-offset 28  :environment-variables-size 4  ;; E
    :resource-limits-offset 32  :resource-limits-size 4  ;; R
    :security-policies-offset 36  :security-policies-size 4  ;; P

    ;; Table Offsets
    :job-step-table-offset-offset 40
    :dataset-table-offset-offset 44
    :environment-table-offset-offset 48
    :resource-limit-table-offset-offset 52
    :security-policy-table-offset-offset 56

    ;; Vault Configuration
    :vault-root-path-offset-offset 60
    :vault-root-path-length-offset 64
    :execution-user-id-offset 68
    :execution-group-id-offset 72
    :umask-value-offset 76  :umask-default #x0000007F

    ;; Resource Limits
    :max-file-descriptor-count-offset 80
    :max-memory-limit-offset 84
    :max-cpu-time-limit-offset 88
    :max-wall-clock-time-limit-offset 92
    :max-process-count-offset 96
    :max-open-file-count-offset 100
    :max-stack-size-offset 104
    :max-data-segment-size-offset 108
    :max-core-file-size-offset 112
    :max-resident-set-size-offset 116
    :max-message-queue-size-offset 120
    :max-semaphore-count-offset 124
    :max-shared-memory-size-offset 128
    :max-signal-count-offset 132
    :max-timer-count-offset 136
    :job-priority-offset 140  :job-priority-range [0 99])

  ;; Job Step Table
  :job-step-table (defstruct JOB-STEP-TABLE
    :record-size 64
    :record-structure (defstruct JOB-STEP-RECORD
      :step-index-offset 0  :step-index-size 4
      :step-name-offset-offset 4  :step-name-offset-size 4
      :step-name-length-offset 8  :step-name-length-size 4
      :program-name-offset-offset 12  :program-name-offset-size 4
      :program-name-length-offset 16  :program-name-length-size 4
      :input-datasets-count-offset 20  :input-datasets-count-size 4
      :input-dataset-list-offset 24  :input-dataset-list-size 4
      :output-datasets-count-offset 28  :output-datasets-count-size 4
      :output-dataset-list-offset 32  :output-dataset-list-size 4
      :success-condition-code-offset 36  :success-condition-code-size 4  :default 0
      :failure-condition-code-offset 40  :failure-condition-code-size 4  :default 8
      :dependency-mask-offset 44  :dependency-mask-size 4
      :timeout-offset 48  :timeout-size 4  :unit "seconds" :zero-means "no timeout"
      :memory-limit-offset 52  :memory-limit-size 4  :unit "bytes" :zero-means "inherited"
      :cpu-limit-offset 56  :cpu-limit-size 4  :unit "seconds" :zero-means "inherited"
      :step-flags-offset 60  :step-flags-size 4)

    :dependency-mask-fields (defstruct DEPENDENCY-MASK
      :bit-31 "previous-step-dependency: 1 depends, 0 independent"
      :bit-30 "parallel-execution-allowed: 1 yes, 0 no"
      :bits-29-0 "reserved: must be zero"
      :invariant (and
        (rule "DEPENDENCY_BIT_SEMANTICS" (or (== bit-31 0) (== bit-31 1)))
        (rule "PARALLEL_BIT_SEMANTICS" (or (== bit-30 0) (== bit-30 1)))
        (rule "RESERVED_BITS_ZERO" (== (bits-29-0) 0))))

    :step-flags-fields (defstruct STEP-FLAGS
      :bit-31 "critical: 1 critical (abort on failure), 0 optional (log only)"
      :bit-30 "network-access: 1 allowed, 0 denied (default denied)"
      :bit-29 "fs-escape: 1 allowed outside vault, 0 denied (default denied)"
      :bit-28 "subprocess: 1 allowed, 0 denied (default denied)"
      :bit-27 "self-modify: 1 allowed, 0 denied (default denied)"
      :bits-26-0 "reserved: must be zero"
      :invariants (list
        (rule "CRITICAL_BIT" (implies (== bit-31 1) "fail entire job"))
        (rule "OPTIONAL_BIT" (implies (== bit-31 0) "log failure, continue"))
        (rule "NETWORK_BIT" (implies (== bit-30 1) "explicit permission required"))
        (rule "FS_ESCAPE_BIT" (implies (== bit-29 1) "explicit permission required"))
        (rule "SUBPROCESS_BIT" (implies (== bit-28 1) "explicit permission required"))
        (rule "SELF_MODIFY_BIT" (implies (== bit-27 1) "explicit permission required"))
        (rule "RESERVED_BITS_ZERO" (== (bits-26-0) 0)))))

  ;; Dataset Table
  :dataset-table (defstruct DATASET-TABLE
    :record-size 48
    :record-structure (defstruct DATASET-RECORD
      :dataset-index-offset 0  :dataset-index-size 4
      :dataset-name-offset-offset 4  :dataset-name-offset-size 4
      :dataset-name-length-offset 8  :dataset-name-length-size 4
      :dataset-path-offset-offset 12  :dataset-path-offset-size 4
      :dataset-path-length-offset 16  :dataset-path-length-size 4
      :dataset-type-offset 20  :dataset-type-size 4
      :dataset-size-offset 24  :dataset-size-size 4  :zero-means "unknown or variable"
      :block-size-offset 28  :block-size-size 4  :default 4096
      :record-length-offset 32  :record-length-size 4  :zero-means "unstructured"
      :record-format-offset 36  :record-format-size 4
      :organization-offset 40  :organization-size 4
      :dataset-flags-offset 44  :dataset-flags-size 4)

    :dataset-type-enum {
      :0x01 "DS_INPUT (read-only source)"
      :0x02 "DS_OUTPUT (write-only result)"
      :0x03 "DS_TEMP (read-write temporary)"
      :0x04 "DS_WORK (read-write workspace)"
      :0x05 "DS_AUDIT (append-only audit log)"
      :0x06 "DS_CONFIG (read-only configuration)"
      :0x07 "DS_LOG (append-only diagnostic log)"
      :0x08 "DS_MANIFEST (read-only manifest reference)"}

    :record-format-enum {
      :0x01 "REC_FIXED (fixed-length records)"
      :0x02 "REC_VARIABLE (variable-length records)"
      :0x03 "REC_UNDEFINED (unstructured byte stream)"
      :0x04 "REC_BLOCKED (blocked fixed records)"}

    :organization-enum {
      :0x01 "ORG_SEQUENTIAL"
      :0x02 "ORG_INDEXED"
      :0x03 "ORG_RELATIVE"
      :0x04 "ORG_DIRECT"}

    :dataset-flags-fields (defstruct DATASET-FLAGS
      :bit-31 "encrypted: 1 yes, 0 plaintext"
      :bit-30 "compressed: 1 yes, 0 raw"
      :bit-29 "append-only: 1 yes, 0 overwrite-allowed"
      :bit-28 "shared: 1 yes, 0 exclusive"
      :bits-27-0 "reserved: must be zero"
      :invariants (list
        (rule "ENCRYPTION_FLAG" (implies (== bit-31 1) "dataset encrypted"))
        (rule "COMPRESSION_FLAG" (implies (== bit-30 1) "dataset compressed"))
        (rule "APPEND_ONLY_FLAG" (implies (== bit-29 1) "append-only mode"))
        (rule "SHARED_FLAG" (implies (== bit-28 1) "shared across steps"))
        (rule "RESERVED_BITS_ZERO" (== (bits-27-0) 0)))))

  ;; Environment Variables Table
  :environment-table (defstruct ENVIRONMENT-TABLE
    :record-size 32
    :record-structure (defstruct ENVIRONMENT-RECORD
      :variable-index-offset 0  :variable-index-size 4
      :variable-name-offset-offset 4  :variable-name-offset-size 4
      :variable-name-length-offset 8  :variable-name-length-size 4
      :variable-value-offset-offset 12  :variable-value-offset-size 4
      :variable-value-length-offset 16  :variable-value-length-size 4
      :variable-flags-offset 20  :variable-flags-size 4)

    :variable-flags-fields (defstruct VARIABLE-FLAGS
      :bit-31 "exported: 1 exported to subprocesses, 0 local"
      :bit-30 "read-only: 1 immutable, 0 mutable"
      :bit-29 "secret: 1 contains secret, 0 public"
      :bits-28-0 "reserved: must be zero"
      :invariants (list
        (rule "SECRET_VARIABLE_MASKED" (implies (== bit-29 1) "masked in audit logs"))
        (rule "SECRET_VARIABLE_NO_DIAG_LOG" (implies (== bit-29 1) "not in diagnostic logs"))
        (rule "SECRET_VARIABLE_NO_SUBPROCESS" (implies (== bit-29 1) "not passed to subprocesses"))
        (rule "EXPORTED_VARIABLE" (implies (== bit-31 1) "exported to env"))
        (rule "READ_ONLY_VARIABLE" (implies (== bit-30 1) "immutable"))
        (rule "RESERVED_BITS_ZERO" (== (bits-28-0) 0)))))

  ;; Resource Limit Table
  :resource-limit-table (defstruct RESOURCE-LIMIT-TABLE
    :record-size 16
    :record-structure (defstruct RESOURCE-LIMIT-RECORD
      :resource-type-offset 0  :resource-type-size 4
      :soft-limit-offset 4  :soft-limit-size 4
      :hard-limit-offset 8  :hard-limit-size 4
      :limit-flags-offset 12  :limit-flags-size 4)

    :resource-type-enum {
      :0x01 "RES_CPU_TIME"
      :0x02 "RES_MEMORY"
      :0x03 "RES_FILE_SIZE"
      :0x04 "RES_STACK_SIZE"
      :0x05 "RES_DATA_SIZE"
      :0x06 "RES_CORE_SIZE"
      :0x07 "RES_NPROC"
      :0x08 "RES_NOFILE"
      :0x09 "RES_MSGQUEUE"
      :0x0A "RES_NICE"
      :0x0B "RES_RTPRIO"
      :0x0C "RES_RTTIME"
      :0x0D "RES_SIGPENDING"
      :0x0E "RES_MEMLOCK"
      :0x0F "RES_AS"
      :0x10 "RES_LOCKS"}

    :limit-flags-fields (defstruct LIMIT-FLAGS
      :bit-31 "enforced: 1 hard limit (terminate on exceed), 0 advisory (warn on exceed)"
      :bits-30-0 "reserved: must be zero"
      :invariants (list
        (rule "ENFORCED_LIMIT" (implies (== bit-31 1) "terminate signal when exceeded"))
        (rule "ADVISORY_LIMIT" (implies (== bit-31 0) "warning log when exceeded"))
        (rule "RESERVED_BITS_ZERO" (== (bits-30-0) 0)))))

  ;; Security Policy Table
  :security-policy-table (defstruct SECURITY-POLICY-TABLE
    :record-size 32
    :record-structure (defstruct SECURITY-POLICY-RECORD
      :policy-index-offset 0  :policy-index-size 4
      :policy-type-offset 4  :policy-type-size 4
      :policy-parameters-offset 8  :policy-parameters-size 24)

    :policy-type-enum {
      :0x01 "POLICY_NO_EXEC (prohibit execution of arbitrary commands)"
      :0x02 "POLICY_NO_NETWORK (prohibit network access)"
      :0x03 "POLICY_NO_FS_ESCAPE (prohibit file system access outside vault)"
      :0x04 "POLICY_NO_CREDENTIALS (prohibit credential inference or emission)"
      :0x05 "POLICY_NO_SUBPROCESS (prohibit subprocess creation)"
      :0x06 "POLICY_NO_SELF_MODIFY (prohibit self-modification)"
      :0x07 "POLICY_NO_SETUID (prohibit setuid/setgid operations)"
      :0x08 "POLICY_NO_PTRACE (prohibit ptrace and debugging)"
      :0x09 "POLICY_NO_MOUNT (prohibit mount/unmount operations)"
      :0x0A "POLICY_NO_CHROOT (prohibit chroot operations)"
      :0x0B "POLICY_NO_SIGNAL (prohibit signal sending to external processes)"
      :0x0C "POLICY_NO_SHARED_MEM (prohibit shared memory outside vault)"}

    :default-security-posture "deny-by-default"
    :note "explicit permission required for each capability")

  ;; JCL Validation Constraints (Boolean Tree)
  :validation-rules (defstruct JCL-VALIDATION-TREE
    :root (and
      (rule "MAGIC_CHECK" (== magic #x4A434C4D))
      (rule "VERSION_CHECK" (== manifest-version #x00000001))
      (rule "JOB_STEP_TABLE_VALID" (forall (step job-steps)
        (and
          (rule "STEP_INDEX_MONOTONIC" (> step-index 0))
          (rule "PROGRAM_NAME_EXISTS" (not (empty? program-name)))
          (rule "DATASETS_VALID" (and
            (forall (ds input-datasets) (member ds dataset-table))
            (forall (ds output-datasets) (member ds dataset-table))))
          (rule "CONDITION_CODES_VALID" (and
            (>= success-condition-code 0)
            (>= failure-condition-code 0)))
          (rule "TIMEOUT_VALID" (or (== timeout 0) (> timeout 0)))
          (rule "MEMORY_LIMIT_VALID" (or (== memory-limit 0) (> memory-limit 0)))
          (rule "CPU_LIMIT_VALID" (or (== cpu-limit 0) (> cpu-limit 0))))))

      (rule "DATASET_TABLE_VALID" (forall (ds datasets)
        (and
          (rule "DATASET_TYPE_VALID" (member dataset-type (range #x01 #x08)))
          (rule "RECORD_FORMAT_VALID" (member record-format (range #x01 #x04)))
          (rule "ORGANIZATION_VALID" (member organization (range #x01 #x04)))
          (rule "READ_ONLY_INPUT" (implies (== dataset-type #x01) "read-only"))
          (rule "WRITE_ONLY_OUTPUT" (implies (== dataset-type #x02) "write-only"))
          (rule "APPEND_ONLY_AUDIT" (implies (== dataset-type #x05) "append-only"))
          (rule "APPEND_ONLY_LOG" (implies (== dataset-type #x07) "append-only")))))

      (rule "ENVIRONMENT_TABLE_VALID" (forall (var environment-variables)
        (and
          (rule "VARIABLE_NAME_EXISTS" (not (empty? variable-name)))
          (rule "SECRET_VARIABLE_CONSTRAINTS" (implies (== secret-bit 1) (and
            (rule "SECRET_MASKED_IN_AUDIT" T)
            (rule "SECRET_NOT_IN_DIAG_LOG" T)
            (rule "SECRET_NOT_PASSED_TO_SUBPROCESSES" T)))))))

      (rule "RESOURCE_LIMIT_TABLE_VALID" (forall (res resource-limits)
        (and
          (rule "RESOURCE_TYPE_VALID" (member resource-type (range #x01 #x10)))
          (rule "SOFT_LIMIT_LE_HARD_LIMIT" (<= soft-limit hard-limit)))))

      (rule "SECURITY_POLICY_TABLE_VALID" (forall (policy security-policies)
        (and
          (rule "POLICY_TYPE_VALID" (member policy-type (range #x01 #x0C)))
          (rule "DENY_BY_DEFAULT" T))))

      (rule "VAULT_BOUNDARY_INTEGRITY"
        :constraint "all file access must be within vault root path")

      (rule "DEPENDENCY_GRAPH_ACYCLIC"
        :constraint "job step dependencies must form a DAG"
        :method "detect cycles in step dependency graph")

      (rule "RESOURCE_CONSISTENCY"
        :constraint "header resource limits must match limit table entries")))

  ;; Execution Security Properties
  :security-properties (list
    "sandboxed execution environment"
    "deny-by-default access control"
    "vault boundary enforcement"
    "resource limits enforced"
    "credential emission prohibited"
    "network access controlled"
    "file system access restricted"
    "subprocess execution controlled"
    "secret variable masking"
    "audit trail maintained"))

;; ============================================================================
;; SUMMARY INVERTED BOOLEAN TREE: CROSS-SECTION VALIDATION
;; ============================================================================

(defvalidation QUIPPER-JCL-INTEGRATION
  :constraint-tree (implies
    (and
      ;; Quipper artifact constraints
      (every-qubit-index-valid
        (forall (q qubit-indices)
          (and (>= q 0) (< q Q))))

      (every-gate-valid
        (forall (g gates)
          (and
            (member (gate-type g) gate-type-enumeration)
            (implies (measurement-gate? g)
              (== (count target-qubits) (count classical-bits)))
            (implies (rotation-gate? g)
              (exists angle-param (== typeof angle-param binary64)))
            (implies (custom-unitary? g)
              (<= (unitarity-error g) 1e-10)))))

      (subroutine-call-graph-acyclic
        (no-cycles (build-subroutine-call-graph)))

      (no-dangling-wires
        (every-wire-used-at-least-once))

      ;; JCL manifest constraints
      (job-steps-valid
        (forall (step job-steps)
          (and
            (dataset-references-valid
              (and
                (forall (ds input-datasets) (member ds datasets))
                (forall (ds output-datasets) (member ds datasets))))
            (dependency-constraints-valid
              (implies (== dependency-previous-step 1) (> step-index 0)))
            (resource-limits-consistent
              (forall (limit (union step-limits header-limits))
                (exists global-limit (== limit global-limit)))))))

      (dataset-table-consistent
        (forall (ds datasets)
          (and
            (valid-dataset-type (member dataset-type dataset-type-enum))
            (valid-record-format (member record-format record-format-enum))
            (valid-organization (member organization organization-enum))
            (read-write-constraints
              (implies (== dataset-type DS_INPUT) (== mode read-only))
              (implies (== dataset-type DS_OUTPUT) (== mode write-only))
              (implies (== dataset-type DS_AUDIT) (== mode append-only))
              (implies (== dataset-type DS_LOG) (== mode append-only))))))

      (security-policies-enforced
        (forall (policy security-policies)
          (and
            (valid-policy-type (member policy-type policy-type-enum))
            (denies-by-default
              (implies (or
                (== policy-type POLICY_NO_NETWORK)
                (== policy-type POLICY_NO_FS_ESCAPE)
                (== policy-type POLICY_NO_CREDENTIALS))
              (== default-action deny))))))

      ;; Determinism and reproducibility
      (deterministic-generation
        (and
          (no-randomness)
          (fixed-seed 0)
          (identical-ptm-ir-produces-identical-bytes)))

      ;; Integration constraint
      (quipper-independent-from-jcl
        (and
          "Quipper artifact is optional acceleration layer"
          "classical PTM execution independent of Quipper"
          "Quipper does not modify PTM-IR or PTM transition table"
          "Quipper does not access files outside vault boundary")))

    ;; CONSEQUENT: System state is valid and auditable
    (valid-and-auditable-system-state
      (and
        "all gates within valid enumeration"
        "all indices within valid ranges"
        "all subroutine calls match signatures"
        "call graphs acyclic"
        "wires consistent with gate usage"
        "datasets accessible within vault"
        "resource limits enforced"
        "security policies applied"
        "deterministic generation"
        "reproducible via SHA-256 hash"
        "audit manifest complete"))))

(export
  '(QUIPPER-FILE
    JCL-VAULT-MANIFEST
    QUIPPER-JCL-INTEGRATION
    GATE-TYPES
    DATASET-TABLE
    SECURITY-POLICY-TABLE
    VALIDATION-TREE))
