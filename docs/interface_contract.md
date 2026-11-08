# Shared Interface Contract

Status: **integration proposal frozen by Member 01 for the read-only milestone**

This contract defines the signal names, widths, timing rules, and ownership needed to connect the five team work areas. Any change to a listed port must be agreed by affected members and updated here before integration.

## 1. Global conventions

| Item | Decision |
|---|---|
| Clock | `clk`, rising-edge active |
| Reset | `reset`, active high and synchronous for every sequential module |
| Address width | 32 bits |
| Processor data width | 8 bits for the first milestone |
| Cache block width | 128 bits = 16 bytes |
| Cache lines | 64 |
| Tag / index / offset | 22 / 6 / 4 bits |
| Outstanding requests | One at a time |
| Initial operation scope | Read-only |
| Response behavior | `resp_valid` is a one-cycle completion pulse |
| Memory operation | Aligned 16-byte block read |

Write support is deliberately not defined because the project brief does not prescribe write-through versus write-back or the write-miss policy. The team must confirm that scope with the instructor before adding write ports.

## 2. Address and data layout

```text
31                     10 9            4 3          0
+------------------------+---------------+------------+
|       tag[21:0]        |  index[5:0]   | offset[3:0]|
+------------------------+---------------+------------+
```

- `tag = address[31:10]`
- `index = address[9:4]`
- `offset = address[3:0]`
- An aligned block address is `{tag, index, 4'b0000}`.
- Byte lane `n` is `block_data[(8*n) +: 8]`.
- Therefore offset `0` selects `block_data[7:0]`, and offset `15` selects `block_data[127:120]`.
- The memory model must use the same layout: `mem_block[(8*n) +: 8]` represents byte address `mem_addr + n`.

## 3. Processor request and response handshake

1. The requester asserts `req_valid` and supplies `req_addr`.
2. A request is accepted on a rising clock edge when `req_valid && req_ready` is true.
3. The requester must keep `req_valid` and `req_addr` stable until that acceptance edge.
4. The controller captures tag, index, and offset at acceptance. The requester may then change its inputs.
5. `req_ready` is low while a request is in progress, so only one request can be outstanding.
6. Completion is indicated by a one-cycle `resp_valid` pulse. `resp_data` and `resp_hit` are valid in that cycle.
7. `resp_hit = 1` means the accepted request completed from an existing valid cache line. `resp_hit = 0` means it completed after a miss and refill.

There is no response backpressure in the first milestone. A requester must sample the response whenever `resp_valid` is high.

## 4. Main-memory handshake

1. On a miss, the controller asserts `mem_req` and the top level presents the aligned `mem_addr`.
2. `mem_req` and `mem_addr` remain stable until `mem_ready` is observed high on a rising clock edge.
3. `mem_ready` is a one-cycle pulse. `mem_block` is valid for that cycle.
4. The controller pulses `refill_write_en` for one rising edge while the returned block is valid.
5. The data RAM stores `mem_block`, the tag RAM stores `active_tag`, and the valid-bit RAM stores `1` at `active_index`.
6. The response byte after a miss is selected directly from `mem_block` using `active_offset`; it does not depend on reading the just-written RAM in the same cycle.

The exact fixed latency and memory initialization pattern belong in Member 04's `docs/memory_model.md`.

## 5. Module port definitions

### `address_decoder` - Member 01

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `address` | input | 32 | Processor byte address |
| `tag` | output | 22 | `address[31:10]` |
| `index` | output | 6 | `address[9:4]` |
| `offset` | output | 4 | `address[3:0]` |

This module is purely combinational.

### `cache_data_ram` - Member 02

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `clk` | input | 1 | Shared clock |
| `read_index` | input | 6 | Cache line to read |
| `read_block` | output | 128 | Selected cache block |
| `write_en` | input | 1 | Write one block on the rising edge |
| `write_index` | input | 6 | Cache line to write |
| `write_block` | input | 128 | Refill block data |

Required timing: combinational/asynchronous read and synchronous write. Data contents need not reset because an invalid line is ignored.

### `tag_ram` - Member 02

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `clk` | input | 1 | Shared clock |
| `read_index` | input | 6 | Tag entry to read |
| `read_tag` | output | 22 | Stored tag for the selected line |
| `write_en` | input | 1 | Write one tag on the rising edge |
| `write_index` | input | 6 | Tag entry to write |
| `write_tag` | input | 22 | Tag installed during refill |

Required timing: combinational/asynchronous read and synchronous write.

### `valid_bit_ram` - Member 02

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `clk` | input | 1 | Shared clock |
| `reset` | input | 1 | Active-high synchronous clear of all 64 bits |
| `read_index` | input | 6 | Valid entry to read |
| `read_valid` | output | 1 | Valid state of selected line |
| `write_en` | input | 1 | Update one entry on the rising edge |
| `write_index` | input | 6 | Entry to update |
| `write_valid` | input | 1 | New valid value; top level supplies `1` on refill |

Reset has priority over `write_en`. Read is combinational/asynchronous; update is synchronous.

### `tag_comparator` - Member 03

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `requested_tag` | input | 22 | Tag from the accepted request |
| `stored_tag` | input | 22 | Tag read from tag RAM |
| `tags_match` | output | 1 | High when both tags are equal |

This module is combinational and is expected to be instantiated by `cache_lookup`.

### `cache_lookup` - Member 03

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `requested_tag` | input | 22 | Tag from the accepted request |
| `stored_tag` | input | 22 | Tag read from tag RAM |
| `stored_valid` | input | 1 | Valid bit read for the selected line |
| `hit` | output | 1 | `stored_valid && tags_match` |

This module is combinational. It owns hit detection but not controller sequencing.

### `data_selector` - Member 03

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `block_data` | input | 128 | One 16-byte cache or refill block |
| `byte_offset` | input | 4 | Byte position 0 through 15 |
| `selected_byte` | output | 8 | Selected byte using the shared lane convention |

This module is combinational. `cache_top` instantiates it once for the cached block and once for the returned refill block.

### `cache_controller` - Member 04

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `clk` | input | 1 | Shared clock |
| `reset` | input | 1 | Active-high synchronous reset |
| `req_valid` | input | 1 | Request is being presented |
| `req_tag` | input | 22 | Decoded tag before acceptance |
| `req_index` | input | 6 | Decoded index before acceptance |
| `req_offset` | input | 4 | Decoded offset before acceptance |
| `req_ready` | output | 1 | Controller can accept a request |
| `active_tag` | output | 22 | Captured tag, stable during the transaction |
| `active_index` | output | 6 | Captured index, stable during the transaction |
| `active_offset` | output | 4 | Captured offset, stable during the transaction |
| `lookup_hit` | input | 1 | Combinational hit result for active request |
| `cache_byte_data` | input | 8 | Byte selected from the cached block |
| `refill_byte_data` | input | 8 | Byte selected from returned memory block |
| `mem_ready` | input | 1 | Memory block is valid this cycle |
| `mem_req` | output | 1 | Request an aligned block from memory |
| `refill_write_en` | output | 1 | Install block/tag/valid on this rising edge |
| `resp_valid` | output | 1 | One-cycle response-completion pulse |
| `resp_data` | output | 8 | Returned byte |
| `resp_hit` | output | 1 | Hit/miss classification for the response |

The controller must capture `req_*` when a request is accepted and must not change `active_*` until the transaction is complete. It must not assert `mem_req` on a hit and must not assert `refill_write_en` before `mem_ready`.

### `main_memory_model` - Member 04

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `clk` | input | 1 | Shared clock |
| `reset` | input | 1 | Active-high synchronous reset/cancel |
| `mem_req` | input | 1 | Request a 16-byte block |
| `mem_addr` | input | 32 | 16-byte-aligned address; bits `[3:0]` are zero |
| `mem_ready` | output | 1 | One-cycle completion pulse |
| `mem_block` | output | 128 | Returned block using the shared byte-lane order |

The model must use deterministic contents and a documented nonzero latency. It must not assert `mem_ready` before accepting a request.

### `cache_top` - Member 01

| Port | Direction | Width | Purpose |
|---|---|---:|---|
| `clk` | input | 1 | Shared clock |
| `reset` | input | 1 | Active-high synchronous reset |
| `req_valid` | input | 1 | Processor request valid |
| `req_addr` | input | 32 | Processor byte address |
| `req_ready` | output | 1 | Cache can accept request |
| `resp_valid` | output | 1 | Response is valid this cycle |
| `resp_data` | output | 8 | Returned byte |
| `resp_hit` | output | 1 | `1` for hit, `0` for miss/refill |

`cache_top` instantiates and wires all listed modules. It must not reimplement storage, hit detection, data selection, controller sequencing, or memory behavior.

## 6. Ownership and pending hand-offs

| Member | Owned integration files/modules |
|---|---|
| Member 01 | `address_decoder`, `cache_top`, interface and architecture documents |
| Member 02 | `cache_data_ram`, `tag_ram`, `valid_bit_ram` |
| Member 03 | `tag_comparator`, `cache_lookup`, `data_selector` |
| Member 04 | `cache_controller`, `main_memory_model`, FSM and memory-model documents |
| Member 05 | System testbenches, traces, regression, metrics, waveforms, synthesis evidence |

The current top-level skeleton becomes an executable complete cache only after Members 02-04 provide modules matching these ports and Member 05 supplies the system-level verification environment.
