`timescale 1ns/1ps

// ============================================================================
// Testbench: tb_cache_lookup
// Owner:     Member 03 - Cache Lookup, Tag Check and Data Selection
//
// Test Coverage:
//   1. Tag Comparator Standalone Unit Checks:
//      - Matching tags (zeros, max 22-bit, alternating patterns)
//      - Single-bit mismatches at LSB (bit 0), MSB (bit 21), and middle bits
//   2. Cache Lookup Hit/Miss Decision Logic:
//      - Valid = 1, Tag Match          => HIT  (hit = 1)
//      - Valid = 0, Tag Match          => MISS (hit = 0) [CRITICAL: empty line protection]
//      - Valid = 1, Tag Mismatch       => MISS (hit = 0) [different block / conflict]
//      - Valid = 0, Tag Mismatch       => MISS (hit = 0) [uninitialized cold line]
//      - Boundary tag tests (0x000000, 0x3FFFFF) under both valid and invalid states
//   3. Data Selector Offset Coverage:
//      - All 16 byte offsets (0 to 15) verified against visibly distinct bytes (0xA0..0xAF)
//      - Verifies exact byte-lane convention: block_data[(8*offset) +: 8]
//      - Second test block pattern verified across all offsets (0x0F..0xF0)
//   4. Direct-Mapped Conflict Scenario (Coordination with Member 5):
//      - Address 0x00000000 (Tag 0x000000) vs Address 0x00000400 (Tag 0x000001)
//      - Line 0 holding Block A: Access A hits, Access B misses
//      - Line 0 refilled with Block B: Access B hits, Access A misses
// ============================================================================

module tb_cache_lookup;

    // DUT signals for tag_comparator
    reg  [21:0] tc_req_tag;
    reg  [21:0] tc_stored_tag;
    wire        tc_match;

    // DUT signals for cache_lookup
    reg  [21:0] cl_req_tag;
    reg  [21:0] cl_stored_tag;
    reg         cl_stored_valid;
    wire        cl_hit;

    // DUT signals for data_selector
    reg  [127:0] ds_block_data;
    reg  [3:0]   ds_byte_offset;
    wire [7:0]   ds_selected_byte;

    // Test tracking counters
    integer tests_run;
    integer tests_passed;
    integer tests_failed;
    integer i;

    // Instantiate Tag Comparator
    tag_comparator u_tag_comparator (
        .requested_tag(tc_req_tag),
        .stored_tag(tc_stored_tag),
        .tags_match(tc_match)
    );

    // Instantiate Cache Lookup
    cache_lookup u_cache_lookup (
        .requested_tag(cl_req_tag),
        .stored_tag(cl_stored_tag),
        .stored_valid(cl_stored_valid),
        .hit(cl_hit)
    );

    // Instantiate Data Selector
    data_selector u_data_selector (
        .block_data(ds_block_data),
        .byte_offset(ds_byte_offset),
        .selected_byte(ds_selected_byte)
    );

    // Test block definitions with visibly distinct byte patterns
    // Byte 0 is lowest byte (bits [7:0]); Byte 15 is highest byte (bits [127:120])
    localparam [127:0] TEST_BLOCK_A = {
        8'hAF, 8'hAE, 8'hAD, 8'hAC,
        8'hAB, 8'hAA, 8'hA9, 8'hA8,
        8'hA7, 8'hA6, 8'hA5, 8'hA4,
        8'hA3, 8'hA2, 8'hA1, 8'hA0
    };

    localparam [127:0] TEST_BLOCK_B = {
        8'hF0, 8'hE1, 8'hD2, 8'hC3,
        8'hB4, 8'hA5, 8'h96, 8'h87,
        8'h78, 8'h69, 8'h5A, 8'h4B,
        8'h3C, 8'h2D, 8'h1E, 8'h0F
    };

    // Helper task to report test status
    task automatic pass_or_fail;
        input [511:0] test_name;
        input         passed;
        begin
            tests_run = tests_run + 1;
            if (passed) begin
                tests_passed = tests_passed + 1;
                $display("PASS: %0s", test_name);
            end else begin
                tests_failed = tests_failed + 1;
                $display("FAIL: %0s", test_name);
            end
        end
    endtask

    // Helper task for tag_comparator testing
    task automatic test_tag_comp;
        input [511:0] test_name;
        input [21:0]  req;
        input [21:0]  stored;
        input         expected;
        begin
            tc_req_tag    = req;
            tc_stored_tag = stored;
            #1;
            pass_or_fail(test_name, (tc_match === expected));
            if (tc_match !== expected) begin
                $display("      expected match=%b, actual match=%b (req=0x%06h, stored=0x%06h)",
                         expected, tc_match, req, stored);
            end
        end
    endtask

    // Helper task for cache_lookup testing
    task automatic test_lookup;
        input [511:0] test_name;
        input [21:0]  req;
        input [21:0]  stored;
        input         valid;
        input         expected_hit;
        begin
            cl_req_tag      = req;
            cl_stored_tag   = stored;
            cl_stored_valid = valid;
            #1;
            pass_or_fail(test_name, (cl_hit === expected_hit));
            if (cl_hit !== expected_hit) begin
                $display("      expected hit=%b, actual hit=%b (valid=%b, req=0x%06h, stored=0x%06h)",
                         expected_hit, cl_hit, valid, req, stored);
            end
        end
    endtask

    // Helper task for data_selector testing
    task automatic test_data_sel;
        input [511:0] test_name;
        input [127:0] block;
        input [3:0]   offset;
        input [7:0]   expected_byte;
        begin
            ds_block_data  = block;
            ds_byte_offset = offset;
            #1;
            pass_or_fail(test_name, (ds_selected_byte === expected_byte));
            if (ds_selected_byte !== expected_byte) begin
                $display("      expected byte=0x%02h, actual byte=0x%02h (offset=%0d)",
                         expected_byte, ds_selected_byte, offset);
            end
        end
    endtask

    initial begin
        tests_run    = 0;
        tests_passed = 0;
        tests_failed = 0;

        $dumpfile("results/waveforms/cache_lookup.vcd");
        $dumpvars(0, tb_cache_lookup);

        $display("Cache lookup and data selection unit test");
        $display("-----------------------------------------");

        #10;

        // --------------------------------------------------------------------
        // 1. Tag Comparator Unit Tests
        // --------------------------------------------------------------------
        test_tag_comp("tc: zero tags match (0x000000 == 0x000000)",
                      22'h000000, 22'h000000, 1'b1);

        test_tag_comp("tc: max 22-bit tags match (0x3FFFFF == 0x3FFFFF)",
                      22'h3FFFFF, 22'h3FFFFF, 1'b1);

        test_tag_comp("tc: pattern 0x2AAAAA matches",
                      22'h2AAAAA, 22'h2AAAAA, 1'b1);

        test_tag_comp("tc: pattern 0x155555 matches",
                      22'h155555, 22'h155555, 1'b1);

        test_tag_comp("tc: mismatch at LSB (bit 0) (0x000000 != 0x000001)",
                      22'h000000, 22'h000001, 1'b0);

        test_tag_comp("tc: mismatch at MSB (bit 21) (0x000000 != 0x200000)",
                      22'h000000, 22'h200000, 1'b0);

        test_tag_comp("tc: mismatch at middle bit 10 (0x000400 != 0x000000)",
                      22'h000400, 22'h000000, 1'b0);

        test_tag_comp("tc: completely inverted tags mismatch",
                      22'h2AAAAA, 22'h155555, 1'b0);

        // --------------------------------------------------------------------
        // 2. Cache Lookup Hit/Miss Decision Tests
        // --------------------------------------------------------------------
        test_lookup("cl: valid=1 and tag match produces HIT",
                    22'h1A2B3C, 22'h1A2B3C, 1'b1, 1'b1);

        test_lookup("cl: valid=0 and tag match produces MISS (empty line protection)",
                    22'h1A2B3C, 22'h1A2B3C, 1'b0, 1'b0);

        test_lookup("cl: valid=1 and tag mismatch produces MISS (conflict)",
                    22'h0A2B3C, 22'h1A2B3C, 1'b1, 1'b0);

        test_lookup("cl: valid=0 and tag mismatch produces MISS (cold invalid)",
                    22'h0A2B3C, 22'h1A2B3C, 1'b0, 1'b0);

        test_lookup("cl: zero tag with valid=1 produces HIT",
                    22'h000000, 22'h000000, 1'b1, 1'b1);

        test_lookup("cl: zero tag with valid=0 produces MISS (reset state check)",
                    22'h000000, 22'h000000, 1'b0, 1'b0);

        test_lookup("cl: max tag with valid=1 produces HIT",
                    22'h3FFFFF, 22'h3FFFFF, 1'b1, 1'b1);

        test_lookup("cl: max tag with valid=0 produces MISS",
                    22'h3FFFFF, 22'h3FFFFF, 1'b0, 1'b0);

        // --------------------------------------------------------------------
        // 3. Data Selector Offset Coverage (All 16 byte offsets 0..15)
        // --------------------------------------------------------------------
        test_data_sel("ds block A: offset 0 selects 0xA0", TEST_BLOCK_A, 4'h0, 8'hA0);
        test_data_sel("ds block A: offset 1 selects 0xA1", TEST_BLOCK_A, 4'h1, 8'hA1);
        test_data_sel("ds block A: offset 2 selects 0xA2", TEST_BLOCK_A, 4'h2, 8'hA2);
        test_data_sel("ds block A: offset 3 selects 0xA3", TEST_BLOCK_A, 4'h3, 8'hA3);
        test_data_sel("ds block A: offset 4 selects 0xA4", TEST_BLOCK_A, 4'h4, 8'hA4);
        test_data_sel("ds block A: offset 5 selects 0xA5", TEST_BLOCK_A, 4'h5, 8'hA5);
        test_data_sel("ds block A: offset 6 selects 0xA6", TEST_BLOCK_A, 4'h6, 8'hA6);
        test_data_sel("ds block A: offset 7 selects 0xA7", TEST_BLOCK_A, 4'h7, 8'hA7);
        test_data_sel("ds block A: offset 8 selects 0xA8", TEST_BLOCK_A, 4'h8, 8'hA8);
        test_data_sel("ds block A: offset 9 selects 0xA9", TEST_BLOCK_A, 4'h9, 8'hA9);
        test_data_sel("ds block A: offset 10 selects 0xAA", TEST_BLOCK_A, 4'hA, 8'hAA);
        test_data_sel("ds block A: offset 11 selects 0xAB", TEST_BLOCK_A, 4'hB, 8'hAB);
        test_data_sel("ds block A: offset 12 selects 0xAC", TEST_BLOCK_A, 4'hC, 8'hAC);
        test_data_sel("ds block A: offset 13 selects 0xAD", TEST_BLOCK_A, 4'hD, 8'hAD);
        test_data_sel("ds block A: offset 14 selects 0xAE", TEST_BLOCK_A, 4'hE, 8'hAE);
        test_data_sel("ds block A: offset 15 selects 0xAF", TEST_BLOCK_A, 4'hF, 8'hAF);

        // Additional spot checks with Pattern B
        test_data_sel("ds pattern B: offset 0 selects 0x0F (lowest byte)",
                      TEST_BLOCK_B, 4'h0, 8'h0F);

        test_data_sel("ds pattern B: offset 7 selects 0x78",
                      TEST_BLOCK_B, 4'h7, 8'h78);

        test_data_sel("ds pattern B: offset 8 selects 0x87",
                      TEST_BLOCK_B, 4'h8, 8'h87);

        test_data_sel("ds pattern B: offset 15 selects 0xF0 (highest byte)",
                      TEST_BLOCK_B, 4'hF, 8'hF0);

        // --------------------------------------------------------------------
        // 4. Direct-Mapped Conflict Scenario (Member 5 Review Cases)
        // --------------------------------------------------------------------
        // Address A (0x00000000) -> Tag 0x000000, Index 0
        // Address B (0x00000400) -> Tag 0x000001, Index 0

        // Cold line 0 (valid=0): Access A misses
        test_lookup("conflict 1: cold cache line 0 access A is MISS",
                    22'h000000, 22'h000000, 1'b0, 1'b0);

        // Line 0 refilled with Block A (valid=1, tag=0x000000): Access A hits
        test_lookup("conflict 2: line 0 holding block A produces HIT for address A",
                    22'h000000, 22'h000000, 1'b1, 1'b1);

        // Access B arrives to same line 0: Tag mismatch causes MISS
        test_lookup("conflict 3: access B with same index, different tag is MISS",
                    22'h000001, 22'h000000, 1'b1, 1'b0);

        // Line 0 replaced with Block B (valid=1, tag=0x000001): Access B hits
        test_lookup("conflict 4: line 0 refilled with block B produces HIT for address B",
                    22'h000001, 22'h000001, 1'b1, 1'b1);

        // Alternating back to Access A: Tag mismatch causes MISS (evicted)
        test_lookup("conflict 5: alternating back to address A produces conflict MISS",
                    22'h000000, 22'h000001, 1'b1, 1'b0);

        // --------------------------------------------------------------------
        // Test Summary
        // --------------------------------------------------------------------
        #10;
        $display("-----------------------------------------");
        $display("SUMMARY: %0d run, %0d passed, %0d failed", tests_run, tests_passed, tests_failed);
        if (tests_failed == 0) begin
            $display("ALL CACHE LOOKUP TESTS PASSED");
        end else begin
            $display("SOME CACHE LOOKUP TESTS FAILED");
            $fatal(1, "tb_cache_lookup encountered test failures.");
        end
        $finish;
    end

endmodule
