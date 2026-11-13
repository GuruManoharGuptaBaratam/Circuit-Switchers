`timescale 1ns/1ps

// ============================================================================
// Module: cache_lookup
// Owner:  Member 03 - Cache Lookup, Tag Check and Data Selection
//
// Function:
//   Pure combinational logic that decides whether a cache access is a HIT
//   or a MISS. It instantiates the tag_comparator to verify tag equality and
//   combines the comparison result with the line's valid bit.
//
// Hit Condition:
//   hit = stored_valid & tags_match
//
//   - A hit occurs IF AND ONLY IF:
//       1. The selected line contains valid data (stored_valid == 1'b1), AND
//       2. The requested tag matches the stored tag (tags_match == 1'b1).
//   - If stored_valid == 1'b0, hit is 1'b0 even if tag bits match (prevents
//     false hits on uninitialized/empty cache lines).
//   - If requested_tag != stored_tag, hit is 1'b0 (indicates conflict/cold miss).
//
// Ports:
//   requested_tag [21:0] : 22-bit tag from active request
//   stored_tag    [21:0] : 22-bit tag read from tag RAM for selected line
//   stored_valid         : 1-bit valid flag read from valid_bit_ram for selected line
//   hit                  : 1'b1 on cache hit, 1'b0 on cache miss
// ============================================================================

module cache_lookup (
    input  wire [21:0] requested_tag,
    input  wire [21:0] stored_tag,
    input  wire        stored_valid,
    output wire        hit
);

    wire tags_match;

    // Instantiate modular tag comparator
    tag_comparator u_tag_comparator (
        .requested_tag(requested_tag),
        .stored_tag(stored_tag),
        .tags_match(tags_match)
    );

    // Combine valid-bit check with tag comparison
    assign hit = stored_valid & tags_match;

endmodule
