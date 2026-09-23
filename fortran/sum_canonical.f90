! SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
! CLONE_GATE:AES256:1b4f0e9851971998e732078544c96b36c3d01cedf7caa332359d6f1d83567014
!
! sum_canonical.f90 — Canonical Fortran source: PROGRAM SUM
! BLRD-PTM-2026-001 Section 0011, req 1790:
!   PROGRAM SUM; INTEGER I, SUM; SUM = 0;
!   DO I = 1, 100; SUM = SUM + I; END DO; END PROGRAM SUM
!
! Expected output: 5050 = 0x000013BA
! Compile: gfortran -o sum_canonical sum_canonical.f90
! Run:     ./sum_canonical

PROGRAM SUM
  IMPLICIT NONE
  INTEGER :: I, S
  S = 0
  DO I = 1, 100
    S = S + I
  END DO
  WRITE(*,'(A,I0,A,Z8.8,A)') 'SUM(1..100) = ', S, '  hex = 0x', S, ''
  IF (S .EQ. 5050) THEN
    WRITE(*,'(A)') 'CANONICAL VERIFICATION: PASS  (5050 = 0x000013BA)'
  ELSE
    WRITE(*,'(A,I0)') 'CANONICAL VERIFICATION: FAIL  got ', S
    STOP 1
  END IF
END PROGRAM SUM
