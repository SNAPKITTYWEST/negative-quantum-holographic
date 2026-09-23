#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later OR Apache-2.0
# CLONE_GATE:AES256:6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b
#
# run-liquid.sh — LiquidHaskell refinement checker for SupremeKernel.hs
# Author: Ahmad <ahmedparr93@gmail.com>
#
# Requires: GHC 9.x, liquidhaskell
#   cabal install liquidhaskell
#   or: stack install liquidhaskell

set -euo pipefail

FILE="${1:-resonance_masonry/haskell/SupremeKernel.hs}"

echo "=== LiquidHaskell check: $FILE ==="
echo ""

liquid "$FILE" 2>&1 | tee liquid.out

echo ""
echo "=== result ==="
grep -E '(SAFE|UNSAFE|Result|Liquid Type Errors)' liquid.out || echo "(no result line)"

echo ""
echo "Expected:"
echo "  attention     : SAFE  — 0 <= r <= 1 (normalized sum)"
echo "  supremeKernel : SAFE  — 0 <= r <= 1 (attention * {0,1} gate)"
echo "  gcdEuclid     : SAFE  — terminates on Nat / [b]"
