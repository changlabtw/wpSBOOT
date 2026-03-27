#!/bin/bash
#
# Step 2: Build weighted super-MSA and site weights file
#
# Concatenates all N input FASTA alignments into a single PHYLIP super-MSA
# using concatenate.pl (BioPerl-based). Alignments are concatenated in the
# same order as INPUT_FILES so that site positions match the weights.
#
# Each site in the super-MSA inherits the weight of its source alignment:
#
#   site_weight[site] = ALN_WEIGHTS[alignment_index_of_that_site]
#
# The site_weights.txt file is consumed by wei_seqboot in step 3.
#
# Dependencies : Perl, BioPerl (Bio::AlignIO, Bio::Align::Utilities)
# Input        : INPUT_FILES array (FASTA), ALN_WEIGHTS array (from step1)
# Output       : SUPER_PHY    - concatenated alignment in PHYLIP format
#                SITE_WEIGHTS - one weight per site, matching super-MSA columns
#

SUPER_DIR="$OUTPUT_DIR/02_superMSA"
mkdir -p "$SUPER_DIR"

SUPER_PHY="$SUPER_DIR/super_aln.phylip"
SITE_WEIGHTS="$SUPER_DIR/site_weights.txt"

# --- Skip if already complete ---
if [[ "${FORCE:-0}" -eq 0 && -s "$SUPER_PHY" && -s "$SITE_WEIGHTS" ]]; then
    log_stdout "Step 2: Skipping (output exists: $SUPER_PHY)"
    export SUPER_PHY SITE_WEIGHTS
    return 0
fi

log_stdout "Step 2: Building weighted super-MSA..."

# --- Concatenate alignments using concatenate.pl ---
# concatenate.pl --aln takes all input FASTA files in the given order
# and outputs a PHYLIP-format concatenated alignment.
# The order determines site positions, which must match ALN_WEIGHTS below.
perl "$SCRIPT_DIR/concatenate.pl" \
    --aln "${INPUT_FILES[@]}" \
    --out "$SUPER_PHY"

# Verify output
[[ ! -s "$SUPER_PHY" ]] && error "Concatenation failed: $SUPER_PHY is empty"

# Read dimensions from PHYLIP header (line 1: n_taxa  total_length)
n_taxa_out=$(awk 'NR==1{print $1}' "$SUPER_PHY")
total_len=$(awk  'NR==1{print $2}' "$SUPER_PHY")
log "Super-MSA: $n_taxa_out taxa, $total_len sites -> $SUPER_PHY"

# --- Generate site weights file ---
# For each alignment, write its weight once per site.
# Sites are written in the same order as INPUT_FILES (matching concatenate.pl).
> "$SITE_WEIGHTS"
for ((i=0; i<N; i++)); do
    # Get sequence length for this alignment from its first taxon.
    # Accumulate characters until the second ">" header, then stop.
    aln_len=$(awk '/^>/{if(found) exit; found=1; next}
                  found{gsub(/[[:space:]]/, ""); n+=length($0)}
                  END{print n}' "${INPUT_FILES[$i]}")

    weight="${ALN_WEIGHTS[$i]}"
    log "  $(basename "${INPUT_FILES[$i]}"): $aln_len sites, weight=$weight"

    # Write weight once per site for this alignment
    awk -v w="$weight" -v n="$aln_len" 'BEGIN{ for(i=0;i<n;i++) print w }' >> "$SITE_WEIGHTS"
done

n_weights=$(wc -l < "$SITE_WEIGHTS" | tr -d ' ')
log "Site weights: $SITE_WEIGHTS ($n_weights weights)"

# Sanity check: weight count must equal total alignment length
[[ "$n_weights" -ne "$total_len" ]] && \
    error "Weight count ($n_weights) does not match alignment length ($total_len)"

# Export paths for downstream steps
export SUPER_PHY SITE_WEIGHTS
