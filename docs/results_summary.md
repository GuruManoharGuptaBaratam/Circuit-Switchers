# Phase I results

Icarus Verilog 13.0 passed the decoder (6 checks), storage (22), lookup (41)
and integrated controller (40) tests. The top elaborated with real RTL.
Those assertion counts are independent of the 331 completed reads checked
in the five Member 5 runs. The directed test accounted for three additional
accepted requests canceled by reset. No functional RTL changes were needed.
The preserved Icarus timescale warning concerns modules without delay
statements. Transactions were measured with an explicit bench clock and
rising-edge intervals.

| Workload | Completed | Hits | Misses | AMAT (cycles/read) |
| --- | ---: | ---: | ---: | ---: |
| Directed system | 11 | 3 | 8 | 6.3636 |
| Sequential | 32 | 30 | 2 | 2.3750 |
| Repeated | 16 | 15 | 1 | 2.3750 |
| Conflict | 16 | 0 | 16 | 8.0000 |
| Random | 256 | 39 | 217 | 7.0859 |

See the [metrics CSV](../results/metrics/hit_miss_report.csv),
[AMAT derivation](../results/metrics/amat_calculation.md),
[logs](../results/logs), [waveforms](../results/waveforms) and
[regression manifest](../results/phase1_evidence.json). The old
`*_audit_final.log` and `cache_top_without_stubs_final.log` files are
historical snapshots. The full runner regenerates
`cache_top_regression_final.log` and the omitted VCDs on demand. The checked-in
manifest hashes the retained Member 5 evidence.

The first request in the repeated waveform returns A1 after the aligned
read and refill. The second also returns A1, with the hit flag high and
the memory interface idle. The conflict waveform shows aligned reads at
0x000 and 0x400 and consecutive refills of the same index with different
tags, returning A5 and A1.

[Yosys synthesis](../results/synthesis/README.md) succeeded using an
external-memory cache core. The results are generic cells. The project has
no physical timing flow, device utilization, area or Fmax result.
