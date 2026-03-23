#!/bin/bash
#
# test.sh - Test script for wpSBOOT
# https://github.com/changlabtw/wpSBOOT
#
# Runs the wpSBOOT pipeline on the included YPL070W example data (7 alignments)
# and verifies that all expected output files are produced.
#
# Usage:
#   ./test.sh           # quick test (10 bootstrap replicates)
#   ./test.sh --full    # full test  (default N x 100 replicates)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
EXAMPLE_DIR="$SCRIPT_DIR/example/alignments"
TEST_OUT="$SCRIPT_DIR/test_output"

# Parse --full flag
FULL_RUN=0
[[ "${1:-}" == "--full" ]] && FULL_RUN=1

# --- Colours for output ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAILURES=$((FAILURES+1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

FAILURES=0

echo "========================================"
echo " wpSBOOT test"
echo "========================================"

# -----------------------------------------------
# 1. Check dependencies
# -----------------------------------------------
info "Checking dependencies..."

check_tool() {
    local name=$1
    local path=$2
    if [[ -x "$path" ]]; then
        pass "$name found: $path"
    elif command -v "$name" &>/dev/null; then
        pass "$name found in PATH: $(command -v "$name")"
    else
        fail "$name not found (checked $path and PATH)"
    fi
}

check_tool "t_coffee"  "$BIN_DIR/t_coffee"
check_tool "raxml-ng"  "$BIN_DIR/raxml-ng"
check_tool "wei_seqboot" "$BIN_DIR/wei_seqboot"
PERL_BIN="$(command -v perl 2>/dev/null || echo '/usr/bin/perl')"
check_tool "perl" "$PERL_BIN"

# Check BioPerl modules required by concatenate.pl (use the same perl found in PATH)
info "Checking BioPerl modules..."
"$PERL_BIN" -e "use Bio::AlignIO; use Bio::Align::Utilities; use Bio::LocatableSeq;" 2>/dev/null \
    && pass "BioPerl modules available" \
    || fail "BioPerl modules missing (Bio::AlignIO, Bio::Align::Utilities, Bio::LocatableSeq)"

# -----------------------------------------------
# 2. Check example data
# -----------------------------------------------
info "Checking example alignments..."
EXPECTED_ALNS=(
    clustalw_YPL070W.fasta
    DCA_YPL070W.fasta
    dialign_YPL070W.fasta
    mafft_YPL070W.fasta
    muscle_YPL070W.fasta
    probcons_YPL070W.fasta
    tcoffee_YPL070W.fasta
)
for f in "${EXPECTED_ALNS[@]}"; do
    [[ -f "$EXAMPLE_DIR/$f" ]] \
        && pass "Found $f" \
        || fail "Missing $f in $EXAMPLE_DIR"
done

# Bail early if dependencies or data are missing
if [[ $FAILURES -gt 0 ]]; then
    echo ""
    echo -e "${RED}$FAILURES pre-flight check(s) failed. Please fix before running the pipeline.${NC}"
    exit 1
fi

# -----------------------------------------------
# 3. Run the pipeline
# -----------------------------------------------
echo ""
if [[ $FULL_RUN -eq 1 ]]; then
    info "Running FULL test (default bootstrap replicates)..."
    BOOT_OPT=""
else
    info "Running QUICK test (10 bootstrap replicates; use --full for complete run)..."
    BOOT_OPT="-n 10"
fi

# Clean up any previous test output
rm -rf "$TEST_OUT"

# Collect all example alignments into an array of -i arguments
ALN_ARGS=()
for f in "${EXPECTED_ALNS[@]}"; do
    ALN_ARGS+=("-i" "$EXAMPLE_DIR/$f")
done

# Run wpSBOOT
bash "$SCRIPT_DIR/scripts/wpsboot.sh" \
    "${ALN_ARGS[@]}" \
    -o "$TEST_OUT" \
    $BOOT_OPT

# -----------------------------------------------
# 4. Verify outputs
# -----------------------------------------------
echo ""
info "Verifying outputs..."

check_file() {
    local desc=$1
    local path=$2
    if [[ -s "$path" ]]; then
        pass "$desc: $(basename "$path")"
    else
        fail "$desc not found or empty: $path"
    fi
}

check_file "Similarity table"    "$TEST_OUT/01_similarity/similarity.csv"
check_file "Super-MSA (PHYLIP)"  "$TEST_OUT/02_superMSA/super_aln.phylip"
check_file "Site weights"        "$TEST_OUT/02_superMSA/site_weights.txt"
check_file "Bootstrap outfile"   "$TEST_OUT/03_bootstrap/outfile"
check_file "ML tree"             "$TEST_OUT/04_ml_tree/ml_tree.raxml.bestTree"
check_file "Bootstrap trees"     "$TEST_OUT/05_boot_trees/bootstrap_trees.nwk"
check_file "Final support tree"  "$TEST_OUT/wpSBOOT_result.nwk"

# -----------------------------------------------
# 5. Summary
# -----------------------------------------------
echo ""
echo "========================================"
if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}All checks passed.${NC}"
    echo "Final result: $TEST_OUT/wpSBOOT_result.nwk"
else
    echo -e "${RED}$FAILURES check(s) failed.${NC}"
    exit 1
fi
echo "========================================"
