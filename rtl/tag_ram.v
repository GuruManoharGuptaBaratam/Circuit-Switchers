`timescale 1ns/1ps

// Tag storage for the 1 KB direct-mapped cache.
//
// 64 lines x 22 bits. Read is combinational. The selected tag is written
// synchronously on the rising edge of clk when write_en is high.
// Contents are not reset: an invalid line is ignored by the lookup path.
module tag_ram (
    input  wire        clk,
    input  wire [5:0]  read_index,
    output wire [21:0] read_tag,
    input  wire        write_en,
    input  wire [5:0]  write_index,
    input  wire [21:0] write_tag
);

    reg [21:0] mem [0:63];

    assign read_tag = mem[read_index];

    always @(posedge clk) begin
        if (write_en)
            mem[write_index] <= write_tag;
    end

endmodule
