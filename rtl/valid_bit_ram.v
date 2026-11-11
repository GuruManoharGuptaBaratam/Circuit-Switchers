`timescale 1ns/1ps

// Valid-bit storage for the 1 KB direct-mapped cache.
//
// 64 bits, one per cache line. Read is combinational. The selected bit is
// updated synchronously when write_en is high. Active-high synchronous reset
// clears every bit and takes priority over write_en.
module valid_bit_ram (
    input  wire       clk,
    input  wire       reset,
    input  wire [5:0] read_index,
    output wire       read_valid,
    input  wire       write_en,
    input  wire [5:0] write_index,
    input  wire       write_valid
);

    reg [63:0] valid_bits;

    assign read_valid = valid_bits[read_index];

    always @(posedge clk) begin
        if (reset)
            valid_bits <= 64'b0;
        else if (write_en)
            valid_bits[write_index] <= write_valid;
    end

endmodule
