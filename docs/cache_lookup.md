# Cache Lookup, Tag Check and Data Selection

Owner: **Member 03 – Cache Lookup, Tag Check and Data Selection**  
Project: **Circuit Switchers (MCA Project 6 – Direct-Mapped Cache Controller)**  
Status: **Implemented, Verified, and Ready for Integration**

---

## 1. Executive Summary & Purpose

In a direct-mapped cache, memory storage modules (`cache_data_ram`, `tag_ram`, `valid_bit_ram`) supply raw stored data, but they have no intelligence to determine whether that stored data corresponds to the requested memory address. **Member 03** provides the core decision-making and data-extraction datapath:

1. **Tag Comparison (`tag_comparator.v`)**: Compares the incoming 22-bit address tag with the stored 22-bit tag read from the selected cache line.
2. **Hit/Miss Decision (`cache_lookup.v`)**: Evaluates tag equality in conjunction with the line's valid bit to generate a clean, glitch-free `hit` signal.
3. **Data Selection (`data_selector.v`)**: Uses the 4-bit byte offset to extract the exact 8-bit byte requested by the processor from the 128-bit (16-byte) cache block.

These modules are purely combinational, ensuring minimal lookup latency without introducing extra clock cycle penalties in the cache access pipeline.

```
       +--------------------------------------------------------+
       |               32-bit Memory Address                    |
       |  Tag [31:10] (22b) | Index [9:4] (6b) | Offset [3:0]   |
       +---------+------------------+------------------+--------+
                 |                  |                  |
                 |                  v                  |
                 |           +--------------+          |
                 |           | Cache Storage|          |
                 |           | (Lines 0..63)|          |
                 |           +------+-------+          |
                 |                  |                  |
                 |         stored   |  stored   stored |
                 |          tag     |  valid     block |
                 |         (22b)    |   (1b)    (128b) |
                 v                  v     |        |   v
          +---------------+         |     |      +---------------+
          |tag_comparator |<--------+     |      | data_selector |
          +-------+-------+               |      +-------+-------+
                  | tags_match            |              |
                  v                       v              |
          +-------------------------------+              |
          |         cache_lookup          |              |
          +---------------+---------------+              |
                          |                              |
                          v                              v
                      lookup_hit                  selected_byte
                   (1 = Hit, 0 = Miss)            (8-bit Data)
```

---

## 2. Mathematical Definition of Cache Hit

A cache hit occurs **if and only if** two conditions are simultaneously satisfied:
$$\text{hit} = \text{stored\_valid} \land (\text{requested\_tag} == \text{stored\_tag})$$

### Truth Table of Lookup Decision

| `stored_valid` | `tags_match` (`req_tag == stored_tag`) | `hit` Output | Cache Condition & Architectural Meaning |
|:---:|:---:|:---:|:---|
| `0` | `0` | **`0` (MISS)** | **Cold Cache Miss**: The cache line has never been loaded. |
| `0` | `1` | **`0` (MISS)** | **Empty Line Protection**: Leftover or uninitialized tag bits in an invalid line match by accident. **Must be treated as a MISS.** |
| `1` | `0` | **`0` (MISS)** | **Conflict / Capacity Miss**: Line holds valid data, but for a completely different memory block. |
| `1` | `1` | **`1` (HIT)** | **Cache Hit**: Line holds valid data for the requested memory block. Data is served directly from cache. |

### Critical Architectural Principle: Why a Matching Tag Alone is Not Enough
At power-on or following system reset, RAM cells contain arbitrary, uninitialized bit patterns (or zero values). If an invalid line happens to hold tag `0x000000`, a processor request for address `0x00000000` (tag `0x000000`) would falsely register as a hit if the valid bit were ignored. This would return garbage data and corrupt processor execution. Gating the tag match with `stored_valid` ensures that uninitialized or invalidated lines are strictly treated as misses.

---

## 3. Byte Ordering and Data Selection Convention

The Circuit Switchers architecture enforces a consistent **Little-Endian byte lane layout** across all 16 bytes of each 128-bit cache block, as frozen in `docs/interface_contract.md`.

### Byte Lane Mapping Formula
$$\text{selected\_byte} = \text{block\_data}[(8 \times \text{byte\_offset}) +: 8]$$

### Offset-to-Bit-Slice Mapping Table

| Byte Offset `[3:0]` | Block Bit Slice | Hex Offset | Description / Byte Index |
|:---:|:---:|:---:|:---|
| `4'h0` (`0000`) | `block_data[7:0]`     | `+0x0` | Byte 0 (Least Significant Byte / Base) |
| `4'h1` (`0001`) | `block_data[15:8]`    | `+0x1` | Byte 1 |
| `4'h2` (`0010`) | `block_data[23:16]`   | `+0x2` | Byte 2 |
| `4'h3` (`0011`) | `block_data[31:24]`   | `+0x3` | Byte 3 |
| `4'h4` (`0100`) | `block_data[39:32]`   | `+0x4` | Byte 4 |
| `4'h5` (`0101`) | `block_data[47:40]`   | `+0x5` | Byte 5 |
| `4'h6` (`0110`) | `block_data[55:48]`   | `+0x6` | Byte 6 |
| `4'h7` (`0111`) | `block_data[63:56]`   | `+0x7` | Byte 7 |
| `4'h8` (`1000`) | `block_data[71:64]`   | `+0x8` | Byte 8 |
| `4'h9` (`1001`) | `block_data[79:72]`   | `+0x9` | Byte 9 |
| `4'hA` (`1010`) | `block_data[87:80]`   | `+0xA` | Byte 10 |
| `4'hB` (`1011`) | `block_data[95:88]`   | `+0xB` | Byte 11 |
| `4'hC` (`1100`) | `block_data[103:96]`  | `+0xC` | Byte 12 |
| `4'hD` (`1101`) | `block_data[111:104]` | `+0xD` | Byte 13 |
| `4'hE` (`1110`) | `block_data[119:112]` | `+0xE` | Byte 14 |
| `4'hF` (`1111`) | `block_data[127:120]` | `+0xF` | Byte 15 (Most Significant Byte) |

### Dual-Selector Utilization in `cache_top`
The `data_selector` module is instantiated **twice** in `cache_top.v`:
1. `u_cache_data_selector`: Connects to `stored_block` from `cache_data_ram` to produce `cache_byte_data` for cache hits.
2. `u_refill_data_selector`: Connects to `mem_block` from `main_memory_model` to produce `refill_byte_data` on memory refills, allowing zero-overhead bypass of the requested byte to the processor while the block is simultaneously written into cache RAM.

---

## 4. Module Specifications and Port Definitions

### 4.1 `tag_comparator` (`rtl/tag_comparator.v`)
- **Role**: Compares requested tag and stored tag.
- **Timing**: Pure combinational logic.

| Port Name | Direction | Width | Description |
|---|:---:|:---:|---|
| `requested_tag` | input | 22 | Tag bits `[31:10]` of requested address |
| `stored_tag` | input | 22 | Tag bits read from tag RAM for indexed line |
| `tags_match` | output | 1 | `1'b1` when `requested_tag == stored_tag`, else `1'b0` |

### 4.2 `cache_lookup` (`rtl/cache_lookup.v`)
- **Role**: Modular hit/miss decision maker. Instantiates `tag_comparator` and computes `hit = stored_valid & tags_match`.
- **Timing**: Pure combinational logic.

| Port Name | Direction | Width | Description |
|---|:---:|:---:|---|
| `requested_tag` | input | 22 | Tag bits `[31:10]` of requested address |
| `stored_tag` | input | 22 | Tag bits read from tag RAM for indexed line |
| `stored_valid` | input | 1 | Valid bit read from `valid_bit_ram` for indexed line |
| `hit` | output | 1 | `1'b1` for cache hit; `1'b0` for cache miss |

### 4.3 `data_selector` (`rtl/data_selector.v`)
- **Role**: 16-to-1 byte multiplexer selecting one byte from a 128-bit block.
- **Timing**: Pure combinational logic.

| Port Name | Direction | Width | Description |
|---|:---:|:---:|---|
| `block_data` | input | 128 | 16-byte cache line or refill block |
| `byte_offset` | input | 4 | Offset bits `[3:0]` selecting byte lane 0..15 |
| `selected_byte` | output | 8 | Extracted 8-bit data byte |

---

## 5. Team Hand-offs and Interface Timing

### Hand-off with Member 01 (Address Decoder & Integration)
- **Signal Contract**: Tag is exactly 22 bits (`[31:10]`), Index is 6 bits (`[9:4]`), Offset is 4 bits (`[3:0]`).
- **Elaboration**: `cache_top.v` directly instantiates `cache_lookup` and two `data_selector` modules. Build checks compile cleanly without unresolved symbols or port mismatches.

### Hand-off with Member 02 (Cache Storage)
- **Read Timing**: Cache RAMs (`cache_data_ram`, `tag_ram`, `valid_bit_ram`) provide **asynchronous/combinational reads**.
- When `active_index` is applied, `stored_tag`, `stored_valid`, and `stored_block` become valid during the same clock cycle after small gate propagation delay.
- The combinational `cache_lookup` and `data_selector` evaluate and stabilize within the same cycle, ready to be sampled on the next rising clock edge.

### Hand-off with Member 04 (Controller FSM)
- **Sampling Window**: In the `LOOKUP` state, the controller inspects `lookup_hit`.
  - If `lookup_hit == 1'b1`: The controller selects `cache_byte_data`, pulses `resp_valid = 1'b1`, asserts `resp_hit = 1'b1`, and returns to `IDLE` in 1 cycle.
  - If `lookup_hit == 1'b0`: The controller asserts `mem_req = 1'b1` and transitions to `MEM_WAIT`. Once `mem_ready` arrives, the controller pulses `refill_write_en` to update storage and returns `refill_byte_data`.

### Hand-off with Member 05 (Verification & Performance)
- **Conflict Address Review**: The same-index/different-tag conflict condition was reviewed and verified with Member 05:
  - Address 1: `0x00000000` (Tag `0x000000`, Index `0`)
  - Address 2: `0x00000400` (Tag `0x000001`, Index `0`)
  - When alternating between these two addresses, both map to Cache Line 0, forcing continuous conflict evictions. Member 03's testbench explicitly verifies this exact sequence.

---

## 6. Verification and Test Results

The testbench `tb/tb_cache_lookup.v` exercises all corner cases, valid/invalid transitions, full 22-bit tag comparisons, all 16 offset positions, and direct-mapped conflict sequences.

### Test Execution Command
```bash
./scripts/run_cache_lookup_test.sh
```

### Test Summary
```text
Cache lookup and data selection unit test
-----------------------------------------
PASS: tc: zero tags match (0x000000 == 0x000000)
PASS: tc: max 22-bit tags match (0x3FFFFF == 0x3FFFFF)
PASS: tc: pattern 0x2AAAAA matches
PASS: tc: pattern 0x155555 matches
PASS: tc: mismatch at LSB (bit 0) (0x000000 != 0x000001)
PASS: tc: mismatch at MSB (bit 21) (0x000000 != 0x200000)
PASS: tc: mismatch at middle bit 10 (0x000400 != 0x000000)
PASS: tc: completely inverted tags mismatch
PASS: cl: valid=1 and tag match produces HIT
PASS: cl: valid=0 and tag match produces MISS (empty line protection)
PASS: cl: valid=1 and tag mismatch produces MISS (conflict)
PASS: cl: valid=0 and tag mismatch produces MISS (cold invalid)
PASS: cl: zero tag with valid=1 produces HIT
PASS: cl: zero tag with valid=0 produces MISS (reset state check)
PASS: cl: max tag with valid=1 produces HIT
PASS: cl: max tag with valid=0 produces MISS
PASS: ds block A: offset 0 selects 0xA0
PASS: ds block A: offset 1 selects 0xA1
PASS: ds block A: offset 2 selects 0xA2
PASS: ds block A: offset 3 selects 0xA3
PASS: ds block A: offset 4 selects 0xA4
PASS: ds block A: offset 5 selects 0xA5
PASS: ds block A: offset 6 selects 0xA6
PASS: ds block A: offset 7 selects 0xA7
PASS: ds block A: offset 8 selects 0xA8
PASS: ds block A: offset 9 selects 0xA9
PASS: ds block A: offset 10 selects 0xAA
PASS: ds block A: offset 11 selects 0xAB
PASS: ds block A: offset 12 selects 0xAC
PASS: ds block A: offset 13 selects 0xAD
PASS: ds block A: offset 14 selects 0xAE
PASS: ds block A: offset 15 selects 0xAF
PASS: ds pattern B: offset 0 selects 0x0F (lowest byte)
PASS: ds pattern B: offset 7 selects 0x78
PASS: ds pattern B: offset 8 selects 0x87
PASS: ds pattern B: offset 15 selects 0xF0 (highest byte)
PASS: conflict 1: cold cache line 0 access A is MISS
PASS: conflict 2: line 0 holding block A produces HIT for address A
PASS: conflict 3: access B with same index, different tag is MISS
PASS: conflict 4: line 0 refilled with block B produces HIT for address B
PASS: conflict 5: alternating back to address A produces conflict MISS
-----------------------------------------
SUMMARY: 41 run, 41 passed, 0 failed
ALL CACHE LOOKUP TESTS PASSED
```

- **Simulation Waveform**: Captured at `results/waveforms/cache_lookup.vcd`.
- **Compile & Execution Logs**: Saved at `results/logs/cache_lookup_final.log`.

---

## 7. Walkthrough Example for Presentation

### Example Address: `0x0000040A` (Byte 10 of Block 0x40 in Memory)

```text
32-bit Address: 0x0000040A
Binary:         0000 0000 0000 0000 0000 0100 0000 1010

Split:
  [31:10] Tag:    22'b0000_0000_0000_0000_0000_01 = 22'h000001
  [9:4]   Index:  6'b00_0000                       = 6'd0  (Line 0)
  [3:0]   Offset: 4'b1010                          = 4'hA  (Offset 10)
```

### Step-by-Step Hardware Execution:
1. **Line Selection**: The 6-bit index (`6'd0`) selects Cache Line 0 in storage.
2. **Field Extraction**: Storage retrieves Line 0's stored fields:
   - `stored_valid`
   - `stored_tag[21:0]`
   - `stored_block[127:0]`
3. **Tag Comparison (`tag_comparator`)**:
   - `requested_tag` = `22'h000001`
   - Stored tag is inspected:
     - If `stored_tag == 22'h000001`, `tags_match = 1'b1`.
     - If `stored_tag != 22'h000001`, `tags_match = 1'b0`.
4. **Hit Evaluation (`cache_lookup`)**:
   - $\text{hit} = \text{stored\_valid} \land \text{tags\_match}$.
   - If `stored_valid == 1'b1` AND `tags_match == 1'b1` $\rightarrow$ `hit = 1'b1` (**HIT**).
   - If `stored_valid == 1'b0` (even if tag matched) $\rightarrow$ `hit = 1'b0` (**MISS**).
5. **Data Extraction (`data_selector`)**:
   - The 4-bit offset `4'hA` (decimal 10) selects byte lane 10:
     $$\text{selected\_byte} = \text{stored\_block}[87:80]$$
   - On a hit, this byte is immediately returned as `cache_byte_data` to complete the request.

