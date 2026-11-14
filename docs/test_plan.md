# Phase I cache verification

Run `bash scripts/run_all_tests.sh` for the full suite, or
`bash scripts/run_sim.sh WORKLOAD` for one system test. Each simulation starts
with synchronous active-high reset. Bench stimulus changes at falling edges
and the scoreboard samples at rising edges before sequential RTL updates.

| Workload | Stimulus | Pass criteria |
| --- | --- | --- |
| system | Cold reads at 0x04 and 0x17 with the second held while busy, then reread both | Two misses followed by two hits. Both indexes remain resident. Each request completes once |
| system | Reset a populated cache, then reread 0x04 | All valid bits clear and the reread misses |
| system | Cancel three requests in lookup, memory wait and while memory-ready is high | Idle is restored, no stale response or refill handshake after reset, retries miss |
| system | Read 0xFFFFFFFF, then read 0x0000FFFF twice | Two distinct tags despite backing-memory aliasing, then a hit |
| sequential | Read bytes 0x00 through 0x1F | Two block-boundary misses, 30 hits, all 16 offsets and canonical byte order checked |
| repeated | Read 0x04 16 times | One cold miss, then 15 hits with no main-memory traffic on those hits |
| conflict | Alternate 0x00000000 and 0x00000400 16 times | Index zero, tags zero and one, 16 misses and one validated refill per request |
| random | Xorshift32 seed 0x6D2B79F5. Take the low 12 bits after each update for 256 requests | Match independent residency model and expected bytes. Both hits and misses occur |

The reference model tracks a block number and validity at each index. For
each accepted read the scoreboard verifies the captured address, data from
the model's default XOR rule, hit status, exact cycle interval and response
uniqueness. On every miss it verifies the aligned address stays stable while
requested, checks the memory-ready and refill handshake, compares all 16
memory lanes, and checks data/tag/valid installation. The directed run also
changes processor inputs after acceptance and holds a legal second request
stable through backpressure. Reset invalidates lines and aborts outstanding work.

A mismatch or timeout exits nonzero via the simulator failure task. The
runner also requires the verified PASS marker and a nonempty waveform.
Waveforms and logs use workload names. The exact completed read sequence is
in [request_trace.csv](../results/metrics/request_trace.csv).
