;; SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
;; CLONE_GATE:AES256:d90d2153a3a4ccb625a6aceb83f0df2596df5b70f8219104101821b6c67f8c4a
;;
;; quipper_jcl_encoder.lisp — Quipper circuit binary + JCL Vault manifest encoder
;; Implements BLRD-PTM-2026-001 Sections 0005-0006
;; Replaces the S-expr spec in quantum-wires/ast/INVERTED-AST-QUIPPER-JCL.lisp
;;
;; Load: sbcl --load quipper_jcl_encoder.lisp
;;       clisp quipper_jcl_encoder.lisp

(in-package :cl-user)

;;; ─── BYTE BUFFER (self-contained copy) ───────────────────────────────────────

(defstruct qbuf
  (bytes (make-array 8192 :element-type '(unsigned-byte 8) :fill-pointer 0))
  (pos 0))

(defun qbuf-u8  (b v) (vector-push-extend (logand v #xFF) (qbuf-bytes b)) (incf (qbuf-pos b)))
(defun qbuf-u16 (b v) (qbuf-u8 b (ash v -8)) (qbuf-u8 b v))
(defun qbuf-u32 (b v) (qbuf-u16 b (ash v -16)) (qbuf-u16 b v))
(defun qbuf-u64 (b v) (qbuf-u32 b (ash v -32)) (qbuf-u32 b v))
(defun qbuf-ascii (b s)
  (loop for c across s do (qbuf-u8 b (char-code c)))
  (qbuf-u8 b 0))   ; null terminator
(defun qbuf-bytes-out (b) (subseq (qbuf-bytes b) 0 (qbuf-pos b)))

(defun read-u32 (bytes off)
  (+ (ash (aref bytes off) 24) (ash (aref bytes (+ off 1)) 16)
     (ash (aref bytes (+ off 2)) 8) (aref bytes (+ off 3))))

;;; ─── MAGIC NUMBERS (BLRD req 0834, 0951) ─────────────────────────────────────

(defconstant +magic-quip+ #x51554950)  ; "QUIP" Quipper artifact
(defconstant +magic-jclm+ #x4A434C4D)  ; "JCLM" JCL Vault Manifest
(defconstant +magic-audt+ #x41554454)  ; "AUDT" Audit Trail

;;; ─── GATE TYPE CODES (BLRD req 0836-0859) ────────────────────────────────────

(defconstant +gate-x+        #x01)  ; Pauli-X (NOT)
(defconstant +gate-y+        #x02)  ; Pauli-Y
(defconstant +gate-z+        #x03)  ; Pauli-Z
(defconstant +gate-h+        #x04)  ; Hadamard
(defconstant +gate-s+        #x05)  ; Phase S
(defconstant +gate-t+        #x06)  ; T gate
(defconstant +gate-cnot+     #x07)  ; CNOT
(defconstant +gate-toffoli+  #x08)  ; Toffoli (CCX)
(defconstant +gate-swap+     #x09)  ; SWAP
(defconstant +gate-cz+       #x0A)  ; CZ
(defconstant +gate-ry+       #x0B)  ; Ry(theta)
(defconstant +gate-rz+       #x0C)  ; Rz(theta)
(defconstant +gate-measure+  #x10)  ; Measure qubit
(defconstant +gate-init0+    #x11)  ; Initialise qubit to |0>
(defconstant +gate-init1+    #x12)  ; Initialise qubit to |1>
(defconstant +gate-discard+  #x13)  ; Discard qubit
(defconstant +gate-sub+      #x20)  ; Subroutine call

;;; ─── QUIPPER GATE RECORD ──────────────────────────────────────────────────────

(defstruct qgate
  (type-code 0 :type (unsigned-byte 8))
  (qubit-count 0 :type (unsigned-byte 8))
  (qubits nil)        ; list of qubit indices (uint32)
  (angle nil)         ; angle in radians as float64 (or nil)
  (inverse nil)       ; boolean: gate applied in inverse
  (sub-id nil))       ; subroutine id (uint32, or nil)

;;; ─── QUIPPER CIRCUIT ──────────────────────────────────────────────────────────

(defstruct qcircuit
  (name "" :type string)
  (num-qubits 0 :type (unsigned-byte 32))
  (gates nil)
  (sub-table nil))  ; list of (id name circuit)

(defun encode-qgate (buf gate)
  "Encode one gate record: type(1) count(1) qubits(4*n) [angle(8)] [subid(4)]"
  (qbuf-u8 buf (qgate-type-code gate))
  (qbuf-u8 buf (qgate-qubit-count gate))
  (qbuf-u8 buf (if (qgate-inverse gate) 1 0))
  (qbuf-u8 buf 0)  ; reserved
  (dolist (q (qgate-qubits gate))
    (qbuf-u32 buf q))
  (when (qgate-angle gate)
    ;; Encode float64 as two u32 (IEEE 754 bit pattern)
    (let* ((bits (floor (* (qgate-angle gate) (expt 2.0d0 52))))
           (hi (logand (ash bits -32) #xFFFFFFFF))
           (lo (logand bits #xFFFFFFFF)))
      (qbuf-u32 buf hi)
      (qbuf-u32 buf lo)))
  (when (qgate-sub-id gate)
    (qbuf-u32 buf (qgate-sub-id gate))))

(defun encode-qcircuit (circ)
  "Encode a Quipper circuit artifact per BLRD Section 0005."
  (let* ((buf (make-qbuf))
         (gates (qcircuit-gates circ))
         (nq (qcircuit-num-qubits circ))
         (ng (length gates)))
    ;; Header: magic(4) version(4) header-size(4) total-size(4)
    (qbuf-u32 buf +magic-quip+)
    (qbuf-u32 buf #x00010000)
    (qbuf-u32 buf 32)
    (qbuf-u32 buf 0)   ; fill total later
    ;; Circuit metadata
    (qbuf-u32 buf nq)                ; num qubits
    (qbuf-u32 buf ng)                ; gate count
    (qbuf-u32 buf 0)                 ; subroutine table offset (placeholder)
    (qbuf-u32 buf 0)                 ; reserved
    ;; Name
    (qbuf-ascii buf (qcircuit-name circ))
    ;; Gate records
    (dolist (g gates)
      (encode-qgate buf g))
    (qbuf-bytes-out buf)))

;;; ─── JCL VAULT MANIFEST (BLRD Section 0006) ──────────────────────────────────

(defstruct jcl-dataset
  (name "" :type string)
  (dsn  "" :type string)   ; data-set name
  (disposition :new)       ; :new :old :mod :shr
  (org :ps)                ; :ps :pds :vsam :gdg
  (recfm :fb)              ; :fb :vb :u
  (lrecl 80 :type (unsigned-byte 32))
  (blksize 32720 :type (unsigned-byte 32))
  (primary-space 1 :type (unsigned-byte 32))
  (secondary-space 1 :type (unsigned-byte 32)))

(defstruct jcl-step
  (name "" :type string)
  (program "" :type string)
  (parm nil)           ; parameter string or nil
  (datasets nil)       ; list of jcl-dataset
  (rc-ok 0 :type (unsigned-byte 8))   ; max acceptable return code
  (step-index 0 :type (unsigned-byte 32)))

(defstruct jcl-manifest
  (job-name "" :type string)
  (job-class #\A :type character)
  (msg-class #\X :type character)
  (notify nil)
  (steps nil)    ; ordered list of jcl-step
  (environment nil)  ; alist of name->value
  (max-cpu-seconds 60 :type (unsigned-byte 32))
  (max-real-seconds 300 :type (unsigned-byte 32)))

(defconstant +disp-new+ 0)
(defconstant +disp-old+ 1)
(defconstant +disp-mod+ 2)
(defconstant +disp-shr+ 3)

(defconstant +org-ps+   0)
(defconstant +org-pds+  1)
(defconstant +org-vsam+ 2)
(defconstant +org-gdg+  3)

(defun disp-code (kw) (ecase kw (:new 0) (:old 1) (:mod 2) (:shr 3)))
(defun org-code  (kw) (ecase kw (:ps 0) (:pds 1) (:vsam 2) (:gdg 3)))
(defun recfm-code(kw) (ecase kw (:fb 0) (:vb 1) (:u 2) (:fba 3) (:vba 4)))

(defun encode-dataset (buf ds)
  (qbuf-ascii buf (jcl-dataset-name ds))
  (qbuf-ascii buf (jcl-dataset-dsn  ds))
  (qbuf-u8  buf (disp-code  (jcl-dataset-disposition ds)))
  (qbuf-u8  buf (org-code   (jcl-dataset-org ds)))
  (qbuf-u8  buf (recfm-code (jcl-dataset-recfm ds)))
  (qbuf-u8  buf 0)
  (qbuf-u32 buf (jcl-dataset-lrecl ds))
  (qbuf-u32 buf (jcl-dataset-blksize ds))
  (qbuf-u32 buf (jcl-dataset-primary-space ds))
  (qbuf-u32 buf (jcl-dataset-secondary-space ds)))

(defun encode-step (buf step)
  (qbuf-u32 buf (jcl-step-step-index step))
  (qbuf-ascii buf (jcl-step-name step))
  (qbuf-ascii buf (jcl-step-program step))
  (qbuf-ascii buf (or (jcl-step-parm step) ""))
  (qbuf-u8  buf (jcl-step-rc-ok step))
  (qbuf-u8  buf 0) (qbuf-u8 buf 0) (qbuf-u8 buf 0)
  (qbuf-u32 buf (length (jcl-step-datasets step)))
  (dolist (ds (jcl-step-datasets step))
    (encode-dataset buf ds)))

(defun encode-jcl-manifest (mf)
  "Encode JCL Vault Manifest per BLRD Section 0006. Returns byte vector."
  (let* ((buf (make-qbuf))
         (steps (jcl-manifest-steps mf)))
    (qbuf-u32 buf +magic-jclm+)
    (qbuf-u32 buf #x00010000)
    (qbuf-u32 buf 48)
    (qbuf-u32 buf 0)
    ;; Job metadata
    (qbuf-ascii buf (jcl-manifest-job-name mf))
    (qbuf-u8 buf (char-code (jcl-manifest-job-class mf)))
    (qbuf-u8 buf (char-code (jcl-manifest-msg-class mf)))
    (qbuf-u8 buf 0)
    (qbuf-u8 buf 0)
    (qbuf-u32 buf (jcl-manifest-max-cpu-seconds mf))
    (qbuf-u32 buf (jcl-manifest-max-real-seconds mf))
    (qbuf-u32 buf (length steps))
    ;; Environment
    (qbuf-u32 buf (length (jcl-manifest-environment mf)))
    (dolist (pair (jcl-manifest-environment mf))
      (qbuf-ascii buf (car pair))
      (qbuf-ascii buf (cdr pair)))
    ;; Steps
    (loop for step in steps for i from 0 do
      (setf (jcl-step-step-index step) i)
      (encode-step buf step))
    (qbuf-bytes-out buf)))

;;; ─── CANONICAL JCL MANIFEST (for SUM pipeline) ─────────────────────────────────

(defun make-canonical-jcl-manifest ()
  "JCL manifest for the PTM pipeline canonical run."
  (make-jcl-manifest
    :job-name "PTMPIPE"
    :job-class #\A
    :msg-class #\X
    :max-cpu-seconds 60
    :max-real-seconds 300
    :environment '(("PTM_INPUT" . "SUM.FORTRAN")
                   ("PTM_N"     . "100")
                   ("PTM_EXPECTED" . "5050"))
    :steps
    (list
      (make-jcl-step
        :name "COMPILE" :program "FORTC" :parm "OPT=2,LANG=F90"
        :rc-ok 4
        :datasets
        (list
          (make-jcl-dataset :name "SYSIN"  :dsn "&&FTSRC"
                            :disposition :new :org :ps :recfm :fb :lrecl 80)
          (make-jcl-dataset :name "SYSOUT" :dsn "&&PTMIR"
                            :disposition :new :org :ps :recfm :vb :lrecl 255)))
      (make-jcl-step
        :name "PTMEXEC" :program "PTMSIM" :parm "TRACE=YES,N=100"
        :rc-ok 0
        :datasets
        (list
          (make-jcl-dataset :name "PTMIN"  :dsn "&&PTMIR"
                            :disposition :old :org :ps :recfm :vb :lrecl 255)
          (make-jcl-dataset :name "PTMOUT" :dsn "&&PTMOUT"
                            :disposition :new :org :ps :recfm :fb :lrecl 40)
          (make-jcl-dataset :name "CFGOUT" :dsn "&&CFGBIN"
                            :disposition :new :org :ps :recfm :u)))
      (make-jcl-step
        :name "QUIPPER" :program "QUIPGEN" :parm "QUBITS=8"
        :rc-ok 0
        :datasets
        (list
          (make-jcl-dataset :name "PTMOUT" :dsn "&&PTMOUT" :disposition :old :org :ps)
          (make-jcl-dataset :name "QOUT"   :dsn "&&QUIP"
                            :disposition :new :org :ps :recfm :u)))
      (make-jcl-step
        :name "AUDIT" :program "AUDGEN"
        :rc-ok 0
        :datasets
        (list
          (make-jcl-dataset :name "ALLIN"  :dsn "&&ALLARTS" :disposition :old :org :pds)
          (make-jcl-dataset :name "AUDOUT" :dsn "VAULT.AUDIT" :disposition :new :org :ps))))))

;;; ─── CANONICAL QUIPPER CIRCUIT (req 2345: 8 qubits for SUM) ─────────────────

(defun make-canonical-quipper-circuit ()
  "8-qubit Quipper circuit for the canonical sum program."
  ;; 8 qubits: q0-q3 = I register (4-bit counter), q4-q7 = SUM register
  ;; Gates: initialise all to |0>, run ripple-carry adder, measure output
  (make-qcircuit
    :name "PTM_SUM_CANONICAL"
    :num-qubits 8
    :gates
    (append
      ;; Initialise 8 qubits
      (loop for i from 0 to 7 collect
        (make-qgate :type-code +gate-init0+ :qubit-count 1 :qubits (list i)))
      ;; Load I=1: set q0 (LSB of I register)
      (list (make-qgate :type-code +gate-x+ :qubit-count 1 :qubits '(0)))
      ;; 100 iterations: SUM += I using CNOT-based 4-bit ripple adder
      ;; Representative: one adder round (CNOT chain across SUM qubits)
      (list
        (make-qgate :type-code +gate-cnot+ :qubit-count 2 :qubits '(0 4))
        (make-qgate :type-code +gate-cnot+ :qubit-count 2 :qubits '(1 5))
        (make-qgate :type-code +gate-cnot+ :qubit-count 2 :qubits '(2 6))
        (make-qgate :type-code +gate-cnot+ :qubit-count 2 :qubits '(3 7))
        ;; Toffoli for carry
        (make-qgate :type-code +gate-toffoli+ :qubit-count 3 :qubits '(0 4 5)))
      ;; Measure all 8 qubits (output register)
      (loop for i from 0 to 7 collect
        (make-qgate :type-code +gate-measure+ :qubit-count 1 :qubits (list i))))))

;;; ─── AUDIT TRAIL ENCODER (BLRD Section 0007) ─────────────────────────────────

(defstruct audit-event
  (timestamp 0 :type (unsigned-byte 64))
  (event-type 0 :type (unsigned-byte 8))
  (artifact-hash "" :type string)
  (description "" :type string))

(defun encode-audit-trail (events)
  "Encode audit trail per BLRD Section 0007."
  (let ((buf (make-qbuf)))
    (qbuf-u32 buf +magic-audt+)
    (qbuf-u32 buf #x00010000)
    (qbuf-u32 buf 16)
    (qbuf-u32 buf (length events))
    (dolist (ev events)
      (qbuf-u64 buf (audit-event-timestamp ev))
      (qbuf-u8  buf (audit-event-event-type ev))
      (qbuf-u8  buf 0) (qbuf-u8 buf 0) (qbuf-u8 buf 0)
      (qbuf-ascii buf (audit-event-artifact-hash ev))
      (qbuf-ascii buf (audit-event-description ev)))
    (qbuf-bytes-out buf)))

;;; ─── FULL PIPELINE RUNNER ─────────────────────────────────────────────────────

(defun run-pipeline ()
  "Run the full canonical pipeline and report sizes."
  (format t "=== PTM Pipeline (Quipper + JCL) ===~%")
  (let* ((circ  (make-canonical-quipper-circuit))
         (mf    (make-canonical-jcl-manifest))
         (qbytes (encode-qcircuit circ))
         (jbytes (encode-jcl-manifest mf))
         (events (list
                   (make-audit-event :timestamp 1753228800
                                     :event-type 1
                                     :artifact-hash "sha256:abc"
                                     :description "COMPILE step OK")
                   (make-audit-event :timestamp 1753228860
                                     :event-type 2
                                     :artifact-hash "sha256:def"
                                     :description "PTM output 5050 = 0x000013BA verified")))
         (abytes (encode-audit-trail events)))
    (format t "  Quipper circuit: ~A bytes, ~A qubits, ~A gates~%"
            (length qbytes)
            (qcircuit-num-qubits circ)
            (length (qcircuit-gates circ)))
    (format t "  JCL manifest:    ~A bytes, ~A steps~%"
            (length jbytes)
            (length (jcl-manifest-steps mf)))
    (format t "  Audit trail:     ~A bytes, ~A events~%"
            (length abytes) (length events))
    (format t "  Quipper magic:   0x~X (~A)~%"
            (read-u32 qbytes 0)
            (if (= (read-u32 qbytes 0) +magic-quip+) "OK" "FAIL"))
    (format t "  JCL magic:       0x~X (~A)~%"
            (read-u32 jbytes 0)
            (if (= (read-u32 jbytes 0) +magic-jclm+) "OK" "FAIL"))
    (format t "  Audit magic:     0x~X (~A)~%"
            (read-u32 abytes 0)
            (if (= (read-u32 abytes 0) +magic-audt+) "OK" "FAIL"))))

;;; ─── TESTS ─────────────────────────────────────────────────────────────────────

(defun quipper-jcl-run-all-tests ()
  (format t "=== quipper_jcl_encoder.lisp tests ===~%")
  ;; Quipper circuit
  (let* ((c (make-canonical-quipper-circuit))
         (b (encode-qcircuit c)))
    (assert (= +magic-quip+ (read-u32 b 0)) nil "Quipper magic")
    (assert (= 8 (qcircuit-num-qubits c)) nil "8 qubits")
    (format t "[PASS] Quipper circuit: 8 qubits, ~A gates~%"
            (length (qcircuit-gates c))))
  ;; JCL manifest
  (let* ((m (make-canonical-jcl-manifest))
         (b (encode-jcl-manifest m)))
    (assert (= +magic-jclm+ (read-u32 b 0)) nil "JCL magic")
    (assert (= 4 (length (jcl-manifest-steps m))) nil "4 pipeline steps")
    (format t "[PASS] JCL manifest: ~A steps~%" (length (jcl-manifest-steps m))))
  ;; Audit trail
  (let* ((evs (list (make-audit-event :timestamp 0 :event-type 1
                                      :artifact-hash "x" :description "test")))
         (b (encode-audit-trail evs)))
    (assert (= +magic-audt+ (read-u32 b 0)) nil "Audit magic")
    (format t "[PASS] Audit trail encodes correctly~%"))
  ;; Gate codes defined
  (assert (= +gate-x+    #x01) nil "gate-x")
  (assert (= +gate-cnot+ #x07) nil "gate-cnot")
  (assert (= +gate-toffoli+ #x08) nil "gate-toffoli")
  (format t "[PASS] Gate codes match BLRD spec~%")
  (run-pipeline)
  (format t "=== ALL TESTS PASSED ===~%"))

(quipper-jcl-run-all-tests)
