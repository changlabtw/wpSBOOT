#!/bin/bash
#
# wpSBOOT - Weighted Partial Super Bootstrap
# https://github.com/changlabtw/wpSBOOT
#
# Main wrapper script. Accepts multiple alignment files (FASTA), builds a
# weighted super-MSA, generates weighted partial bootstrap samples, infers
# ML and bootstrap trees, and maps support values onto the ML tree.
#
# Usage: wpsboot.sh -i <aln1.fasta> -i <aln2.fasta> [...] -o <output_dir> [options]
#
# Pipeline:
#   Step 1 - Compute pairwise alignment similarity (T-Coffee)
#   Step 2 - Build weighted super-MSA and site weights file
#   Step 3 - Generate weighted partial bootstrap samples (wei_seqboot)
#   Step 4 - Infer ML tree from super-MSA (raxml-ng)
#   Step 5 - Infer bootstrap trees for each replicate (raxml-ng)
#   Step 6 - Map bootstrap support onto ML tree (raxml-ng)
#

set -euo pipefail

# Locate script and bin directories relative to this file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"

# --- Default parameters ---
MODEL="GTR+G"        # substitution model for raxml-ng
THREADS=4            # parallel threads
BOOTSTRAP_REPS=""    # number of bootstrap replicates; default: N_alignments x 100
PARTIAL_FRACTION=""  # partial sampling fraction; default: 1/N_alignments
INPUT_FILES=()       # input alignment files (FASTA), collected via -i

usage() {
    cat << EOF
wpSBOOT - Weighted Partial Super Bootstrap
https://github.com/changlabtw/wpSBOOT

Usage: $(basename "$0") -i <aln1.fasta> -i <aln2.fasta> [...] -o <output_dir> [options]

Required:
  -i <file>    Input alignment (FASTA); specify once per alignment (min. 2)
  -o <dir>     Output directory

Options:
  -n <int>     Bootstrap replicates (default: N_alignments x 100)
  -p <float>   Partial sampling fraction 0.0-1.0 (default: 1/N_alignments)
  -m <model>   Substitution model for raxml-ng (default: GTR+G)
  -T <int>     Threads (default: 4)
  -h           Show this help

Example:
  $(basename "$0") -i clustalw.fasta -i mafft.fasta -i muscle.fasta -o results/
  $(basename "$0") -i example/alignments/*.fasta -o results/ -n 1000

EOF
    exit 0
}

# Logging helpers; exported so sourced step scripts can use them
log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }
export -f log error

# --- Parse command-line arguments ---
while getopts "i:o:n:p:m:T:h" opt; do
    case $opt in
        i) INPUT_FILES+=("$OPTARG") ;;   # accumulate input files
        o) OUTPUT_DIR="$OPTARG" ;;
        n) BOOTSTRAP_REPS="$OPTARG" ;;
        p) PARTIAL_FRACTION="$OPTARG" ;;
        m) MODEL="$OPTARG" ;;
        T) THREADS="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# --- Validate required arguments ---
[[ ${#INPUT_FILES[@]} -lt 2 ]] && error "At least 2 input alignment files required (-i)"
[[ -z "${OUTPUT_DIR:-}" ]]     && error "Output directory required (-o)"
for f in "${INPUT_FILES[@]}"; do
    [[ ! -f "$f" ]] && error "Input file not found: $f"
done

# --- Convert all paths to absolute so that step scripts can cd freely ---
# INPUT_FILES: resolve each to absolute path
for i in "${!INPUT_FILES[@]}"; do
    INPUT_FILES[$i]="$(cd "$(dirname "${INPUT_FILES[$i]}")" && pwd)/$(basename "${INPUT_FILES[$i]}")"
done
# OUTPUT_DIR: create first, then resolve
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

# --- Compute N-dependent defaults ---
N=${#INPUT_FILES[@]}

# Default bootstrap replicates: N x 100 (e.g., 7 alignments -> 700 replicates)
[[ -z "$BOOTSTRAP_REPS" ]] && BOOTSTRAP_REPS=$((N * 100))

# Default partial fraction: 1/N (each bootstrap sample covers ~one alignment's worth of sites)
[[ -z "$PARTIAL_FRACTION" ]] && PARTIAL_FRACTION=$(awk "BEGIN {printf \"%.6f\", 1/$N}")

mkdir -p "$OUTPUT_DIR"

# --- Print run summary ---
log "=== wpSBOOT ==="
log "Input alignments : $N"
for f in "${INPUT_FILES[@]}"; do log "  $(basename "$f")"; done
log "Bootstrap reps   : $BOOTSTRAP_REPS"
log "Partial fraction : $PARTIAL_FRACTION  (default: 1/N = 1/$N)"
log "Model            : $MODEL"
log "Threads          : $THREADS"
log "Output           : $OUTPUT_DIR"

# Export shared variables for use by all sourced step scripts
export BIN_DIR MODEL THREADS BOOTSTRAP_REPS PARTIAL_FRACTION N OUTPUT_DIR SCRIPT_DIR

# --- Execute pipeline steps ---
# Each step script is sourced so it inherits all variables (INPUT_FILES array,
# and any variables exported by earlier steps such as SUPER_PHY, SITE_WEIGHTS, etc.)
source "$SCRIPT_DIR/step1_similarity.sh"
source "$SCRIPT_DIR/step2_superMSA.sh"
source "$SCRIPT_DIR/step3_bootstrap.sh"
source "$SCRIPT_DIR/step4_ml_tree.sh"
source "$SCRIPT_DIR/step5_boot_trees.sh"
source "$SCRIPT_DIR/step6_support.sh"

log "=== Done. Final result: $OUTPUT_DIR/wpSBOOT_result.nwk ==="
