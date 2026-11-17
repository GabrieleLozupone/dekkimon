# Stream benchmark tools (developers only)

These tools measure streaming quality on a Steam Deck. They were used to find the causes of
the stutters and freezes described in [docs/network-optimization.md](../../../docs/network-optimization.md).
Normal users don't need them. Nothing here runs unless you turn it on.

## Turn it on

1. In Steam (Gaming Mode): Dekkimon › Properties › Launch options:

   ```
   DEKKIMON_BENCH=1 %command%
   ```

2. Optional, for Wi-Fi, temperature, clock and power samples, copy the samplers to the Deck:

   ```sh
   scp scripts/dev/bench/session_sampler.sh scripts/dev/bench/keepalive_ab.sh deck@<deck-ip>:Applications/dekkimon/dev/
   ssh deck@<deck-ip> chmod +x Applications/dekkimon/dev/*.sh
   ```

With `DEKKIMON_BENCH=1`, each launch writes to `~/Applications/dekkimon/bench/`:

| File | Content |
| --- | --- |
| `<time>.csv` | One row per second while streaming: bitrate, loss, FEC, frame pacing, decode/render times |
| `<time>.log` | Full app log, including FFmpeg decoder messages and `color pipeline:` lines |
| `<time>.sys.csv` | Per-second Wi-Fi station stats, UDP drops, temperatures, clocks, power (needs `dev/session_sampler.sh`) |

The 40 most recent runs are kept.

## Experiments

If `~/Applications/dekkimon/experiment.conf` exists, its `key=value` lines override the saved
settings for each new stream, without changing them. The keys are:

| Key | Meaning |
| --- | --- |
| `packet_loss_max=<percent>` | Highest packet loss reported to the console (default 5) |
| `idr_on_fec_failure=0\|1` | Ask for a key frame after a frame that couldn't be recovered |
| `reorder_timeout_us=<µs>` | How long to wait for a missing video packet before skipping it (default 16000) |

The applied values are logged in the CSV header (`# config`) and the log.

**Keep-alive A/B test.** Create the empty file `~/Applications/dekkimon/ab-keepalive`, and
`dev/keepalive_ab.sh` alternates 4-minute blocks with and without light gateway pings. The
state is logged in the `keepalive` column of the `.sys.csv` file.

## Read the results

```sh
uv run python scripts/dev/bench/bench_report.py --host deck@<deck-ip> --key ~/.ssh/id_ed25519
uv run python scripts/dev/bench/bench_report.py --local path/to/bench   # files already copied
```

For each session, the report shows the bitrate distribution, packet loss, lost and dropped
frames, the worst seconds, and the colour pipeline with an HDR verdict. It never reads
`Chiaki.conf` or any credentials.

Don't poll the Deck over SSH during a measured stream: the extra Wi-Fi traffic changes the
results.
