#!/bin/bash
#
# Step 6: Map bootstrap support onto the ML tree
#
# Uses raxml-ng --support to calculate bootstrap support values by comparing
# the ML tree topology against all bootstrap trees. The resulting tree has
# branch support values expressed as bootstrap percentages (0-100).
#
# The final tree is copied to the output root as wpSBOOT_result.nwk for
# easy access.
#
# Input  : ML_TREE (from step4), BOOT_TREES (from step5)
# Output : wpSBOOT_result.nwk - ML tree annotated with bootstrap support
#

SUPPORT_DIR="$OUTPUT_DIR/06_support"
mkdir -p "$SUPPORT_DIR"

log "Step 6: Mapping bootstrap support onto ML tree..."

cd "$SUPPORT_DIR"

# Map bootstrap support values onto the ML tree
# raxml-ng --support writes output to <prefix>.raxml.support
"$BIN_DIR/raxml-ng" \
    --support \
    --tree "$ML_TREE" \
    --bs-trees "$BOOT_TREES" \
    --prefix support \
    2>&1 | tee raxml-ng_support.log

SUPPORT_TREE="$SUPPORT_DIR/support.raxml.support"
[[ ! -f "$SUPPORT_TREE" ]] && error "Bootstrap support mapping failed: $SUPPORT_TREE not found"

# Copy final result to the output root directory for convenient access
cp "$SUPPORT_TREE" "$OUTPUT_DIR/wpSBOOT_result.nwk"

log "Bootstrap support tree: $OUTPUT_DIR/wpSBOOT_result.nwk"
