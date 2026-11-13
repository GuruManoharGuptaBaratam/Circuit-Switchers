`timescale 1ns/1ps

// ============================================================================
// Module: data_selector
// Owner:  Member 03 - Cache Lookup, Tag Check and Data Selection
//
// Function:
//   Pure combinational 16-to-1 byte multiplexer that extracts a single 8-bit
//   byte from a 128-bit (16-byte) cache line or memory refill block using a
//   4-bit offset.
//
// Byte Ordering Convention:
//   Follows the frozen Circuit Switchers Shared Interface Contract:
//     - Byte lane n corresponds to block_data[(8*n) +: 8]
//     - Offset 4'h0 selects block_data[7:0]     (lowest byte)
//     - Offset 4'h1 selects block_data[15:8]
//     - Offset 4'h2 selects block_data[23:16]
//     - Offset 4'h3 selects block_data[31:24]
//     - Offset 4'h4 selects block_data[39:32]
//     - Offset 4'h5 selects block_data[47:40]
//     - Offset 4'h6 selects block_data[55:48]
//     - Offset 4'h7 selects block_data[63:56]
//     - Offset 4'h8 selects block_data[71:64]
//     - Offset 4'h9 selects block_data[79:72]
//     - Offset 4'hA selects block_data[87:80]
//     - Offset 4'hB selects block_data[95:88]
//     - Offset 4'hC selects block_data[103:96]
//     - Offset 4'hD selects block_data[111:104]
//     - Offset 4'hE selects block_data[119:112]
//     - Offset 4'hF selects block_data[127:120]   (highest byte)
//
// Ports:
//   block_data    [127:0] : 128-bit (16-byte) input block
//   byte_offset   [3:0]   : 4-bit byte offset (0 to 15)
//   selected_byte [7:0]   : 8-bit selected byte
// ============================================================================

module data_selector (
    input  wire [127:0] block_data,
    input  wire [3:0]   byte_offset,
    output reg  [7:0]   selected_byte
);

    always @(*) begin
        case (byte_offset)
            4'h0: selected_byte = block_data[7:0];
            4'h1: selected_byte = block_data[15:8];
            4'h2: selected_byte = block_data[23:16];
            4'h3: selected_byte = block_data[31:24];
            4'h4: selected_byte = block_data[39:32];
            4'h5: selected_byte = block_data[47:40];
            4'h6: selected_byte = block_data[55:48];
            4'h7: selected_byte = block_data[63:56];
            4'h8: selected_byte = block_data[71:64];
            4'h9: selected_byte = block_data[79:72];
            4'hA: selected_byte = block_data[87:80];
            4'hB: selected_byte = block_data[95:88];
            4'hC: selected_byte = block_data[103:96];
            4'hD: selected_byte = block_data[111:104];
            4'hE: selected_byte = block_data[119:112];
            4'hF: selected_byte = block_data[127:120];
            default: selected_byte = 8'h00;
        endcase
    end

endmodule

