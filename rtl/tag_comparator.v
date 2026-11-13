`timescale 1ns/1ps

// ============================================================================
// Module: tag_comparator
// Owner:  Member 03 - Cache Lookup, Tag Check and Data Selection
//
// Function:
//   Pure combinational comparator that checks whether the requested 22-bit tag
//   matches the 22-bit tag stored in the selected cache line.
//
// Ports:
//   requested_tag [21:0] : 22-bit tag from the incoming/active request address
//   stored_tag    [21:0] : 22-bit tag currently stored in the indexed cache line
//   tags_match           : 1'b1 if requested_tag == stored_tag, else 1'b0
// ============================================================================

module tag_comparator (
    input  wire [21:0] requested_tag,
    input  wire [21:0] stored_tag,
    output wire        tags_match
);

    assign tags_match = (requested_tag == stored_tag);

endmodule

