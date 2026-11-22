# Direct-Mapped Cache Controller
## MCA Project 6 — Final Evaluation Presentation

> **Presentation Guide for the Team:**
> - Designed for a **10–12 minute** total group presentation (~2 minutes per topic).
> - Each topic corresponds to one team member's domain without using generic labels like "Member 01".
> - Every slide lists the **exact image file to insert**, the **concise on-slide bullet points**, and the **exact spoken script**.

---

### Slide 1: Title & Executive Summary
* **Presenter:** Group Lead / Topic 1 Presenter
* **Visual Asset to Insert:** 
  - `submission/report/figures/planning/system_architecture.png`
* **On-Slide Content:**
  - **Project Title:** Direct-Mapped Cache Controller
  - **Course:** Modern Computer Architecture (MCA) — Project 6
  - **Team:** Circuit Switchers (Department of CS & AI)
  - **Core Baseline:**
    - 1 KB Data Capacity | 64 Cache Lines | 16-Byte Block Size
    - 32-bit Byte Address Space | Read-Only Integration Baseline
    - 2-Cycle Hit Latency | 8-Cycle Miss Latency | 6-Cycle Miss Penalty
  - **Verified Result:** 100% test pass rate across 331 memory read transactions.
* **Speaker Script (What to Say):**
  > "Good morning, respected evaluators. Today, our team, Circuit Switchers, presents our implementation and verification of a Direct-Mapped Cache Controller for Modern Computer Architecture Project 6. We designed a complete, synthesizable 1 KB cache subsystem in Verilog featuring 16-byte blocks, a 4-state controller FSM, and a cycle-accurate main-memory model. Over the next ten minutes, we will walk you through the architecture, storage hierarchy, hit/miss detection, controller timing, and our empirical workload benchmarks."

---

### Slide 2: Motivation & The Memory Hierarchy
* **Presenter:** Group Lead / Topic 1 Presenter
* **Visual Asset to Insert:**
  - `submission/report/figures/planning/cache_hit_miss_flow.png`
* **On-Slide Content:**
  - **The Memory Wall:** CPUs execute instructions in ~1 ns; accessing DRAM takes ~50–100 ns.
  - **The Principle of Locality:**
    - *Temporal Locality:* Recently accessed data is likely to be accessed again soon (loops, stack variables).
    - *Spatial Locality:* Nearby memory addresses are likely to be accessed consecutively (arrays, sequential instructions).
  - **The Objective:**
    - Bridge the processor-memory speed gap.
    - Serve repeated and adjacent requests in **2 clock cycles** instead of waiting **8 clock cycles** for main memory.
* **Speaker Script (What to Say):**
  > "In modern computing, the processor operates at gigahertz speeds, but fetching data from external DRAM is a major bottleneck. A cache solves this by exploiting locality of reference. Temporal locality means variables reused in loops should stay close to the CPU. Spatial locality means when we fetch one byte, we should fetch its entire neighborhood. In our design, every miss brings in an aligned 16-byte block, allowing subsequent nearby reads to complete in just 2 cycles rather than 8."

---

## TOPIC 1: Address Decoding & Top-Level System Architecture
*(Owned by Guru Manohar Gupta)*

### Slide 3: Cache Geometry & Address Field Derivation
* **Visual Asset to Insert:**
  - `submission/report/figures/address_breakdown.png`
* **On-Slide Content:**
  - **32-bit Address Partitioning:**
    - **Tag [31:10] (22 bits):** Identifies which unique 1 KB block from memory occupies the line.
    - **Index [9:4] (6 bits):** Selects 1 of the 64 available cache lines ($2^6 = 64$).
    - **Offset [3:0] (4 bits):** Selects 1 of the 16 bytes within the block ($2^4 = 16$).
  - **Hardware Implementation (`rtl/address_decoder.v`):**
    - Zero-latency, combinational wire slicing.
    - Verified against boundary addresses (`0x00000000`, `0x0000000F`, `0x00000010`, `0x00000400`).
* **Speaker Script (What to Say):**
  > "I designed the address decoding and top-level integration. In a direct-mapped cache, the 32-bit address is split into three fields derived directly from powers of two. Our 16-byte block requires a 4-bit offset to address individual bytes. With 1 KB total capacity, 1024 divided by 16 gives 64 lines, requiring a 6-bit index. The remaining 22 bits form the tag. My address decoder is pure combinational logic with zero gate delay, feeding the tag, index, and offset continuously to the rest of the system."

---

### Slide 4: Top-Level Integration & Interconnect Wiring
* **Visual Asset to Insert:**
  - `submission/report/figures/planning/module_connections.png`
* **On-Slide Content:**
  - **Integrated Top-Level (`rtl/cache_top.v`):**
    - Clean separation of concerns: structural wiring without embedded FSM state logic.
    - Standard handshake interfaces: `req_valid`/`req_ready` (processor) and `mem_req`/`mem_ready` (memory).
  - **Memory Base Address Alignment:**
    - Block base address formed combinationally: `mem_addr = {active_tag, active_index, 4'b0000}`.
  - **Dual Data Selectors:**
    - Selector 1: Extracts requested byte on a cache hit.
    - Selector 2: Enables **Refill Bypass** on a cache miss directly from the memory bus.
* **Speaker Script (What to Say):**
  > "In `cache_top.v`, I integrated all five workstreams into a single synthesizable chip. It connects the storage banks, lookup comparator, controller FSM, and memory interface. Notice how the memory refill address is aligned: by appending four zero bits to the active tag and index, the controller always requests the aligned 16-byte boundary. Furthermore, I wired dual data selectors to enable refill bypass: when a block arrives from memory, the requested byte is delivered directly to the processor in that same cycle without waiting for a separate RAM read."

---

## TOPIC 2: Cache Storage Subsystem
*(Owned by Harsith Priyan)*

### Slide 5: Memory Storage Hierarchy (Data, Tag & Valid RAMs)
* **Visual Asset to Insert:**
  - `submission/report/figures/planning/module_connections.png` *(Focus on the RAM blocks)*
* **On-Slide Content:**
  - **Physical Storage Arrays (`rtl/`):**
    - **Data RAM (`cache_data_ram.v`):** 64 entries $\times$ 128 bits (1024 bytes data capacity).
    - **Tag RAM (`tag_ram.v`):** 64 entries $\times$ 22 bits (1408 bits metadata).
    - **Valid-Bit RAM (`valid_bit_ram.v`):** 64 entries $\times$ 1 bit (64 bits status metadata).
  - **Total Silicon Footprint:**
    - 8,192 bits Data + 1,408 bits Tag + 64 bits Valid = **9,664 bits (1,208 bytes)**.
  - **Timing Characteristics:**
    - Read: Asynchronous / combinational read based on `read_index`.
    - Write: Synchronous single-cycle update qualified by `refill_write_en`.
* **Speaker Script (What to Say):**
  > "I built the physical storage subsystem of the cache. While the advertised cache size is 1 KB of data, the actual silicon requires 1,208 bytes to store the necessary metadata. The storage is divided into three separate RAM modules: a 64-by-128-bit Data RAM, a 64-by-22-bit Tag RAM, and a 64-bit Valid array. All three RAMs perform combinational reads so the lookup logic can inspect the line immediately, while writes are synchronous, updating the line on the rising clock edge during a refill."

---

### Slide 6: Reset Guarantees & Line Update Protocol
* **Visual Asset to Insert:**
  - Waveform snippet or table from `results/waveforms/cache_storage_final.vcd`
* **On-Slide Content:**
  - **The Cold-Start Hazard:**
    - Uninitialized silicon flip-flops power up with random values (arbitrary 1s and 0s).
    - Matching uninitialized tag bits would cause catastrophic **false hits**.
  - **The Hardware Solution:**
    - Active-high synchronous reset forces **all 64 valid bits to 0**.
    - Data and Tag RAM contents do not require clearing, saving silicon area and reset time.
  - **Atomic Refill Update:**
    - When `refill_write_en` pulses for 1 cycle:
      - Line receives incoming 128-bit block.
      - Tag RAM receives active 22-bit tag.
      - Valid bit for that line flips to `1`.
* **Speaker Script (What to Say):**
  > "A critical design requirement in hardware is preventing false hits. On power-up, RAM cells hold random electrical noise. If an address matched random bits in an uninitialized line, the cache would return garbage. My valid-bit module implements a synchronous reset that clears all 64 valid bits to zero. The data and tag RAMs do not need resetting. When a refill occurs, a single `refill_write_en` pulse atomically writes the new block, updates the tag, and asserts the valid bit in that line simultaneously."

---

## TOPIC 3: Lookup Engine, Hit Detection & Data Selection
*(Owned by Pranavi Mathur)*

### Slide 7: Tag Comparison & Hit Gating Logic
* **Visual Asset to Insert:**
  - Flow diagram / schematic of the comparator and AND gate:
```
  Requested Tag [21:0] ---> | 22-bit Tag | ---> Tag Match
  Stored Tag [21:0]    ---> | Comparator |          |
                                                    v
                                                [ AND Gate ] ---> HIT / MISS
  Stored Valid Bit ---------------------------->    ^
```
* **On-Slide Content:**
  - **Modules (`rtl/tag_comparator.v` & `rtl/cache_lookup.v`):**
    - Pure combinational comparison of the 22-bit requested tag vs. stored tag.
  - **Exact Hit Condition:**
    $$\mathbf{Hit = (Stored\ Valid == 1'b1)\ \&\&\ (Requested\ Tag == Stored\ Tag)}$$
  - **Safety Rules:**
    - If `Stored Valid == 0`, `Hit` is forced to `0` regardless of tag comparator output.
    - If `Tags Mismatch`, `Hit` is `0` (indicates line is occupied by another block).
  - **Verification:** 41 / 41 unit tests passed covering valid hits, invalid misses, and tag mismatches.
* **Speaker Script (What to Say):**
  > "I implemented the decision-making engine of the cache. When an address is looked up, my `tag_comparator` checks whether the 22-bit requested tag equals the 22-bit tag stored in that line. The `cache_lookup` module then gates this comparison with the valid bit: a hit occurs if and only if the valid bit is 1 AND the tags match. If the valid bit is 0, the output is guaranteed to be 0 even if the tags happen to match. This combinational decision is generated immediately for the controller FSM."

---

### Slide 8: 16-to-1 Data Multiplexing & Refill Bypass
* **Visual Asset to Insert:**
  - `submission/report/figures/planning/module_connections.png` *(Highlighting data selectors)*
* **On-Slide Content:**
  - **Byte Selection Engine (`rtl/data_selector.v`):**
    - 16-to-1 byte multiplexer extracting one 8-bit byte from a 128-bit block.
    - Controlled by the 4-bit `byte_offset`:
      $$\text{selected\_byte} = \text{block\_data}[(8 \times \text{byte\_offset}) +: 8]$$
  - **Canonical Byte Ordering:**
    - Offset `4'h0` selects `block_data[7:0]` (Little-Endian base byte).
    - Offset `4'hF` selects `block_data[127:120]` (Byte 15).
  - **Refill Bypass Operation:**
    - On a cache miss, data is sliced directly from incoming `mem_block` in parallel with RAM writing, eliminating an extra read cycle.
* **Speaker Script (What to Say):**
  > "The processor requests a single byte, but cache lines store 16-byte blocks. My `data_selector` module is a 16-to-1 multiplexer that uses the 4-bit offset to slice the exact 8-bit byte from the 128-bit block. In `cache_top`, this module is instantiated twice: once for normal cache hits, and once for refill bypass. By selecting the byte directly from the incoming memory bus during a miss refill, we avoid having to write the RAM and read it back on the next clock, saving one clock cycle of CPU stall time."

---

## TOPIC 4: Controller FSM & Memory Subsystem
*(Owned by Yatin Singh)*

### Slide 9: 4-State Controller Finite State Machine
* **Visual Asset to Insert:**
  - `submission/report/figures/controller_fsm.png`
* **On-Slide Content:**
  - **Controller Architecture (`rtl/cache_controller.v`):**
    - 4-state Mealy/Moore synchronous FSM: `IDLE (00)`, `LOOKUP (01)`, `MEM_WAIT (10)`, `RESPOND (11)`.
  - **State Responsibilities:**
    - `IDLE`: Ready for request (`req_ready = 1`). Latches `req_addr` on `req_valid`.
    - `LOOKUP`: Evaluates hit. If Hit $\rightarrow$ `RESPOND`. If Miss $\rightarrow$ `MEM_WAIT`.
    - `MEM_WAIT`: Asserts `mem_req = 1`, holds address stable. Upon `mem_ready`, pulses `refill_write_en = 1`.
    - `RESPOND`: Asserts 1-cycle `resp_valid = 1` with data, then returns to `IDLE`.
* **Speaker Script (What to Say):**
  > "I designed the traffic manager of the cache: the 4-state controller FSM. In `IDLE`, the controller waits with `req_ready` high. When a request arrives, it transitions to `LOOKUP`. If the lookup logic reports a hit, the FSM transitions directly to `RESPOND`, taking only 2 cycles. If it misses, it transitions to `MEM_WAIT`, raises `mem_req`, and waits for memory to finish. On the cycle memory asserts `mem_ready`, the controller pulses `refill_write_en` to update the line and moves to `RESPOND`. Reset safely returns the controller to `IDLE` from any state."

---

### Slide 10: Timing Analysis & Waveform Evidence
* **Visual Asset to Insert:**
  - `submission/report/figures/controller_waveform.png` (or `results/waveforms/cache_controller_miss_hit.png`)
* **On-Slide Content:**
  - **Empirical Cycle Timing:**
    - **Hit Latency:** **2 cycles** (`IDLE` $\rightarrow$ `LOOKUP` $\rightarrow$ `RESPOND`).
    - **Miss Latency:** **8 cycles** ($\text{Memory Latency [4]} + 4\text{ FSM cycles}$).
    - **Miss Penalty:** $\text{Miss Latency} - \text{Hit Latency} = 8 - 2 = \mathbf{6\text{ cycles}}$.
  - **Waveform Walkthrough (Cold Miss Followed by Repeat Hit):**
    - *Read 0x00000004 (Miss):* `mem_req` stays high for 4 cycles; line 0 refilled; returns byte `0xA1` at cycle 8.
    - *Read 0x00000004 (Hit):* Immediately hits at cycle 2; `mem_req` remains strictly 0.
* **Speaker Script (What to Say):**
  > "This waveform demonstrates our cycle-accurate timing in GTKWave. The first access to address `0x04` is a cold miss: the controller asserts `mem_req` for the aligned block, waits 4 cycles for memory latency, refills the cache on cycle 6, and delivers the byte on cycle 7, totaling 8 cycles. When the testbench immediately requests `0x04` again, it is an instant hit: `mem_req` never goes high, memory is never bothered, and the byte is delivered in exactly 2 cycles. This confirms our 6-cycle miss penalty."

---

## TOPIC 5: System Verification, Workloads & Synthesis
*(Owned by Dadi Dinesh)*

### Slide 11: Verification Environment & Scoreboard Architecture
* **Visual Asset to Insert:**
  - Mermaid diagram or screenshot of testbench execution:
```
  [ Stimulus Generator ] ---> [ DUT: cache_top ] ---> [ Actual Outputs ]
            |                                                 |
            v                                                 v
  [ Golden XOR Model ] -----------------------------> [ Cycle Scoreboard ]
```
* **On-Slide Content:**
  - **Self-Checking Scoreboard (`tb/tb_cache_system.v`):**
    - Independent golden reference model computing expected data:
      $$\text{Expected Byte} = \text{Address}[7:0] \oplus \text{Address}[15:8] \oplus \text{0xA5}$$
    - Protocol checkers: continuously verify bus stability, valid-bit persistence, and handshake timing.
  - **Regression Coverage:**
    - 331 completed read transactions verified with zero errors.
    - Validated reset aborts during active memory waits.
* **Speaker Script (What to Say):**
  > "I owned system-level verification, performance benchmarking, and hardware synthesis. Rather than manually inspecting waveforms, I built an automated self-checking scoreboard in `tb_cache_system.v`. It models line residency independently and computes the mathematically expected byte using an XOR function. Every single read is checked for byte correctness, exact cycle latency, and handshake protocol validity. Across 331 total memory reads, our testbench reported zero errors."

---

### Slide 12: Workload Evaluation & Locality Proof
* **Visual Asset to Insert:**
  - Table of workload results:

| Workload Trace | Total Reads | Hits | Misses | Hit Rate | AMAT (Cycles) |
|---|:---:|:---:|:---:|:---:|:---:|
| **Sequential** | 32 | 30 | 2 | **93.75%** | **2.3750** |
| **Repeated** | 16 | 15 | 1 | **93.75%** | **2.3750** |
| **Conflict** | 16 | 0 | 16 | **0.00%** | **8.0000** |
| **Random** | 256 | 39 | 217 | **15.23%** | **7.0859** |

* **On-Slide Content:**
  - **Sequential Access:** Proves **Spatial Locality** (2 misses across 32 reads).
  - **Repeated Access:** Proves **Temporal Locality** (15 hits out of 16 reads).
  - **Conflict Access:** Proves **Direct-Mapped Collision** (alternating `0x000` and `0x400` results in 100% misses due to line 0 contention).
* **Speaker Script (What to Say):**
  > "We tested our cache across four representative access patterns. In the sequential workload, reading 32 consecutive bytes produced a 93.75% hit rate because fetching 16-byte blocks satisfies subsequent neighbor reads—proving spatial locality. In the repeated workload, rereading the same variable produced 15 hits out of 16—proving temporal locality. Finally, our conflict workload alternated between addresses 0x000 and 0x400. Because both map to line 0, they repeatedly evict each other, producing a 100% miss rate and proving expected direct-mapped behavior."

---

### Slide 13: AMAT Calculation & Yosys RTL Synthesis
* **Visual Asset to Insert:**
  - Synthesis summary graphic or snippet from `results/synthesis/stat.json`
* **On-Slide Content:**
  - **Average Memory Access Time (AMAT):**
    $$\mathbf{AMAT = \text{Hit Time} + (\text{Miss Rate} \times \text{Miss Penalty})}$$
    $$\text{Sequential AMAT} = 2 + (0.0625 \times 6) = \mathbf{2.375\text{ cycles/access}}$$
    - Provides a **$3.37\times$ speedup** over an un-cached memory system ($8.0\text{ cycles}$).
  - **RTL Synthesis Results (Yosys Open Synthesis Suite):**
    - Target: Generic cell technology mapping.
    - Synthesizable cell count: $\approx 7,500$ cells (DFFs, logic gates, multiplexers).
    - Status: 100% synthesizable RTL with **zero inferred latches**.
* **Speaker Script (What to Say):**
  > "Using our measured values, we calculated the Average Memory Access Time. For sequential workloads, the AMAT is 2.375 clock cycles per read, representing a 3.37x speedup compared to an un-cached 8-cycle memory access. We also synthesized the entire cache core using Yosys. The design synthesized cleanly into approximately 7,500 generic gates with zero inferred latches, verifying that our Verilog code is fully synthesizable hardware."

---

### Slide 14: Conclusion & Future Scope
* **Presenter:** Group Lead / Topic 1 Presenter
* **Visual Asset to Insert:**
  - `submission/report/figures/system_architecture.pdf` (or `planning/system_architecture.png`)
* **On-Slide Content:**
  - **Project Achievements:**
    - Synthesizable 1 KB direct-mapped cache controller.
    - Verified 4-state controller FSM with deterministic memory model.
    - Full documentation, reproducible test scripts, and complete IEEE-format report.
  - **Scope & Limitations:**
    - Read-only baseline (writes deferred by design agreement).
  - **Future Roadmap:**
    - Write support: Write-Through with write buffers or Write-Back with Dirty Bits.
    - Associativity: 2-way or 4-way set-associativity with Pseudo-LRU replacement to eliminate conflict misses.
* **Speaker Script (What to Say):**
  > "To conclude, Circuit Switchers has delivered a complete, verified, and synthesizable direct-mapped cache controller. Every architectural module was independently tested and integrated into a robust read path. For future work, this design can be naturally extended with write-back capabilities using dirty bits and multi-way set associativity to mitigate conflict misses. We are now open for questions. Thank you."

---

### Slide 15: Appendix — Live Demo Quick Commands
* **On-Slide Content:**
  - **Full Regression Test (Runs in ~2 seconds):**
    ```bash
    bash scripts/run_all_tests.sh
    ```
  - **Run Individual Workload (e.g., Sequential or Conflict):**
    ```bash
    bash scripts/run_sim.sh sequential
    bash scripts/run_sim.sh conflict
    ```
  - **View Waveforms in GTKWave:**
    ```bash
    gtkwave results/waveforms/cache_controller_final.vcd
    ```
  - **Submission Package:** Complete IEEE Report (`circuit_switchers_ieee_report.pdf`) and 5-minute video walkthrough (`Circuit_Switchers_5min_Final_Architecture_Fixed.mp4`).
* **Speaker Script (What to Say):**
  > "If the evaluation committee wishes to see the live simulation, we can execute our automated regression runner in a single command, demonstrating that all unit tests and workloads pass in real time."
