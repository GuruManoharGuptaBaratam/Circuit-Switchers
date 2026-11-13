# Circuit Switchers

**Modern Computer Architecture - Project 6: Direct-Mapped Cache Controller**

Circuit Switchers is a five-member Verilog project implementing a 1 KB direct-mapped cache with 16-byte blocks and 32-bit byte addresses. The submission deadline is **16 November 2026**.

This repository contains:
- Member 01's address decoder, top-level integration skeleton, and interface contract;
- Member 02's tested cache storage (data RAM, tag RAM, and valid-bit RAM);
- Member 03's tested tag comparator, cache lookup decision logic, and 16-to-1 data selector.

A runnable complete cache still depends on Member 04's controller FSM & main-memory model and Member 05's system verification.

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
| Member 04 | Controller FSM and deterministic main-memory model | In progress |
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
|   `-- data_selector.v
|-- tb/
|   |-- tb_address_decoder.v
|   |-- tb_cache_storage.v
|   |-- tb_cache_lookup.v
|   `-- stubs/
|       `-- cache_top_dependency_stubs.v
|-- scripts/
|   |-- run_address_decoder_test.sh
|   |-- run_cache_storage_test.sh
|   |-- run_cache_lookup_test.sh
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

Compile-only stubs live under `tb/stubs/` only for Member 04's pending controller FSM and main memory model so the top-level connections can be elaborated.

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

## Full-cache integration status

`rtl/cache_top.v` is an integration skeleton. Member 01's decoder, Member 02's storage modules, and Member 03's lookup/selection modules are fully integrated and match all ports. Member 04's controller and main-memory modules are still required for full system operation.

To test compilation and elaboration of `cache_top` with real RTL and remaining Member 04 stubs:

```bash
./scripts/check_cache_top.sh
```

Pending RTL:

- `rtl/cache_controller.v` (Member 04)
- `rtl/main_memory_model.v` (Member 04)

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
- `docs/controller_requirements.md` hands the frozen controller requirements to Member 04 without occupying Member 04's final `docs/fsm_design.md`.
- `docs/system_test_requirements.md` hands verification requirements to Member 05 without occupying Member 05's final `docs/test_plan.md`.
