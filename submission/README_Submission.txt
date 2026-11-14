CIRCUIT SWITCHERS - MCA PROJECT 6
PHASE I SUBMISSION STATUS

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

Integrated and verified by Member 04:
- rtl/cache_controller.v
- rtl/main_memory_model.v
- tb/tb_cache_controller.v
- docs/fsm_design.md
- docs/memory_model.md
- scripts/run_cache_controller_test.sh
- results/logs/cache_controller_final.log
- results/waveforms/cache_controller_final.vcd
- results/waveforms/cache_controller_miss_hit.png
- scripts/plot_controller_figures.py
- submission/report/figures/controller_fsm.{pdf,png} (now the implemented FSM)
- submission/report/figures/controller_waveform.{pdf,png}
- submission/presentation/member04_slides.md

Current scope:
- 32-bit address split into 22-bit tag, 6-bit index, and 4-bit offset
- Read-only, byte-wide first integration milestone
- Integrated cache using the shared interface contract

Member 05 evidence:
- Test plan and results: docs/test_plan.md and docs/results_summary.md
- Complete regression: bash scripts/run_all_tests.sh
- Generic synthesis: bash scripts/run_synthesis.sh
- IEEE report: submission/report/circuit_switchers_ieee_report.pdf

Prototype video: Recording pending.
