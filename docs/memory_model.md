# Main-Memory Model

Owner: **Member 04 - Cache Controller FSM and Main-Memory Model**
RTL: `rtl/main_memory_model.v`

The main-memory model is a **simulation-only** Verilog byte array. It is not a physical RAM. It returns one aligned 16-byte block per request after a fixed, documented delay, so the controller can be tested against a memory that does not respond immediately.

## 1. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `LATENCY` | 4 | Cycles from the request-acceptance edge to the `mem_ready` cycle. Must be ≥ 1 |
| `MEM_BYTES` | 65536 | Array size in bytes (64 KB). Must be a power of two ≥ 16 |
| `INIT_FILE` | `""` | Optional `$readmemh` file. If empty, the deterministic pattern below is used |

`cache_top` instantiates the model with the defaults.

## 2. Addressing

- The array is `reg [7:0] mem [0:MEM_BYTES-1]`, one byte per address.
- The model forces `mem_addr[3:0]` to zero, so every request reads an aligned 16-byte block. `cache_top` already drives `mem_addr = {tag, index, 4'b0000}`.
- Addresses are reduced modulo `MEM_BYTES`. Addresses ≥ 64 KB therefore alias onto the array. Tests should stay below 0x10000 or account for this.

## 3. Deterministic contents

With no `INIT_FILE`, every byte is initialised at time 0 to:

```text
mem[a] = a[7:0] ^ a[15:8] ^ 8'hA5
```

| Address | Byte | Note |
|---|---:|---|
| 0x0000 | 0xA5 | |
| 0x0004 | 0xA1 | |
| 0x000F | 0xAA | |
| 0x0013 | 0xB6 | Different index (line 1) |
| 0x0400 | 0xA1 | Same index as 0x0000, different tag |
| 0x0404 | 0xA5 | |

Properties:
- **Repeatable:** the same address always returns the same byte.
- **All 16 bytes in a block differ**, because they differ in `a[3:0]`. A byte-lane or offset mistake is therefore visible.
- **Conflicting blocks differ.** For example, block 0x000 starts `A5 A4 A7 …` and block 0x400 starts `A1 A0 A3 …`, so returning stale data after a replacement is detected.

Testbenches compute the expected byte with the same expression (see `pattern_byte` in `tb/tb_cache_controller.v`). Member 05's system tests should reuse it.

## 4. Block layout

Byte lane `n` of the returned block is `mem_block[8*n +: 8] = mem[mem_addr + n]`. Offset 0 is in bits `[7:0]` and offset 15 is in bits `[127:120]`. This matches `docs/interface_contract.md` and `rtl/data_selector.v`.

## 5. Handshake and latency

1. **Accept:** on a rising edge where `mem_req = 1` and the model is idle (not busy, and not presenting `mem_ready` in that cycle), the model latches the aligned address and becomes busy.
2. **Wait:** the model counts down `LATENCY` edges.
3. **Respond:** `mem_ready` is high for **exactly one cycle**, `LATENCY` cycles after the acceptance edge, and `mem_block` is valid in that cycle.
4. The requester (the controller) holds `mem_req` high until it sees `mem_ready`. The model will not re-accept that request in the `mem_ready` cycle.
5. `mem_ready` is never asserted without an accepted request.
6. **Reset** (synchronous, active high) cancels any request in flight and clears `mem_ready`/`mem_block`.

```text
edge     : A(accept)  A+1  A+2  A+3  A+4
mem_req  :     1       1    1    1    1     0
busy     :     0->1    1    1    1    1->0
mem_ready:     0       0    0    0    1     0      (LATENCY = 4)
```

Because `mem_req` becomes visible one edge before the model accepts it, the controller sees **LATENCY + 1** cycles of waiting. The full miss costs **LATENCY + 2** cycles more than a hit (see `docs/fsm_design.md`, section 5).

## 6. Verification

The model is exercised through the integrated cache in `tb/tb_cache_controller.v`:
- T2 checks the exact wait length and that the installed line equals the expected 16-byte block.
- T5 checks that a conflicting block returns different, correct data.
- T8 checks that reset cancels an in-flight request with no stale `mem_ready`.
