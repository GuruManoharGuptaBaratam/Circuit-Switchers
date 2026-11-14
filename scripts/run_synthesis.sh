#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
command -v yosys >/dev/null || { echo "Yosys is required" >&2; exit 127; }
mkdir -p build results/synthesis

# Keep the cache hierarchy and interconnect verbatim. Expose the three
# memory responses/requests and the block-address bus as external ports.
python3 - <<'PY'
from pathlib import Path
import re

text = Path("rtl/cache_top.v").read_text()
text = text.replace("module cache_top (", "module cache_core (", 1)
for name, width, direction in [
    ("mem_req", "", "output"), ("mem_addr", "[31:0]", "output"),
    ("mem_ready", "", "input"), ("mem_block", "[127:0]", "input"),
]:
    text, count = re.subn(rf"^    wire +(?:\S+ +)?{name};\n", "", text, flags=re.M)
    if count != 1:
        raise SystemExit(f"Expected one internal declaration for {name}")
    port = f"    {direction} wire {width} {name},\n"
    text = text.replace("    // Processor/requester interface.", port + "    // Processor/requester interface.", 1)
text, count = re.subn(r"\n    main_memory_model u_main_memory_model \([^;]+;\n", "\n", text)
if count != 1:
    raise SystemExit("Expected one simulation memory instance")
Path("build/cache_core.v").write_text(text)
PY

rtl=()
for source in rtl/*.v; do
    case "$source" in rtl/cache_top.v|rtl/main_memory_model.v) ;; *) rtl+=("$source");; esac
done
commands="read_verilog ${rtl[*]} build/cache_core.v; synth -top cache_core -flatten; check -assert; tee -o build/synthesis_stat.json stat -json"
{
    yosys -V
    echo "Scope: cache_core with external memory ports, flattened generic gates"
    echo "Command: yosys -p '$commands'"
    yosys -p "$commands"
} > build/yosys.log 2>&1 || { tail -30 build/yosys.log >&2; exit 1; }
cp build/yosys.log results/synthesis/yosys_final.txt
cp build/synthesis_stat.json results/synthesis/stat.json
echo "PASS generic synthesis (results/synthesis/stat.json)"
