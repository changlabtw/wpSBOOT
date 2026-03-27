#!/bin/bash
#
# Step 5: Infer a tree for each bootstrap replicate
#
# Splits the concatenated wei_seqboot outfile into individual PHYLIP files
# (one per replicate), then runs raxml-ng on each to infer a bootstrap tree.
# Bootstrap trees are collected into a single file for use in step 6.
#
# Replicates are processed in parallel up to THREADS jobs at a time to
# reduce wall-clock time.
#
# Input  : BOOT_FILE (from step3), ML_TREE dir context
#          BOOTSTRAP_REPS, THREADS, MODEL (from wpsboot.sh)
# Output : BOOT_TREES - all bootstrap trees in Newick format (one per line)
#

BOOT_TREE_DIR="$OUTPUT_DIR/05_boot_trees"
mkdir -p "$BOOT_TREE_DIR"

BOOT_TREES="$BOOT_TREE_DIR/bootstrap_trees.nwk"

# --- Skip if already complete ---
if [[ "${FORCE:-0}" -eq 0 && -s "$BOOT_TREES" ]]; then
    log_stdout "Step 5: Skipping (output exists: $BOOT_TREES)"
    export BOOT_TREES
    return 0
fi

log_stdout "Step 5: Inferring $BOOTSTRAP_REPS bootstrap trees..."

# --- Split the wei_seqboot outfile into individual PHYLIP files ---
# wei_seqboot writes replicates sequentially; each starts with a PHYLIP
# header line of the form "     N_taxa     N_sites"
log "  Splitting bootstrap outfile into individual replicates..."
awk -v out_dir="$BOOT_TREE_DIR" '
/^[[:space:]]+[0-9]+[[:space:]]+[0-9]+[[:space:]]*$/ {
    # New replicate begins: open a new output file
    if (out_file) close(out_file)
    rep++
    out_file = out_dir "/boot_" rep ".phy"
}
{
    # Write every line (including the header) to the current replicate file
    if (rep > 0) print > out_file
}
' "$BOOT_FILE"

# --- Infer bootstrap tree for each replicate ---
# Run up to THREADS raxml-ng jobs in parallel using a simple background-job pool

> "$BOOT_TREES"   # initialise (will be appended to sequentially after parallel runs)

# Function: infer tree for one replicate; called in a subshell via &
infer_boot_tree() {
    local rep=$1
    local phy="$BOOT_TREE_DIR/boot_${rep}.phy"
    local prefix="$BOOT_TREE_DIR/boot_tree_${rep}"

    [[ ! -f "$phy" ]] && { echo "WARNING: missing replicate file $phy" >&2; return; }

    # raxml-ng: --tree pars{1} for speed; --redo to allow reruns
    "$BIN_DIR/raxml-ng" \
        --msa "$phy" \
        --model "$MODEL" \
        --prefix "$prefix" \
        --threads 1 \
        --seed "$rep" \
        --tree pars{1} \
        --redo \
        > /dev/null 2>&1
}
export -f infer_boot_tree

# Progress interval: report at every 25% (minimum every 1 rep)
PROGRESS_INTERVAL=$(( BOOTSTRAP_REPS / 4 ))
[[ "$PROGRESS_INTERVAL" -lt 1 ]] && PROGRESS_INTERVAL=1

# Run in parallel, THREADS jobs at a time
job_count=0
for ((rep=1; rep<=BOOTSTRAP_REPS; rep++)); do
    infer_boot_tree "$rep" &
    job_count=$((job_count + 1))

    # Wait when the job pool is full
    if [[ $job_count -ge $THREADS ]]; then
        wait
        job_count=0
    fi

    # Progress report at each 25% milestone
    if [[ $((rep % PROGRESS_INTERVAL)) -eq 0 ]]; then
        log_stdout "  Step 5: $rep / $BOOTSTRAP_REPS bootstrap tree jobs launched"
    fi
done
wait  # wait for any remaining background jobs

log_stdout "Step 5: All bootstrap tree jobs completed"

# --- Collect bootstrap trees in replicate order ---
for ((rep=1; rep<=BOOTSTRAP_REPS; rep++)); do
    tree_f="$BOOT_TREE_DIR/boot_tree_${rep}.raxml.bestTree"
    if [[ -f "$tree_f" ]]; then
        cat "$tree_f" >> "$BOOT_TREES"
    else
        log "WARNING: tree not found for replicate $rep (skipped)"
    fi
done

n_trees=$(wc -l < "$BOOT_TREES" | tr -d ' ')
n_missing=$(( BOOTSTRAP_REPS - n_trees ))
log "Bootstrap trees: $BOOT_TREES ($n_trees / $BOOTSTRAP_REPS collected)"

if [[ "$n_trees" -eq 0 ]]; then
    error "No bootstrap trees were produced"
elif [[ "$n_missing" -gt 0 ]]; then
    error "$n_missing / $BOOTSTRAP_REPS bootstrap trees missing — check raxml-ng logs in $BOOT_TREE_DIR"
fi

# --- Clean up intermediate per-replicate files ---
if [[ "${KEEP_INTERMEDIATES:-0}" -eq 0 ]]; then
    rm -f "$BOOT_TREE_DIR"/boot_*.phy "$BOOT_TREE_DIR"/boot_tree_*.*
    log "Intermediate bootstrap files removed (use -k to keep)"
fi

# Export path for downstream steps
export BOOT_TREES
