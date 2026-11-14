`timescale 1ns/1ps
module tb_sequential_access;
    cache_system_fixture #(.WORKLOAD("sequential")) suite();
endmodule
