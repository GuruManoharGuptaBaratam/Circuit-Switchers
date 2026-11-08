# 32-Bit Address Breakdown

## Why divide the address?

A processor gives the cache one 32-bit byte address. A direct-mapped cache needs three different pieces of that address:

- **Index:** which one of the 64 cache lines should be checked?
- **Tag:** does that line contain the requested memory block or a different block that maps to the same line?
- **Offset:** which one of the 16 bytes inside the selected block is requested?

```text
Address bits:  [31........................10][9.......4][3....0]
Meaning:       [         TAG (22)          ][INDEX (6)][OFFSET]
```

## Deriving the field widths

The cache holds 1 KB and each block holds 16 bytes:

```text
number of lines = 1024 bytes / 16 bytes = 64 lines
```

Six bits can select 64 values (`2^6 = 64`), so the index is 6 bits.

Four bits can select 16 byte positions (`2^4 = 16`), so the offset is 4 bits.

The remaining high-order address bits are the tag:

```text
tag bits = 32 - 6 - 4 = 22 bits
```

Therefore:

```verilog
tag    = address[31:10];
index  = address[9:4];
offset = address[3:0];
```

## Why the tag is necessary

The 6-bit index repeats every 64 memory blocks. A 16-byte block multiplied by 64 lines is 1024 bytes, so addresses one cache capacity apart can select the same line. The tag distinguishes them.

For example:

- `0x00000000` -> tag 0, index 0
- `0x00000400` -> tag 1, index 0

Both must use cache line 0. If the second block replaces the first, the stored tag changes from 0 to 1, preventing a false hit.

## Worked examples

### `0x00000000` - zero address

```text
binary: 00000000000000000000000000000000
split:  0000000000000000000000 | 000000 | 0000
tag:    0x000000
index:  0
offset: 0
```

This selects the first byte of the first block in line 0.

### `0x00000004` - byte offset 4

```text
binary: 00000000000000000000000000000100
split:  0000000000000000000000 | 000000 | 0100
tag:    0x000000
index:  0
offset: 4
```

The tag and index are unchanged, so this is another byte in the same 16-byte block.

### `0x0000000F` - last byte of the first block

```text
binary: 00000000000000000000000000001111
split:  0000000000000000000000 | 000000 | 1111
tag:    0x000000
index:  0
offset: 15
```

Offset 15 is the final byte position in a 16-byte block.

### `0x00000010` - first byte of the next block

```text
binary: 00000000000000000000000000010000
split:  0000000000000000000000 | 000001 | 0000
tag:    0x000000
index:  1
offset: 0
```

Adding 16 moves to a new block. The index increments and the offset returns to zero.

### `0x00000400` - same index, different tag

```text
binary: 00000000000000000000010000000000
split:  0000000000000000000001 | 000000 | 0000
tag:    0x000001
index:  0
offset: 0
```

This address is 1024 bytes after `0x00000000`. It maps to the same line but represents a different memory block, which is the classic direct-mapped conflict case.

### `0xFFFFFFFF` - maximum 32-bit address

```text
binary: 11111111111111111111111111111111
split:  1111111111111111111111 | 111111 | 1111
tag:    0x3FFFFF
index:  63
offset: 15
```

Every field is at its maximum value: the largest 22-bit tag, last cache line, and last byte in the block.

## Quick reference

| Address | Tag | Index | Offset | Meaning |
|---|---:|---:|---:|---|
| `0x00000000` | `0x000000` | 0 | 0 | First byte, first block |
| `0x00000004` | `0x000000` | 0 | 4 | Byte 4 in first block |
| `0x0000000F` | `0x000000` | 0 | 15 | Last byte in first block |
| `0x00000010` | `0x000000` | 1 | 0 | First byte in next block |
| `0x00000400` | `0x000001` | 0 | 0 | Same line as address zero, new tag |
| `0xFFFFFFFF` | `0x3FFFFF` | 63 | 15 | Maximum values |
