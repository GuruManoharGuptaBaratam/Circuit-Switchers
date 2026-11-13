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

COMPILE_LOG="results/logs/cache_controller_compile.log"
SIM_LOG="results/logs/cache_controller_final.log"
SIM_BIN="build/cache_controller_sim"
WAVEFORM="results/waveforms/cache_controller_final.vcd"

echo "Compiling cache controller test against the fully integrated cache_top (no stubs)..."
iverilog -g2012 -Wall -s tb_cache_controller -o "${SIM_BIN}" \
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
    tb/tb_cache_controller.v \
    2>&1 | tee "${COMPILE_LOG}"

echo "Running cache controller test..."
vvp "${SIM_BIN}" 2>&1 | tee "${SIM_LOG}"

grep -q "RESULT: ALL TESTS PASSED" "${SIM_LOG}" || { echo "FAILURE: see ${SIM_LOG}" >&2; exit 1; }
test -s "${WAVEFORM}"

echo "SUCCESS: cache controller tests passed and waveform generated."
echo "Test log: ${REPO_ROOT}/${SIM_LOG}"
echo "Waveform: ${REPO_ROOT}/${WAVEFORM}"
