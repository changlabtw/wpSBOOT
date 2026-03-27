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
VERSION="$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "unknown")"

# --- Default parameters ---
MODEL="GTR+G"          # substitution model for raxml-ng
THREADS=4              # parallel threads
BOOTSTRAP_REPS=""      # number of bootstrap replicates; default: N_alignments x 100
PARTIAL_FRACTION=""    # partial sampling fraction; default: 1/N_alignments
SEED=""                # random seed for wei_seqboot; default: time-based
FORCE=0                # skip existing outputs (0) or rerun all steps (1)
KEEP_INTERMEDIATES=0   # delete per-replicate bootstrap files after step 5 (0) or keep (1)
INPUT_FILES=()         # input alignment files (FASTA), collected via -i

usage() {
    cat << EOF
wpSBOOT - Weighted Partial Super Bootstrap
https://github.com/changlabtw/wpSBOOT

Usage: $(basename "$0") -i <aln1.fasta> -i <aln2.fasta> [...] -o <output_dir> [options]

Required:
  -i <file>    Input alignment (FASTA); specify once per alignment (min. 2)
  -o <dir>     Output directory (created if it does not exist)

Options:
  -n <int>     Bootstrap replicates (default: N x 100, where N = number of alignments)
  -p <float>   Partial sampling fraction 0.0-1.0 (default: 1/N)
  -m <model>   Substitution model for raxml-ng (default: GTR+G)
  -T <int>     Threads (default: 4)
  -s <int>     Random seed for bootstrap sampling (default: time-based, not reproducible)
  -f           Force rerun of all steps, ignoring any existing outputs
  -k           Keep intermediate per-replicate bootstrap files (default: deleted after step 5)
  -v           Print version and exit
  -h           Show this help and exit

Pipeline steps and output folders:
  Step 1  Pairwise alignment similarity (t_coffee)   -> <output_dir>/01_similarity/
  Step 2  Weighted super-MSA (concatenate.pl)        -> <output_dir>/02_superMSA/
  Step 3  Weighted partial bootstrap (wei_seqboot)   -> <output_dir>/03_bootstrap/
  Step 4  ML tree inference (raxml-ng)               -> <output_dir>/04_ml_tree/
  Step 5  Bootstrap tree inference (raxml-ng)        -> <output_dir>/05_boot_trees/
  Step 6  Map bootstrap support (raxml-ng)           -> <output_dir>/06_support/

Final result:
  <output_dir>/wpSBOOT_result.nwk   ML tree with bootstrap support values
  <output_dir>/wpsboot.log          Full pipeline log

Examples:
  $(basename "$0") -i clustalw.fasta -i mafft.fasta -i muscle.fasta -o results/
  $(basename "$0") -i example/YPL070W/*.fasta -o results/YPL070W -n 1000 -T 8
  $(basename "$0") -i aln1.fasta -i aln2.fasta -o results/ -f    # force full rerun

EOF
    exit 0
}

# Initial logging helpers (before log file is known; write to stdout only)
log()   { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }
export -f log error

# --- Parse command-line arguments ---
while getopts "i:o:n:p:m:T:s:fkvh" opt; do
    case $opt in
        i) INPUT_FILES+=("$OPTARG") ;;   # accumulate input files
        o) OUTPUT_DIR="$OPTARG" ;;
        n) BOOTSTRAP_REPS="$OPTARG" ;;
        p) PARTIAL_FRACTION="$OPTARG" ;;
        m) MODEL="$OPTARG" ;;
        T) THREADS="$OPTARG" ;;
        s) SEED="$OPTARG" ;;
        f) FORCE=1 ;;
        k) KEEP_INTERMEDIATES=1 ;;
        v) echo "wpSBOOT $VERSION"; exit 0 ;;
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

# --- Set up log file (start fresh each run) ---
LOG_FILE="$OUTPUT_DIR/wpsboot.log"
> "$LOG_FILE"
export LOG_FILE

# Redefine logging helpers with file output now that LOG_FILE is known:
#   log()        -> log file only (detailed pipeline output)
#   log_stdout() -> stdout + log file (key milestones shown to user)
#   error()      -> stderr + log file, then exit
log()        { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }
log_stdout() { local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"; echo "$msg"; echo "$msg" >> "$LOG_FILE"; }
error()      { local msg="[ERROR] $*"; echo "$msg" >&2; echo "$msg" >> "$LOG_FILE"; exit 1; }
export -f log log_stdout error

# --- Print run summary ---
log_stdout "=== wpSBOOT ==="
log_stdout "Input alignments : $N"
for f in "${INPUT_FILES[@]}"; do log "  $(basename "$f")"; done
log_stdout "Bootstrap reps   : $BOOTSTRAP_REPS"
log_stdout "Partial fraction : $PARTIAL_FRACTION  (default: 1/N = 1/$N)"
log_stdout "Seed             : ${SEED:-time-based (not reproducible)}"
log_stdout "Model            : $MODEL"
log_stdout "Threads          : $THREADS"
log_stdout "Output           : $OUTPUT_DIR"
log_stdout "Log              : $LOG_FILE"

# --- Validate taxa consistency across all input alignments ---
get_taxa() { grep '^>' "$1" | awk '{print $1}' | sed 's/^>//' | sort; }
ref_taxa=$(get_taxa "${INPUT_FILES[0]}")
for f in "${INPUT_FILES[@]:1}"; do
    file_taxa=$(get_taxa "$f")
    if [[ "$ref_taxa" != "$file_taxa" ]]; then
        error "Taxa mismatch: $(basename "$f") has different sequence IDs than $(basename "${INPUT_FILES[0]}")"
    fi
done
log "Input taxa validated ($(echo "$ref_taxa" | wc -w | tr -d ' ') taxa consistent across all alignments)"

# Export shared variables for use by all sourced step scripts
export BIN_DIR MODEL THREADS BOOTSTRAP_REPS PARTIAL_FRACTION SEED FORCE KEEP_INTERMEDIATES N OUTPUT_DIR SCRIPT_DIR

# --- Execute pipeline steps ---
# Each step script is sourced so it inherits all variables (INPUT_FILES array,
# and any variables exported by earlier steps such as SUPER_PHY, SITE_WEIGHTS, etc.)
TIME_START=$(date +%s)
source "$SCRIPT_DIR/step1_similarity.sh"
source "$SCRIPT_DIR/step2_superMSA.sh"
source "$SCRIPT_DIR/step3_bootstrap.sh"
source "$SCRIPT_DIR/step4_ml_tree.sh"
source "$SCRIPT_DIR/step5_boot_trees.sh"
source "$SCRIPT_DIR/step6_support.sh"
TIME_END=$(date +%s)

ELAPSED=$(( TIME_END - TIME_START ))
ELAPSED_MIN=$(( ELAPSED / 60 ))
ELAPSED_SEC=$(( ELAPSED % 60 ))

log_stdout "=== Done. Final result: $OUTPUT_DIR/wpSBOOT_result.nwk ==="
log_stdout "=== Total runtime: ${ELAPSED_MIN}m ${ELAPSED_SEC}s ==="

# --- Bootstrap support summary ---
python3 "$SCRIPT_DIR/support_summary.py" \
    "$OUTPUT_DIR/wpSBOOT_result.nwk" \
    "$OUTPUT_DIR/05_boot_trees/bootstrap_trees.nwk" | tee -a "$LOG_FILE"
