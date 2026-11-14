`timescale 1ns/1ps
module tb_repeated_access;
    cache_system_fixture #(.WORKLOAD("repeated")) suite();
endmodule
