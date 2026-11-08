// Address decoder for the 1 KB direct-mapped cache.
//
// Address layout:
//   address[31:10] -> 22-bit tag
//   address[9:4]   -> 6-bit cache-line index
//   address[3:0]   -> 4-bit byte offset within a 16-byte block
module address_decoder (
    input  wire [31:0] address,
    output wire [21:0] tag,
    output wire [5:0]  index,
    output wire [3:0]  offset
);

    assign tag    = address[31:10];
    assign index  = address[9:4];
    assign offset = address[3:0];

endmodule
