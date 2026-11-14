# Average memory access time

Latency is the number of clock periods from the rising edge that accepts
`req_valid && req_ready` to the rising edge that samples `resp_valid`.
The RTL asserts response-valid immediately after E1 for a hit and E7 for
a miss, and the consumer samples it at E2 or E8, respectively. On a miss,
memory accepts at E2, asserts ready after E6 (default latency 4), and
the cache samples ready and refills at E7.

The measured hit time is 2 cycles, miss time is 8 cycles
and additional miss penalty is 6 cycles. The observed times below
match the direct mean of all completed reads in each run. Canceled
requests and idle cycles between accesses are excluded. The simulated
clock period is 10 ns. There is no hardware timing or no-cache baseline.

| Workload | Miss fraction | Hit time + miss fraction × penalty | AMAT (cycles/read) |
| --- | --- | --- | ---: |
| system | 8/11 | 2 + (8/11) × 6 | 6.3636 |
| sequential | 2/32 | 2 + (2/32) × 6 | 2.3750 |
| repeated | 1/16 | 2 + (1/16) × 6 | 2.3750 |
| conflict | 16/16 | 2 + (16/16) × 6 | 8.0000 |
| random | 217/256 | 2 + (217/256) × 6 | 7.0859 |
