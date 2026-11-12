#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."
for tool in iverilog vvp; do
    command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: $tool is required." >&2; exit 127; }
done
mkdir -p build results/logs results/waveforms
iverilog -g2012 -Wall -s tb_cache_storage -o build/cache_storage_sim \
    rtl/cache_data_ram.v rtl/tag_ram.v rtl/valid_bit_ram.v tb/tb_cache_storage.v \
    2>&1 | tee results/logs/cache_storage_compile.log
vvp build/cache_storage_sim 2>&1 | tee results/logs/cache_storage_final.log
test -s results/waveforms/cache_storage.vcd
echo "SUCCESS: cache storage unit tests and waveform generation completed."
