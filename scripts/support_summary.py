#!/usr/bin/env python3
#
# support_summary.py - Bootstrap support summary for a Newick tree
# https://github.com/changlabtw/wpSBOOT
#
# Reads a Newick tree file (e.g. wpSBOOT_result.nwk) and reports:
#   - Tree topology (ASCII) with bootstrap support at internal nodes
#   - Simplified Newick (topology + support, no branch lengths)
#   - Mean, median, min, max bootstrap support
#   - Count and fraction of fully supported nodes (100)
#   - Whole-tree topology support (fraction of bootstrap trees with identical topology)
#
# Usage:
#   python3 support_summary.py <result.nwk>
#   python3 support_summary.py <result.nwk> <bootstrap_trees.nwk>
#

import sys

# ──────────────────────────────────────────────
# Newick parser
# ──────────────────────────────────────────────

def parse_newick(s):
    """Parse a Newick string into a nested dict tree."""
    s = s.strip().rstrip(';')
    pos = [0]
    return _parse_node(s, pos)

def _read_token(s, pos):
    """Read a bare label (name or support value) up to the next special char."""
    start = pos[0]
    while pos[0] < len(s) and s[pos[0]] not in '(),;:':
        pos[0] += 1
    return s[start:pos[0]]

def _parse_node(s, pos):
    node = {'name': '', 'support': None, 'children': []}
    if pos[0] < len(s) and s[pos[0]] == '(':
        pos[0] += 1                          # consume '('
        while True:
            node['children'].append(_parse_node(s, pos))
            if pos[0] >= len(s) or s[pos[0]] != ',':
                break
            pos[0] += 1                      # consume ','
        pos[0] += 1                          # consume ')'
        label = _read_token(s, pos)
        if label:
            try:
                node['support'] = int(label)
            except ValueError:
                node['name'] = label         # labelled clade, not a support value
    else:
        node['name'] = _read_token(s, pos)   # leaf taxon name

    # consume branch length (: value) — stored but not used
    if pos[0] < len(s) and s[pos[0]] == ':':
        pos[0] += 1
        _read_token(s, pos)

    return node

# ──────────────────────────────────────────────
# Topology Newick (support values, no lengths)
# ──────────────────────────────────────────────

def to_topology_newick(node):
    """Reconstruct Newick with support labels but without branch lengths."""
    if not node['children']:
        return node['name']
    inner = ','.join(to_topology_newick(c) for c in node['children'])
    support = str(node['support']) if node['support'] is not None else ''
    return f"({inner}){support}"

# ──────────────────────────────────────────────
# ASCII tree renderer
# ──────────────────────────────────────────────

def _render(node, prefix, connector, child_prefix, lines):
    """Recursively build ASCII tree lines."""
    if node['children']:
        label = f"[{node['support']}]" if node['support'] is not None else '[·]'
    else:
        label = node['name']
    lines.append(prefix + connector + label)

    for i, child in enumerate(node['children']):
        last = (i == len(node['children']) - 1)
        _render(
            child,
            prefix + child_prefix,
            '└── ' if last else '├── ',
            '    ' if last else '│   ',
            lines,
        )

def render_ascii(node):
    """Return ASCII tree as a list of strings."""
    lines = []
    _render(node, '', '', '', lines)
    return lines

# ──────────────────────────────────────────────
# Support value extraction
# ──────────────────────────────────────────────

def collect_support(node, values):
    if node['children']:
        if node['support'] is not None:
            values.append(node['support'])
        for c in node['children']:
            collect_support(c, values)

# ──────────────────────────────────────────────
# Whole-tree topology support
# ──────────────────────────────────────────────

def get_bipartitions(node):
    """
    Return the set of non-trivial bipartitions of an unrooted tree.
    Each bipartition is represented as a frozenset of the taxa on the
    smaller side (canonical form), so rooting differences don't matter.
    """
    all_leaves = _get_leaves(node)
    splits = set()
    _collect_splits(node, all_leaves, splits)
    return splits

def _get_leaves(node):
    if not node['children']:
        return frozenset([node['name']])
    result = frozenset()
    for c in node['children']:
        result = result | _get_leaves(c)
    return result

def _collect_splits(node, all_leaves, splits):
    """Recursively collect bipartitions; returns the leaf set of this subtree."""
    if not node['children']:
        return frozenset([node['name']])
    subtree_leaves = frozenset()
    for c in node['children']:
        cl = _collect_splits(c, all_leaves, splits)
        subtree_leaves = subtree_leaves | cl
    # Record the split defined by this internal node (skip root — both sides = all_leaves)
    other = all_leaves - subtree_leaves
    if subtree_leaves and other:   # non-trivial and not the root edge
        canonical = frozenset(subtree_leaves) if len(subtree_leaves) <= len(other) \
                    else frozenset(other)
        splits.add(canonical)
    return subtree_leaves

def whole_tree_support(ref_tree, boot_trees_file, verbose=False):
    """
    Count how many bootstrap trees have exactly the same unrooted topology
    as the reference tree. Returns (matching_count, total_count).
    If verbose=True, prints each replicate's topology and match status.
    """
    ref_splits = get_bipartitions(ref_tree)
    ref_topo   = to_topology_newick(ref_tree) + ';'
    matched = 0
    total   = 0

    if verbose:
        print("Whole-tree topology match detail")
        print('─' * 35)
        print(f"  Reference: {ref_topo}")
        print('─' * 35)

    try:
        with open(boot_trees_file) as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                total += 1
                boot_tree   = parse_newick(line)
                boot_splits = get_bipartitions(boot_tree)
                is_match    = (boot_splits == ref_splits)
                if is_match:
                    matched += 1
                if verbose:
                    boot_topo = to_topology_newick(boot_tree) + ';'
                    mark = 'MATCH' if is_match else 'DIFF '
                    print(f"  [{total:>3}] {mark}  {boot_topo}")
    except FileNotFoundError:
        print(f"Error: bootstrap trees file not found: {boot_trees_file}", file=sys.stderr)
        sys.exit(1)

    if verbose:
        print('─' * 35)

    return matched, total

# ──────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('-')]
    flags = [a for a in sys.argv[1:] if a.startswith('-')]

    if not args or '-h' in flags or '--help' in flags:
        print(f"""\
Bootstrap support summary for a wpSBOOT result tree.

Usage:
  python3 {sys.argv[0]} <result.nwk> [bootstrap_trees.nwk] [--verbose]

Arguments:
  result.nwk
      ML tree with per-node bootstrap support values produced by wpSBOOT
      (e.g. <output_dir>/wpSBOOT_result.nwk). Reports tree topology, per-node
      support statistics (mean, median, min, max, fully supported nodes).

  bootstrap_trees.nwk  (optional)
      All bootstrap trees in Newick format, one per line
      (e.g. <output_dir>/05_boot_trees/bootstrap_trees.nwk). When provided,
      also computes whole-tree topology support: the fraction of bootstrap
      replicates whose unrooted topology is identical to the ML reference tree.

Options:
  --verbose
      Print each bootstrap replicate's topology and whether it matches the
      reference tree (MATCH / DIFF). Requires bootstrap_trees.nwk.
      Default: off (only the final count is shown).

  -h, --help
      Show this help and exit.

Examples:
  python3 {sys.argv[0]} results/wpSBOOT_result.nwk
  python3 {sys.argv[0]} results/wpSBOOT_result.nwk results/05_boot_trees/bootstrap_trees.nwk
  python3 {sys.argv[0]} results/wpSBOOT_result.nwk results/05_boot_trees/bootstrap_trees.nwk --verbose
""")
        sys.exit(0)

    verbose   = '--verbose' in flags
    boot_file = args[1] if len(args) >= 2 else None

    try:
        with open(args[0]) as fh:
            newick = fh.read().strip()
    except FileNotFoundError:
        print(f"Error: file not found: {args[0]}", file=sys.stderr)
        sys.exit(1)

    tree = parse_newick(newick)

    values = []
    collect_support(tree, values)

    # ── Tree topology ──
    n_taxa = len(_get_leaves(tree))
    topo   = to_topology_newick(tree) + ';'
    print("Tree topology")
    print('─' * 35)
    if n_taxa < 20:
        for line in render_ascii(tree):
            print(' ', line)
    print(f"  Newick: {topo}")
    print('─' * 35)

    # ── Bootstrap summary ──
    print()
    if not values:
        print("No bootstrap support values found.")
        return

    n       = len(values)
    mean    = sum(values) / n
    sv      = sorted(values)
    median  = sv[n // 2] if n % 2 else (sv[n // 2 - 1] + sv[n // 2]) / 2
    minimum = min(values)
    maximum = max(values)
    n_full  = sum(1 for v in values if v == 100)

    print("Bootstrap support summary")
    print('─' * 35)
    print(f"  Internal nodes   : {n}")
    print(f"  Mean             : {mean:.1f}")
    print(f"  Median           : {median:.1f}")
    print(f"  Min              : {minimum}")
    print(f"  Max              : {maximum}")
    print(f"  Fully supported  : {n_full}/{n}  ({100*n_full/n:.0f}%)")
    print('─' * 35)
    print(f"  Per-node values  : {sv}")

    # ── Whole-tree topology support ──
    if boot_file:
        print()
        matched, total = whole_tree_support(tree, boot_file, verbose=verbose)
        pct = 100 * matched / total if total else 0.0
        print("Whole-tree topology support")
        print('─' * 35)
        print(f"  Bootstrap trees  : {total}")
        print(f"  Exact topology   : {matched}/{total}  ({pct:.1f}%)")
        print('─' * 35)

if __name__ == '__main__':
    main()
