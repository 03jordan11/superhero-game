"""Summarize raw frames from one accepted fixed-camera forest/traffic benchmark."""
import json
import math
import statistics
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parents[1]
label = sys.argv[1] if len(sys.argv) > 1 else "before_traffic_removal_verified"
folder = ROOT / "artifacts" / "forest_traffic_baseline"
report = json.loads((folder / f"{label}.json").read_text(encoding="utf-8-sig"))
assert report.get("valid_baseline"), "Incomplete or rejected baseline"
groups = {}
for sample in report["scenarios"]:
    key = (sample["view"], sample["forests_enabled"])
    group = groups.setdefault(key, {"samples": [], "rows": []})
    group["samples"].append(sample)
    raw = ROOT / sample["raw_samples"].removeprefix("res://")
    group["rows"].extend(json.loads(raw.read_text(encoding="utf-8")))

summary = []
for (view, enabled), group in groups.items():
    assert len(group["samples"]) == report["config"]["trials"]
    rows = group["rows"]
    stats = {}
    for key in rows[0]:
        values = sorted(row[key] for row in rows)
        stats[key] = {
            "mean": statistics.fmean(values),
            "p95": values[math.ceil(len(values) * .95) - 1],
            "p99": values[math.ceil(len(values) * .99) - 1],
        }
    summary.append({
        "view": view, "forests_enabled": enabled, "frames": len(rows),
        "fps": 1000 / stats["frame_ms"]["mean"], "stats": stats,
        "trial_fps": [s["fps"] for s in group["samples"]],
        "population_endpoints": [{"start": s["population_start"], "end": s["population_end"]}
                                 for s in group["samples"]],
    })

gains = {}
for view in {entry["view"] for entry in summary}:
    on = next(s for s in summary if s["view"] == view and s["forests_enabled"])
    off = next(s for s in summary if s["view"] == view and not s["forests_enabled"])
    gains[view] = {"fps_gain_percent": (off["fps"] / on["fps"] - 1) * 100,
                   "frame_time_reduction_percent": (1 - off["stats"]["frame_ms"]["mean"] /
                                                       on["stats"]["frame_ms"]["mean"]) * 100}
output = {"label": label, "scenarios": summary, "gains": gains}
(folder / f"{label}_summary.json").write_text(json.dumps(output, indent=2), encoding="utf-8")

lines = [f"# {label}", "", "RTX 4090; Godot 4.7.2 Forward+/D3D12; 2560×1440; 17:00; "
         "100% render scale; shadows/bloom off; Low crowd/vehicle density; uncapped, VSync off.", "",
         "Three 8-second trials per state/view, pooled from raw frame samples. "
         "Only northern/coastal tree visibility changes; traffic remains running.", "",
         "| View | Forests | FPS | Frame ms | P95 ms | P99 ms | Render CPU ms | GPU ms | Physics tick ms | Draw calls | Objects | Primitives | Render MiB |",
         "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
for entry in summary:
    s = entry["stats"]
    lines.append(f"| {entry['view']} | {'On' if entry['forests_enabled'] else 'Off'} | "
                 f"{entry['fps']:.1f} | {s['frame_ms']['mean']:.2f} | {s['frame_ms']['p95']:.2f} | "
                 f"{s['frame_ms']['p99']:.2f} | {s['render_cpu_ms']['mean']:.2f} | "
                 f"{s['gpu_ms']['mean']:.2f} | {s['physics_tick_ms']['mean']:.2f} | "
                 f"{s['draw_calls']['mean']:.0f} | {s['rendered_objects']['mean']:.0f} | "
                 f"{s['primitives']['mean']:.0f} | {s['render_memory_mib']['mean']:.0f} |")
lines += ["", "## Forests-off differences", ""]
for view, gain in gains.items():
    lines.append(f"- {view}: FPS **+{gain['fps_gain_percent']:.1f}%**; "
                 f"frame time **−{gain['frame_time_reduction_percent']:.1f}%**.")
lines += ["", "Simulation remains live, so actor counts/poses vary between trials. "
          "Player locomotion is frozen. Physics is per-tick time; CPU/GPU timings overlap and must not be added. "
          "Hiding trees does not unload their resources or nodes. "
          "These controlled views are not a guarantee of traversal FPS. "
          "The traffic-removal after measurement has not been run.", "",
          "Raw reports, per-frame samples, actor counts, configuration, source hashes and comparison "
          "screenshots are beside this file. The earlier unverified run was rejected due to disabled GPU timing."]
destination = folder / f"{label}_summary.md"
destination.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("\n".join(lines))
