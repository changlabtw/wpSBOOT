#!/bin/bash
#
# Step 4: Infer ML tree from the super-MSA
#
# Runs raxml-ng on the full concatenated super-MSA to produce a maximum
# likelihood (ML) tree. This tree is used in step 6 as the reference onto
# which bootstrap support values are mapped.
#
# Input  : SUPER_PHY (from step2)
#          MODEL, THREADS (from wpsboot.sh)
# Output : ML_TREE - path to the best-scoring ML tree (Newick format)
#

ML_DIR="$OUTPUT_DIR/04_ml_tree"
mkdir -p "$ML_DIR"

log "Step 4: Inferring ML tree (model=$MODEL, threads=$THREADS)..."

cd "$ML_DIR"

# Run raxml-ng ML inference
# --tree pars{1} starts from one parsimony tree (faster than random starts)
# --redo overwrites any existing output with the same prefix
"$BIN_DIR/raxml-ng" \
    --msa "$SUPER_PHY" \
    --model "$MODEL" \
    --prefix ml_tree \
    --threads "$THREADS" \
    --seed 12345 \
    --tree pars{1} \
    --redo \
    2>&1 | tee raxml-ng_ml.log

ML_TREE="$ML_DIR/ml_tree.raxml.bestTree"
[[ ! -f "$ML_TREE" ]] && error "ML tree inference failed: $ML_TREE not found"

log "ML tree: $ML_TREE"

# Export path for downstream steps
export ML_TREE
