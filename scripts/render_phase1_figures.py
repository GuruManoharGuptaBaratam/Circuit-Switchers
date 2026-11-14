#!/usr/bin/env python3
"""Render editable architecture figures and waveform windows from Icarus VCDs."""
import hashlib
import json
from pathlib import Path
from reportlab.pdfgen import canvas

ROOT = Path(__file__).resolve().parents[1]
FIGURES = ROOT / "submission/report/figures"
WAVES = ROOT / "results/waveforms"
INK = "#172840"
BLUE = "#1D609D"
PALE = "#EDF4FB"


def diagram(name, height, nodes, edges):
    pdf = canvas.Canvas(str(FIGURES / f"{name}.pdf"), pagesize=(520, height), invariant=True)
    pdf.setStrokeColor(BLUE)
    for points in edges:
        path = pdf.beginPath()
        path.moveTo(*points[0])
        for point in points[1:]:
            path.lineTo(*point)
        pdf.drawPath(path)
        x, y = points[-1]
        last_x, last_y = points[-2]
        length = ((x - last_x)**2 + (y - last_y)**2)**0.5
        dx, dy = (x - last_x)/length, (y - last_y)/length
        pdf.line(x, y, x - 7*dx + 3*dy, y - 7*dy - 3*dx)
        pdf.line(x, y, x - 7*dx - 3*dy, y - 7*dy + 3*dx)
    for x, y, width, lines in nodes:
        pdf.setFillColor(PALE)
        pdf.roundRect(x, y, width, 46, 5, fill=1)
        pdf.setFillColor(INK)
        for row, line in enumerate(lines):
            pdf.setFont("Helvetica-Bold" if row == 0 else "Helvetica", 13 if row == 0 else 11)
            pdf.drawCentredString(x + width/2, y + 29 - 15*row, line)
    pdf.save()


def load_signals(source, wanted):
    scopes, signals = [], {}
    changes = {name: {} for name in wanted}
    time = 0
    with source.open() as stream:
        for line in stream:
            fields = line.split()
            if not fields:
                continue
            if fields[0] == "$scope":
                scopes.append(fields[2])
            elif fields[0] == "$upscope":
                scopes.pop()
            elif fields[0] == "$var" and scopes[-1] == "dut" and fields[4] in wanted:
                signals[fields[3]] = fields[4]
            elif fields[0] == "$enddefinitions":
                break
        if set(signals.values()) != set(wanted):
            raise ValueError(f"Missing VCD signals in {source}")
        for line in stream:
            value = line.strip()
            if not value or value.startswith("$"):
                continue
            if value[0] == "#":
                time = int(value[1:]) / 1000  # Bench VCD resolution is 1 ps.
            else:
                bits, code = value[1:].split() if value[0] == "b" else (value[0], value[1:])
                if code in signals:
                    changes[signals[code]][time] = bits
    return changes


def waveform(name, workload, end, labels):
    names = ("clk", "reset", "req_valid", "req_ready", "active_tag", "active_index",
             "mem_req", "mem_addr", "mem_ready", "refill_write_en",
             "resp_valid", "resp_hit", "resp_data")
    events = load_signals(WAVES / f"{workload}_system_final.vcd", names)
    start = 5
    left, right, bottom, spacing = 104, 590, 29, 19
    top = bottom + spacing*len(names)
    pdf = canvas.Canvas(str(FIGURES / f"{name}.pdf"), pagesize=(602, top + 29), invariant=True)

    def x(time):
        return left + (time-start)/(end-start)*(right-left)

    pdf.setFont("Helvetica", 11)
    for tick in range(20, end + 1, 20):
        pdf.setStrokeColor("#DBE4ED")
        pdf.line(x(tick), bottom, x(tick), top)
        pdf.setFillColor(INK)
        pdf.drawCentredString(x(tick), 15, str(tick))
    pdf.drawRightString(left - 9, 15, "Time (ns)")
    for time, label in labels:
        pdf.setFillColor(INK)
        pdf.setFont("Helvetica-Bold", 11)
        pdf.drawCentredString(x(time), top + 12, label)
    buses = {"active_tag": 1, "active_index": 1, "mem_addr": 8, "resp_data": 2}
    for row, signal in enumerate(names):
        y = top - spacing*(row+1) + 4
        pdf.setFont("Helvetica", 12)
        pdf.setFillColor(INK)
        pdf.drawRightString(left - 8, y + 2, signal)
        pdf.setStrokeColor(BLUE)
        values = events[signal]
        value = next((val for time, val in reversed(list(values.items())) if time <= start), "x")
        segments = [(start, value)] + [(time, val) for time, val in values.items() if start < time < end]
        segments.append((end, value))
        for (t0, val), (t1, _) in zip(segments, segments[1:]):
            x0, x1 = x(t0), x(t1)
            if signal in buses:
                pdf.line(x0, y, x1, y)
                pdf.line(x0, y+12, x1, y+12)
                pdf.line(x0, y, x0, y+12)
                pdf.setFont("Helvetica", 11)
                label = f"{int(val, 2):0{buses[signal]}X}" if set(val) <= {"0", "1"} else "X"
                if x1-x0 > pdf.stringWidth(label, "Helvetica", 11) + 4:
                    pdf.drawCentredString((x0+x1)/2, y+2, label)
            else:
                level = {"0": 0, "1": 12}.get(val, 6)
                if val not in ("0", "1"):
                    pdf.line(x0, y, x0, y+12)
                if t0 != start:
                    pdf.line(x0, y+previous_level, x0, y+level)
                pdf.line(x0, y+level, x1, y+level)
                previous_level = level
    pdf.save()


def main():
    diagram("system_architecture", 216, [
        (8, 159, 153, ("Processor", "request / response")),
        (183, 159, 154, ("Address decoder", "22 / 6 / 4 bits")),
        (354, 159, 158, ("Cache controller", "one outstanding read")),
        (8, 65, 153, ("Lookup + selectors", "tag/valid and byte lanes")),
        (183, 65, 154, ("Cache storage", "64 data/tag/valid entries")),
        (354, 65, 158, ("Memory model", "16-byte block handshake")),
    ], [
        [(161, 183), (183, 183)], [(337, 183), (354, 183)],
        [(437, 159), (437, 111)], [(451, 111), (451, 159)],
        [(402, 159), (402, 136), (260, 136), (260, 111)],
        [(183, 88), (161, 88)], [(84, 65), (84, 43), (516, 43), (516, 178), (512, 178)],
        [(354, 72), (341, 72), (341, 31), (53, 31), (53, 65)],
        [(477, 205), (477, 213), (84, 213), (84, 205)],
    ])
    # The bottom feedback line returns selected bytes to the controller.
    diagram("cache_hit_miss_flow", 325, [
        (130, 269, 260, ("Accept request", "Capture tag, index and offset")),
        (130, 202, 260, ("Read selected cache line", "Valid bit set and tags equal?")),
        (8, 116, 234, ("Hit", "Latch selected cached byte")),
        (278, 116, 234, ("Miss", "Request aligned block; wait for ready")),
        (278, 57, 234, ("Refill", "Write data/tag/valid; latch refill byte")),
        (130, 3, 260, ("Respond for one cycle", "Return byte and hit flag")),
    ], [
        [(260, 269), (260, 248)], [(190, 202), (125, 162)],
        [(330, 202), (395, 162)], [(395, 116), (395, 103)],
        [(125, 116), (125, 71), (188, 71), (188, 49)],
        [(385, 57), (385, 49)],
    ])
    diagram("module_connections", 274, [
        (172, 222, 176, ("cache_controller", "active fields + control")),
        (6, 139, 158, ("Data/tag/valid RAM", "read and refill at active_index")),
        (180, 139, 160, ("cache_lookup", "contains tag_comparator")),
        (354, 139, 160, ("main_memory_model", "mem_req, mem_addr, mem_ready")),
        (6, 53, 158, ("Cached data_selector", "stored_block + active_offset")),
        (354, 53, 160, ("Refill data_selector", "mem_block + active_offset")),
        (180, 3, 160, ("Controller inputs", "cache and refill bytes")),
    ], [
        [(205, 222), (205, 203), (85, 203), (85, 185)],
        [(260, 222), (260, 185)], [(273, 185), (273, 222)],
        [(315, 222), (315, 204), (420, 204), (420, 185)],
        [(448, 185), (448, 212), (327, 212), (327, 222)],
        [(164, 162), (180, 162)], [(85, 139), (85, 99)], [(434, 139), (434, 99)],
        [(434, 139), (434, 122), (140, 122), (140, 139)],
        [(85, 53), (85, 26), (180, 26)], [(434, 53), (434, 26), (340, 26)],
    ])
    waveform("system_miss_hit", "repeated", 129, [(53, "Cold miss and refill"), (113, "Repeat hit")])
    waveform("system_conflict", "conflict", 189, [(49, "Install tag 0"), (142, "Replace with tag 1")])
    inputs = {
        "system_miss_hit": "repeated_system_final.vcd",
        "system_conflict": "conflict_system_final.vcd",
    }
    manifest = {}
    for figure in sorted(FIGURES.glob("*.pdf")):
        record = {"pdf_sha256": hashlib.sha256(figure.read_bytes()).hexdigest()}
        if figure.stem in inputs:
            source = WAVES / inputs[figure.stem]
            record.update(vcd=str(source.relative_to(ROOT)),
                          vcd_sha256=hashlib.sha256(source.read_bytes()).hexdigest())
        manifest[figure.stem] = record
    (FIGURES / "render_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")



if __name__ == "__main__":
    main()
