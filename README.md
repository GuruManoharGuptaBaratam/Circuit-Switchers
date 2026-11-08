# Circuit Switchers

**Modern Computer Architecture - Project 6: Direct-Mapped Cache Controller**

Circuit Switchers is a five-member Verilog project implementing a 1 KB direct-mapped cache with 16-byte blocks and 32-bit byte addresses. The submission deadline is **16 November 2026**.

This repository currently contains Member 01's completed source and documentation scope: the address decoder, its self-checking unit test, and a top-level integration skeleton with a frozen interface proposal. It does **not** yet claim a runnable complete cache because Members 02-04's RTL and Member 05's system verification are pending.

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

| Member | Responsibility |
|---|---|
| Member 01 | Address decoder, top-level integration, shared interfaces, architecture |
| Member 02 | Cache data RAM, tag RAM, valid-bit RAM |
| Member 03 | Tag comparison, hit logic, byte selection |
| Member 04 | Controller FSM and deterministic main-memory model |
| Member 05 | System testbenches, traces, metrics, waveforms, synthesis evidence |

## Repository layout

```text
Circuit-Switchers/
|-- README.md
|-- docs/
|   |-- architecture.md
|   |-- address_breakdown.md
|   |-- interface_contract.md
|   |-- fsm_design.md
|   |-- test_plan.md
|   `-- report/
|-- rtl/
|   |-- address_decoder.v
|   `-- cache_top.v
|-- tb/
|   `-- tb_address_decoder.v
|-- scripts/
|   `-- run_sim.sh
|-- results/
|   |-- logs/
|   |-- waveforms/
|   |-- metrics/
|   `-- synthesis/
`-- submission/
    `-- README_Submission.txt
```

No placeholder RTL has been created for other members' modules.

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
./scripts/run_sim.sh
```

The script checks prerequisites, creates output directories, compiles the decoder and testbench, runs the simulation, and fails with nonzero status if compilation, simulation, or waveform generation fails.

Equivalent manual commands:

```bash
mkdir -p build results/logs results/waveforms
iverilog -g2012 -Wall -s tb_address_decoder \
  -o build/address_decoder_sim \
  rtl/address_decoder.v tb/tb_address_decoder.v
vvp build/address_decoder_sim
```

Expected successful summary:

```text
SUMMARY: 6 run, 6 passed, 0 failed
ALL ADDRESS DECODER TESTS PASSED
```

Generated files:

- `results/logs/address_decoder_compile.log`
- `results/logs/address_decoder_test.log`
- `results/waveforms/address_decoder.vcd`

To inspect the waveform after a successful simulation:

```bash
gtkwave results/waveforms/address_decoder.vcd
```

Add `address`, `tag`, `index`, and `offset` to the GTKWave view.

## Full-cache integration status

`rtl/cache_top.v` is an integration skeleton and intentionally references modules that have not yet been delivered. It should be syntax/interface checked with temporary build-only stubs or compiled after the real modules arrive. A full-cache simulation command will be added by Member 05 only after those dependencies exist.

Pending RTL:

- `rtl/cache_data_ram.v`
- `rtl/tag_ram.v`
- `rtl/valid_bit_ram.v`
- `rtl/tag_comparator.v`
- `rtl/cache_lookup.v`
- `rtl/data_selector.v`
- `rtl/cache_controller.v`
- `rtl/main_memory_model.v`

## Collaboration workflow

1. Create a branch for one workstream, for example `feature/cache-storage`.
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
- `docs/fsm_design.md` is a clearly marked hand-off for Member 04.
- `docs/test_plan.md` records Member 01's unit test and Member 05's pending system scope.
