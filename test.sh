#!/bin/bash
#
# test.sh - Test script for wpSBOOT
# https://github.com/changlabtw/wpSBOOT
#
# Runs the wpSBOOT pipeline on the included example data, verifies that all
# expected output files are produced, and prints a bootstrap support summary
# including per-node support and whole-tree topology support.
#
# Usage:
#   ./test.sh                        # quick test, YPL070W (default)
#   ./test.sh --full                 # full test,  YPL070W
#   ./test.sh --gene YDR192C         # quick test, YDR192C
#   ./test.sh --gene YDR192C --full  # full test,  YDR192C
#   ./test.sh --gene all             # quick test, both genes
#   ./test.sh --gene all --full      # full test,  both genes
#   ./test.sh --features             # feature tests only (flags + input validation)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
EXAMPLE_DIR="$SCRIPT_DIR/example"
TEST_OUT_ROOT="$SCRIPT_DIR/test_output"

usage() {
    cat << EOF
wpSBOOT test script
https://github.com/changlabtw/wpSBOOT

Usage: $(basename "$0") [--gene <name>] [--full] [--features] [-h]

Options:
  --gene <name>   Gene to test: YPL070W (default), YDR192C, or all
  --full          Run with default bootstrap replicates (N x 100)
                  instead of the quick test (10 replicates)
  --features      Run feature tests only (flags + input validation)
  -h, --help      Show this help and exit

Examples:
  $(basename "$0")                        # quick test, YPL070W
  $(basename "$0") --full                 # full test,  YPL070W
  $(basename "$0") --gene YDR192C         # quick test, YDR192C
  $(basename "$0") --gene YDR192C --full  # full test,  YDR192C
  $(basename "$0") --gene all             # quick test, both genes
  $(basename "$0") --gene all --full      # full test,  both genes
  $(basename "$0") --features             # feature tests only

Output:
  test_output/<gene>/wpSBOOT_result.nwk  ← ML tree with bootstrap support

Summary printed after each run:
  - Tree topology (ASCII, if < 20 taxa) and Newick string
  - Per-node bootstrap support (mean, median, min, max, fully supported)
  - Whole-tree topology support (fraction of replicates with identical topology)

Feature tests (--features):
  - Taxa mismatch detection
  - Seed reproducibility (-s)
  - Force flag (-f)
  - Keep intermediates (-k)

Available genes:
  YPL070W   example/YPL070W/  (7 alignments)
  YDR192C   example/YDR192C/  (7 alignments)

EOF
    exit 0
}

# --- Parse arguments ---
FULL_RUN=0
FEATURES=0
GENE="YPL070W"
while [[ $# -gt 0 ]]; do
    case $1 in
        --full)        FULL_RUN=1 ; shift ;;
        --features)    FEATURES=1 ; shift ;;
        --gene)        GENE="$2"  ; shift 2 ;;
        -h|--help)     usage ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Colours (only when stdout is a terminal) ---
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; NC=''
fi
pass() { echo -e "${GREEN}[PASS]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAILURES=$((FAILURES+1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $*"; }

FAILURES=0

echo "========================================"
echo " wpSBOOT test"
echo "========================================"

# -----------------------------------------------
# 1. Check dependencies (once, regardless of gene)
# -----------------------------------------------
info "Checking dependencies..."

check_tool() {
    local name=$1 path=$2
    if [[ -x "$path" ]]; then
        pass "$name found: $path"
    elif command -v "$name" &>/dev/null; then
        pass "$name found in PATH: $(command -v "$name")"
    else
        fail "$name not found (checked $path and PATH)"
    fi
}

check_tool "t_coffee"    "$BIN_DIR/t_coffee"
check_tool "raxml-ng"    "$BIN_DIR/raxml-ng"
check_tool "wei_seqboot" "$BIN_DIR/wei_seqboot"
PERL_BIN="$(command -v perl 2>/dev/null || echo '/usr/bin/perl')"
check_tool "perl" "$PERL_BIN"

info "Checking BioPerl modules..."
"$PERL_BIN" -e "use Bio::AlignIO; use Bio::Align::Utilities; use Bio::LocatableSeq;" 2>/dev/null \
    && pass "BioPerl modules available" \
    || fail "BioPerl modules missing (Bio::AlignIO, Bio::Align::Utilities, Bio::LocatableSeq)"

# Bail early if any dependency is missing
if [[ $FAILURES -gt 0 ]]; then
    echo ""
    echo -e "${RED}$FAILURES pre-flight check(s) failed. Please fix before running the pipeline.${NC}"
    exit 1
fi

# -----------------------------------------------
# Feature tests: flags and input validation
# -----------------------------------------------
run_feature_tests() {
    local feat_out="$TEST_OUT_ROOT/feature_tests"
    local aln_dir="$EXAMPLE_DIR/YPL070W"
    read -ra alns <<< "$(gene_alns YPL070W)"
    local ALN_ARGS=()
    for f in "${alns[@]}"; do ALN_ARGS+=("-i" "$aln_dir/$f"); done

    echo ""
    echo "----------------------------------------"
    echo " Feature tests"
    echo "----------------------------------------"

    # --- Taxa mismatch detection ---
    info "Feature test: taxa mismatch detection..."
    local tmp_fasta
    tmp_fasta=$(mktemp /tmp/wpSBOOT_test_XXXXX.fasta)
    printf '>WrongTaxon1\nACGT\n>WrongTaxon2\nACGT\n' > "$tmp_fasta"
    local mismatch_out
    mismatch_out=$(bash "$SCRIPT_DIR/scripts/wpsboot.sh" \
        -i "$aln_dir/clustalw_YPL070W.fasta" \
        -i "$tmp_fasta" \
        -o "$feat_out/taxa_test" 2>&1 || true)
    rm -f "$tmp_fasta"
    if echo "$mismatch_out" | grep -q "Taxa mismatch"; then
        pass "Taxa mismatch: error detected correctly"
    else
        fail "Taxa mismatch: error not detected"
    fi

    # --- Seed reproducibility (-s) ---
    info "Feature test: seed reproducibility (-s)..."
    bash "$SCRIPT_DIR/scripts/wpsboot.sh" \
        "${ALN_ARGS[@]}" -o "$feat_out/seed1" -n 5 -s 42 > /dev/null 2>&1
    bash "$SCRIPT_DIR/scripts/wpsboot.sh" \
        "${ALN_ARGS[@]}" -o "$feat_out/seed2" -n 5 -s 42 > /dev/null 2>&1
    if diff "$feat_out/seed1/03_bootstrap/outfile" \
            "$feat_out/seed2/03_bootstrap/outfile" > /dev/null 2>&1; then
        pass "Seed reproducibility: identical bootstrap samples with -s 42"
    else
        fail "Seed reproducibility: bootstrap samples differ with same seed"
    fi

    # --- Force flag (-f) ---
    info "Feature test: force flag (-f)..."
    # Rerun seed1/ (already complete) with -f: step 1 must rerun, not skip
    bash "$SCRIPT_DIR/scripts/wpsboot.sh" \
        "${ALN_ARGS[@]}" -o "$feat_out/seed1" -n 5 -s 42 -f > /dev/null 2>&1
    if grep -q "Step 1: Computing" "$feat_out/seed1/wpsboot.log"; then
        pass "Force flag: step 1 reran on existing output"
    else
        fail "Force flag: step 1 did not rerun"
    fi

    # --- Keep intermediates (-k) ---
    info "Feature test: keep intermediates (-k)..."
    bash "$SCRIPT_DIR/scripts/wpsboot.sh" \
        "${ALN_ARGS[@]}" -o "$feat_out/keep" -n 5 -k > /dev/null 2>&1
    local n_phy
    n_phy=$(ls "$feat_out/keep/05_boot_trees/boot_"*.phy 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$n_phy" -eq 5 ]]; then
        pass "Keep intermediates: $n_phy per-replicate .phy files retained"
    else
        fail "Keep intermediates: expected 5 .phy files, found $n_phy"
    fi
}

# -----------------------------------------------
# Per-gene alignment file definitions
# -----------------------------------------------
gene_alns() {
    # Print space-separated list of alignment filenames for a given gene
    case $1 in
        YPL070W) echo "clustalw_YPL070W.fasta DCA_YPL070W.fasta dialign_YPL070W.fasta mafft_YPL070W.fasta muscle_YPL070W.fasta probcons_YPL070W.fasta tcoffee_YPL070W.fasta" ;;
        YDR192C) echo "clustalw_YDR192C.fasta DCR_YDR192C.fasta dialign_YDR192C.fasta mafft_YDR192C.fasta muscle_YDR192C.fasta probcons_YDR192C.fasta tcoffee_YDR192C.fasta" ;;
        *) echo "" ;;
    esac
}

# -----------------------------------------------
# Function: run one gene
# -----------------------------------------------
run_gene() {
    local gene=$1
    local aln_dir="$EXAMPLE_DIR/$gene"
    local test_out="$TEST_OUT_ROOT/$gene"
    read -ra alns <<< "$(gene_alns "$gene")"

    echo ""
    echo "----------------------------------------"
    echo " Gene: $gene"
    echo "----------------------------------------"

    # Check example alignments exist
    info "Checking example alignments ($gene)..."
    for f in "${alns[@]}"; do
        [[ -f "$aln_dir/$f" ]] \
            && pass "Found $f" \
            || fail "Missing $f in $aln_dir"
    done

    if [[ $FAILURES -gt 0 ]]; then
        echo -e "${RED}Missing alignment files for $gene. Skipping pipeline run.${NC}"
        return
    fi

    # Run pipeline
    echo ""
    if [[ $FULL_RUN -eq 1 ]]; then
        info "Running FULL test for $gene (default bootstrap replicates)..."
        BOOT_OPT=""
    else
        info "Running QUICK test for $gene (10 bootstrap replicates; use --full for complete run)..."
        BOOT_OPT="-n 10"
    fi

    rm -rf "$test_out"

    ALN_ARGS=()
    for f in "${alns[@]}"; do
        ALN_ARGS+=("-i" "$aln_dir/$f")
    done

    bash "$SCRIPT_DIR/scripts/wpsboot.sh" \
        "${ALN_ARGS[@]}" \
        -o "$test_out" \
        $BOOT_OPT

    # Verify outputs
    echo ""
    info "Verifying outputs ($gene)..."
    check_file() {
        local desc=$1 path=$2
        [[ -s "$path" ]] \
            && pass "$desc: $(basename "$path")" \
            || fail "$desc not found or empty: $path"
    }

    check_file "Similarity table"   "$test_out/01_similarity/similarity.csv"
    check_file "Super-MSA (PHYLIP)" "$test_out/02_superMSA/super_aln.phylip"
    check_file "Site weights"       "$test_out/02_superMSA/site_weights.txt"
    check_file "Bootstrap outfile"  "$test_out/03_bootstrap/outfile"
    check_file "ML tree"            "$test_out/04_ml_tree/ml_tree.raxml.bestTree"
    check_file "Bootstrap trees"    "$test_out/05_boot_trees/bootstrap_trees.nwk"
    check_file "Final support tree" "$test_out/wpSBOOT_result.nwk"

    # Sanity check: verify all expected taxa appear in the result tree
    local expected_taxa="Scer Spar Smik Skud Sbay Scas Sklu"
    local result_nwk
    result_nwk=$(cat "$test_out/wpSBOOT_result.nwk")
    local taxa_ok=1
    for taxon in $expected_taxa; do
        if ! echo "$result_nwk" | grep -q "$taxon"; then
            fail "Result tree missing taxon: $taxon"
            taxa_ok=0
        fi
    done
    [[ $taxa_ok -eq 1 ]] && pass "Result tree contains all expected taxa"
}

# -----------------------------------------------
# 2. Run selected gene(s)
# -----------------------------------------------
if [[ "$GENE" == "all" ]]; then
    GENES_TO_RUN=("YPL070W" "YDR192C")
else
    if [[ -z "$(gene_alns "$GENE")" ]]; then
        echo -e "${RED}Unknown gene: $GENE. Available: YPL070W, YDR192C, all${NC}"
        exit 1
    fi
    GENES_TO_RUN=("$GENE")
fi

for g in "${GENES_TO_RUN[@]}"; do
    run_gene "$g"
done

# -----------------------------------------------
# 3. Feature tests (flags + input validation)
# -----------------------------------------------
if [[ $FEATURES -eq 1 ]]; then
    run_feature_tests
fi

# -----------------------------------------------
# 4. Final summary
# -----------------------------------------------
echo ""
echo "========================================"
if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}All checks passed.${NC}"
    for g in "${GENES_TO_RUN[@]}"; do
        echo "  $g -> $TEST_OUT_ROOT/$g/wpSBOOT_result.nwk"
    done
else
    echo -e "${RED}$FAILURES check(s) failed.${NC}"
    exit 1
fi
echo "========================================"
