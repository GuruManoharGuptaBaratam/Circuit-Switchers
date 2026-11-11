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

if ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: vvp is not installed or not on PATH." >&2
    echo "It is normally installed with Icarus Verilog." >&2
    exit 127
fi

mkdir -p build results/logs results/waveforms

COMPILE_LOG="results/logs/address_decoder_compile.log"
TEST_LOG="results/logs/address_decoder_final.log"
SIM_BINARY="build/address_decoder_sim"

echo "Compiling address decoder unit test..."
iverilog -g2012 -Wall \
    -s tb_address_decoder \
    -o "${SIM_BINARY}" \
    rtl/address_decoder.v \
    tb/tb_address_decoder.v \
    2>&1 | tee "${COMPILE_LOG}"

echo "Running address decoder unit test..."
vvp "${SIM_BINARY}" 2>&1 | tee "${TEST_LOG}"

if [[ ! -s results/waveforms/address_decoder.vcd ]]; then
    echo "ERROR: simulation completed without producing the expected VCD file." >&2
    exit 1
fi

echo "SUCCESS: address decoder tests completed."
echo "Test log: ${REPO_ROOT}/${TEST_LOG}"
echo "Waveform: ${REPO_ROOT}/results/waveforms/address_decoder.vcd"
