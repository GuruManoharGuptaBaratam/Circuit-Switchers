`timescale 1ns/1ps

module tb_address_decoder;

    reg  [31:0] address;
    wire [21:0] tag;
    wire [5:0]  index;
    wire [3:0]  offset;

    integer tests_run;
    integer tests_passed;
    integer tests_failed;

    address_decoder dut (
        .address(address),
        .tag(tag),
        .index(index),
        .offset(offset)
    );

    task automatic run_test;
        input [255:0] test_name;
        input [31:0]  test_address;
        input [21:0]  expected_tag;
        input [5:0]   expected_index;
        input [3:0]   expected_offset;
        begin
            tests_run = tests_run + 1;
            address = test_address;
            #1;

            if ((tag === expected_tag) &&
                (index === expected_index) &&
                (offset === expected_offset)) begin
                tests_passed = tests_passed + 1;
                $display("PASS: %0s | address=0x%08h tag=0x%06h index=%0d offset=%0d",
                         test_name, address, tag, index, offset);
            end else begin
                tests_failed = tests_failed + 1;
                $display("FAIL: %0s | address=0x%08h", test_name, address);
                $display("      expected tag=0x%06h index=%0d offset=%0d",
                         expected_tag, expected_index, expected_offset);
                $display("      actual   tag=0x%06h index=%0d offset=%0d",
                         tag, index, offset);
            end
        end
    endtask

    initial begin
        tests_run = 0;
        tests_passed = 0;
        tests_failed = 0;
        address = 32'h00000000;

        $dumpfile("results/waveforms/address_decoder.vcd");
        $dumpvars(0, tb_address_decoder);

        $display("Address decoder unit test");
        $display("-------------------------");

        run_test("zero address",
                 32'h00000000, 22'h000000, 6'h00, 4'h0);
        run_test("byte offset 4",
                 32'h00000004, 22'h000000, 6'h00, 4'h4);
        run_test("last byte of first block",
                 32'h0000000F, 22'h000000, 6'h00, 4'hF);
        run_test("next memory block",
                 32'h00000010, 22'h000000, 6'h01, 4'h0);
        run_test("same index, different tag",
                 32'h00000400, 22'h000001, 6'h00, 4'h0);
        run_test("maximum address",
                 32'hFFFFFFFF, 22'h3FFFFF, 6'h3F, 4'hF);

        $display("-------------------------");
        $display("SUMMARY: %0d run, %0d passed, %0d failed",
                 tests_run, tests_passed, tests_failed);

        if (tests_failed == 0) begin
            $display("ALL ADDRESS DECODER TESTS PASSED");
            $finish;
        end else begin
            $fatal(1, "ADDRESS DECODER TESTS FAILED");
        end
    end

endmodule
