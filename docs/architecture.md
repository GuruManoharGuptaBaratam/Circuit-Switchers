# Direct-Mapped Cache Architecture

## Project objective

Circuit Switchers is a Verilog implementation of a 1 KB direct-mapped cache controller for MCA Project 6. The cache keeps copies of 16-byte main-memory blocks so that repeated or nearby byte reads can complete faster than a new main-memory access.

The repository contains Member 01's address decoder and top-level integration skeleton, and Member 02's cache storage. Hit detection, miss sequencing, refill control, and system verification depend on Members 03 and 04 and on Member 05.

## Why a cache helps

- **Temporal locality:** recently used data is likely to be used again. A repeated access can become a cache hit.
- **Spatial locality:** nearby data is likely to be used soon. Fetching a 16-byte block makes neighboring bytes available together.

## Cache organization

| Property | Value |
|---|---:|
| Address width | 32 bits |
| Cache capacity | 1024 bytes |
| Block size | 16 bytes / 128 bits |
| Cache lines | 64 |
| Tag width | 22 bits |
| Index width | 6 bits |
| Offset width | 4 bits |

The index selects exactly one of 64 lines. That line contains a 128-bit data block, a 22-bit stored tag, and one valid bit. Direct mapping needs no replacement search: a new block replaces the one line selected by its index.

## System diagram

```mermaid
flowchart LR
    P[Processor / request generator]
    D[Address decoder<br/>tag 22 | index 6 | offset 4]
    C[Cache controller FSM]
    DATA[Cache data RAM<br/>64 x 128 bits]
    TAG[Tag RAM<br/>64 x 22 bits]
    VALID[Valid-bit RAM<br/>64 x 1 bit]
    LOOKUP[Lookup logic<br/>valid and tag match]
    SELECT[Byte selector<br/>offset selects 1 of 16 bytes]
    MEM[Main-memory model<br/>aligned 128-bit block read]
    R[Response<br/>byte + valid + hit flag]

    P -->|req_valid, req_addr| D
    D -->|decoded fields| C
    C -->|active index| DATA
    C -->|active index| TAG
    C -->|active index| VALID
    TAG -->|stored tag| LOOKUP
    VALID -->|stored valid| LOOKUP
    C -->|active tag| LOOKUP
    DATA -->|stored block| SELECT
    C -->|active offset| SELECT
    LOOKUP -->|hit / miss| C
    SELECT -->|cached byte| C
    C -->|miss: mem_req + aligned address| MEM
    MEM -->|mem_ready + 128-bit block| SELECT
    MEM -->|refill block| DATA
    C -->|refill enable + active tag/index| DATA
    C -->|refill enable + active tag/index| TAG
    C -->|refill enable + valid=1| VALID
    C -->|completion| R
    R --> P
```

The same byte-selector interface is instantiated twice in `cache_top`: once for the cached line and once for the returned memory block. This lets a miss response select its byte directly from `mem_block` while the block is being installed.

## Request flow

### 1. Accept and decode

The requester presents `req_addr` with `req_valid`. The decoder continuously produces `tag`, `index`, and `offset`. When `req_valid && req_ready` is true on a rising edge, the controller captures those fields as the active request.

### 2. Select one line

The active 6-bit index reads one data block, one stored tag, and one valid bit. Storage reads are defined as combinational in the first integration contract.

### 3. Decide hit or miss

A hit is:

```text
hit = stored_valid AND (active_tag == stored_tag)
```

The tag is required because many different memory blocks share the same 6-bit index. For example, `0x00000000` and `0x00000400` both select line 0 but have different tags.

### 4A. Hit path

The byte selector uses the 4-bit offset to choose one byte from the cached 128-bit block. The controller returns it with `resp_valid = 1` and `resp_hit = 1`. Main memory is not requested.

### 4B. Miss and refill path

The controller forms an aligned block address by clearing bits `[3:0]`, asserts `mem_req`, and waits for `mem_ready`. When the 128-bit block arrives, the selected cache line is updated:

- data RAM receives the returned block;
- tag RAM receives the active tag;
- valid-bit RAM receives `1`;
- the requested byte is selected from the returned block;
- the controller responds with `resp_hit = 0`.

The next request to the same block can hit unless another address with the same index replaces it.

## Module roles and ownership

| Module | Role | Owner |
|---|---|---|
| `address_decoder` | Split the 32-bit address into tag/index/offset | Member 01 |
| `cache_top` | Connect all modules without duplicating their behavior | Member 01 |
| `cache_data_ram` | Store 64 cache blocks | Member 02 |
| `tag_ram` | Store one tag per line | Member 02 |
| `valid_bit_ram` | Store/reset one valid bit per line | Member 02 |
| `tag_comparator` | Compare requested and stored tags | Member 03 |
| `cache_lookup` | Combine tag match and valid bit into hit | Member 03 |
| `data_selector` | Select a byte from a 128-bit block | Member 03 |
| `cache_controller` | Sequence acceptance, lookup, miss, refill, and response | Member 04 |
| `main_memory_model` | Return deterministic blocks after documented latency | Member 04 |
| System testbenches | Prove integrated behavior and measure results | Member 05 |

## Deliberate scope limits

- The first milestone is read-only and byte-wide.
- Only one processor request may be active.
- No write-through/write-back choice has been made.
- No LRU logic is required because the cache is direct-mapped.
- The Verilog main-memory model is a simulation component, not physical DRAM.
- Full-cache operation is pending the other members' real modules; the top-level skeleton does not hide those missing dependencies.
