#!/usr/bin/env python3
"""Validate passing simulation evidence and regenerate Phase I metrics."""
import csv
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
WORKLOADS = ("system", "sequential", "repeated", "conflict", "random")
COMPONENTS = ("address_decoder", "cache_storage", "cache_lookup", "cache_controller", "cache_top")
COLUMNS = ("workload", "completed", "hits", "misses", "canceled", "hit_rate_pct",
           "miss_rate_pct", "mean_hit_cycles", "mean_miss_cycles", "amat_cycles")
FORMAT = "{:.4f}"


def capture(scope):
    logs = ROOT / "results/logs"
    waves = ROOT / "results/waveforms"
    output = ROOT / "results/metrics"
    output.mkdir(parents=True, exist_ok=True)
    files = list(ROOT.glob("rtl/*.v")) + list(ROOT.glob("tb/*.v"))
    rows, traces = [], []
    all_hit_cycles = all_miss_cycles = all_hits = all_misses = 0
    for workload in WORKLOADS:
        log = logs / f"{workload}_system_final.log"
        wave = waves / f"{workload}_system_final.vcd"
        lines = log.read_text().splitlines()
        if f"PASS {workload}" not in lines or wave.stat().st_size == 0:
            raise SystemExit(f"Missing passing evidence for {workload}")
        [summary] = [line.split(",") for line in lines if line.startswith("METRICS,")]
        _, label, count, hits, misses, hit_cycles, miss_cycles, canceled = summary
        count, hits, misses, hit_cycles, miss_cycles, canceled = map(
            int, (count, hits, misses, hit_cycles, miss_cycles, canceled))
        read_rows = [line.split(",")[1:] for line in lines if line.startswith("READ,")
                     and not line.startswith("READ,number,")]
        hit_samples, miss_samples = [], []
        for expected_number, (number, address, actual, expected, hit, cycles) in enumerate(read_rows, 1):
            if int(number) != expected_number or actual != expected or hit not in ("0", "1"):
                raise SystemExit(f"Malformed or failing read in {log.name}: {number}")
            (hit_samples if hit == "1" else miss_samples).append(int(cycles))
            traces.append((workload, number, "0x" + address, "0x" + actual,
                           "0x" + expected, hit, cycles))
        if (label != workload or count < 1 or count != len(read_rows) or
                (hits, misses, hit_cycles, miss_cycles) !=
                (len(hit_samples), len(miss_samples), sum(hit_samples), sum(miss_samples))):
            raise SystemExit(f"Read rows disagree with the summary in {log.name}")
        all_hits += hits
        all_misses += misses
        all_hit_cycles += hit_cycles
        all_miss_cycles += miss_cycles
        rows.append((workload, count, hits, misses, canceled, 100 * hits / count,
                     100 * misses / count, hit_cycles / hits if hits else None,
                     miss_cycles / misses if misses else None, (hit_cycles + miss_cycles) / count))
        files += [log, wave]
    hit_time = all_hit_cycles / all_hits
    miss_time = all_miss_cycles / all_misses
    penalty = miss_time - hit_time
    calculations = []
    for label, count, _, misses, _, _, _, _, _, observed in rows:
        calculated = hit_time + misses / count * penalty
        if abs(observed - calculated) > 1e-9:
            raise SystemExit(f"{label}: AMAT does not match direct mean of observations")
        calculations.append(
            f"| {label} | {misses}/{count} | {hit_time:g} + ({misses}/{count}) × {penalty:g} | {observed:.4f} |")
    with (output / "hit_miss_report.csv").open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(COLUMNS)
        for row in rows:
            writer.writerow(FORMAT.format(x) if isinstance(x, float) else x for x in row)
    with (output / "request_trace.csv").open("w", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(("workload", "request", "address", "actual", "expected", "hit", "cycles"))
        writer.writerows(traces)
    (output / "amat_calculation.md").write_text(f"""# Average memory access time

Latency is the number of clock periods from the rising edge that accepts
`req_valid && req_ready` to the rising edge that samples `resp_valid`.
The RTL asserts response-valid immediately after E1 for a hit and E7 for
a miss, and the consumer samples it at E2 or E8, respectively. On a miss,
memory accepts at E2, asserts ready after E6 (default latency 4), and
the cache samples ready and refills at E7.

The measured hit time is {hit_time:g} cycles, miss time is {miss_time:g} cycles
and additional miss penalty is {penalty:g} cycles. The observed times below
match the direct mean of all completed reads in each run. Canceled
requests and idle cycles between accesses are excluded. The simulated
clock period is 10 ns. There is no hardware timing or no-cache baseline.

| Workload | Miss fraction | Hit time + miss fraction × penalty | AMAT (cycles/read) |
| --- | --- | --- | ---: |
""" + "\n".join(calculations) + "\n", encoding="utf-8")
    if scope == "all":
        files += [logs / f"{name}_regression_final.log" for name in COMPONENTS]
        files += [waves / f"{name}_final.vcd" for name in COMPONENTS if name != "cache_top"]
    files += list(output.iterdir())
    files += [ROOT / f"scripts/{name}" for name in
              ("run_all_tests.sh", "run_sim.sh", "capture_phase1_evidence.py")]
    manifest = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "baseline_git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "command": "bash scripts/run_all_tests.sh" + (" system" if scope == "system" else ""),
        "iverilog": subprocess.check_output(["iverilog", "-V"], text=True).splitlines()[0],
        "vvp": subprocess.check_output(["vvp", "-V"], stderr=subprocess.STDOUT, text=True).splitlines()[0],
        "passed_component_targets": COMPONENTS if scope == "all" else [],
        "passed_system_workloads": WORKLOADS,
        "sha256": {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
                   for path in sorted(files)},
    }
    (ROOT / "results/phase1_evidence.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    if sys.argv[1:] not in (["all"], ["system"]):
        raise SystemExit("Run scripts/run_all_tests.sh [all|system] to regenerate evidence.")
    capture(sys.argv[1])
