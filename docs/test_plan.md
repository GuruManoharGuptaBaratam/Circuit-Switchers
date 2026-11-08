# Test Plan and Ownership Hand-Off

System verification owner: **Member 05 - Verification, Performance, and Evidence**

Member 01 owns the decoder unit test described below. Full-cache traces, metrics, system waveforms, and synthesis evidence remain pending until the other RTL modules are integrated.

## Member 01 unit test

The testbench `tb/tb_address_decoder.v` automatically checks six directed cases.

| Test | Address | Expected tag | Expected index | Expected offset |
|---|---:|---:|---:|---:|
| Zero address | `0x00000000` | `0x000000` | 0 | 0 |
| Byte offset 4 | `0x00000004` | `0x000000` | 0 | 4 |
| Last byte of first block | `0x0000000F` | `0x000000` | 0 | 15 |
| Next memory block | `0x00000010` | `0x000000` | 1 | 0 |
| Same index, different tag | `0x00000400` | `0x000001` | 0 | 0 |
| Maximum address | `0xFFFFFFFF` | `0x3FFFFF` | 63 | 15 |

Pass criteria:

- Every comparison prints `PASS`.
- Summary reports `6 run, 6 passed, 0 failed`.
- A failure ends simulation with nonzero status.
- `results/waveforms/address_decoder.vcd` is nonempty.

## Pending system tests for Member 05

After Members 02-04 deliver their modules, system verification must include:

- cold-cache miss and refill;
- repeated access becoming a hit;
- sequential bytes within one 16-byte block;
- accesses to different indexes coexisting;
- alternating `0x00000000` and `0x00000400` to demonstrate conflict misses;
- all 16 byte offsets and byte-lane ordering;
- returned-data checks against deterministic memory contents;
- request/response handshake checks;
- hit/miss totals, rates, and AMAT with stated units;
- reset during idle and agreed reset edge cases.

The exact traces, random seed, expected data, and measured results must be committed by Member 05 and must not be inferred or fabricated here.
