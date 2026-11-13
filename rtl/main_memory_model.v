`timescale 1ns/1ps

// ============================================================================
// Module: main_memory_model
// Owner:  Member 04 - Cache Controller FSM and Main-Memory Model
//
// Function:
//   Simulation-only main memory. Returns one aligned 16-byte block per request
//   after a fixed, documented latency. Ports follow docs/interface_contract.md.
//
// Storage:
//   A byte array of MEM_BYTES entries (default 64 KB). A request address is
//   reduced modulo MEM_BYTES, so higher addresses alias onto the array.
//
// Deterministic contents (default, when INIT_FILE is empty):
//   mem[a] = a[7:0] ^ a[15:8] ^ 8'hA5      for a in 0 .. MEM_BYTES-1
//   The 16 bytes of any block are all different (they differ in a[3:0]) and
//   blocks that share a cache index but differ in tag (e.g. 0x000 and 0x400)
//   return different data, so byte-order and conflict mistakes are visible.
//   If INIT_FILE is set, the array is loaded with $readmemh instead.
//
// Handshake and latency (LATENCY >= 1, default 4):
//   - A request is accepted on a rising edge where mem_req = 1 while the model
//     is idle (not busy and not currently presenting mem_ready).
//   - mem_ready is a one-cycle pulse that is high exactly LATENCY cycles after
//     the acceptance edge. mem_block is valid in that cycle.
//   - Byte lane n of mem_block (mem_block[8*n +: 8]) holds address mem_addr+n.
//   - mem_ready is never asserted without an accepted request.
//   - Synchronous active-high reset cancels any request in flight.
// ============================================================================

module main_memory_model #(
    parameter integer LATENCY   = 4,
    parameter integer MEM_BYTES = 65536,
    parameter         INIT_FILE = ""
) (
    input  wire         clk,
    input  wire         reset,
    input  wire         mem_req,
    input  wire [31:0]  mem_addr,
    output reg          mem_ready,
    output reg  [127:0] mem_block
);

    localparam integer ADDR_BITS = $clog2(MEM_BYTES);

    reg [7:0]  mem [0:MEM_BYTES-1];

    reg        busy;
    reg [31:0] latched_addr;
    integer    countdown;
    integer    i;
    integer    n;

    // Deterministic pattern, also used by testbenches to compute expectations.
    function [7:0] pattern_byte;
        input [31:0] addr;
        begin
            pattern_byte = addr[7:0] ^ addr[15:8] ^ 8'hA5;
        end
    endfunction

    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end else begin
            for (i = 0; i < MEM_BYTES; i = i + 1)
                mem[i] = pattern_byte(i);
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            busy         <= 1'b0;
            countdown    <= 0;
            latched_addr <= 32'b0;
            mem_ready    <= 1'b0;
            mem_block    <= 128'b0;
        end else begin
            mem_ready <= 1'b0;

            if (busy) begin
                if (countdown == 0) begin
                    for (n = 0; n < 16; n = n + 1)
                        mem_block[8*n +: 8] <= mem[(latched_addr + n) & (MEM_BYTES - 1)];
                    mem_ready <= 1'b1;
                    busy      <= 1'b0;
                end else begin
                    countdown <= countdown - 1;
                end
            end else if (mem_req && !mem_ready) begin
                // Accept a new request. The requester holds mem_req high
                // through the mem_ready cycle, so !mem_ready prevents the
                // same request from being accepted twice.
                busy         <= 1'b1;
                latched_addr <= {mem_addr[31:4], 4'b0000};
                countdown    <= LATENCY - 1;
            end
        end
    end

    // Parameter sanity checks (simulation only).
    initial begin
        if (LATENCY < 1) begin
            $display("ERROR: main_memory_model LATENCY must be >= 1 (got %0d)", LATENCY);
            $finish;
        end
        if ((MEM_BYTES & (MEM_BYTES - 1)) != 0 || MEM_BYTES < 16) begin
            $display("ERROR: main_memory_model MEM_BYTES must be a power of two >= 16");
            $finish;
        end
    end

endmodule
