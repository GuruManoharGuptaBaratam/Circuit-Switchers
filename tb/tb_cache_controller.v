`timescale 1ns/1ps

// ============================================================================
// Testbench: tb_cache_controller
// Owner:     Member 04 - Cache Controller FSM and Main-Memory Model
//
// Focused controller tests run against the real integrated cache_top (all
// delivered RTL, no stubs). Internal controller/memory/storage signals are
// observed hierarchically. Workload traces, statistics and AMAT belong to
// Member 05's system testbenches; this file only proves controller behaviour.
//
// Directed tests (PDF section 3.4):
//   T1  Reset during idle -> IDLE, req_ready = 1, all valid bits cleared.
//   T2  Cold miss: mem_req asserted with the aligned block address, waits the
//       full memory latency, refills block/tag/valid, returns correct byte.
//   T3  Repeat same address -> hit, no memory request, 2-cycle latency.
//   T4  Other offset in the same block -> hit with the correct byte.
//   T5  Conflict (same index, different tag) -> miss and line replacement.
//   T6  Original address again -> miss (it was evicted).
//   T7  Different index -> miss; both lines then stay resident (hits).
//   T8  Reset during MEM_WAIT cancels the request; no stale mem_ready/refill.
//   T9  req_valid held high continuously -> exactly one accept per response.
//
// Continuous monitors (every cycle):
//   M1  refill_write_en is never high unless mem_ready is high.
//   M2  mem_addr is stable while mem_req stays high.
//   M3  mem_addr is 16-byte aligned whenever mem_req is high.
//   M4  resp_valid is a one-cycle pulse.
//   M5  req_ready is low while a request is in progress.
// ============================================================================

module tb_cache_controller;

    localparam integer LATENCY = 4;      // main_memory_model default
    localparam [1:0]   S_IDLE  = 2'd0;
    localparam [1:0]   S_MEM_WAIT = 2'd2;

    reg         clk;
    reg         reset;
    reg         req_valid;
    reg  [31:0] req_addr;
    wire        req_ready;
    wire        resp_valid;
    wire [7:0]  resp_data;
    wire        resp_hit;

    integer tests_run    = 0;
    integer tests_passed = 0;
    integer tests_failed = 0;
    integer monitor_errors = 0;

    // Monitor bookkeeping.
    integer mem_req_count  = 0;   // rising edges of mem_req
    integer refill_count   = 0;   // cycles with refill_write_en
    integer mem_wait_cycles = 0;  // cycles with mem_req && !mem_ready (current txn)
    reg        prev_mem_req;
    reg [31:0] prev_mem_addr;
    reg        prev_resp_valid;
    reg        monitors_on;

    cache_top dut (
        .clk(clk),
        .reset(reset),
        .req_valid(req_valid),
        .req_addr(req_addr),
        .req_ready(req_ready),
        .resp_valid(resp_valid),
        .resp_data(resp_data),
        .resp_hit(resp_hit)
    );

    // 10 ns clock.
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("results/waveforms/cache_controller_final.vcd");
        $dumpvars(0, tb_cache_controller);
    end

    // ------------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------------
    function [7:0] pattern_byte;
        input [31:0] addr;
        begin
            pattern_byte = addr[7:0] ^ addr[15:8] ^ 8'hA5;
        end
    endfunction

    function [127:0] expected_block;
        input [31:0] addr;
        integer k;
        reg [31:0] base;
        begin
            base = {addr[31:4], 4'b0000};
            for (k = 0; k < 16; k = k + 1)
                expected_block[8*k +: 8] = pattern_byte(base + k);
        end
    endfunction

    task check;
        input        cond;
        input [8*96-1:0] msg;
        begin
            tests_run = tests_run + 1;
            if (cond) begin
                tests_passed = tests_passed + 1;
                $display("  PASS: %0s", msg);
            end else begin
                tests_failed = tests_failed + 1;
                $display("  FAIL: %0s", msg);
            end
        end
    endtask

    // Issue one request and wait for its response.
    // Returns response data/hit, cycles from acceptance edge to the resp_valid
    // cycle, number of new memory requests, and observed memory wait cycles.
    task do_request;
        input  [31:0] addr;
        output [7:0]  data;
        output        hit;
        output integer latency;
        output integer mem_reqs;
        output integer wait_cycles;
        integer start_mem_reqs;
        begin
            @(negedge clk);
            req_valid = 1'b1;
            req_addr  = addr;
            while (!req_ready) @(negedge clk);
            start_mem_reqs  = mem_req_count;
            mem_wait_cycles = 0;
            @(posedge clk);              // acceptance edge
            latency = 0;
            @(negedge clk);
            req_valid = 1'b0;
            req_addr  = 32'hDEAD_BEEF;   // requester may change inputs now
            latency = 1;
            while (!resp_valid) begin
                @(negedge clk);
                latency = latency + 1;
            end
            data        = resp_data;
            hit         = resp_hit;
            mem_reqs    = mem_req_count - start_mem_reqs;
            wait_cycles = mem_wait_cycles;
        end
    endtask

    // ------------------------------------------------------------------------
    // Continuous protocol monitors (sampled mid-cycle on the falling edge).
    // ------------------------------------------------------------------------
    always @(negedge clk) begin
        if (monitors_on && !reset) begin
            if (dut.refill_write_en && !dut.mem_ready) begin
                monitor_errors = monitor_errors + 1;
                $display("  MONITOR FAIL @%0t: refill_write_en without mem_ready", $time);
            end
            if (dut.mem_req && prev_mem_req && dut.mem_addr !== prev_mem_addr) begin
                monitor_errors = monitor_errors + 1;
                $display("  MONITOR FAIL @%0t: mem_addr changed during mem_req (%h -> %h)",
                         $time, prev_mem_addr, dut.mem_addr);
            end
            if (dut.mem_req && dut.mem_addr[3:0] !== 4'b0000) begin
                monitor_errors = monitor_errors + 1;
                $display("  MONITOR FAIL @%0t: unaligned mem_addr %h", $time, dut.mem_addr);
            end
            if (resp_valid && prev_resp_valid) begin
                monitor_errors = monitor_errors + 1;
                $display("  MONITOR FAIL @%0t: resp_valid longer than one cycle", $time);
            end
            if (req_ready && dut.u_cache_controller.state !== S_IDLE) begin
                monitor_errors = monitor_errors + 1;
                $display("  MONITOR FAIL @%0t: req_ready high outside IDLE", $time);
            end
            if (dut.mem_req && !prev_mem_req)       mem_req_count = mem_req_count + 1;
            if (dut.refill_write_en)                refill_count  = refill_count + 1;
            if (dut.mem_req && !dut.mem_ready)      mem_wait_cycles = mem_wait_cycles + 1;
        end
        prev_mem_req    = dut.mem_req;
        prev_mem_addr   = dut.mem_addr;
        prev_resp_valid = resp_valid;
    end

    // ------------------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------------------
    reg [7:0]  r_data;
    reg        r_hit;
    integer    r_lat;
    integer    r_mreq;
    integer    r_wait;
    integer    refills_before;
    integer    j;
    reg        stray_ready;

    initial begin
        reset       = 1'b1;
        req_valid   = 1'b0;
        req_addr    = 32'b0;
        monitors_on = 1'b0;
        prev_mem_req = 1'b0;
        prev_mem_addr = 32'b0;
        prev_resp_valid = 1'b0;

        $display("============================================================");
        $display(" tb_cache_controller : Member 04 controller + memory tests");
        $display(" Memory latency = %0d cycles", LATENCY);
        $display("============================================================");

        // ---------------- T1: reset during idle ----------------
        $display("\n[T1] Reset during idle");
        repeat (3) @(posedge clk);
        @(negedge clk);
        reset = 1'b0;
        monitors_on = 1'b1;
        check(dut.u_cache_controller.state === S_IDLE, "controller state is IDLE after reset");
        check(req_ready === 1'b1,                      "req_ready high after reset");
        check(resp_valid === 1'b0,                     "resp_valid low after reset");
        check(dut.mem_req === 1'b0,                    "mem_req low after reset");
        check(dut.u_valid_bit_ram.valid_bits === 64'b0, "all 64 valid bits cleared");

        // ---------------- T2: cold miss ----------------
        $display("\n[T2] Cold miss at 0x00000004");
        fork
            do_request(32'h0000_0004, r_data, r_hit, r_lat, r_mreq, r_wait);
            begin : watch_mem_addr
                // Capture the address on the first mem_req cycle.
                @(posedge dut.mem_req);
                #1;
                check(dut.mem_addr === 32'h0000_0000, "mem_addr is aligned block 0x00000000");
            end
        join
        check(r_hit === 1'b0,                          "resp_hit = 0 (miss)");
        check(r_mreq == 1,                             "exactly one memory request issued");
        // mem_req is high 1 cycle before memory's acceptance edge, then
        // LATENCY cycles until mem_ready: LATENCY + 1 cycles without data.
        check(r_wait == LATENCY + 1,                   "controller held mem_req until mem_ready (LATENCY+1 cycles)");
        check(r_data === pattern_byte(32'h0000_0004),  "returned byte equals memory[0x04]");
        check(r_lat == LATENCY + 4,                    "miss latency = LATENCY + 4 cycles");
        @(negedge clk);
        check(dut.u_valid_bit_ram.valid_bits[0] === 1'b1,                "line 0 valid bit set by refill");
        check(dut.u_tag_ram.mem[0] === 22'h0,                            "line 0 tag = 0x000000");
        check(dut.u_cache_data_ram.mem[0] === expected_block(32'h0),     "line 0 data = memory block 0x00000000");
        check(dut.u_valid_bit_ram.valid_bits[63:1] === 63'b0,            "no other line became valid");

        // ---------------- T3: repeat -> hit ----------------
        $display("\n[T3] Repeat 0x00000004 -> hit");
        refills_before = refill_count;
        do_request(32'h0000_0004, r_data, r_hit, r_lat, r_mreq, r_wait);
        check(r_hit === 1'b1,                          "resp_hit = 1 (hit)");
        check(r_mreq == 0,                             "no memory request on hit");
        check(refill_count == refills_before,          "no refill on hit");
        check(r_data === pattern_byte(32'h0000_0004),  "hit returns correct byte");
        check(r_lat == 2,                              "hit latency = 2 cycles");

        // ---------------- T4: same block, other offset ----------------
        $display("\n[T4] Same block, offset 15 (0x0000000F) -> hit");
        do_request(32'h0000_000F, r_data, r_hit, r_lat, r_mreq, r_wait);
        check(r_hit === 1'b1 && r_mreq == 0,           "hit without memory request");
        check(r_data === pattern_byte(32'h0000_000F),  "offset 15 returns correct byte");

        // ---------------- T5: conflict ----------------
        $display("\n[T5] Conflict 0x00000404 (index 0, tag 1) -> miss + replace");
        do_request(32'h0000_0404, r_data, r_hit, r_lat, r_mreq, r_wait);
        check(r_hit === 1'b0 && r_mreq == 1,           "conflict is a miss with one memory request");
        check(r_data === pattern_byte(32'h0000_0404),  "returns memory[0x404], not the old line");
        @(negedge clk);
        check(dut.u_tag_ram.mem[0] === 22'h1,                              "line 0 tag replaced with 0x000001");
        check(dut.u_cache_data_ram.mem[0] === expected_block(32'h400),     "line 0 data replaced with block 0x400");

        // ---------------- T6: original address evicted ----------------
        $display("\n[T6] 0x00000004 again -> miss (evicted)");
        do_request(32'h0000_0004, r_data, r_hit, r_lat, r_mreq, r_wait);
        check(r_hit === 1'b0 && r_mreq == 1,           "evicted block misses again");
        check(r_data === pattern_byte(32'h0000_0004),  "correct byte after re-fill");

        // ---------------- T7: different index coexist ----------------
        $display("\n[T7] Different index 0x00000013 -> miss, then both lines hit");
        do_request(32'h0000_0013, r_data, r_hit, r_lat, r_mreq, r_wait);
        check(r_hit === 1'b0 && r_mreq == 1,           "line 1 cold miss");
        check(r_data === pattern_byte(32'h0000_0013),  "line 1 returns correct byte");
        do_request(32'h0000_0000, r_data, r_hit, r_lat, r_mreq, r_wait);
        check(r_hit === 1'b1 && r_data === pattern_byte(32'h0), "line 0 still resident (hit)");
        do_request(32'h0000_001E, r_data, r_hit, r_lat, r_mreq, r_wait);
        check(r_hit === 1'b1 && r_data === pattern_byte(32'h1E), "line 1 still resident (hit)");

        // ---------------- T8: reset during MEM_WAIT ----------------
        $display("\n[T8] Reset while waiting for memory");
        @(negedge clk);
        req_valid = 1'b1;
        req_addr  = 32'h0000_0820;          // index 2, cold
        @(negedge clk);
        req_valid = 1'b0;
        while (dut.u_cache_controller.state !== S_MEM_WAIT) @(negedge clk);
        @(negedge clk);                     // memory has accepted, now busy
        check(dut.u_main_memory_model.busy === 1'b1, "memory busy with in-flight request");
        refills_before = refill_count;
        reset = 1'b1;
        @(negedge clk);
        reset = 1'b0;
        check(dut.u_cache_controller.state === S_IDLE, "reset returns controller to IDLE");
        check(dut.u_main_memory_model.busy === 1'b0,   "reset cancels in-flight memory request");
        check(dut.u_valid_bit_ram.valid_bits === 64'b0, "reset clears all valid bits");
        stray_ready = 1'b0;
        for (j = 0; j < LATENCY + 4; j = j + 1) begin
            @(negedge clk);
            if (dut.mem_ready || dut.refill_write_en || resp_valid) stray_ready = 1'b1;
        end
        check(!stray_ready, "no stale mem_ready/refill/response after reset");
        do_request(32'h0000_0004, r_data, r_hit, r_lat, r_mreq, r_wait);
        check(r_hit === 1'b0 && r_data === pattern_byte(32'h4), "post-reset access misses and is correct");

        // ---------------- T9: req_valid held high ----------------
        $display("\n[T9] req_valid held high across a transaction");
        @(negedge clk);
        req_valid = 1'b1;
        req_addr  = 32'h0000_0004;          // resident -> hit
        j = 0;
        // Hold for 6 cycles; a hit takes 2 cycles + 1 IDLE cycle, so two
        // requests are accepted and exactly two responses are produced.
        repeat (6) begin
            @(negedge clk);
            if (resp_valid) j = j + 1;
        end
        req_valid = 1'b0;
        repeat (3) begin
            @(negedge clk);
            if (resp_valid) j = j + 1;
        end
        check(j == 2, "one response per accepted request (2 accepts -> 2 responses)");

        // ---------------- Summary ----------------
        repeat (2) @(negedge clk);
        check(monitor_errors == 0, "protocol monitors M1-M5 reported no violations");

        $display("\n============================================================");
        $display(" Tests run: %0d  Passed: %0d  Failed: %0d", tests_run, tests_passed, tests_failed);
        $display(" Memory requests issued: %0d  Refill writes: %0d", mem_req_count, refill_count);
        if (tests_failed == 0)
            $display(" RESULT: ALL TESTS PASSED");
        else
            $display(" RESULT: FAILURES DETECTED");
        $display("============================================================");
        $finish;
    end

    // Safety timeout.
    initial begin
        #100000;
        $display("FAIL: simulation timeout");
        $finish;
    end

endmodule
