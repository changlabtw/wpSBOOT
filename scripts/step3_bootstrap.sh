#!/bin/bash
#
# Step 3: Generate weighted partial bootstrap samples
#
# Runs wei_seqboot to produce BOOTSTRAP_REPS bootstrap replicates from the
# super-MSA. Sites are sampled according to their weights (higher weight =
# higher probability of selection). Each replicate draws PARTIAL_FRACTION
# of the total sites (default: 1/N), then resamples with replacement.
#
# wei_seqboot call:
#   wei_seqboot -n <reps> -p <fraction> <super_aln.phylip> <site_weights.txt>
#
# Output is written to a file named "outfile" in the working directory.
# This file contains all BOOTSTRAP_REPS replicates concatenated in PHYLIP format.
#
# Input  : SUPER_PHY, SITE_WEIGHTS (from step2)
#          BOOTSTRAP_REPS, PARTIAL_FRACTION (from wpsboot.sh)
# Output : BOOT_FILE - all bootstrap replicates in concatenated PHYLIP format
#

BOOT_DIR="$OUTPUT_DIR/03_bootstrap"
mkdir -p "$BOOT_DIR"

log "Step 3: Generating $BOOTSTRAP_REPS bootstrap samples (partial fraction=$PARTIAL_FRACTION)..."

# wei_seqboot always writes output to a file named "outfile" in the current
# working directory, so we change into the bootstrap directory first
cd "$BOOT_DIR"

"$BIN_DIR/wei_seqboot" \
    -n "$BOOTSTRAP_REPS" \
    -p "$PARTIAL_FRACTION" \
    "$SUPER_PHY" \
    "$SITE_WEIGHTS"

BOOT_FILE="$BOOT_DIR/outfile"
[[ ! -f "$BOOT_FILE" ]] && error "wei_seqboot failed: outfile not found in $BOOT_DIR"

log "Bootstrap samples: $BOOT_FILE"

# Export path for downstream steps
export BOOT_FILE
