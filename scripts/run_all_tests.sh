#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
case "${1:-all}" in
    all|components|system) scope=${1:-all} ;;
    *) echo "Usage: $0 [all|components|system]" >&2; exit 2 ;;
esac

mkdir -p results/logs results/waveforms
failures=0
if [[ $scope != system ]]; then
    for check in address_decoder cache_storage cache_lookup cache_controller cache_top; do
        script="run_${check}_test.sh"
        if [[ $check == cache_top ]]; then script=check_cache_top.sh; fi
        log="results/logs/${check}_regression_final.log"
        if bash "scripts/$script" >"$log" 2>&1; then
            echo "PASS $check ($log)"
            if [[ -f results/waveforms/$check.vcd ]]; then
                cp "results/waveforms/$check.vcd" "results/waveforms/${check}_final.vcd"
            fi
        else
            echo "FAIL $check ($log)" >&2
            failures=$((failures + 1))
        fi
    done
fi
if [[ $scope != components ]]; then
    for workload in system sequential repeated conflict random; do
        if ! bash scripts/run_sim.sh "$workload"; then failures=$((failures + 1)); fi
    done
fi
if (( failures > 0 )); then
    echo "FAIL regression ($failures failing targets)" >&2
    exit 1
fi
if [[ $scope != components ]]; then
    python3 scripts/capture_phase1_evidence.py "$scope"
fi
echo "PASS regression ($scope)"
