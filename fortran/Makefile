# SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
# Fortran PTM pipeline build

FC      = gfortran
FFLAGS  = -O2 -Wall -std=f2003

all: sum_canonical ptm_pipeline

sum_canonical: sum_canonical.f90
	$(FC) $(FFLAGS) -o sum_canonical sum_canonical.f90

ptm_pipeline: ptm.f90
	$(FC) $(FFLAGS) -o ptm_pipeline ptm.f90

test: all
	@echo "--- sum_canonical ---"
	./sum_canonical
	@echo "--- ptm_pipeline ---"
	./ptm_pipeline

clean:
	rm -f sum_canonical ptm_pipeline *.mod *.o

.PHONY: all test clean
