#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

# Ensure Homebrew path is checked if not in standard PATH
if ! command -v iverilog >/dev/null 2>&1; then
    if [ -x "/opt/homebrew/bin/iverilog" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
    fi
fi

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: Icarus Verilog (iverilog) is not installed or not on PATH." >&2
    echo "See README.md for installation instructions." >&2
    exit 127
fi

mkdir -p build results/logs

COMPILE_LOG="results/logs/cache_top_compile_check.log"
COMPILE_OUTPUT="build/cache_top_compile_check"

echo "Checking cache_top ports and elaboration with all delivered RTL (no stubs)..."
iverilog -g2012 -Wall \
    -s cache_top \
    -o "${COMPILE_OUTPUT}" \
    rtl/address_decoder.v \
    rtl/cache_data_ram.v \
    rtl/tag_ram.v \
    rtl/valid_bit_ram.v \
    rtl/tag_comparator.v \
    rtl/cache_lookup.v \
    rtl/data_selector.v \
    rtl/cache_controller.v \
    rtl/main_memory_model.v \
    rtl/cache_top.v \
    2>&1 | tee "${COMPILE_LOG}"

echo "SUCCESS: cache_top compiled with the complete delivered RTL."
echo "Compile log: ${REPO_ROOT}/${COMPILE_LOG}"
