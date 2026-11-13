#!/usr/bin/env python3
"""Member 04 figures: controller FSM diagram and miss/hit waveform.

Usage (from repo root, after ./scripts/run_cache_controller_test.sh):
    python3 scripts/plot_controller_figures.py

Reads  results/waveforms/cache_controller_final.vcd
Writes submission/report/figures/controller_fsm.{pdf,png}
       submission/report/figures/controller_waveform.{pdf,png}
       results/waveforms/cache_controller_miss_hit.png
"""
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
VCD = os.path.join(ROOT, "results/waveforms/cache_controller_final.vcd")
FIG_DIR = os.path.join(ROOT, "submission/report/figures")
WAVE_PNG = os.path.join(ROOT, "results/waveforms/cache_controller_miss_hit.png")

STATE_NAMES = {0: "IDLE", 1: "LOOKUP", 2: "MEM_WAIT", 3: "RESPOND"}

# Signals to plot: (label, VCD scope path, signal name, kind)
SIGNALS = [
    ("clk", "tb_cache_controller", "clk", "bit"),
    ("req_valid", "tb_cache_controller", "req_valid", "bit"),
    ("req_ready", "tb_cache_controller", "req_ready", "bit"),
    ("state", "tb_cache_controller.dut.u_cache_controller", "state", "state"),
    ("mem_req", "tb_cache_controller.dut", "mem_req", "bit"),
    ("mem_addr", "tb_cache_controller.dut", "mem_addr", "hex"),
    ("mem_ready", "tb_cache_controller.dut", "mem_ready", "bit"),
    ("refill_write_en", "tb_cache_controller.dut", "refill_write_en", "bit"),
    ("resp_valid", "tb_cache_controller", "resp_valid", "bit"),
    ("resp_hit", "tb_cache_controller", "resp_hit", "bit"),
    ("resp_data", "tb_cache_controller", "resp_data", "hex"),
]


# --------------------------------------------------------------------------
# Minimal VCD reader
# --------------------------------------------------------------------------
def read_vcd(path, wanted):
    """Return {(scope, name): [(time, value_str), ...]} for wanted signals."""
    ids = {}
    scope = []
    changes = {key: [] for key in wanted}
    time = 0
    with open(path) as f:
        in_defs = True
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if in_defs:
                tok = line.split()
                if tok[0] == "$scope":
                    scope.append(tok[2])
                elif tok[0] == "$upscope":
                    scope.pop()
                elif tok[0] == "$var":
                    code, name = tok[3], tok[4]
                    key = (".".join(scope), name)
                    if key in changes:
                        ids.setdefault(code, []).append(key)
                elif tok[0] == "$enddefinitions":
                    in_defs = False
                continue
            if line[0] == "#":
                time = int(line[1:])
            elif line[0] in "01xXzZ":
                for key in ids.get(line[1:], []):
                    changes[key].append((time, line[0]))
            elif line[0] in "bB":
                val, code = line[1:].split()
                for key in ids.get(code, []):
                    changes[key].append((time, val))
    missing = [k for k, v in changes.items() if not v]
    if missing:
        sys.exit(f"Signals not found in VCD: {missing}")
    return changes


def value_at(series, t):
    v = series[0][1]
    for ts, val in series:
        if ts > t:
            break
        v = val
    return v


def to_int(v):
    try:
        return int(v, 2)
    except ValueError:
        return None


# --------------------------------------------------------------------------
# Waveform figure
# --------------------------------------------------------------------------
def plot_waveform(changes):
    key = {label: (scope, name) for label, scope, name, _ in SIGNALS}
    rv = changes[key["req_valid"]]
    resp = changes[key["resp_valid"]]

    # Window: first request (T2 cold miss) through the second response (T3 hit).
    t_start = next(t for t, v in rv if v == "1") - 10000
    resp_rises = [t for t, v in resp if v == "1"]
    t_end = resp_rises[1] + 14000

    fig, ax = plt.subplots(figsize=(13, 6.6))
    n = len(SIGNALS)
    for row, (label, scope, name, kind) in enumerate(SIGNALS):
        y0 = (n - 1 - row) * 1.0
        series = [(t, v) for t, v in changes[(scope, name)] if t <= t_end]
        pts = [(t_start, value_at(changes[(scope, name)], t_start))]
        pts += [(t, v) for t, v in series if t > t_start]
        pts.append((t_end, pts[-1][1]))
        ax.text(t_start - 1500, y0 + 0.3, label, ha="right", va="center",
                fontsize=10, family="monospace")
        if kind == "bit":
            xs, ys = [], []
            for i, (t, v) in enumerate(pts):
                level = y0 + (0.6 if v == "1" else 0.0)
                if xs:
                    xs.append(t)
                    ys.append(ys[-1])
                xs.append(t)
                ys.append(level)
            color = "#555555" if label == "clk" else "#1f5fa8"
            ax.plot(xs, ys, color=color, lw=1.4 if label != "clk" else 0.9)
        else:
            # Bus: draw segments with labels.
            segs = []
            for i in range(len(pts) - 1):
                t0, v = pts[i]
                t1 = pts[i + 1][0]
                if t1 <= t0:
                    continue
                if segs and segs[-1][2] == v:
                    segs[-1][1] = t1
                else:
                    segs.append([t0, t1, v])
            for t0, t1, v in segs:
                iv = to_int(v)
                if kind == "state":
                    txt = STATE_NAMES.get(iv, v)
                    fill = {"IDLE": "#eeeeee", "LOOKUP": "#dbe9f7",
                            "MEM_WAIT": "#fde7c8", "RESPOND": "#d8f0d8"}.get(txt, "#ffffff")
                else:
                    txt = "x" if iv is None else f"{iv:X}"
                    fill = "#ffffff"
                ax.add_patch(plt.Polygon(
                    [(t0, y0 + 0.3), (t0 + 600, y0 + 0.6), (t1 - 600, y0 + 0.6),
                     (t1, y0 + 0.3), (t1 - 600, y0), (t0 + 600, y0)],
                    closed=True, facecolor=fill, edgecolor="#1f5fa8", lw=1.0))
                if t1 - t0 > 8000:
                    ax.text((t0 + t1) / 2, y0 + 0.3, txt, ha="center",
                            va="center", fontsize=8.5, family="monospace")

    # Annotate phases.
    miss_resp, hit_resp = resp_rises[0], resp_rises[1]
    top = n + 0.05
    ax.annotate("", xy=(miss_resp + 10000, top), xytext=(t_start + 10000, top),
                arrowprops=dict(arrowstyle="<->", color="#b03030"))
    ax.text((t_start + miss_resp) / 2 + 10000, top + 0.2,
            "Cold miss 0x00000004: mem_req -> wait -> mem_ready + refill -> resp (resp_hit=0)",
            ha="center", fontsize=9.5, color="#b03030")
    hit_start = max(t for t, v in rv if v == "1" and t < hit_resp)
    ax.annotate("", xy=(hit_resp + 10000, top), xytext=(hit_start, top),
                arrowprops=dict(arrowstyle="<->", color="#2a7a2a"))
    ax.text((hit_start + hit_resp + 10000) / 2, top + 0.2, "Repeat: hit, no mem_req",
            ha="center", fontsize=9.5, color="#2a7a2a")

    ax.set_xlim(t_start - 22000, t_end)
    ax.set_ylim(-0.3, n + 0.6)
    ax.set_yticks([])
    ticks = list(range(t_start - t_start % 10000, t_end, 20000))
    ax.set_xticks(ticks)
    ax.set_xticklabels([f"{t // 1000}" for t in ticks], fontsize=8)
    ax.set_xlabel("simulation time (ns), 10 ns clock")
    for s in ("top", "right", "left"):
        ax.spines[s].set_visible(False)
    ax.set_title("Member 04 controller: cold miss then hit (tb_cache_controller T2-T3, LATENCY = 4)",
                 fontsize=11)
    fig.tight_layout()
    for out in (os.path.join(FIG_DIR, "controller_waveform.pdf"),
                os.path.join(FIG_DIR, "controller_waveform.png"), WAVE_PNG):
        fig.savefig(out, dpi=180)
    plt.close(fig)


# --------------------------------------------------------------------------
# FSM diagram
# --------------------------------------------------------------------------
def plot_fsm():
    fig, ax = plt.subplots(figsize=(10, 6.2))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 6.2)
    ax.axis("off")

    pos = {"IDLE": (2.0, 4.6), "LOOKUP": (6.0, 4.6),
           "MEM_WAIT": (6.0, 1.6), "RESPOND": (2.0, 1.6)}
    sub = {"IDLE": "2'd0  req_ready=1", "LOOKUP": "2'd1",
           "MEM_WAIT": "2'd2  mem_req=1", "RESPOND": "2'd3  resp_valid=1"}
    fill = {"IDLE": "#eeeeee", "LOOKUP": "#dbe9f7",
            "MEM_WAIT": "#fde7c8", "RESPOND": "#d8f0d8"}
    w, h = 2.3, 0.9
    for s, (x, y) in pos.items():
        ax.add_patch(FancyBboxPatch((x - w / 2, y - h / 2), w, h,
                                    boxstyle="round,pad=0.05", fc=fill[s],
                                    ec="#1f3f66", lw=1.6))
        ax.text(x, y + 0.13, s, ha="center", va="center", fontsize=13, weight="bold")
        ax.text(x, y - 0.22, sub[s], ha="center", va="center", fontsize=8.5,
                family="monospace")

    def arrow(p, q, label, lx, ly, rad=0.0, color="#1f3f66"):
        ax.add_patch(FancyArrowPatch(p, q, arrowstyle="-|>", mutation_scale=16,
                                     connectionstyle=f"arc3,rad={rad}",
                                     color=color, lw=1.5))
        ax.text(lx, ly, label, ha="center", va="center", fontsize=8.8,
                bbox=dict(fc="white", ec="none", pad=1.5))

    arrow((3.2, 4.6), (4.8, 4.6), "req_valid /\ncapture tag,index,offset", 4.0, 5.25)
    arrow((4.85, 4.2), (3.15, 2.0), "lookup_hit /\nlatch cache byte, resp_hit=1",
          4.0, 3.35)
    arrow((6.0, 4.1), (6.0, 2.1), "!lookup_hit", 6.75, 3.1)
    arrow((4.8, 1.6), (3.2, 1.6),
          "mem_ready /\nrefill_write_en=1 (data,tag,valid)\nlatch refill byte, resp_hit=0",
          4.0, 0.75)
    arrow((1.6, 2.1), (1.6, 4.1), "always", 1.0, 3.1)
    # Self loops.
    arrow((1.4, 5.1), (2.6, 5.1), "!req_valid", 2.0, 5.85, rad=-1.6)
    arrow((6.6, 1.1), (5.4, 1.1), "!mem_ready / hold mem_req, mem_addr", 6.0, 0.25, rad=-1.6)

    ax.text(8.0, 5.4, "reset (any state) -> IDLE", fontsize=9, color="#b03030")
    ax.text(7.45, 4.3,
            "Timing from accept edge:\n  hit  = 2 cycles\n  miss = LATENCY + 4 cycles\n"
            "         (8 with LATENCY=4)\n  miss penalty = LATENCY + 2",
            fontsize=8.8, family="monospace", va="top",
            bbox=dict(fc="#fffbe6", ec="#c9b458"))
    ax.set_title("cache_controller.v FSM (as implemented)", fontsize=12)
    fig.tight_layout()
    for ext in ("pdf", "png"):
        fig.savefig(os.path.join(FIG_DIR, f"controller_fsm.{ext}"), dpi=180)
    plt.close(fig)


def main():
    if not os.path.exists(VCD):
        sys.exit("Run ./scripts/run_cache_controller_test.sh first (VCD missing).")
    wanted = [(scope, name) for _, scope, name, _ in SIGNALS]
    plot_waveform(read_vcd(VCD, wanted))
    plot_fsm()
    print("Wrote controller_fsm.{pdf,png}, controller_waveform.{pdf,png} and", WAVE_PNG)


if __name__ == "__main__":
    main()
