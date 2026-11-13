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

for tool in iverilog vvp; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool is required." >&2; exit 127; }
done

mkdir -p build results/logs results/waveforms

COMPILE_LOG="results/logs/cache_lookup_compile.log"
SIM_LOG="results/logs/cache_lookup_final.log"
SIM_BIN="build/cache_lookup_sim"
WAVEFORM="results/waveforms/cache_lookup.vcd"

echo "Compiling cache lookup unit test..."
iverilog -g2012 -Wall -s tb_cache_lookup -o "${SIM_BIN}" \
    rtl/tag_comparator.v \
    rtl/cache_lookup.v \
    rtl/data_selector.v \
    tb/tb_cache_lookup.v \
    2>&1 | tee "${COMPILE_LOG}"

echo "Running cache lookup unit test..."
vvp "${SIM_BIN}" 2>&1 | tee "${SIM_LOG}"

test -s "${WAVEFORM}"

echo "SUCCESS: cache lookup unit tests and waveform generation completed."
echo "Test log: ${REPO_ROOT}/${SIM_LOG}"
echo "Waveform: ${REPO_ROOT}/${WAVEFORM}"

