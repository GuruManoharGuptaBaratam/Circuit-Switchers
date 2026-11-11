# Address Decoder Unit-Test Plan

Owner: **Member 01 - Address Decoder and Top-Level Integration**

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
- The passing output is saved as `results/logs/address_decoder_final.log`.

Run the test with:

```bash
./scripts/run_address_decoder_test.sh
```
