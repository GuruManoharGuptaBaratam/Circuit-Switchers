CIRCUIT SWITCHERS - MCA PROJECT 6
MEMBER 01 SUBMISSION STATUS

Implemented by Member 01:
- rtl/address_decoder.v
- rtl/cache_top.v
- tb/tb_address_decoder.v
- docs/address_breakdown.md
- docs/interface_contract.md
- docs/architecture.md
- scripts/run_sim.sh
- README.md and project scaffolding

Current scope:
- 32-bit address split into 22-bit tag, 6-bit index, and 4-bit offset
- Read-only, byte-wide first integration milestone
- Top-level integration skeleton using the shared interface contract

Pending team integration:
- Member 02 cache data/tag/valid storage RTL
- Member 03 lookup, comparator, and data-selector RTL
- Member 04 controller FSM and main-memory model RTL
- Member 05 full-system tests, metrics, waveform evidence, and synthesis results

Do not submit this placeholder as the final team report. Before final submission,
replace or extend it with the repository URL, commit/tag, exact run commands,
tool versions, verified test results, report/slides, evidence locations, and any
declared limitations.
