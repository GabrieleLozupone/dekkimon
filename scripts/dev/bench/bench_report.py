"""Pull and summarise Dekkimon stream benchmarks from a Steam Deck.

    uv run python scripts/dev/bench/bench_report.py --host deck@<deck-ip> --key ~/.ssh/id_ed25519
    uv run python scripts/dev/bench/bench_report.py --local path/to/bench   # already copied

Each launch of the Deck build writes bench/<time>.csv (one row per second while streaming)
and bench/<time>.log (full app log incl. "color pipeline:" lines). This prints, per session:
bitrate distribution, packet loss, lost/dropped frames, the worst seconds, and the colour
pipeline with a plain-language HDR verdict. Only standard library; credentials are never read.
"""
import argparse, csv, os, re, statistics, subprocess, sys, tempfile
from pathlib import Path

REMOTE_DIR = "Applications/dekkimon/bench"


def pull(host, key, dest):
    dest.mkdir(parents=True, exist_ok=True)
    cmd = ["scp", "-q", "-o", "BatchMode=yes"]
    if key:
        cmd += ["-i", os.path.expanduser(key)]
    cmd += [f"{host}:{REMOTE_DIR}/*", str(dest)]
    subprocess.run(cmd, check=True)


def pct(values, q):
    if not values:
        return 0.0
    v = sorted(values)
    return v[min(len(v) - 1, max(0, round(q * (len(v) - 1))))]


def sessions(path):
    """Split a CSV file into sessions at '# session start' markers."""
    current, out = None, []
    header = None
    with open(path, newline="", encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("wall_time,"):
                header = next(csv.reader([line]))
                continue
            if line.startswith("# session start"):
                current = {"start": line.split("start", 1)[1].strip(), "rows": [], "summary": "", "config": ""}
                out.append(current)
                continue
            if line.startswith("# config") and current:
                current["config"] = line[len("# config"):].strip()
                continue
            if line.startswith("# Benchmark summary") and current:
                current["summary"] = line[2:].strip()
                continue
            if line.startswith("#") or not line.strip() or header is None:
                continue
            if current is None:
                current = {"start": "?", "rows": [], "summary": "", "config": ""}
                out.append(current)
            current["rows"].append(dict(zip(header, next(csv.reader([line])))))
    return out


def hdr_advice(line):
    if "tone-mapped to SDR output" in line:
        return ("The PS5 sends HDR but the Deck output is SDR, so libplacebo tone-maps it down. "
                "Enable HDR in Steam > Settings > Display (and 'HDR' for this shortcut), and "
                "make sure the PS5 has HDR on with 'Adjust HDR' calibrated.")
    if "HDR passthrough" in line:
        m = re.search(r"swapchain \S+ luma [\d.e-]+-(\d+) nits", line)
        peak = f" (display target peak {m.group(1)} nits)" if m else ""
        return ("HDR reaches the display end to end" + peak + ". If highlights clip or the image looks "
                "flat, re-run the PS5 HDR calibration on the Deck itself and compare tonemap settings.")
    if "SDR source on HDR output" in line:
        return "The PS5 is sending SDR. Turn HDR on in the PS5 video output settings (HDR: On When Supported)."
    return "SDR end to end."


def load_sys(path):
    """bench/<stamp>.sys.csv from session_sampler.sh, keyed by wall-clock second."""
    if not path.exists():
        return {}
    with open(path, newline="", encoding="utf-8", errors="replace") as f:
        return {r["wall_time"][:19]: r for r in csv.DictReader(f)}


def _num(v):
    try:
        return float(str(v).split()[0])
    except (ValueError, IndexError):
        return None


def correlate(rows, bad, sysrows):
    """Print Wi-Fi/thermal/clock state around loss seconds versus the clean seconds."""
    keys = sorted(sysrows)

    def at(wall, off=0):
        i = next((k for k, key in enumerate(keys) if key >= wall[:19]), None)
        if i is None:
            return None
        return sysrows[keys[max(0, min(len(keys) - 1, i + off))]]

    def delta(wall, col):
        a, b = at(wall, -1), at(wall, 0)
        if not a or not b or _num(a[col]) is None or _num(b[col]) is None:
            return None
        return _num(b[col]) - _num(a[col])

    def summary(sel, label):
        if not sel:
            return
        sig = [_num(at(r["wall_time"])["wifi_signal"]) for r in sel if at(r["wall_time"])]
        sig = [v for v in sig if v is not None]
        rxd = [delta(r["wall_time"], "wifi_rx_drop_misc") for r in sel]
        drops = [delta(r["wall_time"], "chiaki_udp_drops") for r in sel]
        rxd = [v for v in rxd if v is not None]
        drops = [v for v in drops if v is not None]
        print(f"   {label:<12} signal dBm min {min(sig) if sig else '-':>5}  avg {statistics.mean(sig) if sig else 0:6.1f}"
              f"   wifi rx drops/s {statistics.mean(rxd) if rxd else 0:6.1f}   chiaki socket overflow/s {statistics.mean(drops) if drops else 0:5.1f}")

    print("system during the session (session_sampler):")
    summary([r for r in rows if r not in bad], "clean secs")
    summary(bad, "loss secs")
    for r in sorted(bad, key=lambda r: -int(r["frames_lost_delta"]))[:5]:
        s = at(r["wall_time"])
        if not s:
            continue
        print(f"   {r['wall_time'][11:19]}  freq {s['wifi_freq']}  sig {s['wifi_signal']}  rx {s['wifi_rx_rate']}"
              f"  rxdrop+{delta(r['wall_time'], 'wifi_rx_drop_misc') or 0:.0f}  sockdrop+{delta(r['wall_time'], 'chiaki_udp_drops') or 0:.0f}"
              f"  cpu {s['cpu_mhz']}MHz gpu {s['gpu_mhz']}MHz  apu {s['apu_c']}C wifi {s['wifi_c']}C  {s['apu_w']}W")
    freqs = {s["wifi_freq"] for s in sysrows.values() if s["wifi_freq"]}
    if len(freqs) > 1:
        print("   !! Wi-Fi channel changed during the session:", ", ".join(sorted(freqs)), "(DFS radar move or roam)")
    temps = [_num(s["apu_c"]) for s in sysrows.values() if _num(s["apu_c"]) is not None]
    if temps:
        print(f"   APU temperature {min(temps):.0f}-{max(temps):.0f} C")


def _i(r, col):
    v = _num(r.get(col, ""))
    return v if v is not None else 0.0


def per_second_drops(r):
    """Render drops in this second. Older CSVs wrote the per-second count into dropped_frames."""
    return _i(r, "dropped_delta") if "replaced" in r else _i(r, "dropped_frames")


def bursts(rows, gap=5):
    """Indices of the first second of each loss burst (loss seconds closer than `gap` s merge)."""
    out, prev = [], -99
    for i, r in enumerate(rows):
        if _i(r, "frames_lost_delta") > 0 or _i(r, "packet_loss_pct") > 1.0:
            if i - prev > gap:
                out.append(i)
            prev = i
    return out


QUIET_MBPS, QUIET_SECS = 1.5, 5


def quiet_resumes(rows):
    """Indices where the bitrate comes back (> 3 Mbps) after >= QUIET_SECS seconds below QUIET_MBPS."""
    out, run = [], 0
    for i, r in enumerate(rows):
        b = _i(r, "bitrate_mbps")
        if b < QUIET_MBPS:
            run += 1
        else:
            if run >= QUIET_SECS and b > 3.0:
                out.append(i)
            run = 0
    return out


def internals(rows, config=""):
    """FEC, console bitrate target, reorder skips and render pacing (new CSV columns only)."""
    if not rows or "fec_units" not in rows[0]:
        return
    src = sum(_i(r, "src_units") for r in rows)
    fec = sum(_i(r, "fec_units") for r in rows)
    print(f"FEC            overhead {fec / src if src else 0:.3f} (fec/source units)   recovered {sum(_i(r, 'fec_recovered') for r in rows):.0f}"
          f"   failed {sum(_i(r, 'fec_failed') for r in rows):.0f} frames")
    pre = set()
    for b in bursts(rows):
        pre.update(range(max(0, b - 10), b))
    if pre:
        ps = sum(_i(rows[i], "src_units") for i in pre)
        pf = sum(_i(rows[i], "fec_units") for i in pre)
        print(f"               overhead in the 10 s before loss bursts {pf / ps if ps else 0:.3f}")
    tgt = [_i(r, "target_bitrate") for r in rows if _i(r, "target_bitrate") > 0]
    if tgt:
        print(f"console target bitrate (raw units)  p05 {pct(tgt, .05):.0f}  median {pct(tgt, .5):.0f}  p95 {pct(tgt, .95):.0f}"
              f"   rtt median {pct([_i(r, 'rtt') for r in rows], .5):.2f}")
    sk = sum(_i(r, "video_skipped") for r in rows)
    late = sum(_i(r, "video_late") for r in rows)
    print(f"reorder        skipped {sk:.0f} packets, {late:.0f} arrived late ({late / sk if sk else 0:.0%} of skipped)")
    meas = [_i(r, "loss_measured_pct") for r in rows]
    m = re.search(r"packet_loss_max=([\d.]+)", config)
    cap = float(m.group(1)) if m else 5.0
    print(f"loss measured  max {max(meas):.1f}%   seconds above the reported cap ({cap:g}%): "
          f"{sum(1 for v in meas if v > cap)}")
    arrived = sum(_i(r, "arrived") for r in rows)
    shown = sum(_i(r, "shown") for r in rows)
    repl = sum(_i(r, "replaced") for r in rows)
    late_s = sum(_i(r, "show_late") for r in rows)
    bunched = sum(_i(r, "arrive_bunched") for r in rows)
    print(f"pacing         decoded {arrived:.0f}  shown {shown:.0f}  replaced {repl:.0f} ({repl / arrived if arrived else 0:.2%})"
          f"   decoder bursts (<4 ms) {bunched:.0f}   render pickups >25 ms {late_s:.0f}")
    print(f"               max gaps p99/max: decode {pct([_i(r, 'arrive_gap_max_ms') for r in rows], .99):.0f}/{max(_i(r, 'arrive_gap_max_ms') for r in rows):.0f} ms"
          f"   gui handoff {pct([_i(r, 'handoff_max_ms') for r in rows], .99):.0f}/{max(_i(r, 'handoff_max_ms') for r in rows):.0f} ms"
          f"   render {pct([_i(r, 'show_gap_max_ms') for r in rows], .99):.0f}/{max(_i(r, 'show_gap_max_ms') for r in rows):.0f} ms")


def ab_rows(rows, sysrows):
    """Attach the keep-alive state (sys.csv 'keepalive') to each stream second; None if absent."""
    if not sysrows or "keepalive" not in next(iter(sysrows.values())):
        return None
    keys = sorted(sysrows)
    out, j = [], 0
    for r in rows:
        w = r["wall_time"][:19]
        while j + 1 < len(keys) and keys[j + 1] <= w:
            j += 1
        out.append(sysrows[keys[j]].get("keepalive", "").strip())
    return out


def ab_collect(acc, rows, states, sysrows):
    keys = sorted(sysrows)
    for st in ("0", "1"):
        idx = [i for i, s in enumerate(states) if s == st]
        if not idx:
            continue
        a = acc.setdefault(st, {"secs": 0, "loss_secs": 0, "lost": 0, "bursts": 0, "resumes": 0,
                                "resumes_hit": 0, "quiet_mcs": [], "busy_mcs": []})
        a["secs"] += len(idx)
        a["loss_secs"] += sum(1 for i in idx if _i(rows[i], "frames_lost_delta") > 0 or _i(rows[i], "packet_loss_pct") > 1.0)
        a["lost"] += sum(_i(rows[i], "frames_lost_delta") for i in idx)
        a["bursts"] += sum(1 for b in bursts(rows) if states[b] == st)
        for q in quiet_resumes(rows):
            if states[q] != st:
                continue
            a["resumes"] += 1
            if any(_i(rows[k], "frames_lost_delta") > 0 or _i(rows[k], "packet_loss_pct") > 1.0
                   for k in range(q, min(len(rows), q + 4))):
                a["resumes_hit"] += 1
        for i in idx:
            s = sysrows.get(rows[i]["wall_time"][:19])
            m = re.search(r"mcs(\d+)", (s or {}).get("wifi_rx_rate", "") or "")
            if m:
                (a["quiet_mcs"] if _i(rows[i], "bitrate_mbps") < QUIET_MBPS else a["busy_mcs"]).append(int(m.group(1)))


def ab_print(acc):
    if not acc:
        return
    print("\n=== keep-alive A/B (all sessions above; 1 = 15 ms gateway pings, 0 = none)")
    print("state  stream-min  loss-secs/h  frames-lost/h  bursts/h  quiet->active resumes  hit by loss  rx MCS median quiet/busy")
    for st in ("0", "1"):
        a = acc.get(st)
        if not a or not a["secs"]:
            continue
        h = a["secs"] / 3600
        qm = statistics.median(a["quiet_mcs"]) if a["quiet_mcs"] else "-"
        bm = statistics.median(a["busy_mcs"]) if a["busy_mcs"] else "-"
        print(f"  {st}    {a['secs'] / 60:9.1f}  {a['loss_secs'] / h:11.1f}  {a['lost'] / h:13.1f}  {a['bursts'] / h:8.1f}"
              f"  {a['resumes']:21d}  {a['resumes_hit']:4d} ({a['resumes_hit'] / a['resumes'] if a['resumes'] else 0:.0%})   {qm} / {bm}")
    print("  Needs roughly 30+ minutes per state with several menu/static pauses before the difference means anything.")


def report(folder):
    csvs = sorted(p for p in Path(folder).glob("*.csv") if not p.name.endswith(".sys.csv"))
    if not csvs:
        print("No benchmark CSV files found in", folder)
        return
    ab_acc = {}
    for path in csvs:
        log = path.with_suffix(".log")
        colour = []
        if log.exists():
            colour = [l.split("color pipeline:", 1)[1].strip()
                      for l in log.read_text(encoding="utf-8", errors="replace").splitlines() if "color pipeline:" in l]
        for s in sessions(path):
            rows = [r for r in s["rows"] if r.get("connected") == "1"]
            if not rows:
                continue
            bitrate = [float(r["bitrate_mbps"]) for r in rows if float(r["bitrate_mbps"]) > 0]
            loss = [float(r["packet_loss_pct"]) for r in rows]
            lost = sum(int(r["frames_lost_delta"]) for r in rows)
            dropped = int(sum(per_second_drops(r) for r in rows))
            bad = [r for r in rows if int(r["frames_lost_delta"]) > 0 or float(r["packet_loss_pct"]) > 1.0]
            print(f"\n=== {path.name}  session {s['start']}  ({len(rows)} s connected)")
            if s.get("config"):
                print("config:", s["config"])
            if bitrate:
                print(f"bitrate Mbps   p05 {pct(bitrate, .05):6.1f}   avg {statistics.mean(bitrate):6.1f}   p95 {pct(bitrate, .95):6.1f}")
            print(f"packet loss %  avg {statistics.mean(loss):6.2f}   p95 {pct(loss, .95):6.2f}   max {max(loss):6.2f}")
            print(f"frames lost {lost}   dropped (render) {dropped}   seconds with loss/lost frames {len(bad)}")
            for r in sorted(bad, key=lambda r: -int(r["frames_lost_delta"]))[:5]:
                print(f"   t={r['t_s']:>6}s  lost {r['frames_lost_delta']:>3}  loss {r['packet_loss_pct']}%  bitrate {r['bitrate_mbps']}  queue {r['queue_depth_avg']}")
            internals(rows, s.get("config", ""))
            sysrows = load_sys(path.with_name(path.stem + ".sys.csv"))
            if sysrows:
                correlate(rows, bad, sysrows)
                states = ab_rows(rows, sysrows)
                if states:
                    ab_collect(ab_acc, rows, states, sysrows)
            pipes = [r["color_pipeline"] for r in rows if r.get("color_pipeline")] or colour
            for p in dict.fromkeys(pipes):
                print("colour:", p)
                print("  ->", hdr_advice(p))
            if s["summary"]:
                print(s["summary"])
    ab_print(ab_acc)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", help="ssh target, e.g. deck@<deck-ip>")
    ap.add_argument("--key", help="ssh private key path (only passed to scp)")
    ap.add_argument("--local", help="folder with already-copied bench files")
    a = ap.parse_args()
    if a.local:
        folder = Path(a.local)
    elif a.host:
        folder = Path(tempfile.gettempdir()) / "dekkimon-bench"
        pull(a.host, a.key, folder)
        print("Copied to", folder)
    else:
        ap.error("--host or --local is required")
    report(folder)


if __name__ == "__main__":
    sys.exit(main())
