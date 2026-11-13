# Circuit Switchers

**Modern Computer Architecture - Project 6: Direct-Mapped Cache Controller**

Circuit Switchers is a five-member Verilog project implementing a 1 KB direct-mapped cache with 16-byte blocks and 32-bit byte addresses. The submission deadline is **16 November 2026**.

This repository contains:
- Member 01's address decoder, top-level integration skeleton, and interface contract;
- Member 02's tested cache storage (data RAM, tag RAM, and valid-bit RAM);
- Member 03's tested tag comparator, cache lookup decision logic, and 16-to-1 data selector;
- Member 04's tested controller FSM and deterministic main-memory model.

With Member 04's modules, `cache_top` is now a complete, runnable read-only cache. Member 05's system-level traces, statistics, AMAT and synthesis evidence are still pending.

## Cache configuration

| Parameter | Value |
|---|---:|
| Address width | 32 bits |
| Cache capacity | 1024 bytes |
| Block size | 16 bytes / 128 bits |
| Number of lines | 64 |
| Tag width | 22 bits |
| Index width | 6 bits |
| Offset width | 4 bits |

```text
32-bit address = [ tag: address[31:10] ][ index: address[9:4] ][ offset: address[3:0] ]
```

## Team roles

| Member | Responsibility | Status |
|---|---|---|
| Member 01 | Address decoder, top-level integration, shared interfaces, architecture | Delivered |
| Member 02 | Cache data RAM, tag RAM, valid-bit RAM | Delivered |
| Member 03 | Tag comparison, hit logic, byte selection | Delivered |
| Member 04 | Controller FSM and deterministic main-memory model | Delivered |
| Member 05 | System testbenches, traces, metrics, waveforms, synthesis evidence | In progress |

## Repository layout

```text
Circuit-Switchers/
|-- README.md
|-- docs/
|   |-- architecture.md
|   |-- address_breakdown.md
|   |-- interface_contract.md
|   |-- cache_storage.md
|   |-- cache_lookup.md
|   |-- address_decoder_test_plan.md
|   |-- controller_requirements.md
|   |-- fsm_design.md
|   |-- memory_model.md
|   |-- system_test_requirements.md
|   `-- report/
|-- rtl/
|   |-- address_decoder.v
|   |-- cache_top.v
|   |-- cache_data_ram.v
|   |-- tag_ram.v
|   |-- valid_bit_ram.v
|   |-- tag_comparator.v
|   |-- cache_lookup.v
|   |-- data_selector.v
|   |-- cache_controller.v
|   `-- main_memory_model.v
|-- tb/
|   |-- tb_address_decoder.v
|   |-- tb_cache_storage.v
|   |-- tb_cache_lookup.v
|   |-- tb_cache_controller.v
|   `-- stubs/
|       `-- cache_top_dependency_stubs.v
|-- scripts/
|   |-- run_address_decoder_test.sh
|   |-- run_cache_storage_test.sh
|   |-- run_cache_lookup_test.sh
|   |-- run_cache_controller_test.sh
|   |-- plot_controller_figures.py
|   |-- check_cache_top.sh
|   `-- capture_phase1_evidence.py
|-- results/
|   |-- logs/
|   |-- waveforms/
|   |-- metrics/
|   `-- synthesis/
`-- submission/
    `-- README_Submission.txt
```

`tb/stubs/cache_top_dependency_stubs.v` holds the original compile-only placeholders for Member 04's modules. The real `rtl/cache_controller.v` and `rtl/main_memory_model.v` now replace them, so no script uses the stubs. Never compile the stubs together with the real files, because that defines each module twice.

## Member 01 implementation

### Address decoder

`rtl/address_decoder.v` is a combinational, synthesizable bit-slice module:

```verilog
tag    = address[31:10];
index  = address[9:4];
offset = address[3:0];
```

### Top-level integration

`rtl/cache_top.v` instantiates the agreed decoder, storage, lookup, byte selection, controller, and main-memory boundaries. It contains only connection and alignment logic. Its expected dependency ports are specified in `docs/interface_contract.md`.

The initial milestone is:

- read-only;
- byte-wide responses;
- one outstanding request;
- active-high synchronous reset;
- request `valid/ready` acceptance;
- one-cycle response-valid completion;
- 128-bit aligned memory refill.

Write-through versus write-back remains an instructor/team decision.

## Software requirements

- Git
- Icarus Verilog (`iverilog` and `vvp`)
- GTKWave (optional, for viewing VCD files)

### Installation examples

Do not run these commands if the tools are already installed. Use the installation method approved for your computer or lab.

macOS with Homebrew:

```bash
brew install icarus-verilog
brew install --cask gtkwave
```

Ubuntu or Debian:

```bash
sudo apt update
sudo apt install iverilog gtkwave
```

Verify the tools:

```bash
iverilog -V
vvp -V
gtkwave --version
```

## Run the address decoder test

From the repository root:

```bash
./scripts/run_address_decoder_test.sh
```

Expected summary:

```text
SUMMARY: 6 run, 6 passed, 0 failed
ALL ADDRESS DECODER TESTS PASSED
```

Generated files:
- `results/logs/address_decoder_compile.log`
- `results/logs/address_decoder_final.log`
- `results/waveforms/address_decoder.vcd`

## Member 02 implementation

### Cache storage

`rtl/cache_data_ram.v`, `rtl/tag_ram.v`, and `rtl/valid_bit_ram.v` are the 64-line storage array:

- data: 64 x 128 bits, combinational read, synchronous full-block write, no reset
- tag: 64 x 22 bits, combinational read, synchronous write, no reset
- valid: 64 bits, combinational read, synchronous update, active-high synchronous clear of every bit

`reset` on the valid-bit RAM has priority over `write_en`. These modules store and return values. Hit detection and refill sequencing stay in the lookup and controller modules. Dimensions, timing, and presentation notes are in `docs/cache_storage.md`.

### Run the storage test

From the repository root:

```bash
./scripts/run_cache_storage_test.sh
```

Expected summary:

```text
SUMMARY: 22 run, 22 passed, 0 failed
ALL CACHE STORAGE TESTS PASSED
```

Generated files:
- `results/logs/cache_storage_compile.log`
- `results/logs/cache_storage_final.log`
- `results/waveforms/cache_storage.vcd`

## Member 03 implementation

### Cache lookup, tag check, and data selection

Member 03 delivers three synthesizable combinational modules:

1. **`rtl/tag_comparator.v`**: Compares the 22-bit requested tag with the 22-bit stored tag read from tag RAM.
2. **`rtl/cache_lookup.v`**: Instantiates `tag_comparator` and computes the exact hit decision:
   $$\text{hit} = \text{stored\_valid} \land \text{tags\_match}$$
   If `stored_valid == 1'b0`, `hit` is guaranteed to be `1'b0` even if uninitialized/leftover tag bits match.
3. **`rtl/data_selector.v`**: Pure combinational 16-to-1 byte multiplexer extracting the requested byte from a 128-bit block using the 4-bit offset:
   $$\text{selected\_byte} = \text{block\_data}[(8 \times \text{byte\_offset}) +: 8]$$
   Instantiated twice in `cache_top.v` (for cached hit readback and refill bypass).

Design notes, hand-off timing, and walkthrough examples are in `docs/cache_lookup.md`.

### Run the cache lookup test

From the repository root:

```bash
./scripts/run_cache_lookup_test.sh
```

Equivalent manual commands:

```bash
mkdir -p build results/logs results/waveforms
iverilog -g2012 -Wall -s tb_cache_lookup \
  -o build/cache_lookup_sim \
  rtl/tag_comparator.v rtl/cache_lookup.v rtl/data_selector.v tb/tb_cache_lookup.v
vvp build/cache_lookup_sim
```

Expected summary:

```text
SUMMARY: 41 run, 41 passed, 0 failed
ALL CACHE LOOKUP TESTS PASSED
```

Generated files:
- `results/logs/cache_lookup_compile.log`
- `results/logs/cache_lookup_final.log`
- `results/waveforms/cache_lookup.vcd`

To view the waveforms in GTKWave:

```bash
gtkwave results/waveforms/cache_lookup.vcd
```

### Cache controller FSM and main-memory model

Member 04 delivers:

1. **`rtl/cache_controller.v`**: 4-state FSM (`IDLE → LOOKUP → [MEM_WAIT] → RESPOND`). It captures the request, returns hits without touching memory, and on a miss holds `mem_req` until `mem_ready`. It then pulses `refill_write_en` once to install data/tag/valid and returns the requested byte with a one-cycle `resp_valid`.
2. **`rtl/main_memory_model.v`**: simulation-only 64 KB byte array with deterministic contents `mem[a] = a[7:0] ^ a[15:8] ^ 0xA5` and a fixed `LATENCY` (default 4 cycles). Returns aligned 16-byte blocks with a one-cycle `mem_ready`.

Measured timing: **hit = 2 cycles**, **miss = LATENCY + 4 = 8 cycles**, so the miss penalty is 6 cycles. Details are in `docs/fsm_design.md` and `docs/memory_model.md`.

### Run the cache controller test

```bash
./scripts/run_cache_controller_test.sh
```

This compiles the complete `cache_top` with every member's RTL (no stubs) and runs `tb/tb_cache_controller.v`. It covers reset, cold miss, wait, refill, response, repeat hit, conflict replacement, eviction, reset during a memory wait, and continuous handshake monitors.

Expected summary:

```text
 Tests run: 40  Passed: 40  Failed: 0
 RESULT: ALL TESTS PASSED
```

Generated files:
- `results/logs/cache_controller_final.log`
- `results/waveforms/cache_controller_final.vcd` (miss → mem_req → wait → refill → response, then hit)

To regenerate the FSM diagram and the waveform figure from that VCD (requires Python 3 with matplotlib):

```bash
python3 scripts/plot_controller_figures.py
```

This writes `submission/report/figures/controller_fsm.{pdf,png}`, `submission/report/figures/controller_waveform.{pdf,png}` and `results/waveforms/cache_controller_miss_hit.png`.

## Full-cache integration status

All modules listed in `docs/interface_contract.md` are now implemented, and `cache_top` elaborates with real RTL only. The compile-only stubs are no longer used.

```bash
./scripts/check_cache_top.sh
```

Remaining work belongs to Member 05: full-system workload traces, hit/miss statistics, AMAT and synthesis evidence.

## Collaboration workflow

1. Create a branch for one workstream, for example `feature/member-3-cache-lookup`.
2. Implement and unit-test only the files owned by that workstream.
3. Confirm ports against `docs/interface_contract.md`.
4. Push the branch and open a pull request.
5. Ask at least one affected module owner to review it.
6. Merge only when the branch compiles and tests pass.
7. Re-run integration checks after each merge.

Never force-push shared branches, commit generated simulation binaries, or silently change a shared port.

## Documentation

- `docs/address_breakdown.md` explains tag, index, and offset with six worked examples.
- `docs/interface_contract.md` defines exact ports and handshake behavior.
- `docs/architecture.md` explains the system flow and includes a Mermaid diagram.
- `docs/cache_storage.md` explains the storage dimensions, reset behavior, and controls.
- `docs/cache_lookup.md` explains tag comparison, valid-bit gating, byte-ordering conventions, and walkthrough examples.
- `docs/address_decoder_test_plan.md` records Member 01's unit test.
- `docs/controller_requirements.md` hands the frozen controller requirements to Member 04.
- `docs/fsm_design.md` gives the controller state diagram, state table, timing and test evidence.
- `docs/memory_model.md` explains memory addressing, deterministic contents, block layout and latency.
- `docs/system_test_requirements.md` hands verification requirements to Member 05 without occupying Member 05's final `docs/test_plan.md`.
