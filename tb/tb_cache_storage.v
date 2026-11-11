`timescale 1ns/1ps

// Self-checking tests for Member 02 cache storage:
// reset, line readback, replacement, and isolation between indexes.
module tb_cache_storage;

    reg clk;
    reg reset;

    reg  [5:0]   data_read_index;
    wire [127:0] data_read_block;
    reg          data_write_en;
    reg  [5:0]   data_write_index;
    reg  [127:0] data_write_block;

    reg  [5:0]  tag_read_index;
    wire [21:0] tag_read_tag;
    reg         tag_write_en;
    reg  [5:0]  tag_write_index;
    reg  [21:0] tag_write_tag;

    reg        valid_write_en;
    reg  [5:0] valid_read_index;
    wire       valid_read_valid;
    reg  [5:0] valid_write_index;
    reg        valid_write_valid;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;
    integer i;
    integer mismatches;

    localparam [127:0] DATA_LINE3_A = 128'h00112233445566778899AABBCCDDEEFF;
    localparam [127:0] DATA_LINE3_B = 128'hFFEEDDCCBBAA99887766554433221100;
    localparam [127:0] DATA_LINE4   = 128'h0123456789ABCDEF0123456789ABCDEF;
    localparam [127:0] DATA_LINE0   = 128'hA5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5;
    localparam [127:0] DATA_LINE63  = 128'h5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A;
    localparam [127:0] DATA_UNUSED  = 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    localparam [21:0] TAG_LINE3_A = 22'h155555;
    localparam [21:0] TAG_LINE3_B = 22'h2AAAAA;
    localparam [21:0] TAG_LINE4   = 22'h3FFFFF;
    localparam [21:0] TAG_UNUSED  = 22'h000001;

    cache_data_ram dut_data (
        .clk(clk),
        .read_index(data_read_index),
        .read_block(data_read_block),
        .write_en(data_write_en),
        .write_index(data_write_index),
        .write_block(data_write_block)
    );

    tag_ram dut_tag (
        .clk(clk),
        .read_index(tag_read_index),
        .read_tag(tag_read_tag),
        .write_en(tag_write_en),
        .write_index(tag_write_index),
        .write_tag(tag_write_tag)
    );

    valid_bit_ram dut_valid (
        .clk(clk),
        .reset(reset),
        .read_index(valid_read_index),
        .read_valid(valid_read_valid),
        .write_en(valid_write_en),
        .write_index(valid_write_index),
        .write_valid(valid_write_valid)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic pass_or_fail;
        input [255:0] test_name;
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

    task automatic write_data;
        input [5:0]   index;
        input [127:0] block;
        begin
            data_write_en = 1'b1;
            data_write_index = index;
            data_write_block = block;
            @(posedge clk);
            #1;
            data_write_en = 1'b0;
        end
    endtask

    task automatic write_tag;
        input [5:0]  index;
        input [21:0] tag_value;
        begin
            tag_write_en = 1'b1;
            tag_write_index = index;
            tag_write_tag = tag_value;
            @(posedge clk);
            #1;
            tag_write_en = 1'b0;
        end
    endtask

    task automatic write_valid_bit;
        input [5:0] index;
        input       valid_value;
        begin
            valid_write_en = 1'b1;
            valid_write_index = index;
            valid_write_valid = valid_value;
            @(posedge clk);
            #1;
            valid_write_en = 1'b0;
        end
    endtask

    task automatic expect_data;
        input [255:0] test_name;
        input [5:0]   index;
        input [127:0] expected;
        begin
            data_read_index = index;
            #1;
            if (data_read_block === expected) begin
                pass_or_fail(test_name, 1'b1);
                $display("      line %0d data=0x%032h", index, data_read_block);
            end else begin
                pass_or_fail(test_name, 1'b0);
                $display("      line %0d expected 0x%032h", index, expected);
                $display("      line %0d actual   0x%032h", index, data_read_block);
            end
        end
    endtask

    task automatic expect_tag;
        input [255:0] test_name;
        input [5:0]   index;
        input [21:0]  expected;
        begin
            tag_read_index = index;
            #1;
            if (tag_read_tag === expected) begin
                pass_or_fail(test_name, 1'b1);
                $display("      line %0d tag=0x%06h", index, tag_read_tag);
            end else begin
                pass_or_fail(test_name, 1'b0);
                $display("      line %0d expected tag=0x%06h", index, expected);
                $display("      line %0d actual   tag=0x%06h", index, tag_read_tag);
            end
        end
    endtask

    task automatic expect_valid;
        input [255:0] test_name;
        input [5:0]   index;
        input         expected;
        begin
            valid_read_index = index;
            #1;
            if (valid_read_valid === expected) begin
                pass_or_fail(test_name, 1'b1);
                $display("      line %0d valid=%b", index, valid_read_valid);
            end else begin
                pass_or_fail(test_name, 1'b0);
                $display("      line %0d expected valid=%b actual=%b",
                         index, expected, valid_read_valid);
            end
        end
    endtask

    task automatic apply_reset;
        begin
            reset = 1'b1;
            data_write_en = 1'b0;
            tag_write_en = 1'b0;
            valid_write_en = 1'b0;
            @(posedge clk);
            #1;
            reset = 1'b0;
        end
    endtask

    initial begin
        tests_run = 0;
        tests_passed = 0;
        tests_failed = 0;
        reset = 1'b0;
        data_read_index = 6'd0;
        data_write_en = 1'b0;
        data_write_index = 6'd0;
        data_write_block = 128'b0;
        tag_read_index = 6'd0;
        tag_write_en = 1'b0;
        tag_write_index = 6'd0;
        tag_write_tag = 22'b0;
        valid_read_index = 6'd0;
        valid_write_en = 1'b0;
        valid_write_index = 6'd0;
        valid_write_valid = 1'b0;

        $dumpfile("results/waveforms/cache_storage.vcd");
        $dumpvars(0, tb_cache_storage);

        $display("Cache storage unit test");
        $display("-----------------------");

        apply_reset();

        mismatches = 0;
        for (i = 0; i < 64; i = i + 1) begin
            valid_read_index = i[5:0];
            #1;
            if (valid_read_valid !== 1'b0) begin
                mismatches = mismatches + 1;
                $display("      line %0d valid=%b after reset", i, valid_read_valid);
            end
        end
        pass_or_fail("reset clears all valid bits", mismatches == 0);

        reset = 1'b1;
        valid_write_en = 1'b1;
        valid_write_index = 6'd3;
        valid_write_valid = 1'b1;
        @(posedge clk);
        #1;
        reset = 1'b0;
        valid_write_en = 1'b0;
        expect_valid("reset overrides valid write", 6'd3, 1'b0);

        write_data(6'd3, DATA_LINE3_A);
        expect_data("line 3 data reads back", 6'd3, DATA_LINE3_A);

        write_data(6'd3, DATA_LINE3_B);
        expect_data("line 3 data is replaced", 6'd3, DATA_LINE3_B);

        write_data(6'd4, DATA_LINE4);
        expect_data("line 4 data keeps line 3", 6'd3, DATA_LINE3_B);
        expect_data("line 4 data reads back", 6'd4, DATA_LINE4);

        write_data(6'd0, DATA_LINE0);
        write_data(6'd63, DATA_LINE63);
        expect_data("line 0 data reads back", 6'd0, DATA_LINE0);
        expect_data("line 63 data reads back", 6'd63, DATA_LINE63);
        expect_data("edge lines keep line 3 data", 6'd3, DATA_LINE3_B);

        data_write_en = 1'b0;
        data_write_index = 6'd3;
        data_write_block = DATA_UNUSED;
        @(posedge clk);
        #1;
        expect_data("disabled data write keeps line", 6'd3, DATA_LINE3_B);

        write_tag(6'd3, TAG_LINE3_A);
        expect_tag("line 3 tag reads back", 6'd3, TAG_LINE3_A);

        write_tag(6'd3, TAG_LINE3_B);
        expect_tag("line 3 tag is replaced", 6'd3, TAG_LINE3_B);

        write_tag(6'd4, TAG_LINE4);
        expect_tag("line 4 tag keeps line 3", 6'd3, TAG_LINE3_B);
        expect_tag("line 4 tag reads back", 6'd4, TAG_LINE4);

        tag_write_en = 1'b0;
        tag_write_index = 6'd3;
        tag_write_tag = TAG_UNUSED;
        @(posedge clk);
        #1;
        expect_tag("disabled tag write keeps line", 6'd3, TAG_LINE3_B);

        write_valid_bit(6'd3, 1'b1);
        expect_valid("line 3 valid bit sets", 6'd3, 1'b1);
        expect_valid("line 4 valid bit stays clear", 6'd4, 1'b0);

        mismatches = 0;
        for (i = 0; i < 64; i = i + 1) begin
            if (i != 3) begin
                valid_read_index = i[5:0];
                #1;
                if (valid_read_valid !== 1'b0) begin
                    mismatches = mismatches + 1;
                    $display("      line %0d valid=%b", i, valid_read_valid);
                end
            end
        end
        pass_or_fail("other valid bits stay clear", mismatches == 0);

        valid_write_en = 1'b0;
        valid_write_index = 6'd3;
        valid_write_valid = 1'b0;
        @(posedge clk);
        #1;
        expect_valid("disabled valid write keeps line", 6'd3, 1'b1);

        write_valid_bit(6'd3, 1'b0);
        expect_valid("valid bit can be cleared", 6'd3, 1'b0);
        expect_valid("clear keeps line 4 invalid", 6'd4, 1'b0);

        write_valid_bit(6'd3, 1'b1);
        write_valid_bit(6'd10, 1'b1);
        apply_reset();
        mismatches = 0;
        for (i = 0; i < 64; i = i + 1) begin
            valid_read_index = i[5:0];
            #1;
            if (valid_read_valid !== 1'b0) begin
                mismatches = mismatches + 1;
                $display("      line %0d valid=%b after second reset", i, valid_read_valid);
            end
        end
        pass_or_fail("reset clears valid bits again", mismatches == 0);

        $display("-----------------------");
        $display("SUMMARY: %0d run, %0d passed, %0d failed",
                 tests_run, tests_passed, tests_failed);

        if (tests_failed == 0) begin
            $display("ALL CACHE STORAGE TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "CACHE STORAGE TESTS FAILED");
        end
    end

endmodule
