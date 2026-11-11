#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_ROOT}"

if ! command -v iverilog >/dev/null 2>&1; then
    echo "ERROR: Icarus Verilog (iverilog) is not installed or not on PATH." >&2
    echo "See README.md for installation instructions." >&2
    exit 127
fi

mkdir -p build results/logs

COMPILE_LOG="results/logs/cache_top_compile_check.log"
COMPILE_OUTPUT="build/cache_top_compile_check"

echo "Checking cache_top ports and elaboration with build-only stubs..."
iverilog -g2012 -Wall \
    -s cache_top \
    -o "${COMPILE_OUTPUT}" \
    rtl/address_decoder.v \
    rtl/cache_data_ram.v \
    rtl/tag_ram.v \
    rtl/valid_bit_ram.v \
    rtl/cache_top.v \
    tb/stubs/cache_top_dependency_stubs.v \
    2>&1 | tee "${COMPILE_LOG}"

echo "SUCCESS: cache_top compiled with the delivered RTL and build-only stubs."
echo "Compile log: ${REPO_ROOT}/${COMPILE_LOG}"
