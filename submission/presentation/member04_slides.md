# Member 04 — Presentation Section (Yatin Singh)

Cache Controller FSM and Main-Memory Model. Three slides, about 90 seconds in total.
Figures: `submission/report/figures/controller_fsm.png` and `submission/report/figures/controller_waveform.png`.

---

## Slide 1 — Why the cache needs a controller

**On slide**
- Hit: the data is already in the cache, so answer immediately
- Miss: main memory is slow and doesn't answer in one cycle
- A miss needs several ordered steps: ask memory → wait → store block, tag, valid → answer
- The controller is a 4-state FSM that runs those steps

**Say**
> "Members 1 to 3 built the parts that split the address, store the lines and decide hit or miss. Something has to run them in the right order. That's the controller. On a hit it answers straight away. On a miss it can't, because main memory is slow, so it asks memory for the whole 16-byte block, waits, stores it in the cache, and then answers."

---

## Slide 2 — The FSM

**On slide:** `controller_fsm.png`

| State | What happens |
|---|---|
| IDLE | Ready for a request; captures tag, index, offset |
| LOOKUP | Checks hit/miss. Hit → RESPOND, miss → MEM_WAIT |
| MEM_WAIT | Holds `mem_req` and the address until `mem_ready`. On that cycle, writes block + tag + valid into the line |
| RESPOND | One-cycle `resp_valid` with the byte, then back to IDLE |

**Say**
> "The controller only ever asks memory from MEM_WAIT, so a hit can never cause a memory request. And the cache write is only allowed in the exact cycle memory says the data is ready, so we can never store garbage. Reset sends it back to IDLE from any state."

---

## Slide 3 — Proof: a miss, then a hit

**On slide:** `controller_waveform.png`
- Cold miss at 0x00000004: `mem_req` for block 0x00000000 → wait 4 cycles → `mem_ready` + refill → answer 0xA1, `resp_hit=0` (8 cycles)
- Same address again: hit in **2 cycles**, no memory request
- Miss penalty = **6 cycles**
- Integrated test with all members' RTL: **40 / 40 checks pass**

**Say**
> "This is the real simulation. The first access to 0x04 misses: the controller asks memory for the aligned block, waits, and on the ready cycle writes the line and returns the byte. That took 8 cycles. Because the line is now valid with the right tag, the second access is a hit in 2 cycles with no memory traffic. That's exactly why a cache speeds things up. Our testbench also checks conflicts, eviction and reset during a memory wait, and every cycle it checks that we never refill before memory is ready."

---

### Likely questions

- **Why does a miss take 8 cycles and not 4?** Memory latency is 4. On top of that there's one cycle for lookup, one for memory to see the request, one for the refill edge and one for the response pulse: LATENCY + 4.
- **Where does the returned byte come from on a miss?** Directly from the block memory just returned, chosen by the offset. It's written into the cache in the same cycle.
- **Is the memory real?** No. It's a Verilog array for simulation with known contents, `mem[a] = a[7:0] ^ a[15:8] ^ 0xA5`, so tests can check every returned byte.
