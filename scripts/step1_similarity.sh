#!/bin/bash
#
# Step 1: Compute pairwise alignment similarity
#
# For each pair of input alignments (i != j), runs T-Coffee aln_compare in
# column mode to compute a similarity score. Per-alignment average similarity
# is then used to derive a weight:
#
#   weight = 100 - avg_pairwise_similarity
#
# Alignments that agree less with others receive higher weight, reflecting
# their greater contribution of unique phylogenetic signal to the super-MSA.
#
# All N*(N-1) pairwise comparisons are independent and run in parallel,
# throttled to THREADS concurrent T-Coffee processes. Each job writes its
# result to a temp file; results are collected after all jobs complete.
#
# Input  : INPUT_FILES array (FASTA alignments)
# Output : SIM_CSV      - table of avg similarity and weight per alignment
#          ALN_WEIGHTS  - bash array of per-alignment weights (for step2)
#

SIM_DIR="$OUTPUT_DIR/01_similarity"
mkdir -p "$SIM_DIR"

SIM_CSV="$SIM_DIR/similarity.csv"

# --- Skip if already complete ---
if [[ "${FORCE:-0}" -eq 0 && -s "$SIM_CSV" ]]; then
    log_stdout "Step 1: Skipping (output exists: $SIM_CSV)"
    ALN_WEIGHTS=()
    while IFS=, read -r _aln _avg weight; do
        ALN_WEIGHTS+=("$weight")
    done < <(tail -n +2 "$SIM_CSV")
    return 0
fi

log_stdout "Step 1: Computing pairwise alignment similarities (threads=$THREADS)..."

# --- Run all N*(N-1) pairwise T-Coffee comparisons in parallel ---
# Each job writes a single similarity value to tmp_<i>_<j>.txt
job_count=0
for ((i=0; i<N; i++)); do
    for ((j=0; j<N; j++)); do
        [[ $i -eq $j ]] && continue

        (
            sim=$("$BIN_DIR/t_coffee" -other_pg aln_compare \
                -al1 "${INPUT_FILES[$i]}" \
                -al2 "${INPUT_FILES[$j]}" \
                -compare_mode column 2>/dev/null \
                | tail -n1 | awk '{print $4}')
            echo "$sim" > "$SIM_DIR/tmp_${i}_${j}.txt"
        ) &

        job_count=$(( job_count + 1 ))
        if [[ $job_count -ge $THREADS ]]; then
            wait
            job_count=0
        fi
    done
done
wait  # wait for any remaining jobs

# --- Collect results and compute per-alignment average similarity ---
declare -a sim_sum
for ((i=0; i<N; i++)); do sim_sum[$i]="0"; done

for ((i=0; i<N; i++)); do
    for ((j=0; j<N; j++)); do
        [[ $i -eq $j ]] && continue
        tmp="$SIM_DIR/tmp_${i}_${j}.txt"
        [[ ! -f "$tmp" ]] && { log "WARNING: missing result for pair ($i,$j)"; continue; }
        sim=$(cat "$tmp")
        sim_sum[$i]=$(echo "${sim_sum[$i]} + $sim" | bc)
    done
done

# Clean up temp files
rm -f "$SIM_DIR"/tmp_*.txt

# --- Compute weights and write CSV ---
echo "alignment,avg_similarity,weight" > "$SIM_CSV"
ALN_WEIGHTS=()
for ((i=0; i<N; i++)); do
    avg=$(echo "scale=4; ${sim_sum[$i]} / ($N - 1)" | bc)
    weight=$(echo "scale=4; 100 - $avg" | bc)
    ALN_WEIGHTS+=("$weight")
    echo "$(basename "${INPUT_FILES[$i]}"),$avg,$weight" >> "$SIM_CSV"
    log "  $(basename "${INPUT_FILES[$i]}"): avg_similarity=$avg  weight=$weight"
done

log "Similarity table: $SIM_CSV"
# ALN_WEIGHTS array is available to subsequent sourced steps
