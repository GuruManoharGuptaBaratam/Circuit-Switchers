#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

workload=${1:-system}
case "$workload" in
    system) top=tb_cache_system ;;
    sequential|repeated|random) top="tb_${workload}_access" ;;
    conflict) top=tb_conflict_miss ;;
    *) echo "Usage: $0 [system|sequential|repeated|conflict|random]" >&2; exit 2 ;;
esac

for tool in iverilog vvp; do
    command -v "$tool" >/dev/null || { echo "FAIL $workload: $tool is required" >&2; exit 127; }
done

mkdir -p build results/logs results/waveforms
log="results/logs/${workload}_system_final.log"
wave="results/waveforms/${workload}_system_final.vcd"
bench=(tb/tb_cache_system.v)
if [[ $top != tb_cache_system ]]; then
    bench+=("tb/$top.v")
fi
rm -f "$wave"
if ! iverilog -g2012 -Wall -s "$top" -o "build/$top" rtl/*.v "${bench[@]}" >"$log" 2>&1 ||
   ! vvp "build/$top" "+vcd=$wave" >>"$log" 2>&1 ||
   ! grep -qx "PASS $workload" "$log" || [[ ! -s "$wave" ]]; then
    cat "$log" >&2
    echo "FAIL $workload ($log)" >&2
    exit 1
fi
echo "PASS $workload ($log, $wave)"
