#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
# CLONE_GATE:AES256:4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f
#
# run-alloy.sh — Batch Alloy checker for resonance.als
# Author: Ahmad <ahmedparr93@gmail.com>
#
# Usage: ./run-alloy.sh [model.als]
# Requires: Java 11+, Alloy 6.2.0 jar
#
# Download jar:
#   wget https://github.com/AlloyTools/org.alloytools.alloy/releases/download/v6.2.0/org.alloytools.alloy.dist.jar

set -euo pipefail

ALLOY_JAR="${ALLOY_JAR:-org.alloytools.alloy.dist.jar}"
MODEL="${1:-resonance_masonry/alloy/resonance.als}"
SOLVER="${SOLVER:-sat4j}"

if [[ ! -f "$ALLOY_JAR" ]]; then
  echo "ERROR: Alloy jar not found at '$ALLOY_JAR'" >&2
  echo "Set ALLOY_JAR=/path/to/org.alloytools.alloy.dist.jar" >&2
  echo "Download v6.2.0: https://github.com/AlloyTools/org.alloytools.alloy/releases" >&2
  exit 1
fi

echo "=== Alloy batch check: $MODEL ==="
echo "Solver: $SOLVER"
echo ""

java -jar "$ALLOY_JAR" -batch -solver "$SOLVER" "$MODEL" 2>&1 | tee alloy.out

echo ""
echo "=== parsed results ==="
grep -E '(No counterexample found|Counterexample found|No instance found|Instance found|UNSAT|SAT)' \
     alloy.out || echo "(no result lines found — check alloy.out)"

echo ""
echo "Expected results for resonance.als:"
echo "  PsiLightCounterexample       run  → Instance found (Branch B witness)"
echo "  L1_PsiPreservesLight_NonEmpty check → No counterexample found (Branch A holds)"
echo "  L1_PsiPreservesLight_AnyGeo  check → Counterexample found (Branch B falsifiable)"
echo "  NoDarkCrossing               check → No counterexample found"
echo "  GodModeNotExempt             check → Counterexample found (privilege ≠ CARE)"
echo "  AuthorizedSyscallPreservesCare check → No counterexample found"
