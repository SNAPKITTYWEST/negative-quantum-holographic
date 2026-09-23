;; SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
;; CLONE_GATE:AES256:59a0dc9da535e2cabeccb08408ea67e634c1a856421061c1b14a100c61fdfc21
;;
;; ============================================================================
;; INVERTED AST: CONTROL FLOW GRAPH BINARY + POLYNOMIAL TURING MACHINE BINARY
;; Sections 0003-0004 (lines 530-700)
;; Converted to Lisp S-expression Boolean Tree with Validation Constraints
;; ============================================================================

;; SECTION 0003: CONTROL FLOW GRAPH BINARY ENCODING
;; ============================================================================

(defstructure CFG-BINARY-ENCODING
  "Root structure: Control Flow Graph binary encoding (magic 0x43464742 'CFGB')"

  :magic #x43464742
  :version "1.0.0"
  :header-size 48  ;; 16 bytes standard + 32 bytes CFG-specific metadata

  :cfgg-model (defstruct CFG-THEORY
    :description "directed graph where nodes are basic blocks"
    :nodes "basic blocks (maximal sequence of consecutive statements)"
    :edges "directed edges between blocks"
    :entry-type "single entry point"
    :exit-type "may have multiple exits")

  :basic-block-definition (defstruct BASIC-BLOCK-SEMANTICS
    :definition "maximal sequence of consecutive statements with single entry and single exit"
    :entry-point "first statement in sequence"
    :exit-point "last statement in sequence"
    :termination-conditions (list
      "branch statement"
      "conditional statement"
      "call statement"
      "return statement"
      "label target"))

  :header (defstruct CFG-HEADER
    :magic-bytes #(#x43 #x46 #x47 #x42)  ;; "CFGB"
    :standard-header-size 16
    :cfg-metadata-size 32

    ;; Header fields (bytes 16-47)
    :block-count-offset 16  :block-count-size 4  ;; N
    :edge-count-offset 20  :edge-count-size 4  ;; E
    :entry-block-index-offset 24  :entry-block-index-size 4  ;; 0-based
    :exit-block-index-offset 28  :exit-block-index-size 4  ;; 0-based, 0xFFFFFFFF if multiple
    :loop-header-count-offset 32  :loop-header-count-size 4
    :loop-header-table-offset-offset 36
    :dominator-tree-offset-offset 40
    :post-dominator-tree-offset-offset 44

    ;; Validation constraints
    :requires-header-validation T
    :requires-bounds-validation T)

  ;; Basic Block Table
  :basic-block-table (defstruct BASIC-BLOCK-TABLE
    :record-count-reference "N"
    :record-size 32  ;; bytes per record
    :record-structure (defstruct BASIC-BLOCK-RECORD
      :block-index-offset 0  :block-index-size 4
      :first-statement-index-offset 4  :first-statement-index-size 4
      :last-statement-index-offset 8  :last-statement-index-size 4  ;; inclusive
      :predecessor-count-offset 12  :predecessor-count-size 4
      :predecessor-list-offset-offset 16
      :successor-count-offset 20  :successor-count-size 4
      :successor-list-offset-offset 24
      :block-flags-offset 28  :block-flags-size 4)

    :block-flags-structure (defstruct BLOCK-FLAGS
      :bit-31-loop-header "1 = loop header, 0 = not"
      :bit-30-loop-exit "1 = loop exit, 0 = not"
      :bit-29-unreachable "1 = unreachable, 0 = reachable"
      :bit-28-contains-call "1 = contains call, 0 = no call"
      :bit-27-contains-io "1 = contains I/O, 0 = no I/O"
      :bits-26-0-reserved "must be zero")

    :block-index-range (implies (block-index) (and (>= block-index 0) (< block-index N)))
    :statement-index-range (implies (stmt-index) (>= stmt-index 0))
    :predecessor-count-range (implies (pred-count) (>= pred-count 0))
    :successor-count-range (implies (succ-count) (>= succ-count 0)))

  ;; Edge Table
  :edge-table (defstruct EDGE-TABLE
    :record-count-reference "E"
    :record-size 16  ;; bytes per record
    :record-structure (defstruct EDGE-RECORD
      :source-block-index-offset 0  :source-block-index-size 4
      :target-block-index-offset 4  :target-block-index-size 4
      :edge-type-offset 8  :edge-type-size 4
      :edge-flags-offset 12  :edge-flags-size 4)

    :edge-type-enumeration {
      :0x01 "EDGE_FALLTHROUGH"
      :0x02 "EDGE_BRANCH_TRUE"
      :0x03 "EDGE_BRANCH_FALSE"
      :0x04 "EDGE_UNCONDITIONAL"
      :0x05 "EDGE_CALL"
      :0x06 "EDGE_RETURN"
      :0x07 "EDGE_EXCEPTION"
      :0x08 "EDGE_BACK_EDGE"}

    :edge-flags-structure (defstruct EDGE-FLAGS
      :bit-31-critical "1 = critical edge, 0 = not critical"
      :bits-30-0-reserved "must be zero")

    :critical-edge-definition "edge from block with multiple successors to block with multiple predecessors"
    :critical-edge-transformation "critical edges are split by inserting empty blocks during optimization"

    :source-target-range (implies (block-idx) (and (>= block-idx 0) (< block-idx N)))
    :edge-type-valid (implies (e-type) (member e-type (list #x01 #x02 #x03 #x04 #x05 #x06 #x07 #x08))))

  ;; Dominator Tree
  :dominator-tree (defstruct DOMINATOR-TREE
    :record-count-reference "N"
    :record-size 4  ;; bytes per entry (32-bit integer)
    :record-structure (defstruct DOMINATOR-ENTRY
      :immediate-dominator-offset 0  :immediate-dominator-size 4)

    :semantics "dominator-tree[i] = index of immediate dominator of block i"
    :entry-block-property "entry block dominates itself; immediate dominator is itself"
    :unreachable-block-property "unreachable block has dominator index 0xFFFFFFFF"

    :dominator-index-range (implies (dom-idx) (or (and (>= dom-idx 0) (< dom-idx N)) (== dom-idx #xFFFFFFFF)))
    :computation-algorithm "Lengauer-Tarjan algorithm"
    :computation-complexity "O(E * alpha(E, N)) where alpha is inverse Ackermann")

  ;; Post-Dominator Tree
  :post-dominator-tree (defstruct POST-DOMINATOR-TREE
    :record-count-reference "N"
    :record-size 4
    :record-structure (defstruct POST-DOMINATOR-ENTRY
      :immediate-post-dominator-offset 0  :immediate-post-dominator-size 4)

    :semantics "post-dominator-tree[i] = index of immediate post-dominator of block i"
    :computation-algorithm "reverse all edges, apply Lengauer-Tarjan"
    :computation-complexity "O(E * alpha(E, N))")

  ;; Loop Header Table
  :loop-header-table (defstruct LOOP-HEADER-TABLE
    :record-count-reference "number of loop headers"
    :record-size 16  ;; bytes per record
    :record-structure (defstruct LOOP-RECORD
      :header-block-index-offset 0  :header-block-index-size 4
      :loop-body-block-count-offset 4  :loop-body-block-count-size 4
      :loop-body-block-list-offset-offset 8
      :nesting-depth-offset 12  :nesting-depth-size 4)

    :nesting-depth-bound 64  ;; maximum loop nesting levels
    :nesting-depth-violation "exceeding 64 levels triggers validation failure"

    :loop-body-block-list "array of 32-bit block indices"

    :natural-loop-detection (defstruct LOOP-THEORY
      :identification-method "back edges in CFG"
      :back-edge-definition "edge whose target dominates its source"
      :natural-loop-definition "for back edge (h -> s), all nodes that can reach s without passing through h"
      :detection-algorithm "depth-first search over dominator tree"
      :detection-complexity "O(N + E)")

    :nesting-depth-range (implies (depth) (and (>= depth 0) (< depth 64))))

  ;; Reachability Analysis
  :reachability-analysis (defstruct REACHABILITY
    :computation-algorithm "depth-first search from entry block"
    :unreachable-blocks "marked with unreachable flag"
    :unreachable-blocks-participation "do NOT participate in Turing Machine lowering"
    :unreachable-blocks-reporting "reported as validation warning")

  ;; CFG Validation Rules (Boolean Tree)
  :validation-rules (defstruct CFG-VALIDATION-TREE
    :root (and
      (rule "MAGIC_CHECK" (== magic #x43464742))
      (rule "VERSION_CHECK" (== version "1.0.0"))
      (rule "HEADER_SIZE_CHECK" (== header-size 48))
      (rule "BLOCK_INDEX_RANGE"
        :antecedent T
        :consequent (forall (b blocks) (and (>= (block-index b) 0) (< (block-index b) N)))
        :note "every block index is within range [0, N-1]")
      (rule "EDGE_REFERENCES_VALID"
        :antecedent T
        :consequent (forall (e edges) (and (valid-block-index (source-block e)) (valid-block-index (target-block e))))
        :note "every edge references valid block indices")
      (rule "ENTRY-BLOCK-NO-PREDECESSORS"
        :antecedent T
        :consequent (== (predecessor-count (block entry-block-index)) 0)
        :note "entry block has no predecessors")
      (rule "EXIT-BLOCK-NO-SUCCESSORS"
        :antecedent (not (== exit-block-index #xFFFFFFFF))
        :consequent (== (successor-count (block exit-block-index)) 0)
        :note "exit block (if unique) has no successors")
      (rule "DOMINATOR-TREE-ACYCLIC"
        :antecedent T
        :consequent "dominator tree forms acyclic partial order"
        :validation-method "verify no cycles in immediate dominator chain")
      (rule "POST-DOMINATOR-TREE-ACYCLIC"
        :antecedent T
        :consequent "post-dominator tree forms acyclic partial order"
        :validation-method "verify no cycles in immediate post-dominator chain")
      (rule "LOOP-HEADER-PREDECESSORS"
        :antecedent (is-loop-header block)
        :consequent (>= (predecessor-count block) 2)
        :note "loop headers have at least two predecessors")
      (rule "BACK-EDGE-TARGETS-LOOP-HEADER"
        :antecedent (== (edge-type edge) #x08)
        :consequent (is-loop-header (target-block edge))
        :note "back edges target loop headers")
      (rule "REACHABILITY-PROPERTY"
        :antecedent T
        :consequent (forall (b blocks) (or (reachable-from-entry b) (is-unreachable b)))
        :note "every block is reachable from entry or explicitly marked unreachable")))

  ;; CFG Validation Failure Policy
  :validation-failure-policy (defstruct FAILURE-POLICY
    :failure-response "fail-closed status"
    :meaning "any CFG validation failure stops the pipeline")

  ;; CFG Security Properties
  :security-properties (list
    "CFG construction reads PTM-IR file as read-only input"
    "CFG construction does not modify PTM-IR file"
    "CFG construction does not execute arbitrary commands"
    "CFG construction does not access network resources"
    "CFG construction does not write outside vault boundary"
    "CFG construction treats PTM-IR file as untrusted input"
    "CFG construction validates PTM-IR header before processing"
    "CFG construction validates statement list bounds before indexing"
    "CFG construction validates symbol table bounds before symbol lookup"
    "CFG construction validates expression node bounds before tree traversal"
    "CFG construction validates constant pool bounds before constant access")

  ;; CFG Bounds Checking Policy
  :bounds-checking-policy (defstruct BOUNDS-POLICY
    :method "unsigned comparison to prevent wrap-around exploits"
    :array-indexing "base pointer plus offset with explicit length checking"
    :pointer-arithmetic "NOT used for structure traversal"
    :structure-offsets "compile-time constants defined in specification")

  ;; Reproducibility & Audit
  :reproducibility (defstruct CFG-REPRODUCIBILITY
    :deterministic T
    :property "identical source produces identical CFG bytes"
    :hash-algorithm "SHA-256"
    :hash-computed-over "complete CFG file"
    :audit-manifest-entry T)


;; SECTION 0004: POLYNOMIAL TURING MACHINE BINARY SPECIFICATION
;; ============================================================================

(defstructure POLYNOMIAL-TURING-MACHINE
  "Root structure: Polynomial Turing Machine binary specification (magic 0x544D5454 'TMTT')"

  :machine-type "multi-tape deterministic Turing machine"
  :polynomial-time-property "operates in time polynomial in the length of encoded input"
  :tape-count 4
  :magic #x544D5454
  :version "1.0.0"
  :header-size 64  ;; 16 bytes standard + 48 bytes PTM metadata

  :tape-configuration (defstruct TAPE-SYSTEM
    :tape-count 4
    :tape-names (list "input tape" "work tape" "control tape" "output tape")

    :input-tape (defstruct INPUT-TAPE
      :definition "read-only after initialization"
      :alphabet {0, 1, B}
      :head-movements (list "right" "stay")
      :head-cannot-move "left"
      :initial-head-position 0)

    :work-tape (defstruct WORK-TAPE
      :definition "read-write tape"
      :alphabet {0, 1, B, X, Y, Z}
      :head-movements (list "left" "right" "stay")
      :initial-head-position 0)

    :control-tape (defstruct CONTROL-TAPE
      :definition "read-write tape"
      :alphabet {0, 1, B}
      :head-movements (list "left" "right" "stay")
      :initial-head-position 0)

    :output-tape (defstruct OUTPUT-TAPE
      :definition "write-only tape"
      :alphabet {0, 1, B}
      :head-movements (list "right" "stay")
      :head-cannot-move "left"
      :initial-head-position 0)

    :tape-structure "one-way infinite sequence of cells extending to the right"
    :cell-content "exactly one symbol from tape alphabet"
    :blank-symbol-definition "B is distinct from 0 and 1"
    :head-per-tape "each tape has its own read-write head"
    :all-heads-start-at 0)

  :header (defstruct PTM-HEADER
    :magic-bytes #(#x54 #x4D #x54 #x54)  ;; "TMTT"
    :standard-header-size 16
    :ptm-metadata-size 48

    ;; Header fields (bytes 16-63)
    :state-count-offset 16  :state-count-size 4  ;; Q
    :transition-count-offset 20  :transition-count-size 4  ;; T
    :initial-state-index-offset 24  :initial-state-index-size 4
    :accepting-state-index-offset 28  :accepting-state-index-size 4
    :rejecting-state-index-offset 32  :rejecting-state-index-size 4
    :halting-state-index-offset 36  :halting-state-index-size 4
    :input-alphabet-size-offset 40  :input-alphabet-size-size 4  ;; always 3: {0, 1, B}
    :work-alphabet-size-offset 44  :work-alphabet-size-size 4  ;; always 6: {0, 1, B, X, Y, Z}
    :control-alphabet-size-offset 48  :control-alphabet-size-size 4  ;; always 3
    :output-alphabet-size-offset 52  :output-alphabet-size-size 4  ;; always 3
    :max-tape-count-offset 56  :max-tape-count-size 4  ;; always 4
    :polynomial-degree-bound-offset 60  :polynomial-degree-bound-size 4  ;; d

    ;; Validation
    :requires-header-validation T
    :requires-state-table-validation T
    :requires-transition-table-validation T)

  :polynomial-degree-bound (defstruct COMPLEXITY-BOUNDS
    :degree "d (32-bit unsigned integer)"
    :time-bound "T(n) <= c * n^d for constant c and all n >= n0"
    :space-bound "S(n) <= c' * n^d for constant c' and all n >= n0"
    :constants-location "recorded in separate complexity report"
    :complexity-report-magic #x434D504C  ;; "CMPL"
    :constants-recorded (list "c (time bound constant)" "c' (space bound constant)"))

  ;; State Table
  :state-table (defstruct STATE-TABLE
    :record-count-reference "Q"
    :record-size 16  ;; bytes per record
    :record-structure (defstruct STATE-RECORD
      :state-index-offset 0  :state-index-size 4
      :state-type-offset 4  :state-type-size 4
      :outgoing-transition-count-offset 8  :outgoing-transition-count-size 4
      :outgoing-transition-list-offset-offset 12)

    :state-type-enumeration {
      :0x01 "STATE_NORMAL"
      :0x02 "STATE_INITIAL"
      :0x03 "STATE_ACCEPTING"
      :0x04 "STATE_REJECTING"
      :0x05 "STATE_HALTING"}

    :state-index-range (implies (s-idx) (and (>= s-idx 0) (< s-idx Q)))
    :state-type-valid (implies (s-type) (member s-type (list #x01 #x02 #x03 #x04 #x05))))

  ;; Transition Table
  :transition-table (defstruct TRANSITION-TABLE
    :record-count-reference "T"
    :record-size 48  ;; bytes per record
    :record-structure (defstruct TRANSITION-RECORD
      :transition-id-offset 0  :transition-id-size 4  ;; unique 32-bit integer
      :source-state-offset 4  :source-state-size 4
      :target-state-offset 8  :target-state-size 4

      ;; Input symbols (read)
      :input-tape-symbol-read-offset 12  :input-tape-symbol-read-size 4  ;; 0x00, 0x01, 0x02
      :work-tape-symbol-read-offset 16  :work-tape-symbol-read-size 4  ;; 0x00-0x05
      :control-tape-symbol-read-offset 20  :control-tape-symbol-read-size 4  ;; 0x00-0x02
      :output-tape-symbol-read-offset 24  :output-tape-symbol-read-size 4  ;; 0x00-0x02

      ;; Output symbols (written)
      :input-tape-symbol-written-offset 28  :input-tape-symbol-written-size 4  ;; 0x00-0x02
      :work-tape-symbol-written-offset 32  :work-tape-symbol-written-size 4  ;; 0x00-0x05
      :control-tape-symbol-written-offset 36  :control-tape-symbol-written-size 4  ;; 0x00-0x02
      :output-tape-symbol-written-offset 40  :output-tape-symbol-written-size 4  ;; 0x00-0x02

      ;; Head movements
      :input-tape-head-movement-offset 44  :input-tape-head-movement-size 1  ;; 0x00=L, 0x01=R, 0x02=S
      :work-tape-head-movement-offset 45  :work-tape-head-movement-size 1  ;; 0x00=L, 0x01=R, 0x02=S
      :control-tape-head-movement-offset 46  :control-tape-head-movement-size 1  ;; 0x00=L, 0x01=R, 0x02=S
      :output-tape-head-movement-offset 47  :output-tape-head-movement-size 1)  ;; 0x00=L, 0x01=R, 0x02=S

    :head-movement-enumeration {
      :0x00 "LEFT"
      :0x01 "RIGHT"
      :0x02 "STAY"}

    :symbol-encoding-input {
      :0x00 "0"
      :0x01 "1"
      :0x02 "B"}

    :symbol-encoding-work {
      :0x00 "0"
      :0x01 "1"
      :0x02 "B"
      :0x03 "X"
      :0x04 "Y"
      :0x05 "Z"}

    :symbol-encoding-control {
      :0x00 "0"
      :0x01 "1"
      :0x02 "B"}

    :symbol-encoding-output {
      :0x00 "0"
      :0x01 "1"
      :0x02 "B"}

    ;; Constraints
    :transition-id-uniqueness "each transition has unique 32-bit ID"
    :source-state-validity (implies (src) (and (>= src 0) (< src Q)))
    :target-state-validity (implies (tgt) (and (>= tgt 0) (< tgt Q)))
    :input-symbol-validity (implies (sym) (member sym (list #x00 #x01 #x02)))
    :work-symbol-validity (implies (sym) (member sym (list #x00 #x01 #x02 #x03 #x04 #x05)))
    :control-symbol-validity (implies (sym) (member sym (list #x00 #x01 #x02)))
    :output-symbol-validity (implies (sym) (member sym (list #x00 #x01 #x02)))
    :input-head-movement-validity (implies (mov) (member mov (list #x00 #x01 #x02)))
    :work-head-movement-validity (implies (mov) (member mov (list #x00 #x01 #x02)))
    :control-head-movement-validity (implies (mov) (member mov (list #x00 #x01 #x02)))
    :output-head-movement-validity (implies (mov) (member mov (list #x00 #x01 #x02))))

  ;; PTM Constraints on Head Movement
  :head-movement-constraints (defstruct HEAD-MOVEMENT-RULES
    :input-tape-restriction
      :antecedent T
      :consequent (member input-head-movement (list #x01 #x02))  ;; RIGHT or STAY only
      :note "input tape head can move right (R) or stay (S) but not left"

    :work-tape-freedom
      :antecedent T
      :consequent (member work-head-movement (list #x00 #x01 #x02))  ;; L, R, or S
      :note "work tape head can move left (L), right (R), or stay (S)"

    :control-tape-freedom
      :antecedent T
      :consequent (member control-head-movement (list #x00 #x01 #x02))  ;; L, R, or S
      :note "control tape head can move left (L), right (R), or stay (S)"

    :output-tape-restriction
      :antecedent T
      :consequent (member output-head-movement (list #x01 #x02))  ;; RIGHT or STAY only
      :note "output tape head can move right (R) or stay (S) but not left")

  ;; PTM Tape Access Constraints
  :tape-access-constraints (defstruct TAPE-ACCESS-RULES
    :input-tape-read-only
      :antecedent T
      :consequent "input tape head can only read, never write"
      :note "write operations must encode output-tape-symbol-written = same as read"

    :output-tape-write-only
      :antecedent T
      :consequent "output tape head can only write, never read"
      :note "read operations must encode output-tape-symbol-read as non-deterministic"

    :work-tape-read-write
      :antecedent T
      :consequent "work tape allows both read and write operations"

    :control-tape-read-write
      :antecedent T
      :consequent "control tape allows both read and write operations")

  ;; PTM Validation Rules (Boolean Tree)
  :validation-rules (defstruct PTM-VALIDATION-TREE
    :root (and
      (rule "MAGIC_CHECK" (== magic #x544D5454))
      (rule "VERSION_CHECK" (== version "1.0.0"))
      (rule "HEADER_SIZE_CHECK" (== header-size 64))
      (rule "INPUT_ALPHABET_SIZE"
        :antecedent T
        :consequent (== input-alphabet-size 3)
        :note "input alphabet always {0, 1, B}")
      (rule "WORK_ALPHABET_SIZE"
        :antecedent T
        :consequent (== work-alphabet-size 6)
        :note "work alphabet always {0, 1, B, X, Y, Z}")
      (rule "CONTROL_ALPHABET_SIZE"
        :antecedent T
        :consequent (== control-alphabet-size 3)
        :note "control alphabet always {0, 1, B}")
      (rule "OUTPUT_ALPHABET_SIZE"
        :antecedent T
        :consequent (== output-alphabet-size 3)
        :note "output alphabet always {0, 1, B}")
      (rule "MAX_TAPE_COUNT"
        :antecedent T
        :consequent (== max-tape-count 4)
        :note "exactly 4 tapes")
      (rule "POLYNOMIAL_DEGREE_VALID"
        :antecedent T
        :consequent (and (>= polynomial-degree-bound 0) (< polynomial-degree-bound 64))
        :note "polynomial degree is reasonable upper bound")
      (rule "STATE_COUNT_NONZERO"
        :antecedent T
        :consequent (> state-count 0)
        :note "must have at least one state")
      (rule "INITIAL_STATE_VALID"
        :antecedent T
        :consequent (and (>= initial-state-index 0) (< initial-state-index Q)))
      (rule "ACCEPTING_STATE_VALID"
        :antecedent T
        :consequent (and (>= accepting-state-index 0) (< accepting-state-index Q)))
      (rule "REJECTING_STATE_VALID"
        :antecedent T
        :consequent (and (>= rejecting-state-index 0) (< rejecting-state-index Q)))
      (rule "HALTING_STATE_VALID"
        :antecedent T
        :consequent (and (>= halting-state-index 0) (< halting-state-index Q)))
      (rule "SPECIAL_STATES_DISTINCT"
        :antecedent T
        :consequent (and
          (not (== accepting-state-index rejecting-state-index))
          (not (== accepting-state-index halting-state-index))
          (not (== rejecting-state-index halting-state-index)))
        :note "accepting, rejecting, and halting states must be distinct")
      (rule "TRANSITION_COUNT_NONZERO"
        :antecedent T
        :consequent (> transition-count 0)
        :note "must have at least one transition")
      (rule "STATE_TABLE_VALID"
        :antecedent T
        :consequent (forall (s states)
          (and
            (>= (state-index s) 0) (< (state-index s) Q)
            (member (state-type s) (list #x01 #x02 #x03 #x04 #x05))))
        :note "all states have valid indices and types")
      (rule "TRANSITION_TABLE_VALID"
        :antecedent T
        :consequent (forall (t transitions)
          (and
            (> (transition-id t) 0)
            (>= (source-state t) 0) (< (source-state t) Q)
            (>= (target-state t) 0) (< (target-state t) Q)
            (member (input-symbol-read t) (list #x00 #x01 #x02))
            (member (work-symbol-read t) (list #x00 #x01 #x02 #x03 #x04 #x05))
            (member (control-symbol-read t) (list #x00 #x01 #x02))
            (member (output-symbol-read t) (list #x00 #x01 #x02))
            (member (input-symbol-written t) (list #x00 #x01 #x02))
            (member (work-symbol-written t) (list #x00 #x01 #x02 #x03 #x04 #x05))
            (member (control-symbol-written t) (list #x00 #x01 #x02))
            (member (output-symbol-written t) (list #x00 #x01 #x02))))
        :note "all transitions have valid structure")
      (rule "INPUT_TAPE_HEAD_NO_LEFT"
        :antecedent T
        :consequent (forall (t transitions)
          (not (== (input-head-movement t) #x00)))
        :note "input tape head never moves left")
      (rule "OUTPUT_TAPE_HEAD_NO_LEFT"
        :antecedent T
        :consequent (forall (t transitions)
          (not (== (output-head-movement t) #x00)))
        :note "output tape head never moves left")
      (rule "POLYNOMIAL_TIME_SOUNDNESS"
        :antecedent T
        :consequent (forall (s states) (> (outgoing-transition-count s) 0))
        :note "all states have at least one outgoing transition (reachability property)")
      (rule "DETERMINISM_PROPERTY"
        :antecedent T
        :consequent "no two transitions with same (source, input, work, control, output) tuple"
        :validation-method "verify no duplicate (state, symbol quadruple) transitions")))

  ;; PTM Security Properties
  :security-properties (list
    "PTM binary specification does not access files outside vault boundary"
    "PTM binary specification does not execute arbitrary commands"
    "PTM binary specification does not request or emit credentials"
    "PTM does not claim quantum supremacy without proof"
    "PTM machine definition is deterministic")

  ;; Reproducibility & Audit
  :reproducibility (defstruct PTM-REPRODUCIBILITY
    :deterministic T
    :seed 0
    :hash-algorithm "SHA-256"
    :hash-computed-over "complete PTM artifact file"
    :audit-manifest-entry T)

  ;; Complexity Report Structure
  :complexity-report (defstruct COMPLEXITY-REPORT
    :magic #x434D504C  ;; "CMPL"
    :contains (list
      "polynomial degree d"
      "time bound constant c"
      "space bound constant c'"
      "derivation notes"
      "proof of polynomial bounds")))
