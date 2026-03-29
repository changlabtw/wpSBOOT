# wpSBOOT — Weighted Partial Super Bootstrap

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/changlabtw/wpSBOOT/actions/workflows/test.yml/badge.svg)](https://github.com/changlabtw/wpSBOOT/actions/workflows/test.yml)
[![Docker](https://img.shields.io/badge/Docker-changlabtw%2Fwpsboot-blue?logo=docker)](https://hub.docker.com/r/changlabtw/wpsboot)

A phylogenetic support assessment protocol that takes multiple sequence alignments (produced by different alignment tools) as input, builds a weighted super-MSA, and generates bootstrap support values using weighted partial resampling.

---

## Overview

Different alignment tools (ClustalW, MAFFT, Muscle, etc.) produce different alignments from the same input sequences, each with its own biases and uncertainties. wpSBOOT exploits this diversity by:

1. **Weighting** each alignment by how much it disagrees with the others — alignments with less inter-aligner agreement carry more unique signal and receive higher weight
2. **Concatenating** all alignments into a single super-MSA
3. **Bootstrapping** with weighted partial resampling — each replicate draws a fraction (1/N) of sites preferentially from high-weight alignments
4. **Inferring** ML and bootstrap trees, then mapping support values

This propagates alignment uncertainty into bootstrap support, providing a more realistic assessment of phylogenetic confidence.

---

## Dependencies

| Tool | Version | Purpose |
|---|---|---|
| [t_coffee](http://www.tcoffee.org) | ≥ 13.0 | Pairwise alignment similarity |
| [RAxML-NG](https://github.com/amkozlov/raxml-ng) | ≥ 1.0 | ML and bootstrap tree inference |
| Perl | ≥ 5.26 | Run `concatenate.pl` |
| [BioPerl](https://bioperl.org) | ≥ 1.7 | Required by `concatenate.pl` (Bio::AlignIO) |
| wei_seqboot | (included) | Weighted partial bootstrap sampling |
| Python | ≥ 3.6 | Run `support_summary.py` (standard library only) |

`t_coffee` and `raxml-ng` binaries are expected in `bin/`, or available in `PATH`. `wei_seqboot` is compiled from the included C++ source.

---

## Installation

### Option A: Docker (easiest — no dependency setup required)

```bash
# Pull the pre-built image
docker pull changlabtw/wpsboot

# Run on your data (mount the directory containing your alignments)
docker run --rm -v /path/to/data:/data changlabtw/wpsboot \
    -i /data/aln1.fasta -i /data/aln2.fasta -i /data/aln3.fasta \
    -o /data/results/

# Run the built-in example (output stays inside the container)
docker run --rm changlabtw/wpsboot \
    bash /opt/wpsboot/test.sh
```

Or build locally from source:

```bash
git clone https://github.com/changlabtw/wpSBOOT.git
cd wpSBOOT
docker build -t wpsboot .
docker run --rm -v /path/to/data:/data wpsboot \
    -i /data/aln1.fasta -i /data/aln2.fasta -o /data/results/
```

> **HPC users**: Docker images are compatible with Singularity/Apptainer without root access:
> ```bash
> singularity pull wpsboot.sif docker://changlabtw/wpsboot
> singularity run -B /path/to/data:/data wpsboot.sif \
>     -i /data/aln1.fasta -i /data/aln2.fasta -o /data/results/
> ```

---

### Option B: conda (recommended)

```bash
git clone https://github.com/changlabtw/wpSBOOT.git
cd wpSBOOT
conda env create -f environment.yml
conda activate wpsboot
cd src/ && make && cd ..
./test.sh
```

> **Coming soon:** A `conda-lock.yml` will be provided for fully reproducible installs (exact package versions pinned). Once available:
> ```bash
> conda install -c conda-forge conda-lock
> conda-lock install conda-lock.yml
> conda activate wpsboot
> cd src/ && make && cd ..
> ./test.sh
> ```

### Option C: manual

### 1. Clone the repository

```bash
git clone https://github.com/changlabtw/wpSBOOT.git
cd wpSBOOT
```

### 2. Compile wei_seqboot

`wei_seqboot` requires a C++11-compatible compiler (no external libraries needed).

```bash
cd src/
make
cd ..
# binary is placed at bin/wei_seqboot
```

### 3. Install t_coffee and RAxML-NG

Download binaries and place them in `bin/`, or install them system-wide so they are in `PATH`.

- **t_coffee**: http://www.tcoffee.org/Projects/tcoffee/#DOWNLOAD
- **RAxML-NG**: https://github.com/amkozlov/raxml-ng/releases

### 4. Install BioPerl

```bash
cpan Bio::AlignIO Bio::Align::Utilities Bio::LocatableSeq
```

### 5. Verify installation

```bash
./test.sh
```

All checks should pass before running on real data.

---

## Usage

```bash
./scripts/wpsboot.sh -i <aln1.fasta> -i <aln2.fasta> [...] -o <output_dir> [options]
```

### Required

| Flag | Description |
|---|---|
| `-i <file>` | Input alignment (FASTA). Specify once per alignment — minimum 2 required. |
| `-o <dir>`  | Output directory (created if it does not exist). |

### Options

| Flag | Default | Description |
|---|---|---|
| `-n <int>` | N × 100 | Number of bootstrap replicates (N = number of input alignments) |
| `-p <float>` | 1/N | Partial sampling fraction (0.0–1.0) |
| `-m <model>` | GTR+G | Substitution model for RAxML-NG |
| `-T <int>` | 4 | Number of threads |
| `-s <int>` | — | Random seed for reproducible bootstrap sampling (default: time-based) |
| `-f` | — | Force rerun of all steps, ignoring any existing outputs |
| `-k` | — | Keep intermediate per-replicate bootstrap files (default: deleted after step 5) |
| `-h` | — | Show help and exit |

---

## Examples

Two yeast gene families are included in `example/`, each with seven alignments produced by different alignment tools.

Input alignments can be specified individually with `-i` or with a glob:

```bash
# Glob shorthand (requires all files in the directory to be input alignments)
./scripts/wpsboot.sh -i "example/YPL070W/*.fasta" -o results/YPL070W
```

### YPL070W

```bash
./scripts/wpsboot.sh \
    -i example/YPL070W/clustalw_YPL070W.fasta \
    -i example/YPL070W/DCA_YPL070W.fasta \
    -i example/YPL070W/dialign_YPL070W.fasta \
    -i example/YPL070W/mafft_YPL070W.fasta \
    -i example/YPL070W/muscle_YPL070W.fasta \
    -i example/YPL070W/probcons_YPL070W.fasta \
    -i example/YPL070W/tcoffee_YPL070W.fasta \
    -o results/YPL070W
```

### YDR192C

```bash
./scripts/wpsboot.sh \
    -i example/YDR192C/clustalw_YDR192C.fasta \
    -i example/YDR192C/DCR_YDR192C.fasta \
    -i example/YDR192C/dialign_YDR192C.fasta \
    -i example/YDR192C/mafft_YDR192C.fasta \
    -i example/YDR192C/muscle_YDR192C.fasta \
    -i example/YDR192C/probcons_YDR192C.fasta \
    -i example/YDR192C/tcoffee_YDR192C.fasta \
    -o results/YDR192C
```

With 7 alignments the defaults resolve to:
- Bootstrap replicates: **700** (7 × 100)
- Partial fraction: **0.143** (1/7) — each replicate draws approximately one alignment's worth of sites from the super-MSA

Or run via the test script:

```bash
./test.sh                        # quick test, YPL070W (default)
./test.sh --full                 # full test,  YPL070W
./test.sh --gene YDR192C         # quick test, YDR192C
./test.sh --gene YDR192C --full  # full test,  YDR192C
./test.sh --gene all             # quick test, both genes
./test.sh --gene all --full      # full test,  both genes
```

---

## Output

The final result is written to:

```
<output_dir>/wpSBOOT_result.nwk    ← ML tree with bootstrap support values
<output_dir>/wpsboot.log           ← full pipeline log
```

Intermediate files are organised by pipeline step:

```
<output_dir>/
├── 01_similarity/
│   └── similarity.csv             ← per-alignment avg similarity and weight
├── 02_superMSA/
│   ├── super_aln.phylip           ← concatenated super-MSA (PHYLIP format)
│   └── site_weights.txt           ← one weight per site (input to wei_seqboot)
├── 03_bootstrap/
│   └── outfile                    ← all bootstrap replicates (PHYLIP, concatenated)
├── 04_ml_tree/
│   └── ml_tree.raxml.bestTree     ← ML best tree (Newick)
├── 05_boot_trees/
│   └── bootstrap_trees.nwk        ← all bootstrap trees (one per line)
└── 06_support/
    └── support.raxml.support      ← support tree (also copied to wpSBOOT_result.nwk)
```

### Support summary

A helper script `scripts/support_summary.py` reports per-node and whole-tree bootstrap support:

```bash
# Per-node summary + tree topology
python3 scripts/support_summary.py <output_dir>/wpSBOOT_result.nwk

# Also compute whole-tree topology support
python3 scripts/support_summary.py <output_dir>/wpSBOOT_result.nwk \
    <output_dir>/05_boot_trees/bootstrap_trees.nwk

# Verbose: print each bootstrap tree and its match status
python3 scripts/support_summary.py <output_dir>/wpSBOOT_result.nwk \
    <output_dir>/05_boot_trees/bootstrap_trees.nwk --verbose
```

**Per-node support** (from `wpSBOOT_result.nwk`): the fraction of bootstrap trees containing each bipartition, as mapped by RAxML-NG.

**Whole-tree topology support**: the fraction of bootstrap trees whose unrooted topology is identical to the ML reference tree (all bipartitions match simultaneously). This is a stricter measure than per-node support — a tree is counted only if every internal branch matches.

---

## Method

### Alignment weighting (Step 1)

For each pair of input alignments, `t_coffee -other_pg aln_compare -compare_mode column` computes a column-wise similarity score. The weight for each alignment is:

```
weight = 100 − average_pairwise_similarity
```

Alignments that differ more from the others receive higher weight, reflecting their contribution of unique phylogenetic signal.

### Weighted super-MSA (Step 2)

All N input alignments are concatenated in order into a single PHYLIP-format super-MSA using `concatenate.pl` (BioPerl). Each site in the super-MSA inherits the weight of its source alignment, producing a per-site weight file for `wei_seqboot`.

### Weighted partial bootstrap (Step 3)

`wei_seqboot` generates bootstrap samples from the super-MSA:
- Sites are drawn with probability proportional to their weight
- Only a fraction (default 1/N) of all sites are selected per replicate
- Selected sites are then resampled with replacement (standard bootstrap)

### ML tree inference (Step 4)

`raxml-ng` infers the maximum-likelihood tree from the full super-MSA using the specified substitution model (default: GTR+G). This serves as the reference topology onto which bootstrap support values are later mapped.

### Bootstrap tree inference (Step 5)

`raxml-ng` infers one ML tree per bootstrap replicate in parallel (up to `THREADS` jobs at a time). All bootstrap trees are collected into a single file for the final step.

### Bootstrap support mapping (Step 6)

`raxml-ng --support` compares each bootstrap tree against the ML reference tree and annotates each internal branch of the ML tree with the fraction of bootstrap replicates that contain the same bipartition. The annotated tree is written to `wpSBOOT_result.nwk`.

---

## Repository structure

```
wpSBOOT/
├── bin/                      ← executables (t_coffee, raxml-ng, wei_seqboot)
├── scripts/
│   ├── wpsboot.sh            ← main pipeline wrapper
│   ├── step1_similarity.sh
│   ├── step2_superMSA.sh
│   ├── step3_bootstrap.sh
│   ├── step4_ml_tree.sh
│   ├── step5_boot_trees.sh
│   ├── step6_support.sh
│   ├── concatenate.pl        ← BioPerl alignment concatenation
│   └── support_summary.py    ← bootstrap support summary (per-node + whole-tree)
├── src/                      ← wei_seqboot C++ source (main.cpp, element.cpp, makefile)
├── example/
│   ├── YPL070W/              ← 7 FASTA alignments for YPL070W
│   └── YDR192C/              ← 7 FASTA alignments for YDR192C
├── test.sh                   ← test script (supports --gene, --full)
└── LICENSE
```

---

## License

GPL3 License. See [LICENSE](LICENSE) for details.

---

## Web Server

> **Note:** The web server is currently unavailable. Please use the command-line interface described above.

~~https://wpsboot.page.link/main~~

---

## References

- Chang J-M, Floden EW, Herrero J, Gascuel O, Di Tommaso P, Notredame C (2019) [Incorporating alignment uncertainty into Felsenstein’s phylogenetic bootstrap to improve its reliability](https://doi.org/10.1093/bioinformatics/btz082). *Bioinformatics* 35:4386–4388
- Ashkenazy H, Sela I, Levy Karin E, Landan G, Pupko T (2019) [Multiple sequence alignment averaging improves phylogeny reconstruction](https://doi.org/10.1093/sysbio/syy036). *Systematic Biology* 68:117–130
- Notredame C, et al. (2000) [T-Coffee: A novel method for fast and accurate multiple sequence alignment](https://doi.org/10.1006/jmbi.2000.4042). *J Mol Biol* 302:205–217
- Kozlov AM, et al. (2019) [RAxML-NG: A fast, scalable and user-friendly tool for maximum likelihood phylogenetic inference](https://doi.org/10.1093/bioinformatics/btz305). *Bioinformatics* 35:4453–4455
