`timescale 1ns/1ps
module tb_random_access;
    cache_system_fixture #(.WORKLOAD("random")) suite();
endmodule
