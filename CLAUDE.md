# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

wpSBOOT (Weighted Partial Super Bootstrap) is a bioinformatics protocol for phylogenetic support assessment. It takes multiple sequence alignments produced by different alignment tools (e.g., ClustalW, MAFFT, Muscle), builds a weighted super-MSA, and generates bootstrap support values using weighted partial resampling. Published at https://github.com/changlabtw/wpSBOOT.

## Commands

```bash
# Run wpSBOOT with multiple alignments
./scripts/wpsboot.sh -i aln1.fasta -i aln2.fasta -i aln3.fasta -o output_dir/

# Run with custom bootstrap replicates and threads
./scripts/wpsboot.sh -i aln1.fasta -i aln2.fasta -o output_dir/ -n 500 -T 8

# Run with custom partial fraction and model
./scripts/wpsboot.sh -i aln1.fasta -i aln2.fasta -o output_dir/ -p 0.5 -m GTR+G

# Quick test (10 replicates) — YPL070W by default
./test.sh

# Full test (default N x 100 replicates)
./test.sh --full

# Test a specific gene or both genes
./test.sh --gene YDR192C
./test.sh --gene all --full

# Bootstrap support summary (per-node + tree topology)
python3 scripts/support_summary.py <output_dir>/wpSBOOT_result.nwk

# Also compute whole-tree topology support
python3 scripts/support_summary.py <output_dir>/wpSBOOT_result.nwk \
    <output_dir>/05_boot_trees/bootstrap_trees.nwk

# Print match/diff detail for each bootstrap replicate
python3 scripts/support_summary.py <output_dir>/wpSBOOT_result.nwk \
    <output_dir>/05_boot_trees/bootstrap_trees.nwk --verbose

# Compile wei_seqboot from source
cd src/ && make && cd ..
```

## Architecture

The pipeline is executed by `scripts/wpsboot.sh`, which sources six step scripts in order. All scripts share variables via the sourcing shell — no subshells are used between steps.

1. **step1_similarity.sh** — Pairwise alignment similarity via T-Coffee
   - Runs `t_coffee -other_pg aln_compare -compare_mode column` for all pairs (i≠j)
   - Computes per-alignment average similarity
   - Weight = `100 - avg_similarity` (less similar = more unique signal = higher weight)
   - Outputs `01_similarity/similarity.csv`; sets `ALN_WEIGHTS` array

2. **step2_superMSA.sh** — Build weighted super-MSA
   - Concatenates all input FASTAs into a single PHYLIP file using `concatenate.pl` (BioPerl)
   - Generates `site_weights.txt`: one weight per site, inherited from its source alignment
   - Outputs `02_superMSA/super_aln.phylip` and `02_superMSA/site_weights.txt`
   - Exports `SUPER_PHY` and `SITE_WEIGHTS`

3. **step3_bootstrap.sh** — Weighted partial bootstrap sampling
   - Calls `wei_seqboot -n $BOOTSTRAP_REPS -p $PARTIAL_FRACTION $SUPER_PHY $SITE_WEIGHTS`
   - Sites sampled with probability proportional to weight; partial fraction = 1/N by default
   - Output written to `03_bootstrap/outfile` (all replicates concatenated in PHYLIP format)
   - Exports `BOOT_FILE`

4. **step4_ml_tree.sh** — ML tree inference
   - Runs `raxml-ng` on the super-MSA to produce the reference ML tree
   - Outputs `04_ml_tree/ml_tree.raxml.bestTree`
   - Exports `ML_TREE`

5. **step5_boot_trees.sh** — Bootstrap tree inference
   - Splits `BOOT_FILE` into individual PHYLIP files (one per replicate)
   - Runs `raxml-ng` on each replicate in parallel (up to `$THREADS` jobs)
   - Collects all bootstrap trees into `05_boot_trees/bootstrap_trees.nwk`
   - Exports `BOOT_TREES`

6. **step6_support.sh** — Map bootstrap support
   - Runs `raxml-ng --support` to map bootstrap values onto the ML tree
   - Copies final result to `$OUTPUT_DIR/wpSBOOT_result.nwk`

## Project Structure

```
wpSBOOT/
├── bin/                  ← executables: t_coffee, raxml-ng, wei_seqboot
├── scripts/
│   ├── wpsboot.sh        ← main wrapper
│   ├── step1–6_*.sh      ← pipeline steps (sourced by wpsboot.sh)
│   ├── concatenate.pl    ← BioPerl alignment concatenation
│   └── support_summary.py ← bootstrap support summary (per-node + whole-tree)
├── src/                  ← wei_seqboot C++ source (main.cpp, element.cpp, makefile)
├── example/
│   ├── YPL070W/          ← 7 FASTA alignments for YPL070W
│   └── YDR192C/          ← 7 FASTA alignments for YDR192C
├── web/                  ← Flask web server (separate from CLI pipeline)
├── test.sh               ← user-facing test script (supports --gene, --full)
└── README.md
```

## support_summary.py

Reports bootstrap support for a wpSBOOT result tree.

```bash
# Per-node summary + ASCII tree topology
python3 scripts/support_summary.py <result.nwk>

# Also compute whole-tree topology support
python3 scripts/support_summary.py <result.nwk> <bootstrap_trees.nwk>

# Verbose: print each bootstrap tree and match/diff status
python3 scripts/support_summary.py <result.nwk> <bootstrap_trees.nwk> --verbose
```

**Per-node support**: fraction of bootstrap trees containing each bipartition (from RAxML-NG `--support`). Reports mean, median, min, max, and count of fully-supported nodes.

**Whole-tree topology support**: fraction of bootstrap trees whose unrooted topology is identical to the ML reference tree (all bipartitions match simultaneously). Stricter than per-node support — a replicate is counted only if every internal branch matches.

## Key Variables

All variables are set in `wpsboot.sh` and inherited by sourced step scripts:

| Variable | Description | Default |
|---|---|---|
| `INPUT_FILES` | Array of input FASTA alignment paths | required |
| `N` | Number of input alignments | derived |
| `OUTPUT_DIR` | Output directory path | required |
| `BOOTSTRAP_REPS` | Number of bootstrap replicates | N × 100 |
| `PARTIAL_FRACTION` | Fraction of super-MSA sites per replicate | 1/N |
| `MODEL` | RAxML-NG substitution model | GTR+G |
| `THREADS` | Parallel threads | 4 |
| `BIN_DIR` | Path to executables | `../bin/` |

Step scripts export these variables for downstream steps:

| Variable | Set by | Used by |
|---|---|---|
| `ALN_WEIGHTS` | step1 | step2 |
| `SUPER_PHY`, `SITE_WEIGHTS` | step2 | step3, step4 |
| `BOOT_FILE` | step3 | step5 |
| `ML_TREE` | step4 | step6 |
| `BOOT_TREES` | step5 | step6 |

## External Tool Dependencies

- **t_coffee** (≥13.0) — alignment similarity; binary in `bin/` or PATH
- **raxml-ng** (≥1.0) — ML and bootstrap tree inference; binary in `bin/` or PATH
- **Perl + BioPerl** — required by `concatenate.pl` (`Bio::AlignIO`, `Bio::Align::Utilities`, `Bio::LocatableSeq`)
- **wei_seqboot** — compiled from `src/` using `make`

## Reference Data for Validation

Pre-computed reference outputs for YPL070W (7 alignments) are in `202603_originalCode/pre_results/`:
- `concatenateAln_YPL070W.phylip` — expected super-MSA
- `YPL070W.wei` — expected site weights
- `YPL070W.tre` — reference ML tree
