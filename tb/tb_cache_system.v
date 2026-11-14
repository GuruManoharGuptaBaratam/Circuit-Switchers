`timescale 1ns/1ps

module tb_cache_system;
    cache_system_fixture suite();
endmodule

module cache_system_fixture #(parameter WORKLOAD = "system");
    localparam MEMORY_LATENCY = 4;
    localparam [31:0] RANDOM_SEED = 32'h6d2b79f5;

    reg clk = 0;
    always #5 clk = !clk;

    reg reset = 1;
    reg req_valid = 0;
    reg [31:0] req_addr = 0;
    wire req_ready, resp_valid, resp_hit;
    wire [7:0] resp_data;

    cache_top dut(clk, reset, req_valid, req_addr, req_ready,
                  resp_valid, resp_data, resp_hit);

    // Independent reference model based on block numbers and line residency.
    reg [63:0] resident = 0;
    reg [27:0] blocks [0:63];
    reg pending = 0;
    reg [31:0] address;
    reg expected_hit;
    integer cycle = 0, accepted_at, memory_at;
    integer accepted = 0, completed = 0, canceled = 0, hits = 0, misses = 0;
    integer hit_cycles = 0, miss_cycles = 0;
    integer handshakes = 0, memory_cycles = 0;
    reg previous_response = 0;
    integer index, lane;
    integer i;
    reg [31:0] random_state = RANDOM_SEED;
    reg [31:0] random_address;
    reg [1023:0] vcd;

    function [7:0] expected_byte(input [31:0] byte_address);
        expected_byte = byte_address[7:0] ^ byte_address[15:8] ^ 8'hA5;
    endfunction

    // Sample stable values at the consumer's rising edge, before NBA updates.
    always @(posedge clk) begin
        cycle = cycle + 1;
        if (reset) begin
            if (pending)
                canceled = canceled + 1;
            pending = 0;
            resident = 0;
            previous_response = 0;
            #1;
            if ({req_ready, resp_valid, dut.mem_req, dut.mem_ready,
                 dut.refill_write_en} !== 5'b10000 ||
                dut.u_valid_bit_ram.valid_bits !== 64'b0)
                $fatal(1, "Reset failed to restore idle and invalidate all lines");
        end else begin
            if (req_ready !== !pending)
                $fatal(1, "cycle %0d: req_ready=%b pending=%b", cycle, req_ready, pending);
            if (resp_valid !== 1'b0 && (resp_valid !== 1'b1 || !pending || previous_response))
                $fatal(1, "cycle %0d: invalid, unsolicited or duplicate response", cycle);

            if (pending && {dut.active_tag, dut.active_index, dut.active_offset} !== address)
                $fatal(1, "Captured address changed, expected %08h", address);

            if (dut.refill_write_en !== dut.mem_ready ||
                (dut.mem_ready !== 1'b0 && dut.mem_req !== 1'b1))
                $fatal(1, "cycle %0d: invalid memory/refill handshake", cycle);
            if (dut.mem_req !== 1'b0) begin
                if (dut.mem_req !== 1'b1 || !pending || expected_hit || handshakes != 0 ||
                    dut.mem_addr !== (address & 32'hfffffff0))
                    $fatal(1, "cycle %0d: unexpected request or misaligned/unstable address %08h for %08h",
                           cycle, dut.mem_addr, address);
                if (memory_cycles == 0)
                    memory_at = cycle;
                memory_cycles = memory_cycles + 1;
                if (dut.mem_ready) begin
                    if (cycle - memory_at != MEMORY_LATENCY + 1)
                        $fatal(1, "%08h: memory-ready sample after %0d cycles, expected %0d",
                               address, cycle - memory_at, MEMORY_LATENCY + 1);
                    for (lane = 0; lane < 16; lane = lane + 1)
                        if (dut.mem_block[8*lane +: 8] !== expected_byte(dut.mem_addr + lane))
                            $fatal(1, "%08h lane %0d: memory byte %02h expected %02h",
                                   dut.mem_addr, lane, dut.mem_block[8*lane +: 8],
                                   expected_byte(dut.mem_addr + lane));
                    handshakes = handshakes + 1;
                end
            end else if (pending && memory_cycles > 0 && handshakes == 0)
                $fatal(1, "%08h: mem_req dropped before mem_ready", address);

            if (resp_valid) begin
                if (resp_data !== expected_byte(address) || resp_hit !== expected_hit)
                    $fatal(1, "%08h: byte %02h expected %02h, hit %b expected %b",
                           address, resp_data, expected_byte(address), resp_hit, expected_hit);
                if (cycle - accepted_at != (expected_hit ? 2 : MEMORY_LATENCY + 4) ||
                    handshakes != (expected_hit ? 0 : 1))
                    $fatal(1, "%08h: unexpected latency %0d or refill count %0d (expected hit=%b)",
                           address, cycle - accepted_at, handshakes, expected_hit);
                if (!expected_hit) begin
                    resident[index] = 1;
                    blocks[index] = address[31:4];
                    if (dut.stored_valid !== 1'b1 || dut.stored_tag !== address[31:10] ||
                        dut.stored_block !== dut.mem_block)
                        $fatal(1, "%08h: completed miss failed to install data/tag/valid", address);
                end
                completed = completed + 1;
                if (resp_hit) begin
                    hits = hits + 1;
                    hit_cycles = hit_cycles + cycle - accepted_at;
                end else begin
                    misses = misses + 1;
                    miss_cycles = miss_cycles + cycle - accepted_at;
                end
                $display("READ,%0d,%08h,%02h,%02h,%0d,%0d",
                         completed, address, resp_data, expected_byte(address),
                         resp_hit, cycle - accepted_at);
                pending = 0;
            end
            previous_response = resp_valid;

            if (req_valid && req_ready) begin
                accepted = accepted + 1;
                pending = 1;
                address = req_addr;
                index = int'(req_addr[9:4]);
                expected_hit = resident[index] && blocks[index] == req_addr[31:4];
                accepted_at = cycle;
                memory_cycles = 0;
                handshakes = 0;
            end
            if (pending && cycle - accepted_at > MEMORY_LATENCY + 5)
                $fatal(1, "%08h: response timeout", address);
        end
    end

    // Enter and return on falling edges to avoid racing the monitor or DUT.
    task offer(input [31:0] requested_address);
        begin
            req_addr = requested_address;
            req_valid = 1;
            @(posedge clk);
            while (req_ready !== 1'b1)
                @(posedge clk);
            @(negedge clk);
            req_valid = 0;
            req_addr = ~requested_address;
        end
    endtask

    task read_byte(input [31:0] requested_address);
        integer target;
        begin
            target = completed + 1;
            offer(requested_address);
            while (completed < target)
                @(negedge clk);
        end
    endtask

    task reset_cache;
        begin
            reset = 1;
            @(negedge clk);
            reset = 0;
        end
    endtask

    task run_directed;
        begin
            // Cold nonzero-offset miss, then hold a second request through
            // backpressure. The second block must coexist with the first.
            offer(32'h00000004);
            offer(32'h00000017);
            while (pending)
                @(negedge clk);
            read_byte(32'h00000004);
            read_byte(32'h00000017);

            reset_cache();
            read_byte(32'h00000004);

            // Reset before lookup finishes, during a memory wait, and while
            // memory-ready is high. The post-reset read must miss each time.
            offer(32'h00000404);
            reset_cache();
            repeat (10) @(negedge clk);
            read_byte(32'h00000404);

            offer(32'h00000804);
            repeat (3) @(negedge clk);
            if (dut.mem_req !== 1'b1 || dut.mem_ready !== 1'b0)
                $fatal(1, "Failed to reach an in-flight memory wait before reset");
            reset_cache();
            repeat (10) @(negedge clk);
            read_byte(32'h00000804);

            offer(32'h00000c04);
            while (!dut.mem_ready)
                @(negedge clk);
            reset_cache();
            repeat (10) @(negedge clk);
            read_byte(32'h00000c04);

            // Full-width addresses still identify distinct cache tags.
            // The simulated backing array aliases addresses above 64 KiB.
            read_byte(32'hffffffff);
            read_byte(32'h0000ffff);
            read_byte(32'h0000ffff);
        end
    endtask

    initial begin
        if ($value$plusargs("vcd=%s", vcd)) begin
            $dumpfile(vcd);
            $dumpvars(0, dut);
        end
        $display("WORKLOAD %0s", WORKLOAD);
        $display("READ,number,address,actual,expected,hit,cycles");
        @(negedge clk);
        reset = 0;
        case (WORKLOAD)
            "system": run_directed();
            "sequential": for (i = 0; i < 32; i = i + 1)
                read_byte(i);
            "repeated": for (i = 0; i < 16; i = i + 1)
                read_byte(32'h00000004);
            "conflict": for (i = 0; i < 16; i = i + 1)
                read_byte(i % 2 ? 32'h00000400 : 32'h00000000);
            "random": begin
                $display("XORSHIFT32 seed=%08h", RANDOM_SEED);
                for (i = 0; i < 256; i = i + 1) begin
                    random_state = random_state ^ (random_state << 13);
                    random_state = random_state ^ (random_state >> 17);
                    random_state = random_state ^ (random_state << 5);
                    // Four tags compete across all 64 lines, with mixed offsets.
                    random_address = {20'b0, random_state[11:0]};
                    read_byte(random_address);
                end
            end
            default: $fatal(1, "Unknown workload %0s", WORKLOAD);
        endcase
        repeat (3) @(negedge clk);
        if (pending || completed == 0 || accepted != completed + canceled ||
            completed != hits + misses)
            $fatal(1, "Inconsistent accounting: accepted=%0d completed=%0d canceled=%0d hits=%0d misses=%0d",
                   accepted, completed, canceled, hits, misses);
        case (WORKLOAD)
            "system": if (completed != 11 || canceled != 3 || hits != 3)
                $fatal(1, "Unexpected directed system coverage");
            "sequential": if (completed != 32 || misses != 2)
                $fatal(1, "Unexpected sequential coverage");
            "repeated": if (completed != 16 || misses != 1)
                $fatal(1, "Unexpected repeated coverage");
            "conflict": if (completed != 16 || hits != 0)
                $fatal(1, "Unexpected conflict coverage");
            "random": if (completed != 256 || hits == 0 || misses == 0)
                $fatal(1, "Unexpected random coverage");
        endcase
        $display("METRICS,%0s,%0d,%0d,%0d,%0d,%0d,%0d",
                 WORKLOAD, completed, hits, misses, hit_cycles, miss_cycles, canceled);
        $display("PASS %0s", WORKLOAD);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Global simulation timeout for %0s", WORKLOAD);
    end
endmodule
