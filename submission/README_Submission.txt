CIRCUIT SWITCHERS - MCA PROJECT 6
MEMBER 01 SUBMISSION STATUS

Implemented by Member 01:
- rtl/address_decoder.v
- rtl/cache_top.v
- tb/tb_address_decoder.v
- docs/address_breakdown.md
- docs/interface_contract.md
- docs/architecture.md
- docs/address_decoder_test_plan.md
- docs/controller_requirements.md
- docs/system_test_requirements.md
- scripts/run_address_decoder_test.sh
- scripts/check_cache_top.sh
- tb/stubs/cache_top_dependency_stubs.v
- README.md and project scaffolding

Integrated and verified by Member 02:
- rtl/cache_data_ram.v
- rtl/tag_ram.v
- rtl/valid_bit_ram.v
- tb/tb_cache_storage.v
- docs/cache_storage.md
- results/logs/cache_storage_final.log

Current scope:
- 32-bit address split into 22-bit tag, 6-bit index, and 4-bit offset
- Read-only, byte-wide first integration milestone
- Top-level integration skeleton using the shared interface contract

Pending team integration:
- Member 03 lookup, comparator, and data-selector RTL
- Member 04 controller FSM and main-memory model RTL
- Member 05 full-system tests, metrics, waveform evidence, and synthesis results

Do not submit this placeholder as the final team report. Before final submission,
replace or extend it with the repository URL, commit/tag, exact run commands,
tool versions, verified test results, report/slides, evidence locations, and any
declared limitations.
