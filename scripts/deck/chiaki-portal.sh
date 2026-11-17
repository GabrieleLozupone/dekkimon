#!/bin/bash
# Launcher for the isolated "Chiaki Portal" build on Steam Deck (~/Applications/chiaki-portal).
# Keeps its own config/data/cache, so the Flatpak chiaki-ng install is untouched.
# Every run records per-second stream stats (bench/<time>.csv) and the full log (bench/<time>.log).
set -u
APP_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
export XDG_CONFIG_HOME="$APP_DIR/config"
export XDG_DATA_HOME="$APP_DIR/data"
export XDG_CACHE_HOME="$APP_DIR/cache"
# Bundled libraries are only those the Deck does not ship; system libraries always win
# for everything else because they are not in this directory.
export LD_LIBRARY_PATH="$APP_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export QT_QUICK_CONTROLS_STYLE=Material
# Qt logs to the journal when stderr is not a terminal; keep everything in the bench log.
export QT_FORCE_STDERR_LOGGING=1
# Streaming experiments: key=value overrides applied at every stream start (see
# applyStreamExperiment in gui/src/streamsession.cpp). No file = saved settings only.
export CHIAKI_EXPERIMENT_FILE="$APP_DIR/experiment.conf"
export QT_MESSAGE_PATTERN="%{time h:mm:ss.zzz} %{if-category}%{category}: %{endif}%{message}"

BENCH_DIR="$APP_DIR/bench"
mkdir -p "$BENCH_DIR" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
stamp="$(date +%Y%m%d-%H%M%S)"
export CHIAKI_BENCH_CSV="${CHIAKI_BENCH_CSV:-$BENCH_DIR/$stamp.csv}"
# Keep the 40 most recent runs.
ls -1t "$BENCH_DIR"/*.csv 2>/dev/null | tail -n +41 | xargs -r rm -f
ls -1t "$BENCH_DIR"/*.log 2>/dev/null | tail -n +41 | xargs -r rm -f

{
    echo "# chiaki-portal launch $stamp"
    echo "# gamescope HDR: ENABLE_GAMESCOPE_WSI=${ENABLE_GAMESCOPE_WSI:-unset} DXVK_HDR=${DXVK_HDR:-unset} STEAM_GAMESCOPE_HDR_SUPPORTED=${STEAM_GAMESCOPE_HDR_SUPPORTED:-unset}"
    echo "# args: $*"
} >>"$BENCH_DIR/$stamp.log"
ls -1t "$BENCH_DIR"/*.sys.csv 2>/dev/null | tail -n +41 | xargs -r rm -f
ls -1t "$BENCH_DIR"/*.ka 2>/dev/null | tail -n +41 | xargs -r rm -f
[ -f "$APP_DIR/experiment.conf" ] && sed 's/^/# experiment.conf: /' "$APP_DIR/experiment.conf" >>"$BENCH_DIR/$stamp.log"

"$APP_DIR/bin/chiaki" "$@" >>"$BENCH_DIR/$stamp.log" 2>&1 &
chiaki_pid=$!
# Per-second Wi-Fi / thermal / clock / power samples next to the stream CSV (bench/<stamp>.sys.csv).
if [ -x "$APP_DIR/session_sampler.sh" ]; then
    "$APP_DIR/session_sampler.sh" "$chiaki_pid" "$BENCH_DIR/$stamp.sys.csv" >/dev/null 2>&1 &
fi
# Keep-alive A/B (only while the marker file exists): alternating 4-minute blocks with and
# without 15 ms gateway pings; the state lands in the sys.csv "keepalive" column.
if [ -f "$APP_DIR/ab-keepalive" ] && [ -x "$APP_DIR/keepalive_ab.sh" ]; then
    "$APP_DIR/keepalive_ab.sh" "$chiaki_pid" "$BENCH_DIR/$stamp.ka" >/dev/null 2>&1 &
fi
trap 'kill -TERM "$chiaki_pid" 2>/dev/null' TERM INT HUP
wait "$chiaki_pid"
status=$?
# wait returns early when a trapped signal arrives; wait again for the real exit.
kill -0 "$chiaki_pid" 2>/dev/null && wait "$chiaki_pid" && status=$?
exit "$status"
