#!/usr/bin/env bash
# One-shot: add OSS CAD Suite to ~/.bashrc (run from WSL).
set -eu
BRC="$HOME/.bashrc"
if grep -q 'oss-cad-suite/environment' "$BRC" 2>/dev/null; then
  echo "Already present in $BRC"
  exit 0
fi
cat >> "$BRC" << 'EOF'

# OSS CAD Suite (Yosys, sby, iverilog, verilator, …)
if [ -f "$HOME/oss-cad-suite/environment" ]; then
  source "$HOME/oss-cad-suite/environment"
fi
EOF
echo "Appended OSS CAD Suite block to $BRC"
