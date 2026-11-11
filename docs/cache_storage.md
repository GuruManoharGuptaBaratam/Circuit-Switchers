# Cache Storage

Owner: **Member 02 - Cache data RAM, tag RAM, and valid-bit RAM**

These modules are the cache's memory. They store a block, a tag, and a valid bit for each line. They do not decide hits, choose a byte, or run the miss sequence. `rtl/cache_top.v` connects them with the ports in `docs/interface_contract.md`.

## What one line holds

Each of the 64 lines holds three fields:

| Field | Module | Width | Reset |
|---|---|---:|---|
| Data block | `cache_data_ram` | 128 bits (16 bytes) | Not reset |
| Tag | `tag_ram` | 22 bits | Not reset |
| Valid bit | `valid_bit_ram` | 1 bit | Cleared to 0 |

```text
64 lines x 16 bytes = 1024 bytes = 1 KB
```

The 6-bit index selects the line. A refill writes the whole 128-bit block, the 22-bit tag, and the valid bit of that same line. Storage keeps the 128-bit word exactly as it arrives. Byte order inside the word is defined by the interface contract and applied by `data_selector`.

## Controls and timing

All three modules use the shared rising-edge `clk`.

| Behavior | Rule |
|---|---|
| Read | Combinational. `read_*` follows the current `read_index` in the same cycle. |
| Write | Synchronous. One rising edge with `write_en` high updates `write_index`. |
| Read and write ports | Separate. A write to one index leaves every other index unchanged. |
| Data and tag reset | No reset port. Stored values are meaningful only while that line's valid bit is 1. |
| Valid reset | `reset` is active-high and synchronous. It clears all 64 bits. |
| Reset priority | On `valid_bit_ram`, `reset` wins over `write_en` in the same cycle. |

`write_en` low leaves the selected line unchanged, even if the write data or write index inputs change. After a write to the line currently being read, the combinational read shows the new value once that rising edge has updated the array.

`cache_top` ties `write_valid` to `1` during refill. The valid-bit module still accepts `write_valid` of 0 so a line can be cleared under explicit control.

## Files

| File | Role |
|---|---|
| `rtl/cache_data_ram.v` | 64 x 128-bit block storage |
| `rtl/tag_ram.v` | 64 x 22-bit tag storage |
| `rtl/valid_bit_ram.v` | 64 valid bits, with synchronous clear |
| `tb/tb_cache_storage.v` | Self-checking storage tests |

## Tests

From the repository root:

```bash
mkdir -p build results/logs results/waveforms
iverilog -g2012 -Wall -s tb_cache_storage \
  -o build/cache_storage_sim \
  rtl/cache_data_ram.v rtl/tag_ram.v rtl/valid_bit_ram.v tb/tb_cache_storage.v
vvp build/cache_storage_sim
```

The testbench checks the storage hand-off:

- after reset, all 64 valid bits are 0
- reset still clears a line when a valid write is requested in that same cycle
- a known 128-bit pattern written to line 3 reads back from line 3
- a second write to line 3 replaces the first block
- writes to lines 0, 4, and 63 do not change line 3
- a tag written to line 3 reads back, including a later replacement
- a tag write to line 4 does not change line 3
- line 3 can be marked valid while line 4 and every other line stay invalid
- `write_en` low does not change data, tag, or valid state
- a later reset clears valid bits that had been set

Expected summary:

```text
SUMMARY: 22 run, 22 passed, 0 failed
ALL CACHE STORAGE TESTS PASSED
```

The run writes `results/waveforms/cache_storage.vcd`.

## What to present

Show one cache line as three stored fields: 16 bytes of data, a 22-bit tag, and one valid bit. Then show a refill write to line 3 and the same value coming back on the read port.

The valid bit is what stops an empty line from looking like a hit. After reset every valid bit is 0, so lookup must treat the line as a miss even if the leftover tag bits happen to match the request. A line becomes usable only after its valid bit is written to 1 with the installed tag and block.
