#!/bin/zsh
set -euo pipefail

# Always run from the package root where this script lives.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Build once if the debug executable is not present yet.
if [[ ! -x ".build/debug/SFTPSlim" ]]; then
  swift build
fi

open ".build/debug/SFTPSlim"
