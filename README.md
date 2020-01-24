# wpSBOOT
weighted partial super bootstrap

## src/concatenate.pl
Union concatenate alignments according to inputting order into a Super-MSA

### requirement
Please install the following modules from BioPerl. Detailed information in <a href="https://bioperl.org/index.html">BioPerl</a>.
* Bio::AlignIO
* Bio::Align::Utilities
* Bio::LocatableSeq

```bash
>perl -MCPAN -e shell
cpan> install Bio::AlignIO
```

### Usage
```bash
concatenate.pl [options] --aln alignment1 alignment2 ... (at least two alignments) --out file
	--intersect: only concatenate sequences appearing in all alignments, otherwise missing sequence is replaced with gap (default)
	--random: concatenate order is random
	--size N: only concatenate first N alignments from inputting, exclusive with replicate mode
	--replicate NUM: replicate one alignment in NUM times, exclusive with size mode
```

### example commend
```bash
../bin/concatanate.pl --aln Dmel_56.phylip_aln Dana_34.phylip_aln Dere_43.phylip_aln
How to concatenate:
	size: 3 alignments
	alignments:
		Dmel_56.phylip_aln
		Dana_34.phylip_aln
		Dere_43.phylip_aln
```
    
### web server @ https://wpsboot.page.link/main

## reference
* original paper: J.-M. Chang, E. W. Floden, J. Herrero, O. Gascuel, P. Di Tommaso, and C. Notredame, <a href="https://doi.org/10.1093/bioinformatics/btz082">Incorporating alignment uncertainty into Felsenstein’s phylogenetic bootstrap to improve its reliability</a>. *Bioinformatics*, Feb. 2019
* related work: H Ashkenazy, I Sela, E Levy Karin, G Landan, T Pupko, <a href="https://doi.org/10.1093/sysbio/syy036"> Multiple sequence alignment averaging improves phylogeny reconstruction</a>. *Systematic biology*, 2019 68 (1), 117-130
