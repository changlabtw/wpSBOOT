# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

wpSBOOT (Weighted Partial Super Bootstrap) is a bioinformatics protocol for phylogenetic support assessment. This repository contains shell scripts for a Methods in Molecular Biology chapter.

## Commands

```bash
# Run wpSBOOT analysis (basic)
./scripts/wpsboot.sh -i <alignment.fasta> -o <output_dir>

# Run with RAxML-NG instead of IQ-TREE2
./scripts/wpsboot.sh -i <alignment.fasta> -o <output_dir> -t raxml-ng

# Run with partitions
./scripts/wpsboot.sh -i <alignment.fasta> -o <output_dir> -p <partitions.txt>

# Test with example data
./scripts/wpsboot.sh -i data/example/example_alignment.fasta -o results/test

# Run pipeline test (no external tools required)
./scripts/test_pipeline.sh
```

## Architecture

The protocol follows a three-step pipeline executed by `scripts/wpsboot.sh`:

1. **step1_generate_samples.sh** - Generates weighted partial bootstrap resampled alignments
   - Parses FASTA/PHYLIP alignments
   - Calculates site weights (uniform or entropy-based)
   - Performs weighted sampling without replacement to select partial sites
   - Applies bootstrap resampling with replacement on selected sites
   - Outputs PHYLIP-format samples to `bootstrap_samples/`
2. **step2_run_inference.sh** - Runs phylogenetic inference on each sample
   - Infers ML tree from original alignment
   - Processes each bootstrap sample individually (supports GNU parallel)
   - Extracts model from ML inference if AUTO was used
   - Collects all bootstrap trees into single file
3. **step3_aggregate_support.sh** - Maps bootstrap support onto the ML tree
   - Uses IQ-TREE2 or RAxML-NG support mapping
   - Generates summary statistics

Each step script is sourced by the main wrapper and inherits variables from it.

### Weighted Partial Sampling Algorithm

The wpSBOOT method combines two sampling strategies:
1. **Weighted partial selection**: Sites are selected without replacement using weighted reservoir sampling (priority = random^(1/weight))
2. **Bootstrap resampling**: Selected sites are resampled with replacement

Weighting schemes:
- `uniform`: All sites have equal probability
- `entropy`: Variable sites (higher Shannon entropy) have higher probability

## Project Structure

- `scripts/` - Shell scripts implementing the protocol
- `data/example/` - Example alignment and partition files for testing
- `config/` - Configuration templates
- `results/` - Output directory (created during analysis)

## Key Variables

The main script (`wpsboot.sh`) sets these variables used by step scripts:
- `$INPUT` - Input alignment path
- `$OUTPUT_DIR` - Output directory path
- `$TOOL` - Phylogenetic tool (iqtree2 or raxml-ng)
- `$BOOTSTRAP_REPS` - Number of bootstrap replicates
- `$WEIGHTING_SCHEME` - Site weighting scheme (uniform, entropy)
- `$PARTIAL_FRACTION` - Fraction of sites for partial sampling (0.0-1.0)
- `$MODEL` - Substitution model
- `$THREADS` - Parallel threads
- `$PARTITIONS` - Optional partition file path
- `$WEIGHTS_FILE` - Optional user-provided weights file

## External Tool Dependencies

- **IQ-TREE2** (≥2.2.0) - Primary phylogenetic inference tool
- **RAxML-NG** (≥1.1.0) - Alternative phylogenetic inference tool

Both tools must be in PATH for the scripts to work.
