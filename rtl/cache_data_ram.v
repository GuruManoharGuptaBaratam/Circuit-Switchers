`timescale 1ns/1ps

// Data storage for the 1 KB direct-mapped cache.
//
// 64 lines x 128 bits. Read is combinational. A complete block is written
// synchronously on the rising edge of clk when write_en is high.
// Contents are not reset: an invalid line is ignored by the lookup path.
module cache_data_ram (
    input  wire         clk,
    input  wire [5:0]   read_index,
    output wire [127:0] read_block,
    input  wire         write_en,
    input  wire [5:0]   write_index,
    input  wire [127:0] write_block
);

    reg [127:0] mem [0:63];

    assign read_block = mem[read_index];

    always @(posedge clk) begin
        if (write_en)
            mem[write_index] <= write_block;
    end

endmodule
