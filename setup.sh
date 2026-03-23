#!/bin/bash
#
# setup.sh - wpSBOOT installation script
# https://github.com/changlabtw/wpSBOOT
#
# This script:
#   1. Compiles wei_seqboot from src/ and places the binary in bin/
#   2. Locates t_coffee and raxml-ng (from PATH or user-supplied paths)
#      and symlinks them into bin/
#
# Usage:
#   ./setup.sh                        # auto-detect tools in PATH
#   ./setup.sh --tcoffee /path/to/t_coffee --raxml /path/to/raxml-ng
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
SRC_DIR="$SCRIPT_DIR/src"

# --- Colours ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; }

# --- Parse optional arguments ---
TCOFFEE_PATH=""
RAXML_PATH=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --tcoffee) TCOFFEE_PATH="$2"; shift 2 ;;
        --raxml)   RAXML_PATH="$2";   shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--tcoffee <path>] [--raxml <path>]"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "========================================"
echo " wpSBOOT setup"
echo "========================================"

mkdir -p "$BIN_DIR"

# -----------------------------------------------
# 1. Compile wei_seqboot
# -----------------------------------------------
echo ""
echo "--- Compiling wei_seqboot ---"

# Check for a C++11-compatible compiler
if command -v g++ &>/dev/null; then
    CXX=g++
elif command -v clang++ &>/dev/null; then
    CXX=clang++
else
    fail "No C++ compiler found (g++ or clang++ required)"
    exit 1
fi
ok "Compiler: $CXX"

# Run make in src/
cd "$SRC_DIR"
make CXX="$CXX" --silent
cd "$SCRIPT_DIR"

if [[ -x "$BIN_DIR/wei_seqboot" ]]; then
    ok "wei_seqboot compiled -> bin/wei_seqboot"
else
    fail "wei_seqboot compilation failed"
    exit 1
fi

# -----------------------------------------------
# 2. Locate t_coffee
# -----------------------------------------------
echo ""
echo "--- Locating t_coffee ---"

if [[ -n "$TCOFFEE_PATH" ]]; then
    # User supplied a path
    if [[ -x "$TCOFFEE_PATH" ]]; then
        ln -sf "$TCOFFEE_PATH" "$BIN_DIR/t_coffee"
        ok "t_coffee linked from: $TCOFFEE_PATH"
    else
        fail "t_coffee not executable at: $TCOFFEE_PATH"
        exit 1
    fi
elif command -v t_coffee &>/dev/null; then
    # Found in PATH — symlink into bin/
    ln -sf "$(command -v t_coffee)" "$BIN_DIR/t_coffee"
    ok "t_coffee found in PATH -> linked to bin/t_coffee"
elif [[ -x "$BIN_DIR/t_coffee" ]]; then
    ok "t_coffee already present in bin/"
else
    warn "t_coffee not found"
    echo "       Download from: http://www.tcoffee.org/Projects/tcoffee/#DOWNLOAD"
    echo "       Then re-run:   ./setup.sh --tcoffee /path/to/t_coffee"
    echo "       Or place the binary manually in bin/t_coffee"
fi

# -----------------------------------------------
# 3. Locate raxml-ng
# -----------------------------------------------
echo ""
echo "--- Locating raxml-ng ---"

if [[ -n "$RAXML_PATH" ]]; then
    if [[ -x "$RAXML_PATH" ]]; then
        ln -sf "$RAXML_PATH" "$BIN_DIR/raxml-ng"
        ok "raxml-ng linked from: $RAXML_PATH"
    else
        fail "raxml-ng not executable at: $RAXML_PATH"
        exit 1
    fi
elif command -v raxml-ng &>/dev/null; then
    ln -sf "$(command -v raxml-ng)" "$BIN_DIR/raxml-ng"
    ok "raxml-ng found in PATH -> linked to bin/raxml-ng"
elif [[ -x "$BIN_DIR/raxml-ng" ]]; then
    ok "raxml-ng already present in bin/"
else
    warn "raxml-ng not found"
    echo "       Download from: https://github.com/amkozlov/raxml-ng/releases"
    echo "       Then re-run:   ./setup.sh --raxml /path/to/raxml-ng"
    echo "       Or place the binary manually in bin/raxml-ng"
fi

# -----------------------------------------------
# 4. Check BioPerl
# -----------------------------------------------
echo ""
echo "--- Checking BioPerl ---"

PERL_BIN="$(command -v perl 2>/dev/null || true)"
if [[ -z "$PERL_BIN" ]]; then
    warn "perl not found — required for concatenate.pl"
elif "$PERL_BIN" -e "use Bio::AlignIO;" 2>/dev/null; then
    ok "BioPerl available ($PERL_BIN)"
else
    warn "BioPerl not found (required by concatenate.pl)"
    echo "       Install with: cpan Bio::AlignIO Bio::Align::Utilities Bio::LocatableSeq"
fi

# -----------------------------------------------
# 5. Summary
# -----------------------------------------------
echo ""
echo "========================================"
echo " Setup complete. Verify with: ./test.sh"
echo "========================================"
