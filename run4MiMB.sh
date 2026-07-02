# Run the six MiMB configurations sequentially, pausing between each so the
# user can stop at any point. Set AUTO_YES=1 to skip prompts (batch mode).

set -u

if [ ! -d "logs" ]; then
  mkdir -p logs
  echo "Created 'logs' directory."
fi

AUTO_YES="${AUTO_YES:-0}"

prompt_next() {
    local next_desc=$1
    if [ "$AUTO_YES" = "1" ]; then
        return 0
    fi
    printf 'Run next config (%s)? [y/N] ' "$next_desc"
    read -r reply < /dev/tty
    case "$reply" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) echo "Stopping."; return 1 ;;
    esac
}

run_cfg() {
    local gene_n=$1
    local tag=$2
    shift 2
    local out="res4MiMB/${gene_n}_${tag}"
    local log="logs/${gene_n}_${tag}.log"
    local args=()
    for a in "$@"; do
        args+=(-i "example/nucleotide/${gene_n}/${a}")
    done
    echo ">>> Running ${gene_n}_${tag}"
    ./scripts/wpsboot.sh "${args[@]}" -o "$out" -s 42 -f > "$log"
    echo ">>> ${gene_n}_${tag} finished (log: $log)"
}

# Ordered list of configurations: gene tag aln1 aln2 ...
CONFIGS=(
    "YPL070W|7aln|clustalw.fasta DCA.fasta dialign.fasta mafft.fasta muscle.fasta probcons.fasta tcoffee.fasta"
    "YPL070W|3aln-clustal-tcoffee-probcons|clustalw.fasta tcoffee.fasta probcons.fasta"
    "YPL070W|3aln-clustal-tcoffee-mafft|clustalw.fasta tcoffee.fasta mafft.fasta"
    "YDR192C|7aln|clustalw.fasta DCA.fasta dialign.fasta mafft.fasta muscle.fasta probcons.fasta tcoffee.fasta"
    "YDR192C|3aln-clustal-tcoffee-probcons|clustalw.fasta tcoffee.fasta probcons.fasta"
    "YDR192C|3aln-clustal-tcoffee-mafft|clustalw.fasta tcoffee.fasta mafft.fasta"
)

n=${#CONFIGS[@]}
for ((i=0; i<n; i++)); do
    IFS='|' read -r gene tag alns <<< "${CONFIGS[i]}"
    # Ask before starting each config (skip the confirmation for the very first one)
    if [ "$i" -gt 0 ]; then
        prompt_next "${gene}_${tag}" || exit 0
    fi
    # shellcheck disable=SC2086
    run_cfg "$gene" "$tag" $alns
done

echo "All configurations complete."
