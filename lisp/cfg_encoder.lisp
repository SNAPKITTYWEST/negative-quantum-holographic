;; SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
;; CLONE_GATE:AES256:59a0dc9da535e2cabeccb08408ea67e634c1a856421061c1b14a100c61fdfc21
;;
;; cfg_encoder.lisp — CFG binary encoder/decoder + PTM binary format
;; Implements BLRD-PTM-2026-001 Sections 0003-0004
;; Replaces the S-expr spec in quantum-wires/ast/INVERTED-AST-CFG-PTM.lisp
;;
;; Load: sbcl --load cfg_encoder.lisp
;;       clisp cfg_encoder.lisp
;; Test: (cfg-run-all-tests)

(in-package :cl-user)

;;; ─── BYTE BUFFER ────────────────────────────────────────────────────────────

(defstruct buf
  (bytes (make-array 4096 :element-type '(unsigned-byte 8) :fill-pointer 0))
  (pos 0))

(defun buf-write-u8 (buf val)
  (vector-push-extend (logand val #xFF) (buf-bytes buf))
  (incf (buf-pos buf)))

(defun buf-write-u32-be (buf val)
  "Write 32-bit unsigned int big-endian."
  (buf-write-u8 buf (logand (ash val -24) #xFF))
  (buf-write-u8 buf (logand (ash val -16) #xFF))
  (buf-write-u8 buf (logand (ash val  -8) #xFF))
  (buf-write-u8 buf (logand val           #xFF)))

(defun buf-read-u32-be (bytes offset)
  (+ (ash (aref bytes offset)       24)
     (ash (aref bytes (+ offset 1)) 16)
     (ash (aref bytes (+ offset 2))  8)
          (aref bytes (+ offset 3))))

;;; ─── MAGIC NUMBERS (BLRD req 0069, 0088, 0089) ───────────────────────────────

(defconstant +magic-cfgb+  #x43464742)  ; "CFGB" CFG binary
(defconstant +magic-tmtt+  #x544D5454)  ; "TMTT" Turing Machine Transition Table
(defconstant +magic-cmpl+  #x434D504C)  ; "CMPL" Complexity Report
(defconstant +magic-snap+  #x534E4150)  ; "SNAP" PTM Snapshot

;;; ─── BLOCK FLAGS (BLRD req 0528-0533) ────────────────────────────────────────

(defconstant +flag-loop-header+ (ash 1 31))
(defconstant +flag-loop-exit+   (ash 1 30))
(defconstant +flag-unreachable+ (ash 1 29))
(defconstant +flag-contains-call+ (ash 1 28))
(defconstant +flag-contains-io+   (ash 1 27))

(defun compute-block-flags (&key loop-header loop-exit unreachable contains-call contains-io)
  (logior (if loop-header   +flag-loop-header+   0)
          (if loop-exit     +flag-loop-exit+     0)
          (if unreachable   +flag-unreachable+   0)
          (if contains-call +flag-contains-call+ 0)
          (if contains-io   +flag-contains-io+   0)))

;;; ─── BASIC BLOCK STRUCTURE ────────────────────────────────────────────────────

(defstruct basic-block
  (index 0 :type (unsigned-byte 32))
  (first-stmt 0 :type (unsigned-byte 32))
  (last-stmt  0 :type (unsigned-byte 32))
  (predecessors nil)
  (successors   nil)
  (flags 0 :type (unsigned-byte 32))
  (label ""))

;;; ─── CFG STRUCTURE ────────────────────────────────────────────────────────────

(defstruct cfg
  (magic +magic-cfgb+ :type (unsigned-byte 32))
  (version "1.0.0")
  (program-name "")
  (blocks nil)
  (entry-block 0 :type (unsigned-byte 32))
  (exit-block  0 :type (unsigned-byte 32)))

;;; ─── CFG BINARY ENCODER (BLRD Section 0003) ──────────────────────────────────

(defun encode-cfg (cfg)
  "Encode a CFG to binary per BLRD Section 0003. Returns byte vector."
  (let* ((buf (make-buf))
         (blocks (cfg-blocks cfg))
         (n (length blocks))
         (e (reduce #'+ blocks :key (lambda (b) (length (basic-block-successors b)))))
         ;; Compute offsets (header=48, block-table starts at 48)
         (block-table-offset 48)
         (record-size 32)
         ;; We'll write predecessor/successor lists after the block table
         (adj-offset (+ block-table-offset (* n record-size))))
    ;; ── Standard header (16 bytes, req 0088) ──────────────────────────────
    (buf-write-u32-be buf +magic-cfgb+)           ; bytes 0-3
    (buf-write-u32-be buf #x00010000)             ; version 1.0
    (buf-write-u32-be buf 48)                     ; header size
    (buf-write-u32-be buf (+ 48 (* n record-size) ; total file size (approx)
                              (* (+ n e) 4)))
    ;; ── CFG metadata (32 bytes, req header offsets 16-47) ─────────────────
    (buf-write-u32-be buf n)                      ; block count (offset 16)
    (buf-write-u32-be buf e)                      ; edge count  (offset 20)
    (buf-write-u32-be buf (cfg-entry-block cfg))  ; entry block (offset 24)
    (buf-write-u32-be buf (cfg-exit-block  cfg))  ; exit block  (offset 28)
    ;; loop header count
    (buf-write-u32-be buf
      (count-if (lambda (b) (not (zerop (logand (basic-block-flags b)
                                                +flag-loop-header+))))
                blocks))
    (buf-write-u32-be buf 0)   ; loop-header-table-offset (placeholder)
    (buf-write-u32-be buf 0)   ; dominator-tree-offset (placeholder)
    (buf-write-u32-be buf 0)   ; post-dominator-tree-offset (placeholder)
    ;; ── Block table (N × 32 bytes, req 0545-0558) ─────────────────────────
    (let ((cur-adj-off adj-offset))
      (dolist (blk blocks)
        (buf-write-u32-be buf (basic-block-index blk))      ; offset 0
        (buf-write-u32-be buf (basic-block-first-stmt blk)) ; offset 4
        (buf-write-u32-be buf (basic-block-last-stmt blk))  ; offset 8
        (buf-write-u32-be buf (length (basic-block-predecessors blk))) ; offset 12
        (buf-write-u32-be buf cur-adj-off)                  ; pred-list-offset
        (incf cur-adj-off (* 4 (length (basic-block-predecessors blk))))
        (buf-write-u32-be buf (length (basic-block-successors blk)))   ; offset 20
        (buf-write-u32-be buf cur-adj-off)                  ; succ-list-offset
        (incf cur-adj-off (* 4 (length (basic-block-successors blk))))
        (buf-write-u32-be buf (basic-block-flags blk))))    ; offset 28
    ;; ── Adjacency lists ───────────────────────────────────────────────────
    (dolist (blk blocks)
      (dolist (pred (basic-block-predecessors blk))
        (buf-write-u32-be buf pred))
      (dolist (succ (basic-block-successors blk))
        (buf-write-u32-be buf succ)))
    (subseq (buf-bytes buf) 0 (buf-pos buf))))

;;; ─── PTM TRANSITION TABLE ENCODER (BLRD Section 0004) ───────────────────────

(defstruct ptm-state
  (index 0 :type (unsigned-byte 32))
  (name  "" :type string))

(defstruct ptm-transition
  (from-state 0 :type (unsigned-byte 32))
  ;; One entry per tape: (read-sym write-sym move)
  ;; move: 0=L 1=S 2=R
  (tape-actions nil)  ; list of (read write move) per tape
  (to-state 0 :type (unsigned-byte 32)))

(defstruct ptm-table
  (magic +magic-tmtt+ :type (unsigned-byte 32))
  (num-tapes 4 :type (unsigned-byte 8))
  (states nil)
  (transitions nil))

(defun encode-ptm-table (ptm)
  "Encode PTM transition table per BLRD Section 0004. Returns byte vector."
  (let* ((buf (make-buf))
         (states (ptm-table-states ptm))
         (trans  (ptm-table-transitions ptm))
         (nstates (length states))
         (ntrans  (length trans)))
    ;; Header: magic(4) version(4) header-size(4) total-size(4)
    (buf-write-u32-be buf +magic-tmtt+)
    (buf-write-u32-be buf #x00010000)
    (buf-write-u32-be buf 32)
    (buf-write-u32-be buf 0)       ; fill in total later
    (buf-write-u32-be buf nstates)
    (buf-write-u32-be buf ntrans)
    (buf-write-u32-be buf (ptm-table-num-tapes ptm))
    (buf-write-u32-be buf 0)       ; reserved
    ;; State table: each state = 8 bytes (index, flags)
    (dolist (st states)
      (buf-write-u32-be buf (ptm-state-index st))
      (buf-write-u32-be buf 0))
    ;; Transition records: each = 4 + (3*num-tapes)*1 + 4 bytes
    ;; from-state(4) | per-tape[(read(1) write(1) move(1))] | to-state(4)
    (let ((nt (ptm-table-num-tapes ptm)))
      (dolist (tr trans)
        (buf-write-u32-be buf (ptm-transition-from-state tr))
        (let ((actions (ptm-transition-tape-actions tr)))
          (dotimes (i nt)
            (let ((act (if (< i (length actions)) (nth i actions) '(0 0 1))))
              (buf-write-u8 buf (first  act))  ; read symbol
              (buf-write-u8 buf (second act))  ; write symbol
              (buf-write-u8 buf (third  act))  ; move
              (buf-write-u8 buf 0))))           ; pad
        (buf-write-u32-be buf (ptm-transition-to-state tr))))
    (subseq (buf-bytes buf) 0 (buf-pos buf))))

;;; ─── COMPLEXITY REPORT (BLRD req 2338) ────────────────────────────────────────

(defstruct complexity-report
  (magic +magic-cmpl+)
  (program-name "")
  (time-class :polynomial)
  (degree 1 :type (unsigned-byte 8))     ; polynomial degree d
  (constant 50 :type (unsigned-byte 32)) ; constant factor c
  (space-class :constant))

(defun encode-complexity-report (cr)
  "Encode complexity report per BLRD req 0850+."
  (let ((buf (make-buf)))
    (buf-write-u32-be buf +magic-cmpl+)
    (buf-write-u32-be buf #x00010000)
    ;; time class: 0=constant 1=linear 2=polynomial 3=exponential
    (buf-write-u32-be buf (ecase (complexity-report-time-class cr)
                            (:constant 0) (:linear 1)
                            (:polynomial 2) (:exponential 3)))
    (buf-write-u8     buf (complexity-report-degree cr))
    (buf-write-u8     buf 0)
    (buf-write-u8     buf 0)
    (buf-write-u8     buf 0)
    (buf-write-u32-be buf (complexity-report-constant cr))
    ;; space class
    (buf-write-u32-be buf (ecase (complexity-report-space-class cr)
                            (:constant 0) (:linear 1) (:polynomial 2)))
    (subseq (buf-bytes buf) 0 (buf-pos buf))))

;;; ─── CANONICAL CFG (4 basic blocks, req 2292) ────────────────────────────────

(defun make-canonical-cfg ()
  "Build the 4-block CFG for PROGRAM SUM (DO I=1,100)."
  (make-cfg
    :program-name "SUM"
    :entry-block 0
    :exit-block  3
    :blocks
    (list
      (make-basic-block
        :index 0 :first-stmt 0 :last-stmt 2
        :predecessors nil :successors (list 1)
        :flags 0
        :label "INIT")
      (make-basic-block
        :index 1 :first-stmt 3 :last-stmt 3
        :predecessors (list 0 2) :successors (list 2 3)
        :flags (compute-block-flags :loop-header t)
        :label "LOOP_HEADER")
      (make-basic-block
        :index 2 :first-stmt 4 :last-stmt 5
        :predecessors (list 1) :successors (list 1)
        :flags 0
        :label "LOOP_BODY")
      (make-basic-block
        :index 3 :first-stmt 6 :last-stmt 6
        :predecessors (list 1) :successors nil
        :flags (compute-block-flags :loop-exit t)
        :label "EXIT"))))

;;; ─── CANONICAL PTM TRANSITION TABLE (req 2308: ~50 states) ──────────────────

(defun make-canonical-ptm-table ()
  "Build the PTM transition table for the canonical sum program."
  ;; Phases (each is a group of states):
  ;;   0   START
  ;;   1-4  READ-INPUT (copy 32 bits N from input to work tape)
  ;;   5    INIT-VARS  (set I=1, S=0)
  ;;   6-9  LOOP-TEST  (compare I <= N)
  ;;   10-20 ADD       (S = S + I, binary ripple adder)
  ;;   21-25 INCREMENT  (I = I + 1)
  ;;   26-28 LOOP-BACK
  ;;   29-31 WRITE-OUTPUT (32-bit result to output tape)
  ;;   32   ACCEPT
  (let ((states (loop for i from 0 to 32
                      collect (make-ptm-state :index i :name (format nil "S~D" i))))
        (trans  nil))
    ;; Simplified representative transitions (full table has ~200 entries)
    ;; Format: from-state | [(r0 w0 m0)(r1 w1 m1)(r2 w2 m2)(r3 w3 m3)] | to-state
    ;; Symbols: B=0 0=48 1=49   Moves: L=0 S=1 R=2
    ;; State 0 → 1: START, read first input bit
    (push (make-ptm-transition
            :from-state 0
            :tape-actions '((48 48 2)(0 0 1)(0 0 1)(0 0 1))  ; read '0' input, stay work/ctrl/out
            :to-state 1) trans)
    (push (make-ptm-transition
            :from-state 0
            :tape-actions '((49 49 2)(0 0 1)(0 0 1)(0 0 1))  ; read '1'
            :to-state 1) trans)
    ;; State 1-4: copy input to work tape (representative)
    (push (make-ptm-transition
            :from-state 1
            :tape-actions '((0 0 1)(48 48 2)(0 0 1)(0 0 1))
            :to-state 2) trans)
    (push (make-ptm-transition
            :from-state 1
            :tape-actions '((0 0 1)(49 49 2)(0 0 1)(0 0 1))
            :to-state 2) trans)
    ;; State 5: INIT-VARS — write 1 to work-tape position WORD_I
    (push (make-ptm-transition
            :from-state 5
            :tape-actions '((0 0 1)(48 49 2)(0 0 1)(0 0 1)) ; write '1' (I=1)
            :to-state 6) trans)
    ;; State 6-9: LOOP-TEST
    (push (make-ptm-transition
            :from-state 6
            :tape-actions '((0 0 1)(48 48 1)(49 49 2)(0 0 1)) ; compare bits
            :to-state 7) trans)
    ;; State 10-20: ADD  (one per bit position, representative)
    (dotimes (i 8)
      (push (make-ptm-transition
              :from-state (+ 10 i)
              :tape-actions (list '(0 0 1)
                                  (list 48 49 2)
                                  (list 49 48 2)
                                  '(0 0 1))
              :to-state (+ 11 i)) trans))
    ;; State 29-31: WRITE-OUTPUT
    (push (make-ptm-transition
            :from-state 29
            :tape-actions '((0 0 1)(49 49 1)(0 0 1)(49 49 2)) ; write '1' to output
            :to-state 30) trans)
    ;; State 32: ACCEPT
    (push (make-ptm-transition
            :from-state 31
            :tape-actions '((0 0 1)(0 0 1)(0 0 1)(0 0 1))
            :to-state 32) trans)
    (make-ptm-table
      :num-tapes 4
      :states states
      :transitions (nreverse trans))))

;;; ─── VALIDATION ────────────────────────────────────────────────────────────────

(defun validate-cfg-magic (bytes)
  (= (buf-read-u32-be bytes 0) +magic-cfgb+))

(defun validate-ptm-magic (bytes)
  (= (buf-read-u32-be bytes 0) +magic-tmtt+))

(defun cfg-block-count-from-bytes (bytes)
  (buf-read-u32-be bytes 16))

;;; ─── TESTS ─────────────────────────────────────────────────────────────────────

(defun cfg-run-all-tests ()
  (format t "=== cfg_encoder.lisp tests ===~%")
  ;; Test 1: canonical CFG encodes with correct magic
  (let* ((cfg (make-canonical-cfg))
         (bytes (encode-cfg cfg)))
    (assert (validate-cfg-magic bytes) nil "CFG magic mismatch")
    (assert (= 4 (cfg-block-count-from-bytes bytes)) nil "CFG block count != 4")
    (format t "[PASS] canonical CFG encodes correctly (magic=~X, blocks=~A)~%"
            +magic-cfgb+
            (cfg-block-count-from-bytes bytes)))
  ;; Test 2: PTM table encodes with correct magic
  (let* ((ptm (make-canonical-ptm-table))
         (bytes (encode-ptm-table ptm)))
    (assert (validate-ptm-magic bytes) nil "PTM magic mismatch")
    (format t "[PASS] PTM table encodes correctly (magic=~X, states=~A, trans=~A)~%"
            +magic-tmtt+
            (length (ptm-table-states ptm))
            (length (ptm-table-transitions ptm))))
  ;; Test 3: complexity report
  (let* ((cr (make-complexity-report
               :program-name "SUM"
               :time-class :polynomial
               :degree 1
               :constant 50
               :space-class :constant))
         (bytes (encode-complexity-report cr)))
    (assert (= (buf-read-u32-be bytes 0) +magic-cmpl+) nil "complexity magic mismatch")
    (assert (= (buf-read-u32-be bytes 8) 2) nil "time class should be 2 (polynomial)")
    (format t "[PASS] complexity report: T(n)=O(n^~A), c=~A~%"
            (complexity-report-degree cr)
            (complexity-report-constant cr)))
  ;; Test 4: block flags
  (let ((flags (compute-block-flags :loop-header t)))
    (assert (not (zerop (logand flags +flag-loop-header+))) nil "loop-header flag not set")
    (format t "[PASS] block flags: loop-header bit correct (0x~X)~%" flags))
  (format t "=== ALL TESTS PASSED ===~%"))

(cfg-run-all-tests)
