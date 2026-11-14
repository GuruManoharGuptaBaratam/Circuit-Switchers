# Cache-core synthesis

From the repository root, run `bash scripts/run_synthesis.sh` with Yosys
and Python 3 on PATH. The flow derives a cache-core top from
`rtl/cache_top.v`, exposing `mem_req`, `mem_addr`, `mem_ready` and
`mem_block`. It preserves the cache connections and excludes the 64 KiB
simulation memory. The generated Verilog and intermediate statistics live
in the ignored build directory.

[Yosys log](yosys_final.txt) records version 0.71+34, source inputs,
flattened generic synthesis, `check -assert`, and final statistics.
[Machine-readable statistics](stat.json) give 32,190 cells including nine
scope metadata cells. The 9,715 flip-flop cells include mapped cache
storage and controller state/data. There are 3,499 multiplexer cells.
Generic synthesis was run without a device, timing constraints, physical
implementation or static timing analysis.
