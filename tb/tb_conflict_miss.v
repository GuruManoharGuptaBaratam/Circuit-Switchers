`timescale 1ns/1ps
module tb_conflict_miss;
    cache_system_fixture #(.WORKLOAD("conflict")) suite();
endmodule
