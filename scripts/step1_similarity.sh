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
# Input  : INPUT_FILES array (FASTA alignments)
# Output : SIM_CSV      - table of avg similarity and weight per alignment
#          ALN_WEIGHTS  - bash array of per-alignment weights (for step2)
#

SIM_DIR="$OUTPUT_DIR/01_similarity"
mkdir -p "$SIM_DIR"

log "Step 1: Computing pairwise alignment similarities..."

SIM_CSV="$SIM_DIR/similarity.csv"
echo "alignment,avg_similarity,weight" > "$SIM_CSV"

# Accumulate pairwise similarity sums for each alignment
declare -a sim_sum
for ((i=0; i<N; i++)); do sim_sum[$i]="0"; done

# All-vs-all pairwise T-Coffee column comparison (i != j)
for ((i=0; i<N; i++)); do
    for ((j=0; j<N; j++)); do
        [[ $i -eq $j ]] && continue

        # t_coffee aln_compare outputs a summary line; the 4th field is the score
        sim=$("$BIN_DIR/t_coffee" -other_pg aln_compare \
            -al1 "${INPUT_FILES[$i]}" \
            -al2 "${INPUT_FILES[$j]}" \
            -compare_mode column 2>/dev/null \
            | tail -n1 | awk '{print $4}')

        sim_sum[$i]=$(echo "${sim_sum[$i]} + $sim" | bc)
    done
done

# Compute per-alignment average similarity and weight; populate ALN_WEIGHTS array
ALN_WEIGHTS=()
for ((i=0; i<N; i++)); do
    # Average over (N-1) comparisons
    avg=$(echo "scale=4; ${sim_sum[$i]} / ($N - 1)" | bc)

    # Weight is inverse of similarity: less similar = more unique signal = higher weight
    weight=$(echo "scale=4; 100 - $avg" | bc)

    ALN_WEIGHTS+=("$weight")
    echo "$(basename "${INPUT_FILES[$i]}"),$avg,$weight" >> "$SIM_CSV"
    log "  $(basename "${INPUT_FILES[$i]}"): avg_similarity=$avg  weight=$weight"
done

log "Similarity table: $SIM_CSV"
# ALN_WEIGHTS array is available to subsequent sourced steps
