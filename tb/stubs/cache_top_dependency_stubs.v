`timescale 1ns/1ps

// Compile-only placeholders for cache_top dependencies that belong to
// Members 03 and 04. These modules deliberately provide no cache behavior.
// Include this file only for the top-level interface/elaboration check, and
// replace each stub with the owning member's RTL during functional simulation.

module tag_comparator (
    input  wire [21:0] requested_tag,
    input  wire [21:0] stored_tag,
    output wire        tags_match
);
    assign tags_match = 1'b0;
endmodule

module cache_lookup (
    input  wire [21:0] requested_tag,
    input  wire [21:0] stored_tag,
    input  wire        stored_valid,
    output wire        hit
);
    assign hit = 1'b0;
endmodule

module data_selector (
    input  wire [127:0] block_data,
    input  wire [3:0]   byte_offset,
    output wire [7:0]   selected_byte
);
    assign selected_byte = 8'b0;
endmodule

module cache_controller (
    input  wire        clk,
    input  wire        reset,
    input  wire        req_valid,
    input  wire [21:0] req_tag,
    input  wire [5:0]  req_index,
    input  wire [3:0]  req_offset,
    output wire        req_ready,
    output wire [21:0] active_tag,
    output wire [5:0]  active_index,
    output wire [3:0]  active_offset,
    input  wire        lookup_hit,
    input  wire [7:0]  cache_byte_data,
    input  wire [7:0]  refill_byte_data,
    input  wire        mem_ready,
    output wire        mem_req,
    output wire        refill_write_en,
    output wire        resp_valid,
    output wire [7:0]  resp_data,
    output wire        resp_hit
);
    assign req_ready       = 1'b0;
    assign active_tag      = 22'b0;
    assign active_index    = 6'b0;
    assign active_offset   = 4'b0;
    assign mem_req         = 1'b0;
    assign refill_write_en = 1'b0;
    assign resp_valid      = 1'b0;
    assign resp_data       = 8'b0;
    assign resp_hit        = 1'b0;
endmodule

module main_memory_model (
    input  wire         clk,
    input  wire         reset,
    input  wire         mem_req,
    input  wire [31:0]  mem_addr,
    output wire         mem_ready,
    output wire [127:0] mem_block
);
    assign mem_ready = 1'b0;
    assign mem_block = 128'b0;
endmodule
